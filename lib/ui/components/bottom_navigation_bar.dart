import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/ui/components/bottom_navigation_bar_item.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

class KinCryptBottomNavigationBar extends StatelessWidget {
  const KinCryptBottomNavigationBar({super.key, required this.items});

  final List<KinCryptBottomNavigationBarItem> items;

  @override
  Widget build(BuildContext context) => Material(
    color: context.theme.surface,
    child: SafeArea(
      top: false,
      minimum: EdgeInsets.only(bottom: context.theme.spaceSm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, thickness: 1, color: context.theme.divider),
          SizedBox(height: context.theme.spaceSm),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.theme.spaceSm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: items,
            ),
          ),
        ],
      ),
    ),
  );
}
