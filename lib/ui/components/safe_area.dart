import 'dart:io';

import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

class KinCryptSafeArea extends StatelessWidget {
  const new({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(top: isDesktop ? context.theme.spaceLg : 0.0),
        child: child,
      ),
    );
  }
}
