import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:proton_go_api_bridge/src/models/auth/auth_session.dart';

part 'auth_state.freezed.dart';

@freezed
sealed class AuthState with _$AuthState {
  const AuthState._();

  const factory AuthState.unknown() = Unknown;
  const factory AuthState.error(Exception exception) = Error;
  const factory AuthState.requireHumanVerification(String url) =
      RequireHumanVerification;
  const factory AuthState.requireTwoFactor(
    AuthSession session, {
    required bool totp,
  }) = RequireTwoFactor;
  // TODO: maybe session info should not reside in memory.
  const factory AuthState.authenticated(AuthSession session) = Authenticated;
}
