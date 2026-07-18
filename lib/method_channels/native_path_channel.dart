import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

final class NativePathChannel {
  static final _logger = Logger('NativePathChannel');

  static const _channel = MethodChannel(
    'ch.cbue.protonContactBridge/native_path',
  );

  Future<String?> getDatabasePath() async {
    try {
      _logger.fine('Requesting database path from native code');
      final path = await _channel.invokeMethod('databasePath');
      return path as String?;
    } on PlatformException catch (e) {
      _logger.severe('Failed to grab database path: ${e.message}');
      return null;
    }
  }
}
