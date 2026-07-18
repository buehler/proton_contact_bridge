# Proton Go API Bridge

Flutter bridge to the Go implementation of Proton authentication, contacts,
SQLite persistence, and synchronization. Commands use the existing protobuf C ABI;
`hook/build.dart` builds and bundles the Go library through Dart native assets.

## Platform initialization

After Flutter binding initialization, await platform setup before creating API
providers or issuing authentication commands:

```dart
WidgetsFlutterBinding.ensureInitialized();
await initializeNativePlatform();
```

Import `package:proton_go_api_bridge/proton_go_api_bridge.dart`. Initialization is
a no-op on Apple platforms. On Android it registers the Java secure-storage helper
with Go. Calls are idempotent across Dart hot restarts and Flutter engines;
initialization failures can be retried. Storage access before setup returns an
error. The supported model is one application process.

The package's Android plugin builds only `libproton_bridge_bootstrap.so`. It owns
one process-lifetime JNI global reference to an application-context helper. It
returns that reference and the JVM handle through a bootstrap MethodChannel;
Dart then passes the borrowed handles to the Go native asset. Repeated setup
allocates no additional global references, including when an isolate exits before
receiving its response. Plugin detachment does not invalidate ongoing Go work.
No secrets travel through the MethodChannel and no second copy of Go is loaded.

Android-only FFI declarations live in `lib/src/native_platform.dart`, separately
from the Apple-generated `bindings.g.dart`. JNI calls attach the current native
thread only when necessary, release local references, and detach threads they
attached. Storage and cryptographic work run synchronously on the calling Go
worker, not the Android UI thread.

## Android storage and logging

Android API 23 or higher is required. The app retains Flutter's higher minimum
when applicable. The plugin uses the Flutter SDK's compile SDK and NDK versions.

- Logs use the NDK's Logcat API with tag `ProtonContactBridge` and Android
  DEBUG/INFO/WARN/ERROR priorities. Long messages are split at UTF-8 boundaries;
  embedded NUL bytes are escaped. The existing Dart callback path is unchanged
  and does not split messages.
- Credentials use AES-256-GCM with a non-exportable Android Keystore key, alias
  `ch.cbue.protonContactBridge.secure_storage.aes256.v1`. Key generation is lazy,
  uses randomized encryption, and requires no biometric prompt. StrongBox is not
  required; hardware backing depends on the device. Key material never enters Go.
- Files live in credential-protected
  `getNoBackupFilesDir()/proton_contact_bridge/secure_storage`, excluded from
  backup and device transfer. Direct Boot storage is rejected. Background use
  remains possible after first unlock; an unlocked screen is not required.
- Filenames are lowercase SHA-256 hashes of the UTF-8 logical key, plus `.bin`.
  Format: four-byte `PCBS` magic, one-byte version `1`, a fresh provider-generated
  12-byte nonce, and ciphertext followed by a 16-byte GCM tag. Associated data is
  the five-byte header, UTF-8 namespace
  `ch.cbue.protonContactBridge.secure_storage`, a zero byte, and the UTF-8 logical
  key. Values are limited to 16 MiB to bound allocations when reading damaged
  records. They may otherwise contain arbitrary bytes, including an empty value.
- All operations are serialized. `AtomicFile` replacement and an explicit file
  sync preserve the previous committed value if a write fails. Atomic-file
  backups and staging files are included in deletion and missing-key checks.
- Missing `Get` returns `ErrKeyNotFound`; missing `Exists` returns false; missing
  `Delete` succeeds. Corruption, authentication failure, key unavailability, and
  filesystem errors remain errors, rather than being treated as a fresh login.
  Java exception messages and stored values are never returned in diagnostics.
- A missing key is not regenerated while encrypted records remain. Use the
  existing logout/`DeleteAll` operation to clear unusable secrets before logging
  in again. Deletion requires no decryption, removes only this namespace's records
  and alias, and can be retried after a partial failure.

There is no migration from another Android storage format and no change to
contact-database encryption. The implementation uses platform APIs directly and
does not depend on `flutter_secure_storage`.

References: [Android Keystore](https://developer.android.com/privacy-and-security/keystore),
[backup exclusions](https://developer.android.com/identity/data/autobackup),
[JNI guidance](https://developer.android.com/ndk/guides/jni-tips),
[NDK logging](https://developer.android.com/ndk/reference/group/logging).

## Verification

Repository policy permits static analysis and Go builds; do not run the app or
add automated tests as part of routine implementation verification.

Run `flutter analyze` at the repository root. Build Go from `src` using
`CGO_ENABLED=1`, `GOOS=android`, and the matching NDK compiler:

| GOARCH | NDK compiler | Build mode |
| --- | --- | --- |
| arm64 | `aarch64-linux-android23-clang` | `c-shared` |
| amd64 | `x86_64-linux-android23-clang` | `c-shared` |

For example, with the NDK compiler on `PATH`:

```sh
GOOS=android GOARCH=arm64 CGO_ENABLED=1 CC=aarch64-linux-android23-clang \
  go build -buildmode=c-shared -o /tmp/proton-android/libbridge_android.so .
```

Also build the macOS shared library for regression coverage. Java can be checked
with `javac --release 17 -proc:none -Xlint:all` against `android.jar` and Flutter's
`flutter.jar`, directing output outside the source tree. Check both JNI C files
with the NDK compiler's `-fsyntax-only -Wall -Wextra -Werror` options.

### Manual device verification

These steps are for an engineer to perform separately, using a disposable account
and a debug build for fault injection. Go builds and static checks do not verify
APK packaging, JNI loading on a device, Keystore behavior, or release shrinking.

1. **Startup and logging:** Launch on an arm64 device and an x86-64 emulator.
   Filter with `adb logcat -s ProtonContactBridge`. Exercise native operations and
   confirm priority mapping. Through the debugger, emit a message over 3,800 bytes
   with multibyte characters at chunk boundaries. Logcat must retain its content;
   the app log callback must receive it once, unsplit. Separately confirm that
   embedded NUL bytes are escaped in Logcat.
2. **Authentication persistence:** Log in, force-stop, and reopen. Authentication
   must restore. Refresh the session, restart again, and confirm the updated
   credential is retained. No biometric or device-credential prompt should appear.
   Inspect the app-private record as binary without printing secrets: it must have
   the documented header and no plaintext credential. Repeated writes must change
   the nonce.
3. **Storage semantics:** Through a debugger, exercise all five Go storage methods
   on a temporary key, including empty/binary values, overwrites, missing reads,
   and repeated deletes. Confirm independent keys retain their values and that
   concurrent operations do not produce mixed or truncated records.
4. **Lock and lifecycle:** Reboot, unlock once, then lock the screen and exercise
   background session refresh. Hot-restart Flutter and detach/recreate an engine;
   subsequent storage calls must work without duplicate initialization or invalid
   references. Before initialization, a storage call must fail clearly.
5. **Logout and recovery:** Log out, repeat logout, and restart. Credentials and
   the namespaced Keystore alias must be absent, and login must remain possible.
   Other app files and other Keystore aliases must be unaffected.
6. **Damaged data:** With the app stopped, truncate a disposable record, change its
   version, or flip a ciphertext byte. Restart for each case. Expect a storage
   error, not silent deletion or key replacement. Reset through logout and log in
   again. Repeat after deleting only this Keystore alias through the debugger
   while leaving its encrypted record; a new key must not be generated.
7. **Write/delete failures:** Use debugger breakpoints around `startWrite`, sync,
   and `finishWrite` to interrupt a replacement. The previous committed record
   must remain readable after restart. Inject an I/O failure during writing or
   deletion; it must reach Go, and a retry of deletion must finish cleanup. During
   token-refresh checks, a remote service may already have invalidated an older
   token, so verify atomic replacement separately with a temporary storage key.
8. **Reinstall and transfer:** Uninstall/reinstall, and separately restore/transfer
   the app to another device. Stored authentication must not migrate; a fresh
   login must work. Do not infer this from `allowBackup=false` alone.
9. **Release packaging:** Build and install a release APK with shrinking enabled.
   Confirm the generated registrant includes this plugin, the APK contains the
   bootstrap and native-assets Go libraries for each selected ABI, and login,
   restart, refresh, and logout work without missing JNI symbols or methods.
