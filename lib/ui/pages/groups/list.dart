import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/ui/shells/main.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  var _searchQuery = '';

  static const _groups = <({String name, String initials})>[
    (name: 'Family', initials: 'FA'),
    (name: 'Friends', initials: 'FR'),
    (name: 'School', initials: 'SC'),
    (name: 'Travel', initials: 'TR'),
    (name: 'Work', initials: 'WO'),
  ];

  @override
  Widget build(BuildContext context) {
    return MainShell(
      onSearchbarChange: (value) => setState(() => _searchQuery = value),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMessage(context, 'Add group'),
        child: const Icon(Icons.add),
      ),
      child: _buildGroupsList(context),
    );
  }

  Widget _buildGroupsList(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final filteredGroups = _groups
        .where((group) => group.name.toLowerCase().contains(query))
        .toList();
    final groupedGroups = <String, List<({String name, String initials})>>{};

    for (final group in filteredGroups) {
      final letter = group.name.substring(0, 1).toUpperCase();
      groupedGroups.putIfAbsent(letter, () => []).add(group);
    }

    if (groupedGroups.isEmpty) {
      return _buildEmptyState(context, Icons.search_off, 'No groups found');
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final entry in groupedGroups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              entry.key,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          for (final group in entry.value)
            ListTile(
              leading: CircleAvatar(child: Text(group.initials)),
              title: Text(group.name),
              onTap: () => _showMessage(context, group.name),
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
