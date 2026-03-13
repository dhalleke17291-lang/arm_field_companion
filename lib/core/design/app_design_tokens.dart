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
  /// Warning/issue badge background.
  static const Color warningBg = Color(0xFFFFEDD5);
  /// Warning/issue badge foreground.
  static const Color warningFg = Color(0xFF9A3412);
  /// Warning/issue badge border.
  static const Color warningBorder = Color(0xFFFED7AA);
  /// Flag indicator color.
  static const Color flagColor = Color(0xFFF59E0B);
  /// Application status — applied.
  static const Color appliedColor = Color(0xFF16A34A);
  /// Application status — skipped.
  static const Color skippedColor = Color(0xFFEA580C);
  /// Application status — missed.
  static const Color missedColor = Color(0xFFDC2626);
  /// Application status — no record / unassigned grid tile.
  static const Color noRecordColor = Color(0xFFD1D5DB);
  /// Unassigned plot tile in grid.
  static const Color unassignedColor = Color(0xFF9CA3AF);
  /// Treatment palette for bird's-eye grid — cycles by index.
  static const List<Color> treatmentPalette = [
    Color(0xFF2D5A40),
    Color(0xFF1D4ED8),
    Color(0xFFEA580C),
    Color(0xFF7C3AED),
    Color(0xFFDC2626),
    Color(0xFF0F766E),
  ];
  /// Open session badge background.
  static const Color openSessionBg = Color(0xFF16A34A);
  /// Open session indicator background (light).
  static const Color openSessionBgLight = Color(0xFFDCFCE7);
  /// Secondary brand green (gradient, hover states).
  static const Color primaryLight = Color(0xFF3D7A57);
  /// Partial completion badge background.
  static const Color partialBg = Color(0xFFFEF3C7);
  /// Partial completion badge foreground.
  static const Color partialFg = Color(0xFF92400E);
  /// Planned/pending badge background.
  static const Color plannedBg = Color(0xFFFFF7ED);
  /// Planned/pending badge foreground.
  static const Color plannedFg = Color(0xFFEA580C);
  /// Bottom sheet drag handle color.
  static const Color dragHandle = Color(0xFFE5E7EB);
  /// Primary tint background (icon containers, hover).
  static const Color primaryTint = Color(0x1A2D5A40);

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

  /// Light shadow for rating cards (blur 4, offset (0,2)).
  static const Color shadowLight = Color(0x08000000);
  static const List<BoxShadow> cardShadowRating = [
    BoxShadow(color: shadowLight, blurRadius: 4, offset: Offset(0, 2)),
  ];
  /// Slightly stronger shadow (e.g. bottom bar).
  static const Color shadowMedium = Color(0x0F000000);
  /// Strong primary tint (e.g. quick button selected glow).
  static const Color primaryTintStrong = Color(0x402D5A40);
  /// Very light shadow (e.g. quick button unselected).
  static const Color shadowVeryLight = Color(0x0D000000);

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
