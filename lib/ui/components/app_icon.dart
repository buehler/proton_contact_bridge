import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

class KinCryptAppIcon extends StatelessWidget {
  const KinCryptAppIcon({
    super.key,
    this.size = 32,
    this.showWordmark = false,
    this.rounded = false,
    this.roundCorners = false,
    this.semanticLabel = 'KinCrypt',
  });

  final double size;
  final bool showWordmark;
  final bool rounded;
  final bool roundCorners;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticLabel,
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: rounded ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: roundCorners
                  ? BorderRadius.circular(context.theme.controlRadius)
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/icon.png', fit: BoxFit.contain),
          ),
          if (showWordmark) ...[
            SizedBox(width: context.theme.spaceMd),
            Text(
              'KinCrypt',
              style: context.theme.sectionTitle.copyWith(
                color: context.theme.textPrimary,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
