import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:proton_contact_bridge/proton/auth/auth_info.dart';

part 'proton_srp.freezed.dart';

const int _srpLength = 256;
const int _saltLength = 10;
const int _maxRetries = 5;

final BigInt _generator = BigInt.from(2);

class ProtonSrpException implements Exception {
  const ProtonSrpException(this.message);

  final String message;

  @override
  String toString() => 'ProtonSrpException: $message';
}

@freezed
sealed class ProtonSrpProof with _$ProtonSrpProof {
  const ProtonSrpProof._();

  const factory ProtonSrpProof({
    required Uint8List clientEphemeral,
    required Uint8List clientProof,
    required Uint8List expectedServerProof,
  }) = _ProtonSrpProof;

  String get clientEphemeralBase64 => base64Encode(clientEphemeral);

  String get clientProofBase64 => base64Encode(clientProof);

  bool verifyServerProofBase64(String serverProof) {
    Uint8List decoded;

    try {
      decoded = base64Decode(serverProof);
    } on FormatException {
      return false;
    }

    return _constantTimeEquals(expectedServerProof, decoded);
  }
}

class ProtonSrpClient {
  ProtonSrpClient._({
    required this.version,
    required this.username,
    required this.password,
    required this.modulus,
    required this.salt,
    required this.serverEphemeral,
  });

  factory ProtonSrpClient.fromAuthInfo({
    required AuthInfo authInfo,
    required String verifiedModulusBase64,
    required String password,
  }) {
    return ProtonSrpClient.fromVerifiedChallenge(
      version: authInfo.version,
      username: authInfo.username,
      password: password,
      verifiedModulusBase64: verifiedModulusBase64,
      saltBase64: authInfo.salt,
      serverEphemeralBase64: authInfo.serverEphemeral,
    );
  }

  /// [verifiedModulusBase64] must be the cleartext extracted from the
  /// successfully verified OpenPGP cleartext-signed Modulus response.
  factory ProtonSrpClient.fromVerifiedChallenge({
    required int version,
    required String username,
    required String password,
    required String verifiedModulusBase64,
    required String saltBase64,
    required String serverEphemeralBase64,
  }) {
    if (version < 0 || version > 4) {
      throw ProtonSrpException(
        'Unsupported SRP password hash version: $version',
      );
    }

    final modulus = _decodeBase64Exact(
      verifiedModulusBase64.trim(),
      _srpLength,
      'modulus',
    );

    final salt = _decodeBase64Exact(saltBase64, _saltLength, 'salt');

    final serverEphemeral = _decodeBase64Exact(
      serverEphemeralBase64,
      _srpLength,
      'server ephemeral',
    );

    return ProtonSrpClient._(
      version: version,
      username: username,
      password: password,
      modulus: modulus,
      salt: salt,
      serverEphemeral: serverEphemeral,
    );
  }

  final int version;
  final String username;
  final String password;

  /// Exactly 256 bytes, little-endian.
  final Uint8List modulus;

  /// Exactly 10 bytes.
  final Uint8List salt;

  /// Exactly 256 bytes, little-endian.
  final Uint8List serverEphemeral;

  ProtonSrpProof generateProof({
    Random? secureRandom,

    /// Only provide this in deterministic protocol tests.
    Uint8List? clientSecretForTesting,
  }) {
    final random = secureRandom ?? Random.secure();

    final n = _bigIntFromLittleEndian(modulus);
    _validateModulus(n);

    final nMinusOne = n - BigInt.one;
    final bPublic = _bigIntFromLittleEndian(serverEphemeral);

    if (bPublic % n == BigInt.zero) {
      throw const ProtonSrpException(
        'Invalid server ephemeral: B mod N is zero',
      );
    }

    final passwordHash = _srpPasswordHash(
      version: version,
      username: username,
      password: password,
      salt: salt,
      modulus: modulus,
    );

    // x = H(H_pw(...) || N), interpreted as little-endian.
    final x = _bigIntFromLittleEndian(passwordHash);

    // k = H(g || N) mod N.
    final k = _hashTwo(_generator, n) % n;

    if (k == BigInt.zero) {
      throw const ProtonSrpException('Invalid SRP multiplier');
    }

    BigInt? clientSecret;
    BigInt? clientEphemeral;
    BigInt? scramblingParameter;

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      final a = clientSecretForTesting == null
          ? _generateEphemeralSecret(nMinusOne, random)
          : _bigIntFromLittleEndian(clientSecretForTesting);

      if (a <= BigInt.one || a >= nMinusOne) {
        throw const ProtonSrpException(
          'Client secret must satisfy 1 < a < N - 1',
        );
      }

      // A = g^a mod N.
      final aPublic = _generator.modPow(a, n);

      // u = H(A || B), interpreted as little-endian.
      final u = _hashTwo(aPublic, bPublic);

      if (u % nMinusOne != BigInt.zero) {
        clientSecret = a;
        clientEphemeral = aPublic;
        scramblingParameter = u;
        break;
      }

      if (clientSecretForTesting != null) {
        break;
      }
    }

    if (clientSecret == null ||
        clientEphemeral == null ||
        scramblingParameter == null) {
      throw const ProtonSrpException(
        'Could not generate a valid scrambling parameter',
      );
    }

    // base = B - k * g^x mod N.
    final verifier = _generator.modPow(x, n);
    final base = (bPublic - ((k * verifier) % n)) % n;

    // exponent = a + u*x mod (N - 1).
    final ux = (scramblingParameter * x) % nMinusOne;
    final exponent = (clientSecret + ux) % nMinusOne;

    // K = (B - k*g^x)^(a + u*x) mod N.
    final sharedSession = base.modPow(exponent, n);

    final clientEphemeralBytes = _bigIntToLittleEndian(
      clientEphemeral,
      _srpLength,
    );

    final serverEphemeralBytes = _bigIntToLittleEndian(bPublic, _srpLength);

    final sharedSessionBytes = _bigIntToLittleEndian(sharedSession, _srpLength);

    // ClientProof = H(A || B || K).
    final clientProof = _expandedHash(
      Uint8List.fromList([
        ...clientEphemeralBytes,
        ...serverEphemeralBytes,
        ...sharedSessionBytes,
      ]),
    );

    // ServerProof = H(A || ClientProof || K).
    final expectedServerProof = _expandedHash(
      Uint8List.fromList([
        ...clientEphemeralBytes,
        ...clientProof,
        ...sharedSessionBytes,
      ]),
    );

    return ProtonSrpProof(
      clientEphemeral: clientEphemeralBytes,
      clientProof: clientProof,
      expectedServerProof: expectedServerProof,
    );
  }
}

Uint8List _srpPasswordHash({
  required int version,
  required String username,
  required String password,
  required Uint8List salt,
  required Uint8List modulus,
}) {
  switch (version) {
    case 0:
      return _passwordHashV0(
        username: username,
        password: password,
        modulus: modulus,
      );

    case 1:
      return _passwordHashV1(
        username: username,
        password: password,
        modulus: modulus,
      );

    case 2:
      return _passwordHashV1(
        username: _cleanUsername(username),
        password: password,
        modulus: modulus,
      );

    case 3:
    case 4:
      return _passwordHashV3AndV4(
        password: password,
        salt: salt,
        modulus: modulus,
      );

    default:
      throw ProtonSrpException(
        'Unsupported SRP password hash version: $version',
      );
  }
}

Uint8List _passwordHashV3AndV4({
  required String password,
  required Uint8List salt,
  required Uint8List modulus,
}) {
  if (salt.length != _saltLength) {
    throw const ProtonSrpException('SRP salt must be 10 bytes');
  }

  final extendedSalt = Uint8List(16)
    ..setRange(0, 10, salt)
    ..setRange(10, 16, ascii.encode('proton'));

  final bcryptHash = _bcryptHashWithRawSalt(
    password: password,
    salt: extendedSalt,
  );

  return _expandedHash(
    Uint8List.fromList([...ascii.encode(bcryptHash), ...modulus]),
  );
}

Uint8List _passwordHashV1({
  required String username,
  required String password,
  required Uint8List modulus,
}) {
  final loweredUsername = username.toLowerCase();
  final usernameMd5 = md5.convert(utf8.encode(loweredUsername)).bytes;
  final md5Hex = _hexEncode(usernameMd5);

  // Replicates the legacy Proton mistake:
  // bcrypt-base64-decode(hex(md5(lowercase(username)))).
  final decodedSalt = BCrypt.decodeBase64(md5Hex, 16);
  final rawSalt = Uint8List.fromList(decodedSalt);

  if (rawSalt.length != 16) {
    throw const ProtonSrpException('Failed to derive legacy bcrypt salt');
  }

  final bcryptHash = _bcryptHashWithRawSalt(password: password, salt: rawSalt);

  return _expandedHash(
    Uint8List.fromList([...ascii.encode(bcryptHash), ...modulus]),
  );
}

Uint8List _passwordHashV0({
  required String username,
  required String password,
  required Uint8List modulus,
}) {
  final loweredUsername = _asciiLowercase(username);

  final prehash = sha512
      .convert(utf8.encode('$loweredUsername$password'))
      .bytes;

  return _passwordHashV1(
    username: username,
    password: base64Encode(prehash),
    modulus: modulus,
  );
}

String _bcryptHashWithRawSalt({
  required String password,
  required Uint8List salt,
}) {
  if (salt.length != 16) {
    throw const ProtonSrpException('bcrypt salt must be 16 bytes');
  }

  final bcryptSalt = BCrypt.encodeBase64(Int8List.fromList(salt), salt.length);

  // The Dart package uses the jBCrypt-compatible $2a$ form. Proton's Rust
  // implementation emits $2y$. The underlying non-buggy computation is the
  // same; the resulting prefix is normalized before feeding it into H().
  final hash2a = BCrypt.hashpw(password, r'$2a$10$' + bcryptSalt);

  if (!hash2a.startsWith(r'$2a$') || hash2a.length != 60) {
    throw const ProtonSrpException('Unexpected bcrypt result format');
  }

  return r'$2y$' + hash2a.substring(4);
}

/// Proton H(data):
/// SHA512(data || 0) || SHA512(data || 1) ||
/// SHA512(data || 2) || SHA512(data || 3).
Uint8List _expandedHash(Uint8List data) {
  final output = BytesBuilder(copy: false);

  for (var part = 0; part < 4; part++) {
    output.add(sha512.convert([...data, part]).bytes);
  }

  final result = output.takeBytes();

  if (result.length != _srpLength) {
    throw const ProtonSrpException('Expanded hash has an invalid length');
  }

  return result;
}

BigInt _hashTwo(BigInt first, BigInt second) {
  final bytes = Uint8List(_srpLength * 2)
    ..setRange(0, _srpLength, _bigIntToLittleEndian(first, _srpLength))
    ..setRange(
      _srpLength,
      _srpLength * 2,
      _bigIntToLittleEndian(second, _srpLength),
    );

  return _bigIntFromLittleEndian(_expandedHash(bytes));
}

void _validateModulus(BigInt n) {
  if (n == BigInt.zero) {
    throw const ProtonSrpException('Modulus is zero');
  }

  if (n.isEven) {
    throw const ProtonSrpException('Modulus is even');
  }

  // Proton requires N mod 8 == 3.
  if ((n & BigInt.from(7)) != BigInt.from(3)) {
    throw const ProtonSrpException('Modulus does not satisfy N mod 8 == 3');
  }

  // Same check as proton-srp:
  // 2^(N - 1) mod N == 1.
  if (_generator.modPow(n - BigInt.one, n) != BigInt.one) {
    throw const ProtonSrpException('N - 1 is not an order of generator 2');
  }
}

BigInt _generateEphemeralSecret(BigInt modulusMinusOne, Random random) {
  for (var attempt = 0; attempt < _maxRetries; attempt++) {
    final candidate = _randomBelow(modulusMinusOne, random);

    if (candidate > BigInt.one) {
      return candidate;
    }
  }

  throw const ProtonSrpException(
    'Could not generate a client ephemeral secret',
  );
}

BigInt _randomBelow(BigInt upperExclusive, Random random) {
  if (upperExclusive <= BigInt.zero) {
    throw ArgumentError.value(
      upperExclusive,
      'upperExclusive',
      'Must be positive',
    );
  }

  final byteLength = (upperExclusive.bitLength + 7) ~/ 8;
  final excessBits = byteLength * 8 - upperExclusive.bitLength;

  while (true) {
    final bytes = Uint8List.fromList(
      List<int>.generate(byteLength, (_) => random.nextInt(256)),
    );

    if (excessBits > 0) {
      bytes[byteLength - 1] &= 0xff >> excessBits;
    }

    final candidate = _bigIntFromLittleEndian(bytes);

    if (candidate < upperExclusive) {
      return candidate;
    }
  }
}

BigInt _bigIntFromLittleEndian(List<int> bytes) {
  var result = BigInt.zero;

  for (var index = bytes.length - 1; index >= 0; index--) {
    result = (result << 8) | BigInt.from(bytes[index] & 0xff);
  }

  return result;
}

Uint8List _bigIntToLittleEndian(BigInt value, int length) {
  if (value.isNegative) {
    throw ArgumentError.value(value, 'value', 'Must not be negative');
  }

  final output = Uint8List(length);
  var remaining = value;

  for (var index = 0; index < length; index++) {
    output[index] = (remaining & BigInt.from(0xff)).toInt();
    remaining >>= 8;
  }

  if (remaining != BigInt.zero) {
    throw ArgumentError.value(value, 'value', 'Does not fit in $length bytes');
  }

  return output;
}

Uint8List _decodeBase64Exact(String value, int expectedLength, String name) {
  late final Uint8List decoded;

  try {
    decoded = base64Decode(value);
  } on FormatException {
    throw ProtonSrpException('$name is not valid base64');
  }

  if (decoded.length != expectedLength) {
    throw ProtonSrpException(
      '$name must decode to $expectedLength bytes; '
      'got ${decoded.length}',
    );
  }

  return decoded;
}

bool _constantTimeEquals(List<int> expected, List<int> actual) {
  if (expected.length != actual.length) {
    return false;
  }

  var difference = 0;

  for (var index = 0; index < expected.length; index++) {
    difference |= expected[index] ^ actual[index];
  }

  return difference == 0;
}

String _hexEncode(List<int> bytes) {
  const digits = '0123456789abcdef';
  final output = StringBuffer();

  for (final byte in bytes) {
    output
      ..write(digits[(byte >> 4) & 0x0f])
      ..write(digits[byte & 0x0f]);
  }

  return output.toString();
}

String _cleanUsername(String username) {
  return username.replaceAll(RegExp(r'[-._]'), '').toLowerCase();
}

String _asciiLowercase(String value) {
  final units = value.codeUnits.map((unit) {
    if (unit >= 0x41 && unit <= 0x5a) {
      return unit + 0x20;
    }

    return unit;
  });

  return String.fromCharCodes(units);
}
