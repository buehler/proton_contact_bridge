import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proton_contact_bridge/providers/sync.dart';
import 'package:proton_contact_bridge/ui/components/activity_indicator.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

enum KinCryptStatusTone { neutral, success, warning, danger }

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

class KinCryptSyncIndicator extends ConsumerWidget {
  const KinCryptSyncIndicator({
    super.key,
    this.label,
    this.onPressed,
    this.announce = false,
  });

  final String? label;
  final VoidCallback? onPressed;
  final bool announce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(contactSyncStateWithProgressProvider).value;
    final state = sync?.$1 ?? ContactSyncState.error;
    final displayLabel =
        label ??
        switch (state) {
          ContactSyncState.idle => 'Synced',
          ContactSyncState.running =>
            '${sync!.$2.processed} / ${sync.$2.total} synced',
          ContactSyncState.offline => 'Offline',
          ContactSyncState.error => 'Sync failed',
        };

    return KinCryptStatusIndicator(
      label: displayLabel,
      tone: switch (state) {
        ContactSyncState.idle => KinCryptStatusTone.success,
        ContactSyncState.running ||
        ContactSyncState.offline => KinCryptStatusTone.neutral,
        ContactSyncState.error => KinCryptStatusTone.danger,
      },
      icon: switch (state) {
        ContactSyncState.offline => Icons.cloud_off_outlined,
        ContactSyncState.error => Icons.error_outline,
        _ => null,
      },
      loading: state == ContactSyncState.running,
      onPressed: onPressed,
      announce: announce,
      semanticLabel: 'Synchronization status: $displayLabel',
    );
  }
}
