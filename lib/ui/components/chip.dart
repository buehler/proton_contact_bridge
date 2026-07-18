import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

class KinCryptChip extends StatelessWidget {
  const KinCryptChip({
    super.key,
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.icon,
    this.onPressed,
    this.semanticLabel,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final IconData? icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && onPressed != null;
    final foreground = selected
        ? context.theme.brandVault
        : context.theme.textMuted;
    final background = selected
        ? context.theme.selectedSurface
        : context.theme.surfaceSoft;
    const radius = BorderRadius.all(Radius.circular(999));

    return Semantics(
      button: onPressed != null,
      enabled: interactive,
      selected: selected,
      label: semanticLabel ?? label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Material(
          color: enabled ? background : background.withValues(alpha: 0.52),
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: interactive ? onPressed : null,
            borderRadius: radius,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.theme.spaceMd,
                vertical: context.theme.spaceSm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: foreground),
                    SizedBox(width: context.theme.spaceXs),
                  ],
                  Text(
                    label,
                    style: context.theme.body.copyWith(
                      color: enabled
                          ? foreground
                          : foreground.withValues(alpha: 0.58),
                    ),
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
