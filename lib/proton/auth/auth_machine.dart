import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:proton_contact_bridge/proton/auth/auth_event.dart';
import 'package:proton_contact_bridge/proton/auth/auth_info.dart';
import 'package:proton_contact_bridge/proton/auth/auth_session.dart';
import 'package:proton_contact_bridge/proton/auth/auth_state.dart';
import 'package:proton_contact_bridge/proton/auth/two_factor_info.dart';
import 'package:proton_contact_bridge/proton/srp/proton_modulus_verifier.dart';
import 'package:proton_contact_bridge/proton/srp/proton_srp.dart';
import 'package:proton_contact_bridge/state_machine/typesafe_state_machine.dart';

final class AuthMachine extends TypeSafeStateMachine<AuthState, AuthEvent> {
  static const String baseUrl = 'https://account.proton.me/api/';

  final _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-PM-AppVersion': 'Other',
        'X-PM-ApiVersion': '3',
      },
    ),
  );
  final modulusVerifier = DartPgProtonModulusVerifier();

  AuthMachine() : super(AuthState.initial()) {
    when((_, event) {
      if (event is Reset) {
        return AuthState.initial();
      }
      return null;
    });
    when((state, event) {
      switch ((state, event)) {
        case (LoggedIn(), Logout()):
        case (Initial(), Logout()):
          return AuthState.loggedOut();
        case (LoggedOut(), Logout()):
          return state;
        default:
          return null;
      }
    });
    when((state, event) {
      switch ((state, event)) {
        case (Initial(), Login(:final username, :final password)):
        case (LoggedOut(), Login(:final username, :final password)):
          _prepareLogin(username, password);
          return AuthState.busy();
        default:
          return null;
      }
    });
    when((state, event) {
      switch ((state, event)) {
        case (
          Busy(),
          SendLoginRequest(
            authInfo: final authInfo,
            clientProof: final clientProof,
          ),
        ):
          _sendLoginAttempt(authInfo, clientProof);
          return AuthState.busy();
        default:
          return null;
      }
    });
    when((state, event) {
      switch ((state, event)) {
        case (
          RequireHumanVerification(:final authInfo, :final clientProof),
          SubmitHumanVerification(:final token, :final type),
        ):
          _sendLoginAttempt(
            authInfo,
            clientProof,
            additionalHeaders: {
              'x-pm-human-verification-token': token,
              'x-pm-human-verification-token-type': type,
            },
          );
          return AuthState.busy();
        default:
          return null;
      }
    });
    when((state, event) {
      switch ((state, event)) {
        case (RequireTwoFactor(:final session), SubmitTotp(:final code)):
          _submitTotp(session, code);
          return AuthState.busy();
        //TODO: fido2
        default:
          return null;
      }
    });
    when((state, event) {
      switch ((state, event)) {
        case (Initial(), LoadSession(:final session)):
          return AuthState.loggedIn(session);
        case (LoggedIn(), LoadSession()):
          return state;
        default:
          return null;
      }
    });
  }

  Future<void> _submitTotp(AuthSession session, String code) async {
    try {
      final response = await _dio.post(
        'auth/v4/2fa',
        data: {'TwoFactorCode': code},
        options: Options(
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'x-pm-uid': session.uid,
          },
        ),
      );

      final data = response.data;
      if (data == null || data['Code'] != 1000) {
        throw Exception('TOTP verification failed');
      }

      setState(
        AuthState.loggedIn(
          session.copyWith(scopes: _readScopes(data['Scopes'])),
        ),
      );
    } catch (e) {
      setState(AuthState.error(Exception('TOTP submission failed: $e')));
    }
  }

  Future<void> _sendLoginAttempt(
    AuthInfo authInfo,
    ProtonSrpProof clientProof, {
    Map<String, dynamic>? additionalData,
    Map<String, dynamic>? additionalHeaders,
  }) async {
    try {
      final response = await _dio.post(
        'auth/v4',
        data: {
          'Username': authInfo.username,
          'SRPSession': authInfo.srpSession,
          'ClientEphemeral': clientProof.clientEphemeralBase64,
          'ClientProof': clientProof.clientProofBase64,
          ...additionalData ?? {},
        },
        options: Options(headers: {...additionalHeaders ?? {}}),
      );

      final data = response.data;
      if (data == null) {
        throw Exception('Empty authentication response');
      }

      final serverProof = data['ServerProof'] as String?;

      if (serverProof == null ||
          !_constantTimeEquals(
            base64Decode(serverProof),
            clientProof.expectedServerProof,
          )) {
        throw Exception('Invalid server proof');
      }

      final accessToken = data['AccessToken'] as String?;
      final refreshToken = data['RefreshToken'] as String?;
      final uid = data['UID'] as String?;
      final userId = data['UserID'] as String?;

      if (accessToken == null ||
          refreshToken == null ||
          uid == null ||
          userId == null) {
        throw Exception('Incomplete authentication response');
      }

      final session = AuthSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        uid: uid,
        userId: userId,
        scopes: _readScopes(data['Scopes']),
      );

      // TODO: second password mode.

      if (data['TwoFactor'] == 1) {
        final twoFA = TwoFactorInfo.fromJson(data['2FA']);
        setState(AuthState.requireTwoFactor(session, twoFA));
        return;
      }

      setState(AuthState.loggedIn(session));
    } on DioException catch (e) {
      if (e.response?.statusCode == 422 && e.response?.data['Code'] == 9001) {
        setState(
          AuthState.requireHumanVerification(
            e.response?.data['Details']?['HumanVerificationToken'],
            e.response?.data['Details']?['WebUrl'],
            (e.response?.data['Details']?['HumanVerificationMethods'] ?? [])
                .join(','),
            e.response?.data['Details']?['ExpiresAt'],
            authInfo,
            clientProof,
          ),
        );
      } else {
        setState(AuthState.error(Exception('Login failed: $e')));
      }
    } catch (e) {
      setState(AuthState.error(Exception('Login failed: $e')));
    }
  }

  Future<void> _prepareLogin(String username, String password) async {
    try {
      final authInfo = await _fetchAuthInfo(username);
      final verifiedModulusBase64 = await modulusVerifier.verifyAndExtract(
        authInfo.modulus,
      );
      final srp = ProtonSrpClient.fromAuthInfo(
        authInfo: authInfo,
        verifiedModulusBase64: verifiedModulusBase64,
        password: password,
      );
      final clientProof = srp.generateProof();
      dispatch(AuthEvent.sendLoginRequest(authInfo, clientProof));
    } on ProtonModulusVerificationException catch (e) {
      setState(AuthState.error(e));
    } catch (e) {
      setState(AuthState.error(Exception('Login failed: $e')));
    }
  }

  Future<AuthInfo> _fetchAuthInfo(String username) async {
    final response = await _dio.post(
      'auth/v4/info',
      data: {'Username': username},
    );

    return AuthInfo(
      code: response.data['Code'],
      username: response.data['Username'],
      version: response.data['Version'],
      modulus: response.data['Modulus'],
      serverEphemeral: response.data['ServerEphemeral'],
      salt: response.data['Salt'],
      srpSession: response.data['SRPSession'],
    );
  }
}

List<String> _readScopes(Object? value) {
  if (value is List) {
    return value.whereType<String>().toList();
  }

  if (value is String) {
    return value.split(' ').where((scope) => scope.isNotEmpty).toList();
  }

  return const [];
}

bool _constantTimeEquals(Uint8List a, Uint8List b) {
  final left = a;
  final right = b;

  if (left.length != right.length) {
    return false;
  }

  var difference = 0;

  for (var i = 0; i < left.length; i++) {
    difference |= left[i] ^ right[i];
  }

  return difference == 0;
}
