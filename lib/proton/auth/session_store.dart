import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:proton_contact_bridge/proton/auth/auth_session.dart';

final class ProtonSessionStore {
  static const _sessionStorageKey = 'proton.session';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked,
      // groupId: iosKeychainAccessGroup,
    ),
  );

  Future<AuthSession?> get() async {
    final sessionJson = await _storage.read(key: _sessionStorageKey);
    if (sessionJson == null) return null;
    return AuthSession.fromJson(jsonDecode(sessionJson));
  }

  Future<void> set(AuthSession session) async {
    final sessionJson = jsonEncode(session.toJson());
    await _storage.write(key: _sessionStorageKey, value: sessionJson);
  }

  Future<void> clear() async {
    await _storage.delete(key: _sessionStorageKey);
  }
}
