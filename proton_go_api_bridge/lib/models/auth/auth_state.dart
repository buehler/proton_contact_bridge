import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_state.freezed.dart';

@freezed
sealed class AuthState with _$AuthState {
  const AuthState._();

  const factory AuthState.unknown() = Unknown;
  const factory AuthState.unauthenticated() = Unauthenticated;
  const factory AuthState.error(Exception exception) = Error;
  const factory AuthState.requireHumanVerification(String url) =
      RequireHumanVerification;
  const factory AuthState.requireTwoFactor({required bool totp}) =
      RequireTwoFactor;
  const factory AuthState.authenticated() = Authenticated;
}
