import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:proton_contact_bridge/ui/pages/login/login_credentials.dart';
import 'package:proton_contact_bridge/ui/pages/login/two_factor_auth.dart';
import 'package:proton_contact_bridge/ui/pages/login/human_verification.dart';
import 'package:proton_go_api_bridge/models/auth/auth_state.dart';

import '../../preview/harness.dart';

@widgetbook.UseCase(name: 'Default', type: LoginCredentialsPage)
Widget buildLoginCredentialsPageDefaultUseCase(BuildContext context) =>
    previewPage(
      context,
      location: '/login/credentials',
      state: PreviewState.populated,
      auth: const AuthState.unauthenticated(),
      authenticationControls: true,
    );

@widgetbook.UseCase(name: 'TOTP', type: TwoFactorAuthPage)
Widget buildTwoFactorAuthPageTotpUseCase(BuildContext context) => previewPage(
  context,
  location: '/login/2fa',
  state: PreviewState.populated,
  authenticationControls: true,
  auth: const AuthState.requireTwoFactor(totp: true),
);

@widgetbook.UseCase(name: 'Unsupported method', type: TwoFactorAuthPage)
Widget buildTwoFactorAuthPageUnsupportedMethodUseCase(BuildContext context) =>
    previewPage(
      context,
      location: '/login/2fa',
      state: PreviewState.populated,
      authenticationControls: true,
      auth: const AuthState.requireTwoFactor(totp: false),
    );

@widgetbook.UseCase(name: 'Unavailable URL', type: HumanVerificationPage)
Widget buildHumanVerificationPageUnavailableUrlUseCase(BuildContext context) =>
    previewPage(
      context,
      location: '/login/captcha',
      state: PreviewState.populated,
      auth: const AuthState.requireHumanVerification(''),
    );
