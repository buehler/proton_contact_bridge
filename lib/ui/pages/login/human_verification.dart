import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proton_contact_bridge/providers/proton_auth.dart';
import 'package:proton_contact_bridge/ui/components/text.dart';
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
            .read(protonAuthProvider)
            .submitHumanVerification(result.$1, result.$2);
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
    return Column(
      children: [
        AppText(
          'Please complete the captcha to continue',
          variant: TypographyVariant.headlineMedium,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        Expanded(child: WebViewWidget(controller: controller)),
      ],
    );
  }
}
