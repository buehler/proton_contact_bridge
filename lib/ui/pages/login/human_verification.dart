import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proton_contact_bridge/providers/proton.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HumanVerificationPage extends ConsumerWidget {
  HumanVerificationPage({super.key, required String captchaUrl})
    : captchaUrl = Uri.parse(captchaUrl);

  final Uri captchaUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    (String, String)? parseMessage(String raw) {
      final json = jsonDecode(raw);

      if (json is! Map || json['type'] != 'HUMAN_VERIFICATION_SUCCESS') {
        return null;
      }

      final payload = json['payload'];
      if (payload is! Map) return null;

      final token = payload['token'] as String?;
      final type = payload['type'] as String?;

      if (token == null || type == null) return null;

      return (token, type);
    }

    void handleMessage(JavaScriptMessage message) {
      final result = parseMessage(message.message);
      if (result != null) {
        ref
            .read(protonAuthProvider.notifier)
            .submitHumanVerification(token: result.$1, method: result.$2);
      }
    }

    late final WebViewController controller;
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('iOS', onMessageReceived: handleMessage)
      ..addJavaScriptChannel(
        'AndroidInterface',
        onMessageReceived: handleMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            await controller.runJavaScript('''
            if (window.AndroidInterface && !window.AndroidInterface.dispatch) {
              window.AndroidInterface.dispatch = function(message) {
                window.AndroidInterface.postMessage(message);
              };
            }
          ''');
          },
        ),
      )
      ..loadRequest(
        captchaUrl.replace(
          queryParameters: {...captchaUrl.queryParameters, 'embed': 'true'},
        ),
      );

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                children: [
                  Icon(
                    Icons.security_outlined,
                    size: 36,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Verify that you are human',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Complete the verification below to continue',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: WebViewWidget(controller: controller)),
          ],
        ),
      ),
    );
  }
}
