import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:proton_contact_bridge/proton/auth/auth_info.dart';
import 'package:proton_contact_bridge/proton/auth/auth_session.dart';
import 'package:proton_contact_bridge/proton/srp/proton_srp.dart';
import 'package:proton_contact_bridge/state_machine/typesafe_state_machine.dart';

part 'auth_event.freezed.dart';

@freezed
sealed class AuthEvent extends MachineEvent with _$AuthEvent {
  const AuthEvent._();

  const factory AuthEvent.reset() = Reset;
  const factory AuthEvent.loadSession(AuthSession session) = LoadSession;
  const factory AuthEvent.login(String username, String password) = Login;
  const factory AuthEvent.logout() = Logout;
  const factory AuthEvent.sendLoginRequest(
    AuthInfo authInfo,
    ProtonSrpProof clientProof,
  ) = SendLoginRequest;
  const factory AuthEvent.submitHumanVerification(String token, String type) =
      SubmitHumanVerification;
  const factory AuthEvent.submitTotp(String code) = SubmitTotp;
}
