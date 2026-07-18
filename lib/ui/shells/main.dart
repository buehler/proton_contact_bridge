import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.child,
    this.floatingActionButton,
    this.onSearchbarChange,
  });

  final Widget child;
  final Widget? floatingActionButton;
  final ValueChanged<String>? onSearchbarChange;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = switch (GoRouterState.of(context).uri.path) {
      final path when path.startsWith('/groups') => 1,
      final path when path.startsWith('/favorites') => 2,
      _ => 0,
    };

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context, selectedIndex),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: widget.child),
          ],
        ),
      ),
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => _goToDestination(context, index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            selectedIcon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_border),
            selectedIcon: Icon(Icons.star),
            label: 'Favorites',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Open menu',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: widget.onSearchbarChange,
                decoration: const InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Sync contacts',
              onPressed: () => _showMessage(context, 'Sync paused'),
              icon: const Icon(Icons.sync),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, int selectedIndex) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text('Contacts'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.contacts_outlined),
              title: const Text('Contacts'),
              selected: selectedIndex == 0,
              onTap: () => _goToDestination(context, 0),
            ),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('Groups'),
              selected: selectedIndex == 1,
              onTap: () => _goToDestination(context, 1),
            ),
            ListTile(
              leading: const Icon(Icons.star_border),
              title: const Text('Favorites'),
              selected: selectedIndex == 2,
              onTap: () => _goToDestination(context, 2),
            ),
          ],
        ),
      ),
    );
  }

  void _goToDestination(BuildContext context, int index) {
    Navigator.of(context).maybePop();
    context.go(switch (index) {
      1 => '/groups',
      2 => '/favorites',
      _ => '/contacts',
    });
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
