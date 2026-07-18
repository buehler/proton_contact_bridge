import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:proton_contact_bridge/proton/auth/auth_info.dart';
import 'package:proton_contact_bridge/proton/auth/auth_session.dart';
import 'package:proton_contact_bridge/proton/auth/two_factor_info.dart';
import 'package:proton_contact_bridge/proton/srp/proton_srp.dart';
import 'package:proton_contact_bridge/state_machine/typesafe_state_machine.dart';

part 'auth_state.freezed.dart';

@freezed
sealed class AuthState extends MachineState with _$AuthState {
  const AuthState._();

  const factory AuthState.initial() = Initial;
  const factory AuthState.loggedOut() = LoggedOut;
  const factory AuthState.busy() = Busy;
  const factory AuthState.error(Exception exception) = Error;
  const factory AuthState.requireHumanVerification(
    String verificationToken,
    String url,
    String verificationType,
    int expiresAt,
    AuthInfo authInfo,
    ProtonSrpProof clientProof,
  ) = RequireHumanVerification;
  const factory AuthState.requireTwoFactor(
    AuthSession session,
    TwoFactorInfo twoFactorInfo,
  ) = RequireTwoFactor;
  const factory AuthState.loggedIn(AuthSession session) = LoggedIn;
}
