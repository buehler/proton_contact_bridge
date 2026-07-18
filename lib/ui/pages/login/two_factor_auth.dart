import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proton_contact_bridge/providers/proton_auth.dart';
import 'package:proton_contact_bridge/ui/components/text.dart';

class TwoFactorAuthPage extends ConsumerWidget {
  TwoFactorAuthPage({super.key});

  final _totpController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Flex(
    direction: Axis.vertical,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AppText(
                  'Please enter your 2FA code',
                  variant: TypographyVariant.headlineMedium,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),

                TextField(
                  controller: _totpController,
                  autofocus: true,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: 'Enter your 2FA code',
                    labelText: '2FA CODE',
                    labelStyle: TypographyVariant.labelMedium.style,
                  ),
                ),
                FilledButton(
                  onPressed: () => ref
                      .read(protonAuthProvider)
                      .submitTotp(_totpController.text),
                  child: const AppText('Submit'),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
