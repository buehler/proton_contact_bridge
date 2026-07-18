import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:proton_contact_bridge/providers/proton.dart';
import 'package:proton_go_api_bridge/models/auth/auth_state.dart';
import 'package:proton_go_api_bridge/models/contacts/sync_state.dart' as b;
import 'package:proton_go_api_bridge/proton_go_api_bridge.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

part 'sync.g.dart';

enum ContactSyncState { idle, running, error, offline }

@riverpod
Stream<ContactSyncState> contactSyncState(Ref ref) async* {
  final protonApi = await ref.watch(protonApiProvider.future);
  final conn = Connectivity().onConnectivityChanged
      .map((l) => l.hasConnectivity)
      .startWith(true);
  final sync = protonApi.contactSyncStateStream
      .startWith(b.ContactSyncState.idle)
      .map(
        (e) => switch (e) {
          b.ContactSyncState.idle => ContactSyncState.idle,
          b.ContactSyncState.running => ContactSyncState.running,
          b.ContactSyncState.error => ContactSyncState.error,
        },
      );

  yield* Rx.combineLatest2(
    conn,
    sync,
    (hasConnection, syncState) => switch ((hasConnection, syncState)) {
      (false, _) => ContactSyncState.offline,
      (true, ContactSyncState.idle) => ContactSyncState.idle,
      (true, ContactSyncState.running) => ContactSyncState.running,
      _ => ContactSyncState.error,
    },
  );
}

@Riverpod(keepAlive: true)
void syncTrigger(Ref ref) {
  final logger = Logger('syncTrigger');

  var foreground =
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  var foregroundSyncPending = foreground;
  var authenticated = false;
  var syncState = ContactSyncState.idle;
  var starting = false;

  Future<void> maybeStartForegroundSync(String reason) async {
    if (!foreground || !foregroundSyncPending || !authenticated || starting) {
      return;
    }

    // A running sync already satisfies this foreground cycle.
    if (syncState == ContactSyncState.running) {
      foregroundSyncPending = false;
      return;
    }

    foregroundSyncPending = false;
    starting = true;

    try {
      logger.info('Triggering foreground sync: $reason');
      final api = await ref.read(protonApiProvider.future);
      await api.startSync();
    } catch (error, stackTrace) {
      logger.severe('Failed to trigger foreground sync.', error, stackTrace);
    } finally {
      starting = false;
    }
  }

  ref.listen(protonAuthProvider, (previous, next) {
    final wasAuthenticated = previous?.value is Authenticated;
    authenticated = next.value is Authenticated;

    if (authenticated && !wasAuthenticated) {
      foregroundSyncPending = true;
      unawaited(maybeStartForegroundSync('authentication initialized'));
    }
  }, fireImmediately: true);

  ref.listen(contactSyncStateProvider, (_, next) {
    final value = next.value;
    if (value == null) return;

    syncState = value;
    unawaited(maybeStartForegroundSync('sync state available'));
  }, fireImmediately: true);

  final lifecycleListener = AppLifecycleListener(
    onPause: () {
      foreground = false;
      foregroundSyncPending = true;
    },
    onResume: () {
      final returningFromBackground = !foreground;
      foreground = true;

      if (returningFromBackground) {
        foregroundSyncPending = true;
        unawaited(maybeStartForegroundSync('app resumed'));
      }
    },
  );

  final timer = Timer.periodic(const Duration(minutes: 10), (_) async {
    if (!foreground ||
        !authenticated ||
        starting ||
        syncState != ContactSyncState.idle) {
      return;
    }

    starting = true;
    try {
      logger.info('Triggering periodic foreground sync.');
      final api = await ref.read(protonApiProvider.future);
      await api.startSync();
    } catch (error, stackTrace) {
      logger.severe('Periodic sync failed.', error, stackTrace);
    } finally {
      starting = false;
    }
  });

  ref.onDispose(() {
    lifecycleListener.dispose();
    timer.cancel();
  });
}
