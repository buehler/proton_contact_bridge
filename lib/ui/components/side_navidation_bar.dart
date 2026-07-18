import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/ui/components/safe_area.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

class KinCryptSideNavigationBar extends StatelessWidget {
  const new({super.key, required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.theme.surface,
      border: Border(right: BorderSide(color: context.theme.divider, width: 1)),
    ),
    child: KinCryptSafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.theme.spaceLg),
        child: Column(
          spacing: context.theme.spaceXl,
          mainAxisSize: MainAxisSize.max,
          children: items,
        ),
      ),
    ),
  );
}

class KinCryptSideNavigationBarItem extends StatefulWidget {
  const new({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  State<KinCryptSideNavigationBarItem> createState() =>
      _KinCryptSideNavigationBarItemState();
}

class _KinCryptSideNavigationBarItemState
    extends State<KinCryptSideNavigationBarItem> {
  var _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final foreground = switch ((_isHovered, widget.isSelected)) {
      (true, _) => context.theme.onBrand,
      (_, true) => context.theme.brandVault,
      _ => context.theme.textMuted,
    };
    final radius = BorderRadius.circular(context.theme.controlRadius);

    return Semantics(
      button: true,
      selected: widget.isSelected,
      enabled: widget.onTap != null,
      label: widget.label,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: 88,
          minHeight: context.theme.minimumTouchTarget,
        ),
        child: Material(
          color: widget.isSelected
              ? context.theme.selectedSurface
              : Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: radius,
            onHover: (hovered) => setState(() => _isHovered = hovered),
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
                  Icon(widget.icon, size: 20, color: foreground),
                  SizedBox(height: context.theme.spaceXs),
                  Text(
                    widget.label,
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
