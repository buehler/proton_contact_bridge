import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/ui/components/app_icon.dart';
import 'package:proton_contact_bridge/ui/components/safe_area.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

class LoginShell extends StatelessWidget {
  const LoginShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.canvas,
      resizeToAvoidBottomInset: false,
      body: KinCryptSafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const logoSize = 64.0;
              final pageHeight =
                  (constraints.maxHeight -
                          logoSize -
                          context.theme.spaceXxl -
                          context.theme.spaceLg * 2)
                      .clamp(0.0, double.infinity)
                      .toDouble();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: context.theme.spaceXxl,
                children: [
                  const KinCryptAppIcon(
                    size: logoSize,
                    showWordmark: true,
                    roundCorners: true,
                  ),
                  Padding(
                    padding: EdgeInsets.all(context.theme.spaceLg),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: pageHeight),
                      child: child,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
