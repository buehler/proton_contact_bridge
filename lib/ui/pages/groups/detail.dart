import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proton_contact_bridge/providers/channels.dart';
import 'package:proton_contact_bridge/providers/contacts.dart';
import 'package:proton_contact_bridge/providers/groups.dart';
import 'package:proton_contact_bridge/providers/proton.dart';
import 'package:proton_contact_bridge/providers/sync.dart';
import 'package:proton_contact_bridge/ui/components/activity_indicator.dart';
import 'package:proton_contact_bridge/ui/components/button.dart';
import 'package:proton_contact_bridge/ui/components/contact_list.dart';
import 'package:proton_contact_bridge/ui/components/message_state.dart';
import 'package:proton_contact_bridge/ui/components/safe_area.dart';
import 'package:proton_contact_bridge/ui/components/status_indicator.dart';
import 'package:proton_contact_bridge/ui/components/text.dart';
import 'package:proton_contact_bridge/ui/components/text_fields.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';
import 'package:proton_go_api_bridge/models/groups/group.dart';
import 'package:proton_go_api_bridge/models/groups/group_mutation.dart';
import 'package:proton_go_api_bridge/proton_go_api_bridge.dart';

class GroupDetailPage extends ConsumerStatefulWidget {
  final String groupName;

  const GroupDetailPage({super.key, required this.groupName});

  @override
  ConsumerState<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends ConsumerState<GroupDetailPage> {
  var _isMutating = false;
  var _selectionMode = false;
  final _selectedContactIds = <String>{};

  String get _groupName => widget.groupName.trim();

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(
      groupContactsProvider(groupName: widget.groupName),
    );
    final syncState = ref.watch(contactSyncStateProvider).value;
    final canMutate =
        !_isMutating &&
        !_selectionMode &&
        (contacts.value?.isNotEmpty ?? false) &&
        (syncState == ContactSyncState.idle ||
            syncState == ContactSyncState.error);
    final canSelect =
        !_isMutating &&
        (contacts.value?.isNotEmpty ?? false) &&
        (syncState == ContactSyncState.idle ||
            syncState == ContactSyncState.error);
    final canRemoveSelected =
        !_isMutating &&
        _selectedContactIds.isNotEmpty &&
        (syncState == ContactSyncState.idle ||
            syncState == ContactSyncState.error);
    final displayName = _groupName.isEmpty ? 'Unknown group' : _groupName;

    return PopScope(
      canPop: !_selectionMode && !_isMutating,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectionMode && !_isMutating) _cancelSelection();
      },
      child: ColoredBox(
        color: context.theme.canvas,
        child: KinCryptSafeArea(
          child: Column(
            children: [
              _GroupDetailHeader(
                groupName: displayName,
                contactCount: contacts.value?.length ?? 0,
                actionsEnabled: canMutate,
                selectionMode: _selectionMode,
                selectionEnabled: canSelect,
                selectedCount: _selectedContactIds.length,
                onBack: _selectionMode
                    ? _cancelSelection
                    : () => Navigator.of(context).maybePop(),
                onSelect: _selectionMode ? _cancelSelection : _startSelection,
                onRename: _showRenameSheet,
                onDelete: () => _confirmDelete(contacts.value!.length),
              ),
              Divider(height: 1, color: context.theme.divider),
              Expanded(
                child: contacts.when(
                  skipLoadingOnReload: true,
                  data: (contacts) => ContactList(
                    contacts: contacts,
                    emptyMessage: 'No contacts in $displayName',
                    selectionMode: _selectionMode,
                    selectedContactIds: _selectedContactIds,
                    onSelectionChanged: _toggleSelection,
                    onSelectionStarted: canSelect ? _startSelection : null,
                  ),
                  loading: () =>
                      const Center(child: KinCryptActivityIndicator(size: 32)),
                  error: (_, _) => const KinCryptMessageState(
                    icon: Icons.error_outline,
                    message: 'Could not load contacts',
                  ),
                ),
              ),
              if (_selectionMode)
                _GroupSelectionBar(
                  selectedCount: _selectedContactIds.length,
                  enabled: canRemoveSelected,
                  onRemove: () => _confirmRemove(contacts.value?.length ?? 0),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _startSelection([String? contactId]) {
    if (_isMutating) return;
    setState(() {
      _selectionMode = true;
      _selectedContactIds.clear();
      if (contactId != null) _selectedContactIds.add(contactId);
    });
  }

  void _toggleSelection(String contactId) {
    if (_isMutating) return;
    setState(() {
      if (!_selectedContactIds.add(contactId)) {
        _selectedContactIds.remove(contactId);
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedContactIds.clear();
    });
  }

  Future<void> _confirmRemove(int memberCount) async {
    final ids = _selectedContactIds.toList()..sort();
    if (ids.isEmpty) return;
    final removesFinalMember = memberCount > 0 && ids.length >= memberCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.theme.surface,
        title: Text(
          'Remove from $_groupName?',
          style: dialogContext.theme.sectionTitle,
        ),
        content: Text(
          'Remove ${ids.length} ${ids.length == 1 ? 'contact' : 'contacts'} from this group? The contacts will not be deleted.'
          '${removesFinalMember ? ' This removes the group because no members will remain.' : ''}',
          style: dialogContext.theme.body,
        ),
        actions: [
          KinCryptTextButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          KinCryptButton(
            label: 'Remove',
            style: KinCryptButtonStyle.danger,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _removeContacts(ids);
  }

  Future<void> _removeContacts(List<String> ids) => _runMutation(
    description: 'Removing contacts from group',
    failureLabel: 'remove contacts from group',
    execute: (api) => api.applyContactGroupChanges([
      for (final id in ids)
        ContactGroupPatch(contactId: id, removeGroups: [_groupName]),
    ]),
    retry: (result) => _removeContacts([
      for (final failure in result.failedContacts) failure.contactId,
    ]),
    onPartial: (result) => setState(() {
      _selectedContactIds
        ..clear()
        ..addAll(result.failedContacts.map((failure) => failure.contactId));
    }),
    onComplete: (_) async {
      try {
        final members = await ref.read(
          groupContactsProvider(groupName: widget.groupName).future,
        );
        if (!mounted) return;
        _cancelSelection();
        if (members.isEmpty) context.go('/groups');
      } catch (error) {
        if (mounted) {
          _showMessage(
            'Contacts were updated, but the group could not be refreshed: $error',
          );
        }
      }
    },
  );

  Future<void> _showRenameSheet() async {
    final List<Group> groups;
    try {
      groups = await ref.read(allGroupsProvider.future);
    } catch (error) {
      if (mounted) _showMessage('Could not load groups: $error');
      return;
    }
    if (!mounted) return;
    final targetName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _RenameGroupSheet(
        sourceName: _groupName,
        existingNames: groups.map((group) => group.name).toSet(),
      ),
    );
    if (targetName != null && mounted) await _rename(targetName);
  }

  Future<void> _confirmDelete(int contactCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.theme.surface,
        title: Text('Delete $_groupName?', style: context.theme.sectionTitle),
        content: Text(
          'This removes the group from $contactCount ${contactCount == 1 ? 'contact' : 'contacts'}. The contacts themselves will not be deleted.',
          style: context.theme.body,
        ),
        actions: [
          KinCryptTextButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          KinCryptButton(
            label: 'Delete group',
            style: KinCryptButtonStyle.danger,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _delete();
  }

  Future<void> _rename(String targetName) => _runMutation(
    description: 'Renaming group',
    failureLabel: 'rename group',
    execute: (api) => api.renameGroup(_groupName, targetName),
    retry: (_) => _rename(targetName),
    onComplete: (result) {
      if (result.requestedCount == 0) {
        context.go('/groups');
      } else {
        context.go(
          '/groups/${Uri.encodeComponent(result.targetName ?? targetName)}',
        );
      }
    },
  );

  Future<void> _delete() => _runMutation(
    description: 'Deleting group',
    failureLabel: 'delete group',
    execute: (api) => api.deleteGroup(_groupName),
    retry: (_) => _delete(),
    onComplete: (_) => context.go('/groups'),
  );

  Future<void> _runMutation({
    required String description,
    required String failureLabel,
    required Future<GroupMutationResult> Function(ProtonApi api) execute,
    required Future<void> Function(GroupMutationResult result) retry,
    void Function(GroupMutationResult result)? onPartial,
    required FutureOr<void> Function(GroupMutationResult result) onComplete,
  }) async {
    if (_isMutating) return;
    final syncState = ref.read(contactSyncStateProvider).value;
    if (syncState != ContactSyncState.idle &&
        syncState != ContactSyncState.error) {
      _showMessage('Group changes are unavailable while syncing or offline.');
      return;
    }

    setState(() => _isMutating = true);
    final navigator = Navigator.of(context, rootNavigator: true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: dialogContext.theme.surface,
            contentPadding: EdgeInsets.all(dialogContext.theme.spaceLg),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const KinCryptActivityIndicator(size: 24),
                SizedBox(width: dialogContext.theme.spaceLg),
                Expanded(child: KinCryptText(description)),
              ],
            ),
          ),
        ),
      ),
    );

    GroupMutationResult? result;
    Object? error;
    try {
      final api = await ref.read(protonApiProvider.future);
      result = await execute(api);
      if (mounted) {
        ref.invalidate(allGroupsProvider);
        ref.invalidate(groupContactsProvider);
        if (result.changedContactIds.isNotEmpty) {
          for (final provider in [
            allContactsProvider,
            contactProvider,
            searchContactsProvider,
          ]) {
            ref.invalidate(provider);
          }
          unawaited(
            ref.read(contactProviderChannelProvider).performLocalContactSync(),
          );
        }
      }
    } catch (caught) {
      error = caught;
    } finally {
      if (navigator.mounted) navigator.pop();
      if (mounted) setState(() => _isMutating = false);
    }

    if (!mounted) return;
    if (error != null) {
      _showMessage('Could not $failureLabel: $error');
    } else if (result != null && result.failedContacts.isNotEmpty) {
      onPartial?.call(result);
      _showMessage(
        '${result.completedCount} of ${result.requestedCount} contacts processed; ${result.failedContacts.length} failed.',
        retry: () {
          if (mounted) unawaited(retry(result!));
        },
      );
    } else if (result != null) {
      await onComplete(result);
    }
  }

  void _showMessage(String message, {VoidCallback? retry}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: retry == null
              ? const Duration(seconds: 4)
              : const Duration(seconds: 12),
          action: retry == null
              ? null
              : SnackBarAction(label: 'Retry', onPressed: retry),
        ),
      );
  }
}

class _GroupDetailHeader extends StatelessWidget {
  const _GroupDetailHeader({
    required this.groupName,
    required this.contactCount,
    required this.actionsEnabled,
    required this.selectionMode,
    required this.selectionEnabled,
    required this.selectedCount,
    required this.onBack,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
  });

  final String groupName;
  final int contactCount;
  final bool actionsEnabled;
  final bool selectionMode;
  final bool selectionEnabled;
  final int selectedCount;
  final VoidCallback onBack;
  final VoidCallback onSelect;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: context.theme.spaceLg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: context.theme.spaceSm,
            right: context.theme.spaceLg,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final theme = context.theme;
              final selectionLabel = selectionMode ? 'Cancel' : 'Select';
              final selectionSemanticLabel = selectionMode
                  ? 'Cancel selection'
                  : 'Select contacts';

              double textButtonWidth(String label) {
                final painter = TextPainter(
                  text: TextSpan(text: label, style: theme.button),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout();
                final width = painter.width + 2 * theme.spaceMd;
                painter.dispose();
                return width;
              }

              final identityWidth = 3 * theme.minimumTouchTarget;
              final compact =
                  constraints.maxWidth <
                  identityWidth +
                      2 * theme.minimumTouchTarget +
                      theme.spaceSm +
                      textButtonWidth('Edit') +
                      textButtonWidth(selectionLabel);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KinCryptIconButton(
                    icon: LucideIcons.chevronLeft,
                    semanticLabel: selectionMode ? 'Cancel selection' : 'Back',
                    onPressed: onBack,
                  ),
                  SizedBox(width: theme.spaceSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KinCryptText(
                          groupName,
                          variant: KinCryptTextVariant.screenTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: theme.spaceXs),
                        const KinCryptSyncIndicator(),
                      ],
                    ),
                  ),
                  if (compact) ...[
                    KinCryptIconButton(
                      icon: LucideIcons.pen,
                      semanticLabel: 'Edit group',
                      style: KinCryptIconButtonStyle.brand,
                      enabled: actionsEnabled,
                      onPressed: onRename,
                    ),
                    KinCryptIconButton(
                      icon: selectionMode
                          ? LucideIcons.x
                          : LucideIcons.copyCheck,
                      semanticLabel: selectionSemanticLabel,
                      style: KinCryptIconButtonStyle.brand,
                      enabled: selectionMode || selectionEnabled,
                      onPressed: onSelect,
                    ),
                  ] else ...[
                    KinCryptTextButton(
                      label: 'Edit',
                      semanticLabel: 'Edit group',
                      enabled: actionsEnabled,
                      onPressed: onRename,
                    ),
                    KinCryptTextButton(
                      label: selectionLabel,
                      semanticLabel: selectionSemanticLabel,
                      enabled: selectionMode || selectionEnabled,
                      onPressed: onSelect,
                    ),
                  ],
                  KinCryptIconButton(
                    icon: LucideIcons.trash2,
                    semanticLabel: 'Delete group',
                    style: KinCryptIconButtonStyle.danger,
                    enabled: actionsEnabled,
                    onPressed: onDelete,
                  ),
                ],
              );
            },
          ),
        ),
        Center(
          child: KinCryptText(
            selectionMode
                ? '$selectedCount selected'
                : '$contactCount ${contactCount == 1 ? 'contact' : 'contacts'}',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}

class _GroupSelectionBar extends StatelessWidget {
  const _GroupSelectionBar({
    required this.selectedCount,
    required this.enabled,
    required this.onRemove,
  });

  final int selectedCount;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.theme.surface,
    child: Padding(
      padding: EdgeInsets.all(context.theme.spaceMd),
      child: KinCryptButton(
        label: 'Remove $selectedCount from group',
        style: KinCryptButtonStyle.danger,
        stretch: true,
        enabled: enabled,
        onPressed: onRemove,
      ),
    ),
  );
}

class _RenameGroupSheet extends StatefulWidget {
  const _RenameGroupSheet({
    required this.sourceName,
    required this.existingNames,
  });

  final String sourceName;
  final Set<String> existingNames;

  @override
  State<_RenameGroupSheet> createState() => _RenameGroupSheetState();
}

class _RenameGroupSheetState extends State<_RenameGroupSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.sourceName,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String name) {
    if (name.isEmpty) return 'Enter a group name.';
    if (name == widget.sourceName) return 'Choose a different name.';
    if (name.contains(',')) return 'Group names cannot contain commas.';
    return null;
  }

  void _submit() {
    final name = _controller.text.trim();
    final error = _validate(name);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final targetName = _controller.text.trim();
    final merges =
        widget.existingNames.contains(targetName) &&
        targetName != widget.sourceName;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: EdgeInsets.all(context.theme.spaceLg),
        decoration: BoxDecoration(
          color: context.theme.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(context.theme.containerRadius),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KinCryptText(
              'Rename group',
              variant: KinCryptTextVariant.sectionTitle,
            ),
            SizedBox(height: context.theme.spaceLg),
            KinCryptTextField(
              controller: _controller,
              autofocus: true,
              label: 'Group name',
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              helperText: 'Commas are not allowed.',
              errorText: _error,
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            ),
            if (merges) ...[
              SizedBox(height: context.theme.spaceMd),
              KinCryptText(
                '“$targetName” already exists. Contacts from this group will join it.',
                color: context.theme.warning,
              ),
            ],
            SizedBox(height: context.theme.spaceLg),
            KinCryptButton(
              label: merges ? 'Merge groups' : 'Rename group',
              stretch: true,
              enabled: _validate(targetName) == null,
              onPressed: _submit,
            ),
            SizedBox(height: context.theme.spaceSm),
            KinCryptButton(
              label: 'Cancel',
              stretch: true,
              style: KinCryptButtonStyle.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
