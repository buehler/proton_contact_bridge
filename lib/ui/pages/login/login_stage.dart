import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proton_contact_bridge/ui/components/text.dart';
import 'package:proton_contact_bridge/ui/display_profile.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

enum LoginStage { credentials, verification, totp }

class LoginStagePanel extends ConsumerWidget {
  const LoginStagePanel({
    super.key,
    required this.stage,
    required this.child,
    this.maxWidth = 420,
  });

  final LoginStage stage;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = DisplayProfile.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: EdgeInsets.all(
          profile == DisplayProfile.compact
              ? context.theme.spaceLg
              : context.theme.spaceXl,
        ),
        decoration: BoxDecoration(
          color: context.theme.surface,
          border: Border.all(color: context.theme.divider),
          borderRadius: BorderRadius.circular(context.theme.containerRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KinCryptText(
              'Connect Proton',
              variant: KinCryptTextVariant.sectionTitle,
            ),
            SizedBox(height: context.theme.spaceXs),
            KinCryptText(_reason, color: context.theme.textMuted),
            SizedBox(height: context.theme.spaceLg),
            _LoginStageIndicator(stage: stage),
            SizedBox(height: context.theme.spaceXl),
            child,
          ],
        ),
      ),
    );
  }

  String get _reason => switch (stage) {
    LoginStage.credentials =>
      'Complete the security steps requested by Proton.',
    LoginStage.verification =>
      'Proton requires human verification before continuing.',
    LoginStage.totp =>
      'Proton requires the current code from your authenticator.',
  };
}

class _LoginStageIndicator extends StatelessWidget {
  const _LoginStageIndicator({required this.stage});

  final LoginStage stage;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = switch (stage) {
      LoginStage.credentials => 0,
      LoginStage.verification => 1,
      LoginStage.totp => 2,
    };

    return Semantics(
      label: 'Authentication step ${selectedIndex + 1} of 3',
      child: ExcludeSemantics(
        child: Wrap(
          spacing: context.theme.spaceSm,
          runSpacing: context.theme.spaceSm,
          children: [
            _StagePill(label: 'Credentials', selected: selectedIndex == 0),
            _StagePill(label: 'Verification', selected: selectedIndex == 1),
            _StagePill(label: 'One-time code', selected: selectedIndex == 2),
          ],
        ),
      ),
    );
  }
}

class _StagePill extends StatelessWidget {
  const _StagePill({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: context.theme.spaceMd,
      vertical: context.theme.spaceSm,
    ),
    decoration: BoxDecoration(
      color: selected
          ? context.theme.selectedSurface
          : context.theme.surfaceSoft,
      borderRadius: BorderRadius.circular(999),
    ),
    child: KinCryptText(
      label,
      variant: KinCryptTextVariant.body,
      color: selected ? context.theme.brandVault : context.theme.textMuted,
    ),
  );
}
