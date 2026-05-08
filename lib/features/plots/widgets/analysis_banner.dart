import 'package:flutter/material.dart';

import '../../../core/design/app_design_tokens.dart';

enum AnalysisBannerSeverity { info, warning, error }

class AnalysisBanner extends StatelessWidget {
  const AnalysisBanner({
    super.key,
    required this.message,
    this.severity = AnalysisBannerSeverity.info,
  });

  final String message;
  final AnalysisBannerSeverity severity;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (severity) {
      AnalysisBannerSeverity.info => (
          AppDesignTokens.sectionHeaderBg,
          AppDesignTokens.secondaryText,
          Icons.info_outline,
        ),
      AnalysisBannerSeverity.warning => (
          AppDesignTokens.warningBg,
          AppDesignTokens.warningFg,
          Icons.warning_amber_rounded,
        ),
      AnalysisBannerSeverity.error => (
          const Color(0xFFDC2626).withValues(alpha: 0.08),
          const Color(0xFFDC2626),
          Icons.error_outline,
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 11, color: fg, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
