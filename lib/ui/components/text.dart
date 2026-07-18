import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

enum TypographyVariant {
  diplayLarge,
  headlineMedium,
  bodyLarge,
  bodyMedium,
  labelMedium,
  labelSmall;

  TextStyle get style => _styles[this]!;
}

final _styles = {
  TypographyVariant.diplayLarge: GoogleFonts.hankenGrotesk(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    height: 56 / 48,
    letterSpacing: -0.02 * 16,
  ),
  TypographyVariant.headlineMedium: GoogleFonts.hankenGrotesk(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
  ),
  TypographyVariant.bodyMedium: GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  ),
  TypographyVariant.labelMedium: GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 16,
    letterSpacing: 0.05 / 12,
  ),
  TypographyVariant.labelSmall: GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    letterSpacing: 0.05 / 12,
  ),
};

class AppText extends StatelessWidget {
  const AppText(
    this.text, {
    super.key,
    this.variant = TypographyVariant.bodyMedium,
    this.color,
  });

  final String text;
  final TypographyVariant variant;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: switch (variant) {
      TypographyVariant.diplayLarge => GoogleFonts.hankenGrotesk(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        height: 56 / 48,
        letterSpacing: -0.02 * 16,
        color: color,
      ),
      TypographyVariant.headlineMedium => GoogleFonts.hankenGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        color: color,
      ),
      _ => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: color,
      ),
    },
  );
}
