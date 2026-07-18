import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

class KinCryptBottomNavigationBarItem extends StatelessWidget {
  const KinCryptBottomNavigationBarItem({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.isSelected = false,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected
        ? context.theme.brandVault
        : context.theme.textMuted;
    final radius = BorderRadius.circular(context.theme.controlRadius);

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: onTap != null,
      label: label,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: 88,
          minHeight: context.theme.minimumTouchTarget,
        ),
        child: Material(
          color: isSelected
              ? context.theme.selectedSurface
              : Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            splashColor: context.theme.brandSignal,
            focusColor: context.theme.brandSignal,
            highlightColor: context.theme.brandSignal,
            hoverColor: context.theme.brandSignal,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.theme.spaceMd,
                vertical: context.theme.spaceSm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: foreground),
                  SizedBox(height: context.theme.spaceXs),
                  Text(
                    label,
                    style: context.theme.meta.copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
