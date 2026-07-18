import 'dart:async';

import 'package:logging/logging.dart';
import 'package:proton_contact_bridge/providers/channels.dart';
import 'package:proton_contact_bridge/providers/storage.dart';
import 'package:proton_go_api_bridge/models/auth/auth_state.dart';
import 'package:proton_go_api_bridge/proton_go_api_bridge.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'proton.g.dart';

@Riverpod(keepAlive: true)
Future<ProtonApi> protonApi(Ref ref) async {
  final nativePathChannel = ref.watch(nativePathChannelProvider);
  final path = await nativePathChannel.getDatabasePath();
  if (path == null) {
    throw Exception('Failed to get database path');
  }
  final api = ProtonApi(path);

  ref.onDispose(api.dispose);

  return api;
}

@Riverpod(keepAlive: true)
class ProtonAuth extends _$ProtonAuth {
  static final _logger = Logger('ProtonAuth');
  late final ProtonApi api;

  @override
  Future<AuthState> build() async {
    api = await ref.watch(protonApiProvider.future);
    final subscription = api.authStateStream.listen((data) async {
      state = AsyncData(data);

      if (data is Unauthenticated) {
        _logger.info('User logged out, clearing user info from storage.');
        await ref
            .read(sharedPreferencesProvider)
            .remove(StorageKeys.userInfo.key);
      }
    });

    ref.onDispose(subscription.cancel);

    await api.initAuth();
    return api.authStateStream.first;
  }

  Future<void> login(String username, String password) =>
      api.login(username, password);

  Future<void> logout() => api.logout();

  Future<void> submitHumanVerification({
    required String token,
    required String method,
  }) => api.submitHumanVerification(token: token, method: method);

  Future<void> submitTotp(String code) => api.submitTotp(code);

  void reset() => api.reset();
}
