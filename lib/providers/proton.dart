import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:proton_go_api_bridge/proton_go_api_bridge.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'proton.g.dart';

@Riverpod(keepAlive: true)
ProtonApi protonApi(Ref ref) {
  final api = ProtonApi();
  ref.onDispose(api.dispose);
  return api;
}

const _sessionKey = 'proton.auth_session';

@Riverpod(keepAlive: true)
class ProtonAuth extends _$ProtonAuth {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked,
      synchronizable: false,
      // groupId: iosKeychainAccessGroup,
    ),
  );

  ProtonApi get api => ref.read(protonApiProvider);

  @override
  Future<AuthState> build() async {
    final subscription = api.authStateStream.listen((authState) {
      state = AsyncData(authState);
    });

    ref.onDispose(subscription.cancel);

    final encodedSession = await _storage.read(key: _sessionKey);

    if (encodedSession == null) {
      return AuthState.unknown();
    }

    final session = AuthSession.fromJson(
      jsonDecode(encodedSession) as Map<String, dynamic>,
    );

    final nextState = api.authStateStream.firstWhere(
      (state) => state is! Unknown,
    );

    await api.refresh(session);

    return nextState;
  }

  Future<void> login(String username, String password) =>
      api.login(username, password);

  Future<void> logout() async {}

  Future<void> submitHumanVerification({
    required String token,
    required String method,
  }) => api.submitHumanVerification(token: token, method: method);

  Future<void> submitTotp(String code) => api.submitTotp(code);

  void reset() => api.reset();
}
