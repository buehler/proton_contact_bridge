import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proton_contact_bridge/providers/channels.dart';
import 'package:proton_contact_bridge/providers/contacts.dart';
import 'package:proton_contact_bridge/providers/groups.dart';
import 'package:proton_contact_bridge/providers/sync.dart';
import 'package:proton_contact_bridge/ui/components/activity_indicator.dart';
import 'package:proton_contact_bridge/ui/components/button.dart';
import 'package:proton_contact_bridge/ui/components/contact_list.dart';
import 'package:proton_contact_bridge/ui/components/list_row.dart';
import 'package:proton_contact_bridge/ui/components/safe_area.dart';
import 'package:proton_contact_bridge/ui/components/status_indicator.dart';
import 'package:proton_contact_bridge/ui/components/text.dart';
import 'package:proton_contact_bridge/ui/components/text_fields.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';
import 'package:proton_go_api_bridge/models/contacts/contact.dart';
import 'package:proton_go_api_bridge/models/groups/group.dart';
import 'package:proton_go_api_bridge/models/groups/group_mutation.dart';

class _ContactsPageHeader extends StatelessWidget {
  const new({
    required this.contactCount,
    required this.selectionMode,
    required this.selectedCount,
    required this.selectEnabled,
    required this.onSelect,
    required this.onCancel,
  });

  final int contactCount;
  final bool selectionMode;
  final int selectedCount;
  final bool selectEnabled;
  final VoidCallback onSelect;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: context.theme.spaceLg),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Contacts', style: context.theme.screenTitle),
                  const KinCryptSyncIndicator(),
                ],
              ),
            ),
            if (selectionMode)
              KinCryptTextButton(label: 'Cancel', onPressed: onCancel)
            else ...[
              KinCryptTextButton(
                label: 'Select',
                enabled: selectEnabled,
                onPressed: onSelect,
              ),
              KinCryptButton(
                label: 'Add',
                icon: LucideIcons.plus200,
                onPressed: () => context.push('/contacts/new'),
              ),
            ],
          ],
        ),
        Align(
          alignment: Alignment.center,
          child: KinCryptText(
            selectionMode
                ? '$selectedCount selected'
                : '$contactCount contacts',
          ),
        ),
      ],
    ),
  );
}

class _ContactsSearchBar extends StatefulWidget {
  const new({this.onChanged});

  final ValueChanged<String>? onChanged;

  @override
  State<_ContactsSearchBar> createState() => _ContactsSearchBarState();
}

class _ContactsSearchBarState extends State<_ContactsSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    _focusNode.unfocus();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(context.theme.spaceLg),
    child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) => KinCryptTextField(
        controller: _controller,
        focusNode: _focusNode,
        hint: 'Search contacts',
        prefixIcon: Icon(LucideIcons.search),
        suffix: value.text.isEmpty
            ? null
            : KinCryptIconButton(
                icon: LucideIcons.x,
                semanticLabel: 'Clear search',
                onPressed: _clear,
              ),
        onChanged: widget.onChanged,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.search,
      ),
    ),
  );
}

class ContactsPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage> {
  var _searchQuery = '';
  var _debouncedSearchQuery = '';
  List<Contact>? _loadedContacts;
  Timer? _searchDebounce;
  var _selectionMode = false;
  var _isMutating = false;
  var _isChoosingGroups = false;
  final _selectedContactIds = <String>{};

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(searchContactsProvider(_debouncedSearchQuery));
    final syncState = ref.watch(contactSyncStateProvider).value;
    final canChangeGroups =
        !_isMutating &&
        !_isChoosingGroups &&
        (syncState == ContactSyncState.idle ||
            syncState == ContactSyncState.error);
    final canSelect = canChangeGroups && (contacts.value?.isNotEmpty ?? false);
    if (contacts.hasValue) {
      _loadedContacts = contacts.value;
    }

    return PopScope(
      canPop: !_selectionMode && !_isMutating,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectionMode && !_isMutating) _cancelSelection();
      },
      child: KinCryptSafeArea(
        child: Column(
          children: [
            _ContactsPageHeader(
              contactCount: contacts.maybeWhen(
                data: (contacts) => contacts.length,
                loading: () => _loadedContacts?.length ?? 0,
                orElse: () => 0,
              ),
              selectionMode: _selectionMode,
              selectedCount: _selectedContactIds.length,
              selectEnabled: canSelect,
              onSelect: _startSelection,
              onCancel: _cancelSelection,
            ),
            _ContactsSearchBar(onChanged: _onSearchChanged),
            Divider(height: 1, color: context.theme.divider),
            Expanded(
              child: contacts.when(
                skipLoadingOnReload: true,
                data: (contacts) => ContactList(
                  contacts: contacts,
                  emptyMessage: 'No contacts found',
                  selectionMode: _selectionMode,
                  selectedContactIds: _selectedContactIds,
                  onSelectionChanged: _toggleSelection,
                  onSelectionStarted: canSelect ? _startSelection : null,
                ),
                loading: () => _loadedContacts == null
                    ? const Center(child: KinCryptActivityIndicator(size: 32))
                    : ContactList(
                        contacts: _loadedContacts!,
                        emptyMessage: 'No contacts found',
                        selectionMode: _selectionMode,
                        selectedContactIds: _selectedContactIds,
                        onSelectionChanged: _toggleSelection,
                        onSelectionStarted: canSelect ? _startSelection : null,
                      ),
                error: (_, _) => _buildEmptyState(
                  context,
                  Icons.error_outline,
                  'Could not load contacts',
                ),
              ),
            ),
            if (_selectionMode)
              _ContactsSelectionBar(
                selectedCount: _selectedContactIds.length,
                enabled: canChangeGroups && _selectedContactIds.isNotEmpty,
                onAdd: _showAddGroupsSheet,
              ),
          ],
        ),
      ),
    );
  }

  void _startSelection([String? contactId]) {
    if (_isMutating || _isChoosingGroups) return;
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

  Future<void> _showAddGroupsSheet() async {
    if (_isChoosingGroups || _selectedContactIds.isEmpty) return;
    setState(() => _isChoosingGroups = true);
    try {
      final List<Group> groups;
      try {
        groups = await ref.read(allGroupsProvider.future);
      } catch (error) {
        if (mounted) _showMessage('Could not load groups: $error');
        return;
      }
      if (!mounted || !_selectionMode || _selectedContactIds.isEmpty) return;
      final names = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        builder: (_) => _AddGroupsSheet(
          contactCount: _selectedContactIds.length,
          existingNames: [for (final group in groups) group.name.trim()],
        ),
      );
      if (names == null || !mounted || !_selectionMode) return;
      final ids = _selectedContactIds.toList()..sort();
      await _addContacts(ids, names);
    } finally {
      if (mounted) setState(() => _isChoosingGroups = false);
    }
  }

  Future<void> _addContacts(List<String> ids, List<String> names) async {
    if (_isMutating || ids.isEmpty || names.isEmpty) return;
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
                const Expanded(
                  child: KinCryptText('Adding contacts to groups'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    GroupMutationResult? result;
    Object? error;
    try {
      final api = ref.read(groupMutationsProvider);
      result = await api.applyContactGroupChanges([
        for (final id in ids)
          ContactGroupPatch(contactId: id, addGroups: names),
      ]);
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
      _showMessage('Could not add contacts to groups: $error');
    } else if (result != null && result.failedContacts.isNotEmpty) {
      final failedIds = [
        for (final failure in result.failedContacts) failure.contactId,
      ];
      setState(() {
        _selectedContactIds
          ..clear()
          ..addAll(failedIds);
      });
      _showMessage(
        '${result.completedCount} of ${result.requestedCount} contacts processed; ${failedIds.length} failed.',
        retry: () {
          if (mounted) unawaited(_addContacts(failedIds, names));
        },
      );
    } else if (result != null) {
      _cancelSelection();
      _showMessage(
        '${result.completedCount} ${result.completedCount == 1 ? 'contact' : 'contacts'} processed.',
      );
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

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchQuery = value;

    if (value.isEmpty) {
      if (_debouncedSearchQuery.isNotEmpty) {
        setState(() => _debouncedSearchQuery = '');
      }
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 240), () {
      if (!mounted || _searchQuery != value || value == _debouncedSearchQuery) {
        return;
      }
      setState(() => _debouncedSearchQuery = value);
    });
  }

  Widget _buildEmptyState(BuildContext context, IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ContactsSelectionBar extends StatelessWidget {
  const _ContactsSelectionBar({
    required this.selectedCount,
    required this.enabled,
    required this.onAdd,
  });

  final int selectedCount;
  final bool enabled;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.theme.surface,
    child: Padding(
      padding: EdgeInsets.all(context.theme.spaceMd),
      child: KinCryptButton(
        label: 'Add $selectedCount to groups',
        stretch: true,
        enabled: enabled,
        onPressed: onAdd,
      ),
    ),
  );
}

class _AddGroupsSheet extends StatefulWidget {
  const _AddGroupsSheet({
    required this.contactCount,
    required this.existingNames,
  });

  final int contactCount;
  final List<String> existingNames;

  @override
  State<_AddGroupsSheet> createState() => _AddGroupsSheetState();
}

class _AddGroupsSheetState extends State<_AddGroupsSheet> {
  final _selectedNames = <String>{};
  final _newNameController = TextEditingController();
  late final _names =
      widget.existingNames
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort(
          (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
        );
  var _query = '';
  var _creatingGroup = false;
  String? _newNameError;

  @override
  void dispose() {
    _newNameController.dispose();
    super.dispose();
  }

  void _createGroup() {
    final name = _newNameController.text.trim();
    if (name.isEmpty || name.contains(',')) {
      setState(
        () => _newNameError = name.isEmpty
            ? 'Enter a group name.'
            : 'Group names cannot contain commas.',
      );
      return;
    }
    setState(() {
      if (!_names.contains(name)) {
        _names.add(name);
        _names.sort(
          (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
        );
      }
      _selectedNames.add(name);
      _newNameController.clear();
      _newNameError = null;
      _creatingGroup = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _names
        .where((name) => name.toLowerCase().contains(_query))
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Container(
          padding: EdgeInsets.all(context.theme.spaceLg),
          decoration: BoxDecoration(
            color: context.theme.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(context.theme.containerRadius),
            ),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: KinCryptText(
                      'Add to groups',
                      variant: KinCryptTextVariant.sectionTitle,
                    ),
                  ),
                  KinCryptTextButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              SizedBox(height: context.theme.spaceMd),
              KinCryptSearchField(
                hint: 'Search groups',
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
              SizedBox(height: context.theme.spaceSm),
              if (filtered.isEmpty)
                Padding(
                  padding: EdgeInsets.all(context.theme.spaceLg),
                  child: const Center(child: KinCryptText('No groups found')),
                )
              else
                for (final name in filtered)
                  KinCryptListRow(
                    title: name,
                    selected: _selectedNames.contains(name),
                    semanticLabel:
                        '$name, ${_selectedNames.contains(name) ? 'selected' : 'not selected'}',
                    leading: Icon(
                      _selectedNames.contains(name)
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: _selectedNames.contains(name)
                          ? context.theme.brandVault
                          : context.theme.textMuted,
                    ),
                    onTap: () => setState(() {
                      if (!_selectedNames.add(name)) {
                        _selectedNames.remove(name);
                      }
                    }),
                  ),
              Divider(height: 1, color: context.theme.divider),
              if (_creatingGroup) ...[
                SizedBox(height: context.theme.spaceMd),
                KinCryptTextField(
                  controller: _newNameController,
                  autofocus: true,
                  label: 'New group name',
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  errorText: _newNameError,
                  onChanged: (_) => setState(() => _newNameError = null),
                  onSubmitted: (_) => _createGroup(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    KinCryptTextButton(
                      label: 'Cancel',
                      onPressed: () => setState(() {
                        _creatingGroup = false;
                        _newNameController.clear();
                        _newNameError = null;
                      }),
                    ),
                    KinCryptTextButton(
                      label: 'Add group',
                      onPressed: _createGroup,
                    ),
                  ],
                ),
              ] else
                KinCryptListRow(
                  title: 'Create new group',
                  leading: Icon(
                    LucideIcons.plus,
                    color: context.theme.brandVault,
                  ),
                  onTap: () => setState(() => _creatingGroup = true),
                ),
              SizedBox(height: context.theme.spaceMd),
              KinCryptText(
                '${_selectedNames.length} ${_selectedNames.length == 1 ? 'group' : 'groups'} selected',
                variant: KinCryptTextVariant.meta,
              ),
              SizedBox(height: context.theme.spaceSm),
              KinCryptButton(
                label:
                    'Add to ${widget.contactCount} ${widget.contactCount == 1 ? 'contact' : 'contacts'}',
                stretch: true,
                enabled: _selectedNames.isNotEmpty && !_creatingGroup,
                onPressed: () =>
                    Navigator.of(context).pop(_selectedNames.toList()..sort()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
