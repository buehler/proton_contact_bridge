import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proton_contact_bridge/providers/proton.dart';
import 'package:proton_contact_bridge/providers/settings.dart';
import 'package:proton_contact_bridge/ui/components/contact_avatar.dart';
import 'package:proton_contact_bridge/ui/components/list_row.dart';
import 'package:proton_contact_bridge/ui/components/text.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';
import 'package:proton_contact_bridge/utils.dart';
import 'package:proton_go_api_bridge/models/contacts/contact.dart';
import 'package:proton_go_api_bridge/proton_go_api_bridge.dart';

class ContactList extends ConsumerWidget {
  const ContactList({
    super.key,
    required this.contacts,
    required this.emptyMessage,
  });

  final List<Contact> contacts;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (contacts.isEmpty) {
      return _EmptyState(message: emptyMessage);
    }

    final settings =
        ref.watch(settingsProvider).value ?? ContactSettings.defaults;
    final favorites = contacts.where((contact) => contact.isFavorite).toList()
      ..sort((left, right) => _compareContacts(left, right, settings));
    final groupedContacts = <String, List<Contact>>{};

    for (final contact in contacts.where((contact) => !contact.isFavorite)) {
      final letter = _groupKey(contact, settings);
      groupedContacts.putIfAbsent(letter, () => []).add(contact);
    }

    for (final group in groupedContacts.values) {
      group.sort((left, right) => _compareContacts(left, right, settings));
    }

    final groups = groupedContacts.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));

    return RefreshIndicator(
      color: context.theme.brandSignal,
      backgroundColor: context.theme.surface,
      onRefresh: () async {
        final api = await ref.read(protonApiProvider.future);
        await api.startSync();
      },
      child: ListView(
        padding: EdgeInsets.symmetric(vertical: context.theme.spaceSm),
        children: [
          for (final contact in favorites)
            _ContactTile(
              key: ValueKey('contact-${contact.id}'),
              contact: contact,
              settings: settings,
            ),
          for (final group in groups) ...[
            KinCryptAlphabetHeader(
              key: ValueKey('group-${group.key}'),
              label: group.key,
            ),
            for (final contact in group.value)
              _ContactTile(
                key: ValueKey('contact-${contact.id}'),
                contact: contact,
                settings: settings,
              ),
          ],
        ],
      ),
    );
  }

  static int _compareContacts(
    Contact left,
    Contact right,
    ContactSettings settings,
  ) {
    final sortNameComparison = _compareText(
      _sortName(left, settings.sortOrder),
      _sortName(right, settings.sortOrder),
    );
    if (sortNameComparison != 0) return sortNameComparison;

    final otherNameComparison = _compareText(
      _otherName(left, settings.sortOrder),
      _otherName(right, settings.sortOrder),
    );
    if (otherNameComparison != 0) return otherNameComparison;

    final displayNameComparison = _compareText(
      _displayName(left, settings.displayOrder),
      _displayName(right, settings.displayOrder),
    );
    if (displayNameComparison != 0) return displayNameComparison;

    return left.id.compareTo(right.id);
  }

  static int _compareText(String left, String right) =>
      left.toLowerCase().compareTo(right.toLowerCase());

  static String _sortName(Contact contact, ContactSortOrder sortOrder) {
    final firstName = contact.name?.firstName.trim() ?? '';
    final lastName = contact.name?.lastName.trim() ?? '';
    final preferred = switch (sortOrder) {
      ContactSortOrder.firstName => firstName,
      ContactSortOrder.lastName => lastName,
    };
    if (preferred.isNotEmpty) return preferred;

    final other = switch (sortOrder) {
      ContactSortOrder.firstName => lastName,
      ContactSortOrder.lastName => firstName,
    };
    if (other.isNotEmpty) return other;

    return _fallbackDisplayName(contact);
  }

  static String _otherName(Contact contact, ContactSortOrder sortOrder) =>
      switch (sortOrder) {
        ContactSortOrder.firstName => contact.name?.lastName.trim() ?? '',
        ContactSortOrder.lastName => contact.name?.firstName.trim() ?? '',
      };

  static String _groupKey(Contact contact, ContactSettings settings) {
    final groupName = _sortName(contact, settings.sortOrder);
    return groupName.isEmpty ? '#' : groupName.substring(0, 1).toUpperCase();
  }

  static String _displayName(
    Contact contact,
    ContactDisplayOrder displayOrder,
  ) {
    final formattedName = contact.formattedName.trim();
    if (formattedName.isNotEmpty) return formattedName;

    final firstName = contact.name?.firstName.trim() ?? '';
    final lastName = contact.name?.lastName.trim() ?? '';
    final structuredName = switch (displayOrder) {
      ContactDisplayOrder.firstNameFirst => [firstName, lastName],
      ContactDisplayOrder.lastNameFirst => [lastName, firstName],
    }.where((part) => part.isNotEmpty).join(' ');
    if (structuredName.isNotEmpty) return structuredName;

    return contact.id.isEmpty ? 'Unknown contact' : contact.id;
  }

  static String _fallbackDisplayName(Contact contact) {
    final formattedName = contact.formattedName.trim();
    if (formattedName.isNotEmpty) return formattedName;

    return contact.id.isEmpty ? 'Unknown contact' : contact.id;
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    super.key,
    required this.contact,
    required this.settings,
  });

  final Contact contact;
  final ContactSettings settings;

  @override
  Widget build(BuildContext context) {
    final displayName = ContactList._displayName(
      contact,
      settings.displayOrder,
    );

    final phone = contact.phones
        .map((phone) => readablePhoneNumber(phone.number))
        .where((number) => number.isNotEmpty)
        .firstOrNull;

    return KinCryptListRow(
      title: displayName,
      subtitle: phone,
      leading: ContactAvatar(
        contact: contact,
        displayName: displayName,
        showFavoriteBadge: true,
      ),
      showDisclosure: true,
      onTap: () => context.push('/contacts/${contact.id}'),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.theme.surface,
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(context.theme.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 48,
              color: context.theme.textMuted,
            ),
            SizedBox(height: context.theme.spaceMd),
            KinCryptText(
              message,
              variant: KinCryptTextVariant.listPrimary,
              color: context.theme.textMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
