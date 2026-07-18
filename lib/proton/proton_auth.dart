import 'dart:async';

import 'package:proton_contact_bridge/proton/auth/auth_event.dart';
import 'package:proton_contact_bridge/proton/auth/auth_machine.dart';
import 'package:proton_contact_bridge/proton/auth/auth_session.dart';
import 'package:proton_contact_bridge/proton/auth/auth_state.dart';
import 'package:proton_contact_bridge/proton/auth/session_store.dart';
import 'package:proton_contact_bridge/proton/auth/two_factor_info.dart';

typedef HumanVerificationRequest =
    FutureOr<(String token, String type)> Function(String);
typedef TotpRequest = FutureOr<String> Function();

final class ProtonAuth {
  final _machine = AuthMachine();
  final _store = ProtonSessionStore();

  Stream<AuthState> get stateStream => _machine.stateStream;
  bool get isLoggedIn => _machine.state is LoggedIn;
  String? get accessToken {
    if (_machine.state case LoggedIn(
      session: AuthSession(:final accessToken),
    )) {
      return accessToken;
    }
    return null;
  }

  String? get uid {
    if (_machine.state case LoggedIn(session: AuthSession(:final uid))) {
      return uid;
    }
    return null;
  }

  void reset() {
    _machine.dispatch(AuthEvent.reset());
  }

  Future<bool> attemptLocalLogin() async {
    final session = await _store.get();
    if (session == null) {
      _machine.dispatch(AuthEvent.logout());
      return false;
    }

    final completer = Completer<bool>();
    late final StreamSubscription subscription;
    subscription = _machine.stateStream.listen((state) async {
      if (state case LoggedIn()) {
        completer.complete(true);
        await subscription.cancel();
      } else if (state is Error) {
        completer.complete(false);
        await subscription.cancel();
      }
    });
    _machine.dispatch(AuthEvent.loadSession(session));

    return completer.future;
  }

  Future<void> logout() async {
    reset();
    await _store.clear();
  }

  void submitHumanVerification(String token, String type) {
    _machine.dispatch(AuthEvent.submitHumanVerification(token, type));
  }

  void submitTotp(String code) {
    _machine.dispatch(AuthEvent.submitTotp(code));
  }

  Future<void> login({
    required String username,
    required String password,
    HumanVerificationRequest? onHumanVerificationRequest,
    TotpRequest? onTotpRequest,
  }) async {
    final completer = Completer<void>();

    late final StreamSubscription subscription;
    subscription = _machine.stateStream.listen((state) async {
      switch (state) {
        case RequireHumanVerification(:final url)
            when onHumanVerificationRequest != null:
          final (token, type) = await onHumanVerificationRequest(url);
          _machine.dispatch(AuthEvent.submitHumanVerification(token, type));
          break;
        case RequireTwoFactor(twoFactorInfo: TwoFactorInfo(hasTOTP: true))
            when onTotpRequest != null:
          final code = await onTotpRequest();
          _machine.dispatch(AuthEvent.submitTotp(code));
          break;
        case LoggedIn(:final session):
          await _store.set(session);
          completer.complete();
          await subscription.cancel();
          break;
        case Error(:final exception):
          completer.completeError(exception);
          await subscription.cancel();
          break;
        default:
          break;
      }
    });

    _machine.dispatch(Login(username, password));

    return completer.future;
  }
}
