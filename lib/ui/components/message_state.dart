import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/ui/components/text.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

class KinCryptMessageState extends StatelessWidget {
  const KinCryptMessageState({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: context.theme.textMuted),
        SizedBox(height: context.theme.spaceMd),
        KinCryptText(message, variant: KinCryptTextVariant.listPrimary),
      ],
    ),
  );
}
