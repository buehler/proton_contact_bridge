import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proton_contact_bridge/providers/proton.dart';
import 'package:proton_contact_bridge/ui/components/activity_indicator.dart';
import 'package:proton_contact_bridge/ui/components/button.dart';
import 'package:proton_contact_bridge/ui/components/status_indicator.dart';
import 'package:proton_contact_bridge/ui/components/text.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';
import 'package:proton_contact_bridge/ui/pages/login/login_stage.dart';
import 'package:proton_go_api_bridge/models/auth/auth_state.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HumanVerificationPage extends ConsumerStatefulWidget {
  const HumanVerificationPage({super.key});

  @override
  ConsumerState<HumanVerificationPage> createState() =>
      _HumanVerificationPageState();
}

class _HumanVerificationPageState
    extends ConsumerState<HumanVerificationPage> {
  static const _verificationError =
      'Verification was not accepted. Reload the challenge and try again.';

  WebViewController? _controller;
  String? _verificationUrl;
  bool _started = false;
  bool _loading = false;
  bool _submitting = false;
  bool _completionSubmitted = false;
  String? _loadError;
  String? _authError;

  Uri? _verificationUri(String? rawUrl) {
    final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'verify.proton.me') {
      return null;
    }

    return uri.replace(
      queryParameters: {...uri.queryParameters, 'embed': 'true'},
    );
  }

  String? _currentVerificationUrl() {
    final authState = ref.read(protonAuthProvider).value;
    if (authState case RequireHumanVerification(:final url)) {
      _verificationUrl = url;
    }
    return _verificationUrl;
  }

  Future<void> _startVerification() async {
    final uri = _verificationUri(_currentVerificationUrl());
    if (uri == null) {
      setState(() {
        _started = true;
        _loadError = 'The Proton verification address is invalid.';
      });
      return;
    }

    setState(() {
      _started = true;
      _loading = true;
      _loadError = null;
      _authError = null;
    });

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('iOS', onMessageReceived: _handleMessage)
      ..addJavaScriptChannel(
        'AndroidInterface',
        onMessageReceived: _handleMessage,
      );

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (_) {
          if (!mounted) return;
          setState(() {
            _loading = true;
            _loadError = null;
          });
        },
        onPageFinished: (_) async {
          try {
            await controller.runJavaScript('''
              if (window.AndroidInterface &&
                  !window.AndroidInterface.dispatch) {
                window.AndroidInterface.dispatch = function(message) {
                  window.AndroidInterface.postMessage(message);
                };
              }
            ''');
          } catch (_) {
            if (!mounted) return;
            setState(() {
              _loadError = 'Unable to prepare the verification challenge.';
            });
          }

          if (!mounted) return;
          setState(() => _loading = false);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == false || !mounted) return;
          setState(() {
            _loading = false;
            _loadError = 'Unable to load the Proton verification challenge.';
          });
        },
      ),
    );

    _controller = controller;
    try {
      await controller.loadRequest(uri);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Unable to load the Proton verification challenge.';
      });
    }
  }

  Future<void> _reloadVerification() async {
    final controller = _controller;
    if (controller == null) {
      await _startVerification();
      return;
    }

    setState(() {
      _loading = true;
      _loadError = null;
      _authError = null;
      _completionSubmitted = false;
    });
    try {
      await controller.reload();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Unable to reload the Proton verification challenge.';
      });
    }
  }

  Future<void> _handleMessage(JavaScriptMessage message) async {
    if (_completionSubmitted || _submitting) return;

    final result = _parseMessage(message.message);
    if (result == null) return;

    setState(() {
      _completionSubmitted = true;
      _submitting = true;
      _authError = null;
    });

    try {
      await ref
          .read(protonAuthProvider.notifier)
          .submitHumanVerification(token: result.$1, method: result.$2);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _completionSubmitted = false;
        _authError = _verificationError;
      });
      return;
    }

    if (!mounted) return;
    final authState = ref.read(protonAuthProvider).value;
    setState(() {
      _submitting = false;
      _completionSubmitted = false;
      if (authState is Error) {
        _authError = _verificationError;
      }
    });
  }

  (String, String)? _parseMessage(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['type'] != 'HUMAN_VERIFICATION_SUCCESS') {
        return null;
      }

      final payload = json['payload'];
      if (payload is! Map) return null;

      final token = payload['token'];
      final type = payload['type'];
      if (token is! String ||
          token.isEmpty ||
          type is! String ||
          type.isEmpty) {
        return null;
      }

      return (token, type);
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableUrl = _currentVerificationUrl();
    final uriIsValid = _verificationUri(availableUrl) != null;

    return LoginStagePanel(
      stage: LoginStage.verification,
      maxWidth: 600,
      child: !_started
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: EdgeInsets.all(context.theme.spaceXl),
                  decoration: BoxDecoration(
                    color: context.theme.surfaceSoft,
                    border: Border.all(color: context.theme.divider),
                    borderRadius: BorderRadius.circular(
                      context.theme.controlRadius,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.document_scanner_outlined,
                        size: 32,
                        color: context.theme.brandVault,
                      ),
                      SizedBox(height: context.theme.spaceMd),
                      const KinCryptText(
                        'Human verification',
                        variant: KinCryptTextVariant.listPrimary,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: context.theme.spaceSm),
                      KinCryptText(
                        'Complete the Proton challenge in this protected '
                        'window.',
                        color: context.theme.textMuted,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (!uriIsValid) ...[
                  SizedBox(height: context.theme.spaceLg),
                  const KinCryptStatusIndicator(
                    label: 'The Proton verification address is unavailable.',
                    tone: KinCryptStatusTone.danger,
                    icon: Icons.error_outline,
                    announce: true,
                  ),
                ],
                SizedBox(height: context.theme.spaceXl),
                KinCryptButton(
                  label: 'Start verification',
                  stretch: true,
                  enabled: uriIsValid,
                  onPressed: _startVerification,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 440,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: context.theme.surfaceSoft,
                    border: Border.all(color: context.theme.divider),
                    borderRadius: BorderRadius.circular(
                      context.theme.controlRadius,
                    ),
                  ),
                  child: _controller == null
                      ? _ChallengeFailure(message: _loadError)
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            IgnorePointer(
                              ignoring: _loading || _submitting,
                              child: WebViewWidget(
                                controller: _controller!,
                              ),
                            ),
                            if (_loading || _submitting)
                              ColoredBox(
                                color: context.theme.surface.withValues(
                                  alpha: 0.86,
                                ),
                                child: Center(
                                  child: KinCryptActivityIndicator(
                                    size: 28,
                                    semanticLabel: _submitting
                                        ? 'Submitting verification'
                                        : 'Loading verification',
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                if (_loadError case final error?) ...[
                  SizedBox(height: context.theme.spaceLg),
                  KinCryptStatusIndicator(
                    label: error,
                    tone: KinCryptStatusTone.danger,
                    icon: Icons.error_outline,
                    announce: true,
                  ),
                ],
                if (_authError case final error?) ...[
                  SizedBox(height: context.theme.spaceLg),
                  KinCryptStatusIndicator(
                    label: error,
                    tone: KinCryptStatusTone.danger,
                    icon: Icons.error_outline,
                    announce: true,
                  ),
                ],
                if (_loadError != null || _authError != null) ...[
                  SizedBox(height: context.theme.spaceMd),
                  KinCryptTextButton(
                    label: 'Reload challenge',
                    icon: Icons.refresh,
                    onPressed: _submitting ? null : _reloadVerification,
                  ),
                ],
              ],
            ),
    );
  }
}

class _ChallengeFailure extends StatelessWidget {
  const _ChallengeFailure({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(context.theme.spaceXl),
      child: KinCryptText(
        message ?? 'Preparing the Proton verification challenge…',
        color: context.theme.textMuted,
        textAlign: TextAlign.center,
      ),
    ),
  );
}
