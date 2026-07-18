import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:proton_go_api_bridge/src/bindings.g.dart';

enum NativeLogLevel {
  debug(-4),
  info(0),
  warn(4),
  error(8);

  final int value;
  const NativeLogLevel(this.value);

  factory NativeLogLevel._fromInt(int value) =>
      NativeLogLevel.values.firstWhere(
        (level) => level.value == value,
        orElse: () => NativeLogLevel.info,
      );
}

typedef LogCallback = void Function(NativeLogLevel level, String message);

final class NativeLoggerCallback {
  static var _nextRegistrationId = 1;
  static final _finalizer = Finalizer<_NativeLoggerRegistration>(
    (registration) => registration.dispose(),
  );

  late final _NativeLoggerRegistration _registration;
  bool _disposed = false;

  NativeLoggerCallback(LogCallback callback) {
    final registrationId = _nextRegistrationId++;
    final listener = NativeCallable<LogCallbackFunction>.listener((
      int level,
      Pointer<Char> message,
    ) {
      final logLevel = NativeLogLevel._fromInt(level);
      var logMessage = '';
      try {
        logMessage = message.address != 0
            ? message.cast<Utf8>().toDartString()
            : '';
      } finally {
        FreeLogMessage(message);
      }
      callback(logLevel, logMessage);
    });

    _registration = _NativeLoggerRegistration(registrationId, listener);
    _finalizer.attach(this, _registration, detach: this);
    RegisterLogCallback(registrationId, listener.nativeFunction);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _finalizer.detach(this);
    _registration.dispose();
  }
}

final class _NativeLoggerRegistration {
  final int id;
  final NativeCallable<LogCallbackFunction> listener;
  bool _disposed = false;

  _NativeLoggerRegistration(this.id, this.listener);

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    UnregisterLogCallback(id);
    listener.close();
  }
}
