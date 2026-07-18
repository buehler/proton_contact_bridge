import 'dart:convert';

import 'package:dart_pg/dart_pg.dart';

import 'proton_srp_server_key.dart';

abstract interface class ProtonModulusVerifier {
  /// Verifies the OpenPGP cleartext signature and returns the verified,
  /// base64-encoded 256-byte modulus.
  Future<String> verifyAndExtract(String signedModulus);
}

class ProtonModulusVerificationException implements Exception {
  const ProtonModulusVerificationException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return 'ProtonModulusVerificationException: $message';
    }

    return 'ProtonModulusVerificationException: $message: $cause';
  }
}

final class DartPgProtonModulusVerifier implements ProtonModulusVerifier {
  static const int _modulusLength = 256;

  /// Parse the pinned key once.
  static final _serverPublicKey = OpenPGP.readPublicKey(
    protonSrpServerPublicKey,
  );

  @override
  Future<String> verifyAndExtract(String signedModulus) async {
    if (signedModulus.isEmpty) {
      throw const ProtonModulusVerificationException('Signed modulus is empty');
    }

    if (!signedModulus.startsWith('-----BEGIN PGP SIGNED MESSAGE-----')) {
      throw const ProtonModulusVerificationException(
        'Modulus is not an OpenPGP cleartext-signed message',
      );
    }

    try {
      final signedMessage = OpenPGP.readSignedMessage(signedModulus);

      final verifications = signedMessage
          .verify([_serverPublicKey])
          .toList(growable: false);

      // Proton modulus messages contain one signature made with the pinned
      // server key. An empty result also means the signature issuer did not
      // match the pinned key.
      if (verifications.length != 1) {
        throw ProtonModulusVerificationException(
          'Expected exactly one signature from the pinned Proton key; '
          'found ${verifications.length}',
        );
      }

      final verification = verifications.single;

      if (!verification.isVerified) {
        final detail = verification.verificationError.trim();

        throw ProtonModulusVerificationException(
          detail.isEmpty
              ? 'Proton modulus signature is invalid'
              : 'Proton modulus signature is invalid: $detail',
        );
      }

      // dart_pg currently declares readSignedMessage() as returning
      // SignedMessageInterface, although its concrete result also implements
      // SignedCleartextMessageInterface and exposes `text`.
      final String cleartext = (signedMessage as dynamic).text as String;

      final modulusBase64 = cleartext.trim();

      if (modulusBase64.isEmpty) {
        throw const ProtonModulusVerificationException(
          'Verified message contains no modulus',
        );
      }

      final modulusBytes = _decodeModulus(modulusBase64);

      if (modulusBytes.length != _modulusLength) {
        throw ProtonModulusVerificationException(
          'Modulus must decode to $_modulusLength bytes; '
          'got ${modulusBytes.length}',
        );
      }

      return modulusBase64;
    } on ProtonModulusVerificationException {
      rethrow;
    } catch (error) {
      throw ProtonModulusVerificationException(
        'Failed to parse or verify the signed Proton modulus',
        error,
      );
    }
  }

  List<int> _decodeModulus(String value) {
    try {
      return base64Decode(value);
    } on FormatException catch (error) {
      throw ProtonModulusVerificationException(
        'Verified modulus is not valid base64',
        error,
      );
    }
  }
}
