import 'package:dio/dio.dart';
import 'package:proton_contact_bridge/proton/proton_auth.dart';

final class AuthInterceptor extends Interceptor {
  const AuthInterceptor(this.protonAuth);

  final ProtonAuth protonAuth;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = protonAuth.accessToken;
    options.headers['Authorization'] = 'Bearer $accessToken';

    final uid = protonAuth.uid;
    options.headers['x-pm-uid'] = uid;

    return super.onRequest(options, handler);
  }
}
