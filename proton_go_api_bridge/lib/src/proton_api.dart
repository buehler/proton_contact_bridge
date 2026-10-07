import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:proton_go_api_bridge/models/auth/auth_state.dart';
import 'package:proton_go_api_bridge/models/contacts/sync_progress.dart';
import 'package:proton_go_api_bridge/models/contacts/sync_state.dart';
import 'package:proton_go_api_bridge/src/bindings.g.dart';
import 'package:proton_go_api_bridge/src/executor.dart';
import 'package:proton_go_api_bridge/src/protobuf/bridge/bridge.pb.dart';
import 'package:proton_go_api_bridge/src/protobuf/commands/commands.pb.dart'
    as c;
import 'package:proton_go_api_bridge/src/protobuf/results/results.pb.dart' as r;
import 'package:rxdart/subjects.dart';

final class ProtonApi {
  static var _nextRegId = 1;
  static var _dbInitialized = false;

  final _authController = BehaviorSubject<AuthState>.seeded(
    AuthState.unknown(),
  );
  final _contactSyncController = BehaviorSubject<ContactSyncState>.seeded(
    ContactSyncState.idle,
  );
  final _contactSyncProgressController =
      BehaviorSubject<ContactSyncProgress>.seeded(ContactSyncProgress(0, 0));

  Stream<AuthState> get authStateStream => _authController.stream;
  Stream<ContactSyncState> get contactSyncStateStream =>
      _contactSyncController.stream;
  Stream<ContactSyncProgress> get contactSyncProgressStream =>
      _contactSyncProgressController.stream;

  late final int _registrationId;
  late final NativeCallable<ContactSyncStateCallbackFunction>
  _syncStateListener;
  late final NativeCallable<ContactSyncProgressCallbackFunction>
  _syncProgressListener;
  bool _disposed = false;

  ProtonApi(String databaseBasePath) {
    if (!_dbInitialized) {
      _dbInitialized = true;
      final p = databaseBasePath.toNativeUtf8();
      try {
        InitializeDatabase(p.cast());
      } finally {
        malloc.free(p);
      }
    }

    _registrationId = _nextRegId++;

    _syncStateListener = NativeCallable.listener((int state) {
      final syncState = ContactSyncState.fromC(state);
      _contactSyncController.add(syncState);
    });

    _syncProgressListener = NativeCallable.listener((int processed, int total) {
      final syncProgress = ContactSyncProgress(processed, total);
      _contactSyncProgressController.add(syncProgress);
    });

    RegisterContactSyncStateCallback(
      _registrationId,
      _syncStateListener.nativeFunction,
    );
    RegisterContactSyncProgressCallback(
      _registrationId,
      _syncProgressListener.nativeFunction,
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    UnregisterContactSyncStateCallback(_registrationId);
    UnregisterContactSyncProgressCallback(_registrationId);
    _syncStateListener.close();
    _syncProgressListener.close();
  }

  void reset() {
    _authController.add(AuthState.unknown());
  }

  Future<void> initAuth() async {
    final result = await executeCommand(
      Command()..login = (c.Login()..init = (c.Login_Init())),
    );

    _handleLoginResult(result);
  }

  Future<void> login(String username, String password) async {
    final result = await executeCommand(
      Command()
        ..login = (c.Login()
          ..usernamePassword = (c.Login_UsernamePassword()
            ..username = username
            ..password = password)),
    );

    _handleLoginResult(result);
  }

  Future<void> logout() async {
    final result = await executeCommand(Command()..logout = (c.Logout()));

    if (result.hasError()) {
      _authController.add(AuthState.error(Exception(result.error.message)));
      return;
    }

    _authController.add(AuthState.unauthenticated());
  }

  Future<void> toggleFavorite(String id) => executeCommand(
    Command(
      contacts: c.Contacts(toggleFavorite: c.Contacts_ToggleFavorite(id: id)),
    ),
  );

  Future<void> submitHumanVerification({
    required String token,
    required String method,
  }) async {
    final result = await executeCommand(
      Command()
        ..login = (c.Login()
          ..submitHumanVerification = (c.Login_SubmitHumanVerification()
            ..token = token
            ..type = method)),
    );

    _handleLoginResult(result);
  }

  Future<void> submitTotp(String code) async {
    final result = await executeCommand(
      Command()..login = (c.Login()..totp = (c.Login_TOTP()..code = code)),
    );

    _handleLoginResult(result);
  }

  void _handleLoginResult(Result result) {
    if (result.hasError()) {
      _authController.add(AuthState.error(Exception(result.error.message)));
      return;
    }

    switch (result.login.whichOutcome()) {
      case r.Login_Outcome.authorized:
        _authController.add(AuthState.authenticated());
        break;
      case r.Login_Outcome.unauthorized:
        _authController.add(AuthState.unauthenticated());
        break;
      case r.Login_Outcome.humanVerificationRequired:
        final verify = result.login.humanVerificationRequired;
        _authController.add(AuthState.requireHumanVerification(verify.uri));
        break;
      case r.Login_Outcome.twoFactorRequired:
        final twoFactor = result.login.twoFactorRequired;
        _authController.add(
          AuthState.requireTwoFactor(totp: twoFactor.totpEnabled),
        );
        break;
      default:
        _authController.add(
          AuthState.error(Exception('Unknown login outcome')),
        );
    }
  }
}
