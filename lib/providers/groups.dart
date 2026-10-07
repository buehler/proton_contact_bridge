import 'dart:async';

import 'package:proton_contact_bridge/providers/proton.dart';
import 'package:proton_go_api_bridge/models/contacts/contact.dart';
import 'package:proton_go_api_bridge/models/groups/group.dart';
import 'package:proton_go_api_bridge/proton_go_api_bridge.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:proton_go_api_bridge/models/groups/group_mutation.dart';

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

/// Replaceable group commands, shared by list and detail page compositions.
abstract interface class GroupMutations {
  Future<GroupMutationResult> renameGroup(String sourceName, String targetName);
  Future<GroupMutationResult> deleteGroup(String name);
  Future<GroupMutationResult> applyContactGroupChanges(
    List<ContactGroupPatch> patches,
  );
}

@riverpod
GroupMutations groupMutations(Ref ref) =>
    _ApiGroupMutations(() => ref.read(protonApiProvider.future));

class _ApiGroupMutations implements GroupMutations {
  _ApiGroupMutations(this.api);
  final Future<ProtonApi> Function() api;

  @override
  Future<GroupMutationResult> renameGroup(
    String sourceName,
    String targetName,
  ) async => (await api()).renameGroup(sourceName, targetName);

  @override
  Future<GroupMutationResult> deleteGroup(String name) async =>
      (await api()).deleteGroup(name);

  @override
  Future<GroupMutationResult> applyContactGroupChanges(
    List<ContactGroupPatch> patches,
  ) async => (await api()).applyContactGroupChanges(patches);
}
