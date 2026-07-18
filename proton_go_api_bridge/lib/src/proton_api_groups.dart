import 'package:proton_go_api_bridge/models/contacts/contact.dart';
import 'package:proton_go_api_bridge/models/groups/group.dart';
import 'package:proton_go_api_bridge/proton_go_api_bridge.dart';
import 'package:proton_go_api_bridge/src/executor.dart';
import 'package:proton_go_api_bridge/src/protobuf/bridge/bridge.pb.dart';
import 'package:proton_go_api_bridge/src/protobuf/commands/commands.pb.dart'
    as c;

extension GroupsApi on ProtonApi {
  Future<List<Group>> getAllGroups() async {
    final result = await executeCommand(
      Command(groups: c.Groups(getAll: c.Groups_GetAll())),
    );

    return result.groups.getAll.groups
        .map(Group.fromProto)
        .toList(growable: false);
  }

  Future<List<Contact>> getGroupContacts(String groupName) async {
    final result = await executeCommand(
      Command(
        groups: c.Groups(
          getGroupContacts: c.Groups_GetGroupContacts(groupName: groupName),
        ),
      ),
    );

    return result.groups.groupContacts.contacts
        .map(Contact.fromProto)
        .toList(growable: false);
  }
}
