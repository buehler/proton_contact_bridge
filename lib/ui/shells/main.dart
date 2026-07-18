import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proton_contact_bridge/ui/components/app_icon.dart';
import 'package:proton_contact_bridge/ui/components/bottom_navigation_bar.dart';
import 'package:proton_contact_bridge/ui/components/bottom_navigation_bar_item.dart';
import 'package:proton_contact_bridge/ui/components/side_navidation_bar.dart';
import 'package:proton_contact_bridge/ui/display_profile.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final StatefulNavigationShell child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = DisplayProfile.of(context);

    if (profile == DisplayProfile.compact) {
      return Scaffold(
        body: child,
        backgroundColor: context.theme.canvas,
        bottomNavigationBar: KinCryptBottomNavigationBar(
          items: [
            KinCryptBottomNavigationBarItem(
              label: 'Contacts',
              icon: LucideIcons.contactRound,
              isSelected: child.currentIndex == 0,
              onTap: () => child.goBranch(0, initialLocation: true),
            ),
            KinCryptBottomNavigationBarItem(
              label: 'Groups',
              icon: LucideIcons.usersRound,
              isSelected: child.currentIndex == 1,
              onTap: () => child.goBranch(1, initialLocation: true),
            ),
            KinCryptBottomNavigationBarItem(
              label: 'Settings',
              icon: LucideIcons.settings2,
              isSelected: child.currentIndex == 2,
              onTap: () => child.goBranch(2, initialLocation: true),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          KinCryptSideNavigationBar(
            items: [
              KinCryptAppIcon(size: 48, rounded: true),
              KinCryptSideNavigationBarItem(
                label: 'Contacts',
                icon: LucideIcons.contactRound,
                isSelected: child.currentIndex == 0,
                onTap: () => child.goBranch(0, initialLocation: true),
              ),
              KinCryptSideNavigationBarItem(
                label: 'Groups',
                icon: LucideIcons.usersRound,
                isSelected: child.currentIndex == 1,
                onTap: () => child.goBranch(1, initialLocation: true),
              ),
              KinCryptSideNavigationBarItem(
                label: 'Settings',
                icon: LucideIcons.settings2,
                isSelected: child.currentIndex == 2,
                onTap: () => child.goBranch(2, initialLocation: true),
              ),
            ],
          ),
          Expanded(child: child),
        ],
      ),
      backgroundColor: context.theme.canvas,
    );
  }
}
