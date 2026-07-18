import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

enum KinCryptTextVariant {
  display,
  screenTitle,
  sectionTitle,
  listPrimary,
  body,
  button,
  meta,
}

class KinCryptText extends StatelessWidget {
  const KinCryptText(
    this.text, {
    super.key,
    this.variant = KinCryptTextVariant.body,
    this.style,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.semanticsLabel,
    this.selectable = false,
  });

  final String text;
  final KinCryptTextVariant variant;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final String? semanticsLabel;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = (style ?? _variantStyle(context)).copyWith(
      color: color ?? style?.color ?? _defaultColor(context),
    );

    if (selectable) {
      return SelectableText(
        text,
        style: resolvedStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
      );
    }

    return Text(
      text,
      style: resolvedStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      semanticsLabel: semanticsLabel,
    );
  }

  TextStyle _variantStyle(BuildContext context) => switch (variant) {
    KinCryptTextVariant.display => context.theme.display,
    KinCryptTextVariant.screenTitle => context.theme.screenTitle,
    KinCryptTextVariant.sectionTitle => context.theme.sectionTitle,
    KinCryptTextVariant.listPrimary => context.theme.listPrimary,
    KinCryptTextVariant.body => context.theme.body,
    KinCryptTextVariant.button => context.theme.button,
    KinCryptTextVariant.meta => context.theme.meta,
  };

  Color _defaultColor(BuildContext context) => switch (variant) {
    KinCryptTextVariant.meta => context.theme.textMuted,
    _ => context.theme.textPrimary,
  };
}

class KinCryptLabel extends StatelessWidget {
  const KinCryptLabel(
    this.text, {
    super.key,
    this.style,
    this.color,
    this.textAlign,
    this.maxLines,
  });

  final String text;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => KinCryptText(
    text,
    variant: KinCryptTextVariant.meta,
    style: style,
    color: color ?? context.theme.textMuted,
    textAlign: textAlign,
    maxLines: maxLines,
  );
}
