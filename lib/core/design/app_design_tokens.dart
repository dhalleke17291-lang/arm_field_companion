import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for Ag-Quest Field Companion.
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
  /// Primary text — near black for titles and strong labels.
  static const Color primaryText = Color(0xFF111827);
  /// Chevron and subtle icon color.
  static const Color iconSubtle = Color(0xFFD1D5DB);
  /// Empty state / no-content badge background.
  static const Color emptyBadgeBg = Color(0xFFF3F4F6);
  /// Empty state / no-content badge foreground.
  static const Color emptyBadgeFg = Color(0xFF9CA3AF);

  /// Crisp border — slightly cooler than divider, for card edges.
  static const Color borderCrisp = Color(0xFFEAECF0);
  /// Section header background.
  static const Color sectionHeaderBg = Color(0xFFEFF2EE);
  /// Success green background (pills, badges).
  static const Color successBg = Color(0xFFD1FAE5);
  /// Success green foreground.
  static const Color successFg = Color(0xFF047857);

  // ——— Spacing ———
  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing24 = 24;
  static const double spacing32 = 32;

  // ——— Radii ———
  /// Card and medium surfaces.
  static const double radiusCard = 12;

  /// Extra small elements (icon containers, tight badges).
  static const double radiusXSmall = 8;
  /// Small elements (chips, inputs).
  static const double radiusSmall = 10;

  /// Large surfaces (sheets, dialogs).
  static const double radiusLarge = 16;

  /// Crisp border width for cards and surfaces.
  static const double borderWidthCrisp = 1.0;

  /// Premium layered shadow for cards: soft depth + subtle rim.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 1),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 3),
          spreadRadius: -2,
        ),
      ];

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

  /// Crisp body text style with slight letter spacing for readability.
  static TextStyle bodyCrispStyle({
    double fontSize = 15,
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
    double letterSpacing = 0.15,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );
}
