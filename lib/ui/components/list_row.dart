import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

class KinCryptAlphabetHeader extends StatelessWidget {
  const KinCryptAlphabetHeader({
    super.key,
    required this.label,
    this.sticky = false,
  });

  final String label;
  final bool sticky;

  @override
  Widget build(BuildContext context) => Container(
    color: sticky ? context.theme.surface : Colors.transparent,
    padding: EdgeInsets.fromLTRB(
      context.theme.spaceLg,
      context.theme.spaceMd,
      context.theme.spaceLg,
      context.theme.spaceXs,
    ),
    child: Text(
      label,
      style: context.theme.meta.copyWith(color: context.theme.textMuted),
    ),
  );
}

class KinCryptListRow extends StatelessWidget {
  const KinCryptListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.roundedEdges = false,
    this.selected = false,
    this.enabled = true,
    this.showDisclosure = false,
    this.compact = false,
    this.subtitleMaxLines = 2,
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool roundedEdges;
  final bool selected;
  final bool enabled;
  final bool showDisclosure;
  final bool compact;
  final int subtitleMaxLines;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && onTap != null;

    final radius = roundedEdges
        ? BorderRadius.circular(context.theme.controlRadius)
        : BorderRadius.circular(0);
    final foreground = enabled
        ? context.theme.textPrimary
        : context.theme.textMuted.withValues(alpha: 0.62);

    return Semantics(
      button: onTap != null,
      enabled: interactive,
      selected: selected,
      label: semanticLabel,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: compact ? context.theme.minimumTouchTarget : 64,
        ),
        child: Material(
          color: selected ? context.theme.selectedSurface : Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: interactive ? onTap : null,
            borderRadius: radius,
            highlightColor: context.theme.selectedSurface,
            focusColor: context.theme.selectedSurface,
            hoverColor: context.theme.selectedSurface,
            splashColor: context.theme.selectedSurface,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.theme.spaceLg,
                vertical: context.theme.spaceSm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading != null) ...[
                    leading!,
                    SizedBox(width: context.theme.spaceMd),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: context.theme.listPrimary.copyWith(
                            color: foreground,
                          ),
                        ),
                        if (subtitle case final subtitle?) ...[
                          SizedBox(height: context.theme.spaceXs),
                          Text(
                            subtitle,
                            maxLines: subtitleMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style: context.theme.body.copyWith(
                              color: context.theme.textMuted.withValues(
                                alpha: enabled ? 1 : 0.62,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    SizedBox(width: context.theme.spaceSm),
                    trailing!,
                  ] else if (showDisclosure) ...[
                    SizedBox(width: context.theme.spaceSm),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: context.theme.textMuted,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
