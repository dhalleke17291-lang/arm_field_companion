import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for ARM Field Companion.
/// Use these for consistent colors, spacing, and radii across the app.
/// Do not duplicate; extend with new tokens as needed.
class AppDesignTokens {
  AppDesignTokens._();

  // ——— Colors ———
  /// Primary brand green.
  static const Color primary = Color(0xFF2D5A40);

  /// Background surface (warm off-white).
  static const Color backgroundSurface = Color(0xFFF8F6F2);

  /// Card surface (white).
  static const Color cardSurface = Color(0xFFFFFFFF);

  /// Secondary / muted text.
  static const Color secondaryText = Color(0xFF6B7280);

  /// Divider and light borders.
  static const Color divider = Color(0xFFE5E7EB);

  // ——— Spacing ———
  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing16 = 16;
  static const double spacing24 = 24;
  static const double spacing32 = 32;

  // ——— Radii ———
  /// Card and medium surfaces.
  static const double radiusCard = 12;

  /// Small elements (chips, inputs).
  static const double radiusSmall = 10;

  /// Large surfaces (sheets, dialogs).
  static const double radiusLarge = 16;

  // ——— Typography ———
  /// Professional, modern header font with high visibility app-wide.
  /// Use for all AppBar titles, gradient header titles, and main screen headings.
  static TextStyle headerTitleStyle({
    double fontSize = 22,
    Color? color,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = -0.2,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );
}
