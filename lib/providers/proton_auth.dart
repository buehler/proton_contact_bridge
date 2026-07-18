import 'package:dio/dio.dart';
import 'package:proton_contact_bridge/proton/auth/auth_state.dart';
import 'package:proton_contact_bridge/proton/interceptors/auth_token.dart';
import 'package:proton_contact_bridge/proton/proton_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'proton_auth.g.dart';

@riverpod
Dio authedProtonDio(Ref ref) {
  const String baseUrl = 'https://mail.proton.me/api/';

  final dio = Dio(
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

  final auth = ref.watch(protonAuthProvider);
  dio.interceptors.add(AuthInterceptor(auth));

  return dio;
}

@riverpod
ProtonAuth protonAuth(Ref ref) => ProtonAuth();

@riverpod
(String?, String?) authInfo(Ref ref) {
  final auth = ref.watch(protonAuthProvider);
  return (auth.accessToken, auth.uid);
}

@riverpod
Stream<AuthState> protonAuthStateStream(Ref ref) =>
    ref.watch(protonAuthProvider).stateStream;
