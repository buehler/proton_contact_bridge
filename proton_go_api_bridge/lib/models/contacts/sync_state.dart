import 'package:proton_go_api_bridge/src/bindings.g.dart';

enum ContactSyncState {
  idle(CONTACT_SYNC_STATE_IDLE),
  running(CONTACT_SYNC_STATE_RUNNING),
  error(CONTACT_SYNC_STATE_ERROR);

  final int value;

  const ContactSyncState(this.value);

  factory ContactSyncState.fromC(int state) => switch (state) {
    CONTACT_SYNC_STATE_IDLE => ContactSyncState.idle,
    CONTACT_SYNC_STATE_RUNNING => ContactSyncState.running,
    CONTACT_SYNC_STATE_ERROR => ContactSyncState.error,
    _ => throw ArgumentError('Unknown contact sync state: $state'),
  };
}
