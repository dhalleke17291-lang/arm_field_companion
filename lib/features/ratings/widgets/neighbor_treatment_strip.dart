import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/plot_display.dart';
import '../../../core/providers.dart';

class NeighborTreatmentStrip extends ConsumerWidget {
  const NeighborTreatmentStrip({
    super.key,
    required this.assessmentId,
    required this.allPlots,
    required this.currentPlotIndex,
    required this.currentPlotId,
    required this.sessionRatings,
  });

  final int assessmentId;
  final List<Plot> allPlots;
  final int currentPlotIndex;
  final int currentPlotId;
  final List<RatingRecord> sessionRatings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // --- Neighbor values (walk order) ---
    String neighborLabel(int offset) {
      final ni = currentPlotIndex + offset;
      if (ni < 0 || ni >= allPlots.length) return '';
      final p = allPlots[ni];
      if (p.isGuardRow) return '';
      final label = getDisplayPlotLabel(p, allPlots);
      final rating = sessionRatings
          .where((r) =>
              r.plotPk == p.id &&
              r.assessmentId == assessmentId &&
              r.isCurrent &&
              !r.isDeleted &&
              r.resultStatus == 'RECORDED')
          .toList();
      final val = rating.isNotEmpty && rating.first.numericValue != null
          ? _formatValue(rating.first.numericValue!)
          : '—';
      return '$label: $val';
    }

    final prev = neighborLabel(-1);
    final next = neighborLabel(1);
    final hasNeighbors = prev.isNotEmpty || next.isNotEmpty;

    // --- Treatment running average (current session only) ---
    final plotCtx = ref.watch(plotContextProvider(currentPlotId));
    final treatmentCode = plotCtx.valueOrNull?.treatmentCode;
    final treatmentId = plotCtx.valueOrNull?.treatment?.id;

    String? treatmentAvgText;
    if (treatmentId != null) {
      final allPlotContexts = <int, int?>{};
      for (final p in allPlots) {
        if (p.isGuardRow) continue;
        final pc = ref.watch(plotContextProvider(p.id)).valueOrNull;
        if (pc != null) allPlotContexts[p.id] = pc.treatment?.id;
      }
      final sameTreatmentPlotPks = allPlotContexts.entries
          .where((e) => e.value == treatmentId)
          .map((e) => e.key)
          .toSet();

      final values = <double>[];
      for (final r in sessionRatings) {
        if (r.assessmentId == assessmentId &&
            r.isCurrent &&
            !r.isDeleted &&
            r.resultStatus == 'RECORDED' &&
            r.numericValue != null &&
            sameTreatmentPlotPks.contains(r.plotPk) &&
            r.plotPk != currentPlotId) {
          values.add(r.numericValue!);
        }
      }

      if (values.isNotEmpty) {
        final avg = values.reduce((a, b) => a + b) / values.length;
        final code = treatmentCode ?? 'TRT';
        treatmentAvgText =
            '$code avg: ${_formatValue(avg)} (${values.length} rated)';
      }
    }

    if (!hasNeighbors && treatmentAvgText == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDesignTokens.spacing16,
        6,
        AppDesignTokens.spacing16,
        0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasNeighbors)
            Row(
              children: [
                Icon(Icons.compare_arrows,
                    size: 14,
                    color: AppDesignTokens.secondaryText.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [prev, next].where((s) => s.isNotEmpty).join('  ·  '),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.secondaryText,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          if (hasNeighbors && treatmentAvgText != null)
            const SizedBox(height: 3),
          if (treatmentAvgText != null)
            Row(
              children: [
                Icon(Icons.analytics_outlined,
                    size: 14,
                    color: AppDesignTokens.primary.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Text(
                  treatmentAvgText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.primary.withValues(alpha: 0.85),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

String _formatValue(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}
