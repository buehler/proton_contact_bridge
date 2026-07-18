import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proton_contact_bridge/providers/proton.dart';
import 'package:proton_contact_bridge/ui/components/button.dart';
import 'package:proton_contact_bridge/ui/components/status_indicator.dart';
import 'package:proton_contact_bridge/ui/components/text_fields.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';
import 'package:proton_contact_bridge/ui/pages/login/login_stage.dart';
import 'package:proton_go_api_bridge/models/auth/auth_state.dart';

class LoginCredentialsPage extends ConsumerStatefulWidget {
  const LoginCredentialsPage({super.key});

  @override
  ConsumerState<LoginCredentialsPage> createState() =>
      _LoginCredentialsPageState();
}

class _LoginCredentialsPageState extends ConsumerState<LoginCredentialsPage> {
  static const _signInError =
      'Sign-in failed. Check your Proton username and password and try again.';

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(protonAuthProvider.notifier)
          .login(_usernameController.text, _passwordController.text);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = _signInError;
      });
      return;
    }

    if (!mounted) return;
    final authState = ref.read(protonAuthProvider).value;
    setState(() {
      _submitting = false;
      if (authState is Error || authState is Unauthenticated) {
        _errorMessage = _signInError;
      }
    });
  }

  void _clearError() {
    if (_errorMessage == null) return;
    setState(() => _errorMessage = null);
  }

  String? _validateRequired(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your $label.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => LoginStagePanel(
    stage: LoginStage.credentials,
    child: AutofillGroup(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KinCryptTextField(
              type: TextFieldType.usernameOrEmail,
              controller: _usernameController,
              focusNode: _usernameFocusNode,
              autofocus: true,
              enabled: !_submitting,
              label: 'Proton username or email',
              hint: 'Enter your username or email',
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  _validateRequired(value, 'Proton username or email'),
              onChanged: (_) => _clearError(),
              onSubmitted: (_) => _passwordFocusNode.requestFocus(),
            ),
            SizedBox(height: context.theme.spaceLg),
            KinCryptTextField(
              type: TextFieldType.password,
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              enabled: !_submitting,
              label: 'Password',
              hint: 'Enter your password',
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              validator: (value) => _validateRequired(value, 'password'),
              onChanged: (_) => _clearError(),
              onSubmitted: (_) => _submit(),
              suffix: KinCryptIconButton(
                icon: _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                semanticLabel: _obscurePassword
                    ? 'Show password'
                    : 'Hide password',
                enabled: !_submitting,
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            if (_errorMessage case final error?) ...[
              SizedBox(height: context.theme.spaceLg),
              KinCryptStatusIndicator(
                label: error,
                tone: KinCryptStatusTone.danger,
                icon: Icons.error_outline,
                announce: true,
              ),
            ],
            SizedBox(height: context.theme.spaceXl),
            KinCryptButton(
              label: 'Continue securely',
              stretch: true,
              loading: _submitting,
              enabled: !_submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    ),
  );
}
