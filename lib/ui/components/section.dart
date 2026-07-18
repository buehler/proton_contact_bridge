import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

enum KinCryptSectionStyle { flat, outlined }

class KinCryptSectionLabel extends StatelessWidget {
  const KinCryptSectionLabel({
    super.key,
    required this.label,
    this.uppercase = true,
    this.trailing,
  });

  final String label;
  final bool uppercase;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          uppercase ? label.toUpperCase() : label,
          style: context.theme.meta.copyWith(color: context.theme.textMuted),
        ),
      ),
      ?trailing,
    ],
  );
}

class KinCryptDivider extends StatelessWidget {
  const KinCryptDivider({super.key, this.indent = 0, this.endIndent = 0});

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    thickness: 1,
    indent: indent,
    endIndent: endIndent,
    color: context.theme.divider,
  );
}

class KinCryptSection extends StatelessWidget {
  const KinCryptSection({
    super.key,
    required this.title,
    required this.children,
    this.style = KinCryptSectionStyle.outlined,
    this.margin,
    this.headerTrailing,
  });

  final String title;
  final List<Widget> children;
  final KinCryptSectionStyle style;
  final EdgeInsetsGeometry? margin;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: style == KinCryptSectionStyle.outlined
                  ? context.theme.spaceMd
                  : 0,
              vertical: context.theme.spaceMd,
            ),
            child: children[index],
          ),
          if (index < children.length - 1) const KinCryptDivider(),
        ],
      ],
    );

    return Padding(
      padding:
          margin ??
          EdgeInsets.symmetric(
            vertical: context.theme.spaceLg,
            horizontal: context.theme.spaceLg,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KinCryptSectionLabel(label: title, trailing: headerTrailing),
          SizedBox(height: context.theme.spaceSm),
          if (style == KinCryptSectionStyle.flat) const KinCryptDivider(),
          if (style == KinCryptSectionStyle.outlined)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: context.theme.divider),
                borderRadius: BorderRadius.circular(
                  context.theme.containerRadius,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: content,
            )
          else
            content,
        ],
      ),
    );
  }
}
