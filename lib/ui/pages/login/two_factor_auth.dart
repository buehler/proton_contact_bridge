import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proton_contact_bridge/providers/proton.dart';
import 'package:proton_contact_bridge/ui/components/button.dart';
import 'package:proton_contact_bridge/ui/components/one_time_code_field.dart';
import 'package:proton_contact_bridge/ui/components/status_indicator.dart';
import 'package:proton_contact_bridge/ui/components/text.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';
import 'package:proton_contact_bridge/ui/pages/login/login_stage.dart';
import 'package:proton_go_api_bridge/models/auth/auth_state.dart';

class TwoFactorAuthPage extends ConsumerStatefulWidget {
  const TwoFactorAuthPage({super.key});

  @override
  ConsumerState<TwoFactorAuthPage> createState() => _TwoFactorAuthPageState();
}

class _TwoFactorAuthPageState extends ConsumerState<TwoFactorAuthPage> {
  static const _totpError =
      'That code was not accepted. Enter the current code and try again.';

  final _totpController = TextEditingController();
  final _totpFocusNode = FocusNode();
  bool _complete = false;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _totpController.dispose();
    _totpFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_complete) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(protonAuthProvider.notifier)
          .submitTotp(_totpController.text);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = _totpError;
      });
      return;
    }

    if (!mounted) return;
    final authState = ref.read(protonAuthProvider).value;
    setState(() {
      _submitting = false;
      if (authState is Error) {
        _errorMessage = _totpError;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(protonAuthProvider).value;
    final totpEnabled = switch (authState) {
      RequireTwoFactor(:final totp) => totp,
      _ => true,
    };

    return LoginStagePanel(
      stage: LoginStage.totp,
      child: totpEnabled
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const KinCryptText(
                  'Enter the six-digit code from your authenticator app.',
                ),
                SizedBox(height: context.theme.spaceXl),
                KinCryptOneTimeCodeField(
                  controller: _totpController,
                  focusNode: _totpFocusNode,
                  autofocus: true,
                  enabled: !_submitting,
                  errorText: _errorMessage,
                  onChanged: (value) {
                    final complete = value.length == 6;
                    if (complete != _complete || _errorMessage != null) {
                      setState(() {
                        _complete = complete;
                        _errorMessage = null;
                      });
                    }
                  },
                ),
                SizedBox(height: context.theme.spaceXl),
                KinCryptButton(
                  label: 'Verify and connect',
                  stretch: true,
                  loading: _submitting,
                  enabled: _complete && !_submitting,
                  onPressed: _submit,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const KinCryptStatusIndicator(
                  label:
                      'This Proton account requires a two-factor method that '
                      'KinCrypt does not support.',
                  tone: KinCryptStatusTone.danger,
                  icon: Icons.error_outlined,
                  announce: true,
                ),
                SizedBox(height: context.theme.spaceMd),
                const KinCryptText(
                  'TOTP from an authenticator app is the only supported '
                  'two-factor method.',
                ),
              ],
            ),
    );
  }
}
