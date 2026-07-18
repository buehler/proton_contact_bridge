import 'dart:async';

import 'package:proton_contact_bridge/providers/proton.dart';
import 'package:proton_go_api_bridge/models/contacts/contact.dart';
import 'package:proton_go_api_bridge/models/groups/group.dart';
import 'package:proton_go_api_bridge/proton_go_api_bridge.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'groups.g.dart';

@riverpod
Future<List<Group>> allGroups(Ref ref) async {
  final api = await ref.watch(protonApiProvider.future);

  return api.getAllGroups();
}

@riverpod
Future<List<Contact>> groupContacts(
  Ref ref, {
  String? groupName,
  Group? group,
}) async {
  assert(
    groupName != null || group != null,
    'Either groupName or group must be provi ded',
  );

  final api = await ref.watch(protonApiProvider.future);

  return api.getGroupContacts(groupName ?? group?.name ?? '');
}
