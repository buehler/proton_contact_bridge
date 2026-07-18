import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/ui/components/activity_indicator.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

enum KinCryptStatusTone { neutral, success, warning, danger }

enum KinCryptSyncState { synced, syncing, pending, offline, failed }

class KinCryptStatusIndicator extends StatelessWidget {
  const KinCryptStatusIndicator({
    super.key,
    required this.label,
    this.tone = KinCryptStatusTone.neutral,
    this.icon,
    this.loading = false,
    this.onPressed,
    this.semanticLabel,
    this.announce = false,
  });

  final String label;
  final KinCryptStatusTone tone;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final bool announce;

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: onPressed == null ? 0 : context.theme.spaceSm,
        vertical: onPressed == null ? 0 : context.theme.spaceXs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const KinCryptActivityIndicator(size: 14)
          else if (icon != null)
            Icon(icon, size: 16, color: color)
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          SizedBox(width: context.theme.spaceSm),
          Flexible(child: Text(label, style: context.theme.meta)),
        ],
      ),
    );

    return Semantics(
      liveRegion: announce,
      button: onPressed != null,
      label: semanticLabel ?? label,
      child: onPressed == null
          ? content
          : ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(
                  context.theme.controlRadius,
                ),
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(
                    context.theme.controlRadius,
                  ),
                  child: content,
                ),
              ),
            ),
    );
  }

  Color _color(BuildContext context) => switch (tone) {
    KinCryptStatusTone.neutral => context.theme.textMuted,
    KinCryptStatusTone.success => context.theme.success,
    KinCryptStatusTone.warning => context.theme.warning,
    KinCryptStatusTone.danger => context.theme.danger,
  };
}

class KinCryptSyncIndicator extends StatelessWidget {
  const KinCryptSyncIndicator({
    super.key,
    required this.state,
    this.label,
    this.onPressed,
    this.announce = false,
  });

  final KinCryptSyncState state;
  final String? label;
  final VoidCallback? onPressed;
  final bool announce;

  @override
  Widget build(BuildContext context) => KinCryptStatusIndicator(
    label: label ?? _defaultLabel,
    tone: _tone,
    icon: _icon,
    loading: state == KinCryptSyncState.syncing,
    onPressed: onPressed,
    announce: announce,
    semanticLabel: 'Synchronization status: ${label ?? _defaultLabel}',
  );

  String get _defaultLabel => switch (state) {
    KinCryptSyncState.synced => 'Synced',
    KinCryptSyncState.syncing => 'Syncing…',
    KinCryptSyncState.pending => 'Changes pending',
    KinCryptSyncState.offline => 'Offline',
    KinCryptSyncState.failed => 'Sync failed',
  };

  KinCryptStatusTone get _tone => switch (state) {
    KinCryptSyncState.synced => KinCryptStatusTone.success,
    KinCryptSyncState.syncing => KinCryptStatusTone.neutral,
    KinCryptSyncState.pending => KinCryptStatusTone.warning,
    KinCryptSyncState.offline => KinCryptStatusTone.neutral,
    KinCryptSyncState.failed => KinCryptStatusTone.danger,
  };

  IconData? get _icon => switch (state) {
    KinCryptSyncState.offline => Icons.cloud_off_outlined,
    KinCryptSyncState.failed => Icons.error_outline,
    _ => null,
  };
}
