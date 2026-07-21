import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_session.freezed.dart';
part 'auth_session.g.dart';

@freezed
sealed class AuthSession with _$AuthSession {
  const factory AuthSession({
    required String uid,
    required String userId,
    required String accessToken,
    required String refreshToken,
  }) = _AuthSession;

  factory AuthSession.fromJson(Map<String, dynamic> json) =>
      _$AuthSessionFromJson(json);
}
