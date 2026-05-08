import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Shared PDF branding constants and widgets for all report builders.
///
/// Logo + "AGNEXIS" label styled to match the app splash screen:
/// uppercase, light weight, letter-spaced.
class PdfBranding {
  static const _kLogoAssetPath = 'assets/Branding/splash_logo.png';

  static const primaryColor = PdfColor.fromInt(0xFF0E3D2F);
  static const textSecondary = PdfColor.fromInt(0xFF555555);

  /// Load the logo image. Returns null if asset unavailable.
  static Future<pw.ImageProvider?> loadLogo() async {
    try {
      final bytes = await rootBundle.load(_kLogoAssetPath);
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  /// Logo + "AGNEXIS" label matching splash screen style.
  /// [logoWidth] controls the logo size (default 44).
  static pw.Widget brandBlock(pw.ImageProvider? logo, {double logoWidth = 44}) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (logo != null)
          pw.Image(logo, width: logoWidth, fit: pw.BoxFit.contain),
        if (logo != null) pw.SizedBox(height: 3),
        pw.Text(
          'AGNEXIS',
          style: pw.TextStyle(
            fontSize: 6.5,
            fontWeight: pw.FontWeight.normal,
            color: primaryColor,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }

  /// Compact brand block for running page headers (smaller logo).
  static pw.Widget brandBlockCompact(pw.ImageProvider? logo) {
    return brandBlock(logo, logoWidth: 28);
  }
}
