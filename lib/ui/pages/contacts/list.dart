import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proton_contact_bridge/providers/contacts.dart';
import 'package:proton_contact_bridge/providers/sync.dart';
import 'package:proton_contact_bridge/ui/components/activity_indicator.dart';
import 'package:proton_contact_bridge/ui/components/button.dart';
import 'package:proton_contact_bridge/ui/components/contact_list.dart';
import 'package:proton_contact_bridge/ui/components/safe_area.dart';
import 'package:proton_contact_bridge/ui/components/status_indicator.dart';
import 'package:proton_contact_bridge/ui/components/text.dart';
import 'package:proton_contact_bridge/ui/components/text_fields.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';
import 'package:proton_go_api_bridge/models/contacts/contact.dart';

class _ContactsPageHeader extends ConsumerWidget {
  const new({required this.contactCount});

  final int contactCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
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
                  KinCryptSyncIndicator(
                    state: switch (ref.watch(contactSyncStateProvider)) {
                      AsyncValue(value: ContactSyncState.running) =>
                        KinCryptSyncState.syncing,
                      AsyncValue(value: ContactSyncState.idle) =>
                        KinCryptSyncState.synced,
                      AsyncValue(value: ContactSyncState.offline) =>
                        KinCryptSyncState.offline,
                      _ => KinCryptSyncState.failed,
                    },
                  ),
                ],
              ),
            ),
            KinCryptButton(
              label: 'Add',
              icon: LucideIcons.plus200,
              onPressed: () => context.push('/contacts/new'),
            ),
          ],
        ),
        Align(
          alignment: Alignment.center,
          child: KinCryptText('$contactCount contacts'),
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(searchContactsProvider(_debouncedSearchQuery));
    if (contacts.hasValue) {
      _loadedContacts = contacts.value;
    }

    return KinCryptSafeArea(
      child: Column(
        children: [
          _ContactsPageHeader(
            contactCount: contacts.maybeWhen(
              data: (contacts) => contacts.length,
              loading: () => _loadedContacts?.length ?? 0,
              orElse: () => 0,
            ),
          ),
          _ContactsSearchBar(onChanged: _onSearchChanged),
          Divider(height: 1, color: context.theme.divider),
          Expanded(
            child: contacts.when(
              skipLoadingOnReload: true,
              data: (contacts) => ContactList(
                contacts: contacts,
                emptyMessage: 'No contacts found',
              ),
              loading: () => _loadedContacts == null
                  ? const Center(child: KinCryptActivityIndicator(size: 32))
                  : ContactList(
                      contacts: _loadedContacts!,
                      emptyMessage: 'No contacts found',
                    ),
              error: (_, _) => _buildEmptyState(
                context,
                Icons.error_outline,
                'Could not load contacts',
              ),
            ),
          ),
        ],
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
