import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

enum KinCryptButtonStyle { primary, secondary, danger, dangerSoft }

enum KinCryptIconButtonStyle { neutral, brand, danger, filled }

class KinCryptButton extends StatelessWidget {
  const KinCryptButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.style = KinCryptButtonStyle.primary,
    this.stretch = false,
    this.loading = false,
    this.enabled = true,
    this.semanticLabel,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final KinCryptButtonStyle style;
  final bool stretch;
  final bool loading;
  final bool enabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && !loading && onPressed != null;
    final backgroundColor = _backgroundColor(context);
    final foregroundColor = _foregroundColor(context);
    final radius = BorderRadius.circular(context.theme.controlRadius);

    final button = ConstrainedBox(
      constraints: BoxConstraints(minHeight: context.theme.minimumTouchTarget),
      child: Material(
        color: interactive
            ? backgroundColor
            : backgroundColor.withValues(alpha: 0.52),
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: interactive ? onPressed : null,
          borderRadius: radius,
          focusColor: context.theme.brandVault.withValues(alpha: 0.14),
          hoverColor: foregroundColor.withValues(alpha: 0.08),
          splashColor: foregroundColor.withValues(alpha: 0.12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.theme.spaceLg,
              vertical: context.theme.spaceMd,
            ),
            child: Row(
              mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foregroundColor,
                    ),
                  )
                else if (icon != null)
                  Icon(icon, size: 20, color: foregroundColor),
                if (loading || icon != null)
                  SizedBox(width: context.theme.spaceSm),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.button.copyWith(
                      color: interactive
                          ? foregroundColor
                          : foregroundColor.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: interactive,
      label: semanticLabel ?? label,
      value: loading ? 'Loading' : null,
      child: stretch ? SizedBox(width: double.infinity, child: button) : button,
    );
  }

  Color _backgroundColor(BuildContext context) => switch (style) {
    KinCryptButtonStyle.primary => context.theme.brandVault,
    KinCryptButtonStyle.secondary => context.theme.surfaceSoft,
    KinCryptButtonStyle.danger => context.theme.danger,
    KinCryptButtonStyle.dangerSoft => context.theme.dangerSurface,
  };

  Color _foregroundColor(BuildContext context) => switch (style) {
    KinCryptButtonStyle.primary => context.theme.onBrand,
    KinCryptButtonStyle.secondary => context.theme.textPrimary,
    KinCryptButtonStyle.danger => context.theme.onDanger,
    KinCryptButtonStyle.dangerSoft => context.theme.danger,
  };
}

class KinCryptTextButton extends StatelessWidget {
  const KinCryptTextButton({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.onPressed,
    this.enabled = true,
    this.semanticLabel,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && onPressed != null;
    final foregroundColor = color ?? context.theme.brandVault;
    final radius = BorderRadius.circular(context.theme.controlRadius);

    return Semantics(
      button: true,
      enabled: interactive,
      label: semanticLabel ?? label,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: context.theme.minimumTouchTarget,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: interactive ? onPressed : null,
            borderRadius: radius,
            splashColor: context.theme.brandSignal,
            focusColor: context.theme.brandSignal,
            highlightColor: context.theme.brandSignal,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.theme.spaceMd),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 20,
                      color: interactive
                          ? foregroundColor
                          : foregroundColor.withValues(alpha: 0.5),
                    ),
                    SizedBox(width: context.theme.spaceSm),
                  ],
                  Text(
                    label,
                    style: context.theme.button.copyWith(
                      color: interactive
                          ? foregroundColor
                          : foregroundColor.withValues(alpha: 0.5),
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

class KinCryptIconButton extends StatelessWidget {
  const KinCryptIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.style = KinCryptIconButtonStyle.neutral,
    this.enabled = true,
    this.selected = false,
    this.size = 20,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final KinCryptIconButtonStyle style;
  final bool enabled;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && onPressed != null;
    final foreground = _foregroundColor(context);
    final background = _backgroundColor(context);
    final radius = BorderRadius.circular(context.theme.controlRadius);

    return Semantics(
      button: true,
      enabled: interactive,
      selected: selected,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: SizedBox.square(
          dimension: context.theme.minimumTouchTarget,
          child: Material(
            color: background,
            borderRadius: radius,
            child: InkWell(
              onTap: interactive ? onPressed : null,
              borderRadius: radius,
              child: Icon(
                icon,
                size: size,
                color: interactive
                    ? foreground
                    : foreground.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _foregroundColor(BuildContext context) => switch (style) {
    KinCryptIconButtonStyle.neutral => context.theme.textMuted,
    KinCryptIconButtonStyle.brand => context.theme.brandVault,
    KinCryptIconButtonStyle.danger => context.theme.danger,
    KinCryptIconButtonStyle.filled => context.theme.brandVault,
  };

  Color _backgroundColor(BuildContext context) => switch (style) {
    KinCryptIconButtonStyle.filled => context.theme.selectedSurface,
    _ => Colors.transparent,
  };
}
