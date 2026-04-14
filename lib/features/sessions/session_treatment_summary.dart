import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/plot_analysis_eligibility.dart';
import '../../core/ui/assessment_display_helper.dart';

/// Treatment summary table: treatments as rows, assessments as columns,
/// cells show mean ± CV%.
class SessionTreatmentSummary extends StatelessWidget {
  const SessionTreatmentSummary({
    super.key,
    required this.plots,
    required this.assessments,
    required this.ratings,
    required this.treatments,
    required this.assignments,
    this.assessmentDisplayNames,
  });

  final List<Plot> plots;
  final List<Assessment> assessments;
  final List<RatingRecord> ratings;
  final List<Treatment> treatments;
  final List<Assignment> assignments;
  final Map<int, String>? assessmentDisplayNames;

  @override
  Widget build(BuildContext context) {
    if (treatments.isEmpty || assessments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          treatments.isEmpty
              ? 'No treatments assigned.'
              : 'No assessments in this session.',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final dataPlots = plots.where(isAnalyzablePlot).toList();

    // Build plot → treatmentId map
    final plotTreatmentMap = <int, int>{};
    for (final a in assignments) {
      if (a.treatmentId != null) {
        plotTreatmentMap[a.plotId] = a.treatmentId!;
      }
    }
    // Fallback to plot.treatmentId for legacy
    for (final p in dataPlots) {
      if (!plotTreatmentMap.containsKey(p.id) && p.treatmentId != null) {
        plotTreatmentMap[p.id] = p.treatmentId!;
      }
    }

    // Build rating lookup: (plotPk, assessmentId) → numericValue
    final ratingMap = <(int, int), double>{};
    for (final r in ratings) {
      if (!r.isCurrent || r.isDeleted) continue;
      if (r.resultStatus == 'RECORDED' && r.numericValue != null) {
        ratingMap[(r.plotPk, r.assessmentId)] = r.numericValue!;
      }
    }

    // Sort treatments by code for consistent display
    final sortedTreatments = List<Treatment>.from(treatments)
      ..sort((a, b) => a.code.compareTo(b.code));

    // Compute stats: treatment × assessment → (mean, cv, n)
    final stats =
        <int, Map<int, ({double mean, double cv, int n})>>{};
    for (final t in sortedTreatments) {
      final tPlotPks = plotTreatmentMap.entries
          .where((e) => e.value == t.id)
          .map((e) => e.key)
          .toSet();
      final aStats = <int, ({double mean, double cv, int n})>{};
      for (final a in assessments) {
        final values = <double>[];
        for (final pk in tPlotPks) {
          final v = ratingMap[(pk, a.id)];
          if (v != null) values.add(v);
        }
        if (values.isNotEmpty) {
          final mean = values.reduce((a, b) => a + b) / values.length;
          double cv = 0;
          if (values.length > 1 && mean.abs() > 1e-9) {
            final variance =
                values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
                    (values.length - 1);
            cv = (math.sqrt(variance) / mean.abs()) * 100;
          }
          aStats[a.id] = (mean: mean, cv: cv, n: values.length);
        }
      }
      stats[t.id] = aStats;
    }

    // Sizing
    final screenWidth = MediaQuery.sizeOf(context).width;
    const trtColWidth = 80.0;
    const minCellWidth = 80.0;
    const maxCellWidth = 120.0;
    const headerHeight = 52.0;
    const rowHeight = 48.0;

    final colCount = assessments.length;
    final availableWidth = screenWidth - trtColWidth - 16;
    var cellWidth = colCount > 0 ? availableWidth / colCount : maxCellWidth;
    cellWidth = cellWidth.clamp(minCellWidth, maxCellWidth);
    final totalDataWidth = cellWidth * colCount;
    final totalHeight =
        headerHeight + (sortedTreatments.length * rowHeight);

    final scheme = Theme.of(context).colorScheme;

    String displayName(Assessment a) {
      if (assessmentDisplayNames != null &&
          assessmentDisplayNames!.containsKey(a.id)) {
        return assessmentDisplayNames![a.id]!;
      }
      return AssessmentDisplayHelper.legacyAssessmentDisplayName(a.name);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: trtColWidth + totalDataWidth,
        child: SingleChildScrollView(
          child: SizedBox(
            height: totalHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Frozen treatment column
                SizedBox(
                  width: trtColWidth,
                  child: Column(
                    children: [
                      Container(
                        width: trtColWidth,
                        height: headerHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          border: const Border(
                            bottom: BorderSide(
                                color: AppDesignTokens.borderCrisp),
                            right: BorderSide(
                                color: AppDesignTokens.borderCrisp),
                          ),
                        ),
                        child: const Text(
                          'Treatment',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                      for (var i = 0; i < sortedTreatments.length; i++)
                        Container(
                          width: trtColWidth,
                          height: rowHeight,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: i.isEven
                                ? scheme.surface
                                : scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                            border: Border(
                              bottom: BorderSide(
                                  color: AppDesignTokens.borderCrisp
                                      .withValues(alpha: 0.5)),
                              right: const BorderSide(
                                  color: AppDesignTokens.borderCrisp),
                            ),
                          ),
                          child: Text(
                            sortedTreatments[i].code.isNotEmpty
                                ? sortedTreatments[i].code
                                : sortedTreatments[i].name,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                // Data columns
                SizedBox(
                  width: totalDataWidth,
                  child: Column(
                    children: [
                      // Header
                      SizedBox(
                        height: headerHeight,
                        child: Row(
                          children: [
                            for (final a in assessments)
                              Container(
                                width: cellWidth,
                                height: headerHeight,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                  border: const Border(
                                    bottom: BorderSide(
                                        color: AppDesignTokens.borderCrisp),
                                    right: BorderSide(
                                        color: AppDesignTokens.borderCrisp),
                                  ),
                                ),
                                child: Text(
                                  displayName(a),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Data rows
                      for (var i = 0; i < sortedTreatments.length; i++)
                        SizedBox(
                          height: rowHeight,
                          child: Row(
                            children: [
                              for (final a in assessments)
                                _TreatmentCell(
                                  width: cellWidth,
                                  height: rowHeight,
                                  stats:
                                      stats[sortedTreatments[i].id]?[a.id],
                                  isEvenRow: i.isEven,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TreatmentCell extends StatelessWidget {
  const _TreatmentCell({
    required this.width,
    required this.height,
    required this.stats,
    required this.isEvenRow,
  });

  final double width;
  final double height;
  final ({double mean, double cv, int n})? stats;
  final bool isEvenRow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isEvenRow
        ? scheme.surface
        : scheme.surfaceContainerHighest.withValues(alpha: 0.4);

    if (stats == null) {
      return Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            bottom: BorderSide(
                color: AppDesignTokens.borderCrisp.withValues(alpha: 0.5)),
            right: BorderSide(
                color: AppDesignTokens.borderCrisp.withValues(alpha: 0.5)),
          ),
        ),
        child: Text(
          '—',
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    final s = stats!;
    final meanStr = _fmt(s.mean);
    final cvStr = s.cv > 0 ? 'CV ${s.cv.toStringAsFixed(0)}%' : '';
    // High CV (>30%) gets a subtle warning color
    final cvColor = s.cv > 30
        ? Colors.orange.shade700
        : scheme.onSurfaceVariant;

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(
              color: AppDesignTokens.borderCrisp.withValues(alpha: 0.5)),
          right: BorderSide(
              color: AppDesignTokens.borderCrisp.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            meanStr,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
          ),
          if (cvStr.isNotEmpty)
            Text(
              '$cvStr · n=${s.n}',
              style: TextStyle(
                fontSize: 9,
                color: cvColor,
                fontWeight: s.cv > 30 ? FontWeight.w600 : FontWeight.w400,
              ),
              maxLines: 1,
            )
          else
            Text(
              'n=${s.n}',
              style: TextStyle(
                fontSize: 9,
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}
