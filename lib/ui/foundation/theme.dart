import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:theme_tailor_annotation/theme_tailor_annotation.dart';

part 'theme.tailor.dart';

@TailorMixin()
final class KinCryptTheme extends ThemeExtension<KinCryptTheme>
    with _$KinCryptThemeTailorMixin {
  @override
  final Color brandVault;
  @override
  final Color brandSignal;
  @override
  final Color onBrand;
  @override
  final Color identitySurface;
  @override
  final Color identitySurfaceDeep;
  @override
  final Color onIdentity;
  @override
  final Color onIdentityMuted;
  @override
  final Color textPrimary;
  @override
  final Color textMuted;
  @override
  final Color canvas;
  @override
  final Color surface;
  @override
  final Color surfaceSoft;
  @override
  final Color divider;
  @override
  final Color selectedSurface;
  @override
  final Color success;
  @override
  final Color successSurface;
  @override
  final Color warning;
  @override
  final Color warningSurface;
  @override
  final Color danger;
  @override
  final Color dangerSurface;
  @override
  final Color onDanger;

  @override
  final double spaceXs;
  @override
  final double spaceSm;
  @override
  final double spaceMd;
  @override
  final double spaceLg;
  @override
  final double spaceXl;
  @override
  final double spaceXxl;
  @override
  final double controlRadius;
  @override
  final double containerRadius;
  @override
  final double minimumTouchTarget;

  @override
  final TextStyle display;
  @override
  final TextStyle screenTitle;
  @override
  final TextStyle sectionTitle;
  @override
  final TextStyle listPrimary;
  @override
  final TextStyle body;
  @override
  final TextStyle button;
  @override
  final TextStyle meta;

  const KinCryptTheme({
    required this.brandVault,
    required this.brandSignal,
    required this.onBrand,
    required this.identitySurface,
    required this.identitySurfaceDeep,
    required this.onIdentity,
    required this.onIdentityMuted,
    required this.textPrimary,
    required this.textMuted,
    required this.canvas,
    required this.surface,
    required this.surfaceSoft,
    required this.divider,
    required this.selectedSurface,
    required this.success,
    required this.successSurface,
    required this.warning,
    required this.warningSurface,
    required this.danger,
    required this.dangerSurface,
    required this.onDanger,
    this.spaceXs = 4,
    this.spaceSm = 8,
    this.spaceMd = 12,
    this.spaceLg = 16,
    this.spaceXl = 24,
    this.spaceXxl = 32,
    this.controlRadius = 12,
    this.containerRadius = 16,
    this.minimumTouchTarget = 48,
    required this.display,
    required this.screenTitle,
    required this.body,
    required this.meta,
    required this.sectionTitle,
    required this.listPrimary,
    required this.button,
  });
}

final kinCryptLightTheme = KinCryptTheme(
  brandVault: Color(0xFF123674),
  brandSignal: Color(0xFF0789A8),
  onBrand: Color(0xFFFFFFFF),
  identitySurface: Color(0xFF102F66),
  identitySurfaceDeep: Color(0xFF071A37),
  onIdentity: Color(0xFFF4F9FF),
  onIdentityMuted: Color(0xFFB8CDE8),
  textPrimary: Color(0xFF17243D),
  textMuted: Color(0xFF506075),
  canvas: Color(0xFFF3F6FA),
  surface: Color(0xFFFFFFFF),
  surfaceSoft: Color(0xFFE8EEF5),
  divider: Color(0xFFC5D0DE),
  selectedSurface: Color(0xFFBEDFE9),
  success: Color(0xFF287B62),
  successSurface: Color(0xFFE4F4EE),
  warning: Color(0xFF93631B),
  warningSurface: Color(0xFFFFF3D8),
  danger: Color(0xFFB44C59),
  dangerSurface: Color(0xFFFBECEF),
  onDanger: Color(0xFFFFFFFF),
  display: GoogleFonts.manrope(
    color: Color(0xFF17243D),
    fontSize: 40,
    height: 44 / 40,
    fontWeight: FontWeight.w500,
  ),
  screenTitle: GoogleFonts.manrope(
    color: Color(0xFF17243D),
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w500,
  ),
  sectionTitle: GoogleFonts.manrope(
    color: Color(0xFF17243D),
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w500,
  ),
  listPrimary: GoogleFonts.manrope(
    color: Color(0xFF17243D),
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w500,
  ),
  body: GoogleFonts.manrope(
    color: Color(0xFF17243D),
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  ),
  button: GoogleFonts.manrope(
    color: Color(0xFF17243D),
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
  ),
  meta: GoogleFonts.manrope(
    color: Color(0xFF506075),
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  ),
);

final kinCryptDarkTheme = KinCryptTheme(
  brandVault: Color(0xFF7BC1FF),
  brandSignal: Color(0xFF29AFC5),
  onBrand: Color(0xFF07101C),
  identitySurface: Color(0xFF0B1C35),
  identitySurfaceDeep: Color(0xFF07101E),
  onIdentity: Color(0xFFF4F9FF),
  onIdentityMuted: Color(0xFFB8CDE8),
  textPrimary: Color(0xFFEDF5FF),
  textMuted: Color(0xFFA2B1C4),
  canvas: Color(0xFF07101C),
  surface: Color(0xFF101B2B),
  surfaceSoft: Color(0xFF152337),
  divider: Color(0xFF29394E),
  selectedSurface: Color(0xFF123442),
  success: Color(0xFF71D3AE),
  successSurface: Color(0xFF17382F),
  warning: Color(0xFFEFBD67),
  warningSurface: Color(0xFF392D19),
  danger: Color(0xFFFF8E9A),
  dangerSurface: Color(0xFF3D2028),
  onDanger: Color(0xFF07101C),
  display: GoogleFonts.manrope(
    color: Color(0xFFEDF5FF),
    fontSize: 40,
    height: 44 / 40,
    fontWeight: FontWeight.w500,
  ),
  screenTitle: GoogleFonts.manrope(
    color: Color(0xFFEDF5FF),
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w500,
  ),
  sectionTitle: GoogleFonts.manrope(
    color: Color(0xFFEDF5FF),
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w500,
  ),
  listPrimary: GoogleFonts.manrope(
    color: Color(0xFFEDF5FF),
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w500,
  ),
  body: GoogleFonts.manrope(
    color: Color(0xFFEDF5FF),
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  ),
  button: GoogleFonts.manrope(
    color: Color(0xFFEDF5FF),
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
  ),
  meta: GoogleFonts.manrope(
    color: Color(0xFFA2B1C4),
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  ),
);
