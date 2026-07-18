import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

const _platformChannel = MethodChannel('ch.cbue.proton_go_api_bridge/platform');
Future<void>? _initialization;

// This Android-only symbol intentionally stays out of the Apple-generated
// bindings. Resolve it from the same native asset as the existing Go API.
@Native<Int32 Function(UintPtr, UintPtr)>(
  symbol: 'InitializeAndroidPlatform',
  assetId: 'package:proton_go_api_bridge/src/bindings.g.dart',
)
external int _initializeAndroidPlatform(int vm, int helper);

/// Connects Android Keystore to Go before any authentication operations.
///
/// Call after WidgetsFlutterBinding.ensureInitialized(). Safe to call again;
/// initialization failures can be retried. Apple platforms need no setup.
Future<void> initializeNativePlatform() async {
  if (!Platform.isAndroid) return;
  final initialization = _initialization ??= _initializeAndroid();
  try {
    await initialization;
  } catch (_) {
    if (identical(_initialization, initialization)) _initialization = null;
    rethrow;
  }
}

Future<void> _initializeAndroid() async {
  final handles = await _platformChannel.invokeMethod<Int64List>('initialize');
  if (handles == null || handles.length != 2 || handles.any((h) => h == 0)) {
    throw StateError(
      'Android platform initialization returned invalid handles',
    );
  }
  final status = _initializeAndroidPlatform(handles[0], handles[1]);
  if (status != 0) {
    throw StateError('Android platform initialization failed (status $status)');
  }
}
