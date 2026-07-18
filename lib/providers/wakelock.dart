import 'package:logging/logging.dart';
import 'package:proton_contact_bridge/providers/sync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'wakelock.g.dart';

@Riverpod(keepAlive: true)
class Wakelock extends _$Wakelock {
  final _logger = Logger('wakelock');

  @override
  bool build() {
    ref.listen(contactSyncStateProvider, (_, state) {
      switch (state) {
        case AsyncValue(value: ContactSyncState.running):
          enable();
          break;
        default:
          disable();
      }
    });

    return false;
  }

  /// Enables the wakelock to keep the screen on
  Future<void> enable() async {
    if (state) return;
    _logger.info('Enabling wakelock');
    await WakelockPlus.enable();
    state = true;
  }

  /// Disables the wakelock to allow the screen to sleep
  Future<void> disable() async {
    if (!state) return;
    _logger.info('Disabling wakelock');
    await WakelockPlus.disable();
    state = false;
  }
}
