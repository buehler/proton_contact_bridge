import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:proton_go_api_bridge/src/bindings.g.dart';
import 'package:proton_go_api_bridge/src/models/auth/auth_session.dart';
import 'package:proton_go_api_bridge/src/models/auth/auth_state.dart';
import 'package:proton_go_api_bridge/src/protobuf/bridge/bridge.pb.dart';
import 'package:proton_go_api_bridge/src/protobuf/commands/commands.pb.dart'
    as c;
import 'package:proton_go_api_bridge/src/protobuf/results/results.pb.dart' as r;
import 'package:rxdart/subjects.dart';

final class ProtonApi {
  final int sessionId;
  final _controller = BehaviorSubject<AuthState>.seeded(AuthState.unknown());

  ProtonApi._(this.sessionId);

  factory ProtonApi() {
    final sessionId = CreateSession();
    final api = ProtonApi._(sessionId);
    _finalizer.attach(ProtonApi._(sessionId), sessionId, detach: api);
    return api;
  }

  static final Finalizer<int> _finalizer = Finalizer(
    (sessionId) => CloseSession(sessionId),
  );

  Stream<AuthState> get authStateStream => _controller.stream;

  void reset() {
    _controller.add(AuthState.unknown());
  }

  Future<void> refresh(AuthSession session) async {}

  Future<void> login(String username, String password) async {
    final result = await _executeCommand(
      Command()
        ..sessionId = sessionId
        ..login = (c.Login()
          ..usernamePassword = (c.Login_UsernamePassword()
            ..username = username
            ..password = password)),
    );

    _handleLoginResult(result);
  }

  Future<void> submitHumanVerification({
    required String username,
    required String password,
    required String token,
    required String method,
  }) async {
    final result = await _executeCommand(
      Command()
        ..sessionId = sessionId
        ..login = (c.Login()
          ..withHumanVerification = (c.Login_WithHumanVerification()
            ..username = username
            ..password = password
            ..token = token
            ..type = method)),
    );

    _handleLoginResult(result);
  }

  Future<void> submitTotp(String code) async {
    final result = await _executeCommand(
      Command()
        ..sessionId = sessionId
        ..login = (c.Login()..totp = (c.Login_TOTP()..code = code)),
    );

    _handleLoginResult(result);
  }

  void dispose() {
    CloseSession(sessionId);
    _finalizer.detach(this);
  }

  void _handleLoginResult(Result result) {
    if (result.hasError()) {
      _controller.add(AuthState.error(Exception(result.error.message)));
      return;
    }

    switch (result.login.whichOutcome()) {
      case r.Login_Outcome.success:
        final session = result.login.success.session;
        _controller.add(
          AuthState.authenticated(
            AuthSession(
              uid: session.uid,
              userId: session.userId,
              accessToken: session.accessToken,
              refreshToken: session.refreshToken,
            ),
          ),
        );
        break;
      case r.Login_Outcome.humanVerificationRequired:
        final verify = result.login.humanVerificationRequired;
        _controller.add(AuthState.requireHumanVerification(verify.uri));
        break;
      case r.Login_Outcome.twoFactorRequired:
        final twoFactor = result.login.twoFactorRequired;
        _controller.add(
          AuthState.requireTwoFactor(
            AuthSession(
              uid: twoFactor.session.uid,
              userId: twoFactor.session.userId,
              accessToken: twoFactor.session.accessToken,
              refreshToken: twoFactor.session.refreshToken,
            ),
            totp: twoFactor.totpEnabled,
          ),
        );
        break;
      case r.Login_Outcome.twoFactorSuccess:
        if (_controller.value case RequireTwoFactor(session: final session)) {
          _controller.add(
            AuthState.authenticated(
              AuthSession(
                uid: session.uid,
                userId: session.userId,
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
              ),
            ),
          );
        } else {
          _controller.add(
            AuthState.error(Exception('Unexpected two-factor success')),
          );
        }
        break;
      default:
        _controller.add(AuthState.error(Exception('Unknown login outcome')));
    }
  }

  Future<Result> _executeCommand(Command command) async {
    // TODO: maybe use isolate.compute here
    final result = using((Arena arena) {
      final commandBytes = command.writeToBuffer();
      final commandBuffer = arena<GoByteBuffer>();
      final nativeDataPtr = arena<ffi.UnsignedChar>(commandBytes.length);
      nativeDataPtr
          .cast<ffi.Uint8>()
          .asTypedList(commandBytes.length)
          .setAll(0, commandBytes);
      commandBuffer.ref.data = nativeDataPtr;
      commandBuffer.ref.len = commandBytes.length;

      final resultBuffer = ExecuteCommand(commandBuffer.ref);
      try {
        if (resultBuffer.data == ffi.nullptr || resultBuffer.len == 0) {
          throw Exception('Failed to execute command');
        }
        final resultData = resultBuffer.data.cast<ffi.Uint8>().asTypedList(
          resultBuffer.len,
        );
        return Result.fromBuffer(resultData);
      } finally {
        FreeByteBuffer(resultBuffer);
      }
    });
    return result;
  }
}
