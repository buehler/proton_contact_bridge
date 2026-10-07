import 'dart:async';

import 'package:proton_contact_bridge/providers/groups.dart';
import 'package:proton_go_api_bridge/models/contacts/contact.dart';
import 'package:proton_go_api_bridge/models/groups/group.dart';
import 'package:proton_go_api_bridge/models/groups/group_mutation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

enum PreviewState { populated, empty, loading, error, missing, minimal }

class PreviewStore implements GroupMutations {
  PreviewStore(
    this.previewState, {
    bool? favorite,
    String groupName = previewGroupName,
  }) : contacts = switch (previewState) {
         PreviewState.empty || PreviewState.missing => [],
         PreviewState.minimal => [minimalContact],
         _ => [...previewContacts],
       } {
    for (var index = 0; index < contacts.length; index++) {
      final contact = contacts[index];
      contacts[index] = contact.copyWith(
        isFavorite: contact.id == previewContactId
            ? favorite ?? contact.isFavorite
            : contact.isFavorite,
        groups: contact.groups
            .map((name) => name == previewGroupName ? groupName : name)
            .toList(),
      );
    }
  }

  final PreviewState previewState;
  final List<Contact> contacts;
  final preferences = MemoryPreferences();
  void Function() changed = () {};
  var _nextId = 0;

  Future<T> query<T>(T value) => switch (previewState) {
    PreviewState.loading => Completer<T>().future,
    PreviewState.error => Future.error(
      StateError('Simulated preview load failure'),
    ),
    _ => Future.value(value),
  };

  Contact? contact(String? id) =>
      contacts.where((contact) => contact.id == id).firstOrNull;

  List<Contact> search(String query) {
    final needle = query.trim().toLowerCase();
    return contacts
        .where(
          (contact) => [
            contact.formattedName,
            contact.name?.firstName ?? '',
            contact.name?.lastName ?? '',
            ...contact.emails.map((email) => email.address),
            ...contact.phones.map((phone) => phone.number),
          ].any((value) => value.toLowerCase().contains(needle)),
        )
        .toList();
  }

  List<Group> get groups =>
      (contacts.expand((contact) => contact.groups).toSet().toList()..sort())
          .map((name) => Group(name: name))
          .toList();

  Contact save(Contact contact) {
    final saved = contact.id.isEmpty
        ? contact.copyWith(id: 'preview-${_nextId++}')
        : contact;
    contacts.removeWhere((contact) => contact.id == saved.id);
    contacts.add(saved);
    changed();
    return saved;
  }

  void delete(String id) {
    contacts.removeWhere((contact) => contact.id == id);
    changed();
  }

  @override
  Future<GroupMutationResult> applyContactGroupChanges(
    List<ContactGroupPatch> patches,
  ) async {
    final changedIds = <String>[];
    final unchangedIds = <String>[];
    final failures = <GroupContactFailure>[];
    for (final patch in patches) {
      final index = contacts.indexWhere(
        (contact) => contact.id == patch.contactId,
      );
      if (index < 0) {
        failures.add(
          GroupContactFailure(
            contactId: patch.contactId,
            message: 'Contact unavailable',
          ),
        );
        continue;
      }
      final old = contacts[index];
      final groups = {...old.groups}
        ..removeAll(patch.removeGroups)
        ..addAll(patch.addGroups);
      if (groups.length == old.groups.length &&
          groups.containsAll(old.groups)) {
        unchangedIds.add(old.id);
      } else {
        contacts[index] = old.copyWith(groups: groups.toList()..sort());
        changedIds.add(old.id);
      }
    }
    changed();
    return GroupMutationResult(
      changedContactIds: changedIds,
      unchangedContactIds: unchangedIds,
      failedContacts: failures,
      requestedCount: patches.length,
      completedCount: changedIds.length + unchangedIds.length,
    );
  }

  @override
  Future<GroupMutationResult> renameGroup(
    String sourceName,
    String targetName,
  ) async {
    final result = await applyContactGroupChanges([
      for (final contact in [...contacts])
        if (contact.groups.contains(sourceName))
          ContactGroupPatch(
            contactId: contact.id,
            removeGroups: [sourceName],
            addGroups: [targetName],
          ),
    ]);
    return result.copyWith(sourceName: sourceName, targetName: targetName);
  }

  @override
  Future<GroupMutationResult> deleteGroup(String name) =>
      applyContactGroupChanges([
        for (final contact in [...contacts])
          if (contact.groups.contains(name))
            ContactGroupPatch(contactId: contact.id, removeGroups: [name]),
      ]);
}

/// Implements preferences without constructing a platform-backed instance.
class MemoryPreferences implements SharedPreferencesAsync {
  final _values = <String, Object>{};

  @override
  Future<String?> getString(String key) async => _values[key] as String?;
  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;
  @override
  Future<int?> getInt(String key) async => _values[key] as int?;
  @override
  Future<double?> getDouble(String key) async => _values[key] as double?;
  @override
  Future<List<String>?> getStringList(String key) async =>
      (_values[key] as List<String>?)?.toList();
  @override
  Future<void> setBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    _values[key] = value;
  }

  @override
  Future<void> setDouble(String key, double value) async {
    _values[key] = value;
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    _values[key] = [...value];
  }

  @override
  Future<bool> containsKey(String key) async => _values.containsKey(key);
  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<Set<String>> getKeys({Set<String>? allowList}) async => _values.keys
      .where((key) => allowList == null || allowList.contains(key))
      .toSet();
  @override
  Future<Map<String, Object?>> getAll({Set<String>? allowList}) async => {
    for (final key in await getKeys(allowList: allowList)) key: _values[key],
  };
  @override
  Future<void> clear({Set<String>? allowList}) async {
    _values.removeWhere(
      (key, _) => allowList == null || allowList.contains(key),
    );
  }
}
