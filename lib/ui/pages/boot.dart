import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:proton_contact_bridge/ui/components/activity_indicator.dart';
import 'package:proton_contact_bridge/ui/components/app_icon.dart';
import 'package:proton_contact_bridge/ui/components/safe_area.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

class BootPage extends StatelessWidget {
  @Preview(name: 'BootPage')
  const BootPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.theme.canvas,
    body: KinCryptSafeArea(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF0F1A24), // The dark solid outer color
              gradient: RadialGradient(
                center: Alignment.center, // Center of the glow
                radius: 0.8, // Adjusts how far the gradient spreads
                colors: [
                  context.theme.brandSignal.withAlpha(
                    100,
                  ), // The lighter inner glow color
                  Colors.transparent, // Fades out completely to let the background color show
                ],
                stops: [0.0, 1.0], // Defines where the colors start and end
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                KinCryptAppIcon(size: 128, rounded: true),
                Text('KinCrypt', style: context.theme.display),
                const SizedBox(height: 16),
                Text('Your contacts stay yours.', style: context.theme.meta),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const KinCryptActivityIndicator(size: 32),
                  const SizedBox(height: 16),
                  Text('Checking secure session...', style: context.theme.meta),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
