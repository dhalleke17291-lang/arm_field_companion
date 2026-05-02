import 'package:flutter/material.dart';

import '../../../core/design/app_design_tokens.dart';
import '../../../domain/models/trial_insight.dart';

class InsightRow extends StatefulWidget {
  const InsightRow({super.key, required this.insight, this.titleOverride});

  final TrialInsight insight;

  /// When set, displayed instead of [insight.title]. Used by grouped
  /// assessment views to show only the treatment name within a group.
  final String? titleOverride;

  @override
  State<InsightRow> createState() => _InsightRowState();
}

class _InsightRowState extends State<InsightRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final insight = widget.insight;
    final severityColor = switch (insight.severity) {
      InsightSeverity.info => AppDesignTokens.primary,
      InsightSeverity.notable => AppDesignTokens.warningFg,
      InsightSeverity.attention => AppDesignTokens.missedColor,
    };

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: insight.severity != InsightSeverity.info
            ? BoxDecoration(
                border: Border(
                  left: BorderSide(color: severityColor, width: 2),
                ),
              )
            : null,
        child: Padding(
          padding: EdgeInsets.only(
              left: insight.severity != InsightSeverity.info ? 8 : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.titleOverride ?? insight.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              const SizedBox(height: 3),
              if (insight.type == InsightType.treatmentTrend &&
                  insight.fromDate != null &&
                  insight.toDate != null) ...[
                Text(
                  '${insight.fromDate} → ${insight.toDate}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.detail,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
              ] else if (insight.type == InsightType.sessionFieldCapture) ...[
                Text(
                  insight.detail,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
              ] else ...[
                Text(
                  insight.detail,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ],
              // Treatment trend rows share a single method note at the card
              // bottom; suppress per-row method box to avoid repetition.
              if (insight.type != InsightType.treatmentTrend) ...[
                if (_expanded) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.sectionHeaderBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${insight.basis.sessionCount} session${insight.basis.sessionCount == 1 ? '' : 's'} · '
                          '${insight.basis.repCount} rep${insight.basis.repCount == 1 ? '' : 's'}'
                          '${insight.basis.assessmentType != null ? ' · ${insight.basis.assessmentType}' : ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppDesignTokens.primaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Method: ${insight.basis.method}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppDesignTokens.secondaryText,
                          ),
                        ),
                        if (insight.basis.threshold != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            insight.basis.threshold!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppDesignTokens.secondaryText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Tap for method',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppDesignTokens.secondaryText
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
