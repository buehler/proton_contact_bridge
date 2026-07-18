import 'dart:async';

import 'package:proton_go_api_bridge/proton_go_api_bridge.dart';
import 'package:proton_go_api_bridge/src/executor.dart';
import 'package:proton_go_api_bridge/src/protobuf/bridge/bridge.pb.dart';
import 'package:proton_go_api_bridge/src/protobuf/commands/commands.pb.dart'
    as c;

extension SyncApi on ProtonApi {
  Future<void> startSync() async {
    await executeCommand(
      Command()..contactSync = (c.ContactSync()..start = c.ContactSync_Start()),
    );
  }

  Future<bool> localEventsAvailable() async {
    final result = await executeCommand(
      Command()
        ..contactSync = (c.ContactSync()
          ..localEventsAvailable = c.ContactSync_LocalEventsAvailable()),
    );

    return result.contactSync.localEventsAvailable.hasEvents;
  }
}
