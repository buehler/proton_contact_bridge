import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/ui/shells/main.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  var _searchQuery = '';

  static const _contacts = <({String name, String initials})>[
    (name: 'Alexander Archer', initials: 'AA'),
    (name: 'Benjamin Brooks', initials: 'BB'),
    (name: 'Brianna Baker', initials: 'BB'),
    (name: 'Caleb Carter', initials: 'CC'),
    (name: 'Chloe Chen', initials: 'CC'),
    (name: 'Daniel Davis', initials: 'DD'),
    (name: 'Diana Dawson', initials: 'DD'),
    (name: 'Elliot Evans', initials: 'EE'),
    (name: 'Fiona Foster', initials: 'FF'),
    (name: 'Grace Green', initials: 'GG'),
  ];

  @override
  Widget build(BuildContext context) {
    return MainShell(
      onSearchbarChange: (value) => setState(() => _searchQuery = value),
      child: _buildContactsList(context),
    );
  }

  Widget _buildContactsList(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final filteredContacts = _contacts
        .where((contact) => contact.name.toLowerCase().contains(query))
        .toList();
    final groupedContacts = <String, List<({String name, String initials})>>{};

    for (final contact in filteredContacts) {
      final letter = contact.name.substring(0, 1).toUpperCase();
      groupedContacts.putIfAbsent(letter, () => []).add(contact);
    }

    if (groupedContacts.isEmpty) {
      return _buildEmptyState(context, Icons.search_off, 'No favorites found');
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final entry in groupedContacts.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              entry.key,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          for (final contact in entry.value)
            ListTile(
              leading: CircleAvatar(child: Text(contact.initials)),
              title: Text(contact.name),
              onTap: () => _showMessage(context, contact.name),
            ),
        ],
      ],
    );
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

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
