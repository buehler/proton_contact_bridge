import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:proton_go_api_bridge/src/protobuf/commands/commands.pb.dart'
    as commands;
import 'package:proton_go_api_bridge/src/protobuf/results/results.pb.dart'
    as results;

part 'group_mutation.freezed.dart';

@freezed
sealed class ContactGroupPatch with _$ContactGroupPatch {
  const ContactGroupPatch._();

  const factory ContactGroupPatch({
    required String contactId,
    @Default([]) List<String> addGroups,
    @Default([]) List<String> removeGroups,
  }) = _ContactGroupPatch;

  commands.Groups_ApplyContactGroupChanges_ContactPatch toProto() =>
      commands.Groups_ApplyContactGroupChanges_ContactPatch(
        contactId: contactId,
        addGroups: addGroups,
        removeGroups: removeGroups,
      );
}

@freezed
sealed class GroupContactFailure with _$GroupContactFailure {
  const factory GroupContactFailure({
    required String contactId,
    required String message,
  }) = _GroupContactFailure;

  factory GroupContactFailure.fromProto(
    results.Groups_Mutation_ContactFailure proto,
  ) => GroupContactFailure(contactId: proto.contactId, message: proto.message);
}

@freezed
sealed class GroupMutationResult with _$GroupMutationResult {
  const factory GroupMutationResult({
    required List<String> changedContactIds,
    required List<String> unchangedContactIds,
    required List<GroupContactFailure> failedContacts,
    required int requestedCount,
    required int completedCount,
    String? sourceName,
    String? targetName,
  }) = _GroupMutationResult;

  factory GroupMutationResult.fromProto(results.Groups_Mutation proto) =>
      GroupMutationResult(
        changedContactIds: proto.changedContactIds.toList(growable: false),
        unchangedContactIds: proto.unchangedContactIds.toList(growable: false),
        failedContacts: proto.failedContacts
            .map(GroupContactFailure.fromProto)
            .toList(growable: false),
        requestedCount: proto.requestedCount,
        completedCount: proto.completedCount,
        sourceName: proto.hasSourceName() ? proto.sourceName : null,
        targetName: proto.hasTargetName() ? proto.targetName : null,
      );
}
