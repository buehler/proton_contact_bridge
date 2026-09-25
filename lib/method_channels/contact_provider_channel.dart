import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

final class ContactProviderChannel {
  static final _logger = Logger('ContactProviderChannel');

  static const _channel = MethodChannel(
    'ch.cbue.protonContactBridge/contact_provider',
  );

  Future<void> resetContactProvider() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      _logger.fine(
        'Skipping resetContactProvider on non-iOS/non-Android platform',
      );
      return;
    }

    try {
      _logger.fine('Resetting contact provider');
      await _channel.invokeMethod('resetContactProvider');
    } on PlatformException catch (e) {
      _logger.severe('Failed to reset contact provider: ${e.message}');
    }
  }

  Future<void> performLocalContactSync([bool force = false]) async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      _logger.fine(
        'Skipping performLocalContactSync on non-iOS/non-Android platform',
      );
      return;
    }

    try {
      _logger.fine('Performing local contact sync');
      await _channel.invokeMethod('performLocalContactSync', {'force': force});
    } on PlatformException catch (e) {
      _logger.severe('Failed to perform local contact sync: ${e.message}');
    }
  }
}
