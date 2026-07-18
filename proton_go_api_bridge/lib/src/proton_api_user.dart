import 'dart:async';

import 'package:proton_go_api_bridge/models/user/user_info.dart';
import 'package:proton_go_api_bridge/proton_go_api_bridge.dart';
import 'package:proton_go_api_bridge/src/executor.dart';
import 'package:proton_go_api_bridge/src/protobuf/bridge/bridge.pb.dart';
import 'package:proton_go_api_bridge/src/protobuf/commands/commands.pb.dart'
    as c;

extension UserApi on ProtonApi {
  Future<UserInfo> getUserInfo() async {
    final result = await executeCommand(Command()..getUser = (c.GetUser()));

    return switch (result.whichResponse()) {
      Result_Response.user => UserInfo(
        id: result.user.id,
        email: result.user.email,
        username: result.user.username,
        displayname: result.user.displayname,
      ),
      _ => UserInfo.empty(),
    };
  }
}
