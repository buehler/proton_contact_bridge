package ch.cbue.proton_go_api_bridge;

import android.content.Context;
import android.os.Build;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyPermanentlyInvalidatedException;
import android.security.keystore.KeyProperties;
import android.util.AtomicFile;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.Key;
import java.security.KeyStore;
import java.security.MessageDigest;
import java.util.Arrays;
import javax.crypto.AEADBadTagException;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** Android-only backend for Go's synchronous SecureStorage interface. */
public final class AndroidSecureStorage {
    private static final Object LOCK = new Object();
    private static final String NAMESPACE = "ch.cbue.protonContactBridge.secure_storage";
    private static final String KEY_ALIAS = NAMESPACE + ".aes256.v1";
    private static final byte[] MAGIC = {'P', 'C', 'B', 'S'};
    private static final byte VERSION = 1;
    private static final int NONCE_SIZE = 12;
    private static final int TAG_BITS = 128;
    private static final int HEADER_SIZE = MAGIC.length + 1;
    private static final int OVERHEAD = HEADER_SIZE + NONCE_SIZE + TAG_BITS / 8;
    // Bound allocations when reading damaged files. These are credentials,
    // not attachments; the same limit applies to writes.
    private static final int MAX_VALUE_SIZE = 16 * 1024 * 1024;
    private static final String RECORD_NAME = "[0-9a-f]{64}\\.bin(?:\\.bak|\\.new)?";

    // Keep in sync with src/storage/android_storage.h. Each response starts
    // with one status byte, followed by raw data only on success.
    private static final int OK = 0;
    private static final int NOT_FOUND = 1;
    private static final int CORRUPT = 3;
    private static final int KEY_UNAVAILABLE = 4;
    private static final int KEYSTORE = 5;
    private static final int IO = 6;
    private static final int UNSUPPORTED_VERSION = 9;
    private static final int AUTHENTICATION = 10;
    private static final int ACCESS = 11;
    private static final int TOO_LARGE = 12;

    private final Context context;

    AndroidSecureStorage(Context context) {
        this.context = context.getApplicationContext();
    }

    public byte[] execute(int operation, byte[] key, byte[] value) {
        synchronized (LOCK) {
            try {
                File directory = directory();
                switch (operation) {
                    case 0:
                        return new byte[] {OK, (byte) (exists(record(directory, key)) ? 1 : 0)};
                    case 1:
                        write(directory, key, value);
                        return new byte[] {OK};
                    case 2:
                        byte[] plaintext = read(directory, key);
                        try {
                            byte[] response = new byte[plaintext.length + 1];
                            System.arraycopy(plaintext, 0, response, 1, plaintext.length);
                            return response;
                        } finally {
                            Arrays.fill(plaintext, (byte) 0);
                        }
                    case 3:
                        deleteRecord(record(directory, key));
                        return new byte[] {OK};
                    case 4:
                        deleteAll(directory);
                        return new byte[] {OK};
                    default:
                        return new byte[] {CORRUPT};
                }
            } catch (StorageFailure failure) {
                return new byte[] {(byte) failure.status};
            } catch (AEADBadTagException failure) {
                return new byte[] {AUTHENTICATION};
            } catch (KeyPermanentlyInvalidatedException failure) {
                return new byte[] {KEY_UNAVAILABLE};
            } catch (GeneralSecurityException failure) {
                return new byte[] {KEYSTORE};
            } catch (IOException failure) {
                return new byte[] {IO};
            } catch (SecurityException failure) {
                return new byte[] {ACCESS};
            } finally {
                Arrays.fill(value, (byte) 0);
            }
        }
    }

    private File directory() throws IOException {
        if (Build.VERSION.SDK_INT >= 24 && context.isDeviceProtectedStorage()) {
            throw new IOException("Credential-protected storage required");
        }
        File base = context.getNoBackupFilesDir();
        if (base == null) throw new IOException("No backup directory unavailable");
        File directory = new File(base, "proton_contact_bridge/secure_storage");
        if (!directory.isDirectory() && !directory.mkdirs() && !directory.isDirectory()) {
            throw new IOException("Storage directory unavailable");
        }
        if (!directory.canRead() || !directory.canWrite()) {
            throw new IOException("Storage directory inaccessible");
        }
        return directory;
    }

    private static File record(File directory, byte[] key) throws GeneralSecurityException {
        byte[] digest = MessageDigest.getInstance("SHA-256").digest(key);
        char[] hex = new char[digest.length * 2];
        final char[] digits = "0123456789abcdef".toCharArray();
        for (int i = 0; i < digest.length; i++) {
            int value = digest[i] & 0xff;
            hex[i * 2] = digits[value >>> 4];
            hex[i * 2 + 1] = digits[value & 0xf];
        }
        return new File(directory, new String(hex) + ".bin");
    }

    private static boolean exists(File file) {
        // AtomicFile may have a committed backup after an interrupted write
        // on older Android versions. A lone .new file is not committed data.
        return file.exists() || new File(file.getPath() + ".bak").exists();
    }

    private static File[] records(File directory) throws IOException {
        File[] files = directory.listFiles((parent, name) -> name.matches(RECORD_NAME));
        if (files == null) throw new IOException("Cannot list stored records");
        return files;
    }

    private static KeyStore keyStore() throws GeneralSecurityException, IOException {
        KeyStore store = KeyStore.getInstance("AndroidKeyStore");
        store.load(null);
        return store;
    }

    private static SecretKey encryptionKey(File directory, boolean create)
            throws GeneralSecurityException, IOException, StorageFailure {
        KeyStore store = keyStore();
        Key key = store.getKey(KEY_ALIAS, null);
        if (key != null) {
            if (!(key instanceof SecretKey) || !"AES".equals(key.getAlgorithm())) {
                throw new StorageFailure(KEY_UNAVAILABLE);
            }
            return (SecretKey) key;
        }
        if (!create || store.containsAlias(KEY_ALIAS) || records(directory).length != 0) {
            throw new StorageFailure(KEY_UNAVAILABLE);
        }

        KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,
                "AndroidKeyStore");
        generator.init(new KeyGenParameterSpec.Builder(KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setKeySize(256)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .setUserAuthenticationRequired(false)
                .build());
        return generator.generateKey();
    }

    private static byte[] header() {
        return ByteBuffer.allocate(HEADER_SIZE).put(MAGIC).put(VERSION).array();
    }

    private static void authenticate(Cipher cipher, byte[] header, byte[] key) {
        cipher.updateAAD(header);
        cipher.updateAAD(NAMESPACE.getBytes(StandardCharsets.UTF_8));
        cipher.updateAAD(new byte[] {0});
        cipher.updateAAD(key);
    }

    private static void write(File directory, byte[] key, byte[] value)
            throws GeneralSecurityException, IOException, StorageFailure {
        if (value.length > MAX_VALUE_SIZE) throw new StorageFailure(TOO_LARGE);
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE, encryptionKey(directory, true));
        byte[] nonce = cipher.getIV();
        if (nonce == null || nonce.length != NONCE_SIZE) throw new StorageFailure(KEYSTORE);
        byte[] header = header();
        authenticate(cipher, header, key);
        byte[] ciphertext = cipher.doFinal(value);

        File file = record(directory, key);
        AtomicFile atomic = new AtomicFile(file);
        FileOutputStream output = null;
        try {
            output = atomic.startWrite();
            output.write(header);
            output.write(nonce);
            output.write(ciphertext);
            // AtomicFile logs sync failures instead of throwing them. Sync
            // explicitly while rollback is still possible.
            output.getFD().sync();
            atomic.finishWrite(output);
            // finishWrite also logs rename failures. Detect them on both the
            // older .bak implementation and the newer .new implementation.
            if (!file.isFile() || new File(file.getPath() + ".new").exists()
                    || new File(file.getPath() + ".bak").exists()) {
                throw new IOException("Atomic write did not complete");
            }
            output = null;
        } finally {
            if (output != null) atomic.failWrite(output);
        }
    }

    private static byte[] read(File directory, byte[] key)
            throws IOException, GeneralSecurityException, StorageFailure {
        File file = record(directory, key);
        byte[] data;
        try (FileInputStream input = new AtomicFile(file).openRead()) {
            long length = input.getChannel().size();
            if (length < OVERHEAD || length > MAX_VALUE_SIZE + OVERHEAD) {
                throw new StorageFailure(CORRUPT);
            }
            data = new byte[(int) length];
            int offset = 0;
            while (offset < data.length) {
                int count = input.read(data, offset, data.length - offset);
                if (count < 0) throw new StorageFailure(CORRUPT);
                offset += count;
            }
            if (input.read() != -1) throw new StorageFailure(CORRUPT);
        } catch (FileNotFoundException failure) {
            if (exists(file)) throw failure;
            throw new StorageFailure(NOT_FOUND);
        }
        if (!Arrays.equals(MAGIC, Arrays.copyOfRange(data, 0, MAGIC.length))) {
            throw new StorageFailure(CORRUPT);
        }
        if (data[MAGIC.length] != VERSION) throw new StorageFailure(UNSUPPORTED_VERSION);

        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, encryptionKey(directory, false),
                new GCMParameterSpec(TAG_BITS, data, HEADER_SIZE, NONCE_SIZE));
        authenticate(cipher, Arrays.copyOfRange(data, 0, HEADER_SIZE), key);
        return cipher.doFinal(data, HEADER_SIZE + NONCE_SIZE,
                data.length - HEADER_SIZE - NONCE_SIZE);
    }

    private static void delete(File file) throws IOException {
        if (!file.delete() && file.exists()) throw new IOException("Cannot delete stored record");
    }

    private static void deleteRecord(File file) throws IOException {
        delete(new File(file.getPath() + ".new"));
        delete(new File(file.getPath() + ".bak"));
        delete(file);
    }

    private static void deleteAll(File directory) throws IOException, GeneralSecurityException {
        for (File file : records(directory)) delete(file);
        // Keep the key when deleting records fails, so remaining data is still
        // readable. Repeated calls can finish either phase without decrypting.
        keyStore().deleteEntry(KEY_ALIAS);
    }

    private static final class StorageFailure extends Exception {
        private static final long serialVersionUID = 1L;
        final int status;

        StorageFailure(int status) {
            this.status = status;
        }
    }
}
