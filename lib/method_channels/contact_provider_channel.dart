import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:proton_go_api_bridge/proton_go_api_bridge.dart';

final class ContactProviderChannel {
  static final _logger = Logger('ContactProviderChannel');

  static const _channel = MethodChannel(
    'ch.cbue.protonContactBridge/contact_provider',
  );

  final ProtonApi _api;

  ContactProviderChannel(this._api);

  Future<void> signalEnumerator() async {
    if (!Platform.isIOS) {
      _logger.fine('Skipping signalEnumerator on non-iOS platform');
      return;
    }

    try {
      _logger.fine('Signaling contact enumerator');
      await _channel.invokeMethod('signalEnumerator');
    } on PlatformException catch (e) {
      _logger.severe('Failed to signal enumerator: ${e.message}');
    }
  }

  Future<void> signalIfRequired() async {
    if (!Platform.isIOS) {
      _logger.fine('Skipping signalIfRequired on non-iOS platform');
      return;
    }

    _logger.fine('Checking for local events available from contact sync');
    try {
      final r = await _api.localEventsAvailable();
      if (r) {
        _logger.info('Local events available, signaling contact enumerator');
        await signalEnumerator();
      } else {
        _logger.fine(
          'No local events available, skipping signal to contact enumerator',
        );
      }
    } catch (e) {
      _logger.severe('Error checking local events', e);
    }
  }
}
