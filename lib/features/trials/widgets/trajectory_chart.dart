import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/design/app_design_tokens.dart';
import '../../derived/domain/trajectory_analysis.dart';

/// Line chart showing treatment trajectories across timings.
/// One line per treatment, straight segments only (no splines),
/// markers at data points, optional error bars.
class TrajectoryChart extends StatelessWidget {
  const TrajectoryChart({
    super.key,
    required this.series,
    this.height = 220,
    this.checkTreatmentNumbers = const {},
  });

  final AssessmentTrajectorySeries series;
  final double height;
  final Set<int> checkTreatmentNumbers;

  @override
  Widget build(BuildContext context) {
    final allPoints = series.treatments
        .expand((t) => t.points)
        .toList();
    if (allPoints.isEmpty) return const SizedBox.shrink();

    final minY = allPoints.map((p) => p.mean).reduce((a, b) => a < b ? a : b);
    final maxY = allPoints.map((p) => p.mean).reduce((a, b) => a > b ? a : b);
    final yRange = maxY - minY;
    final yFloor = (minY - yRange * 0.1).clamp(0.0, double.infinity);
    final yCeil = maxY + yRange * 0.1;

    final lines = <LineChartBarData>[];
    for (var i = 0; i < series.treatments.length; i++) {
      final t = series.treatments[i];
      final color = _treatmentColor(i, t.treatmentNumber);
      final isCheck = checkTreatmentNumbers.contains(t.treatmentNumber);

      lines.add(LineChartBarData(
        spots: t.points
            .map((p) => FlSpot(
                  p.daysAfterTreatment.toDouble(),
                  p.mean,
                ))
            .toList(),
        isCurved: false,
        color: color,
        barWidth: isCheck ? 3 : 2,
        dashArray: isCheck ? [6, 3] : null,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
            radius: 3,
            color: color,
            strokeWidth: 0,
          ),
        ),
        belowBarData: BarAreaData(show: false),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, top: 8),
            child: LineChart(
              LineChartData(
                lineBarsData: lines,
                minY: yFloor,
                maxY: yCeil,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text(
                      'Days After Treatment',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        if (!series.timings
                            .contains(value.toInt())) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${value.toInt()}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppDesignTokens.secondaryText,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.round()}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppDesignTokens.secondaryText,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval:
                      yRange > 0 ? (yRange / 4).ceilToDouble() : 10,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppDesignTokens.borderCrisp.withValues(alpha: 0.5),
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    bottom:
                        BorderSide(color: AppDesignTokens.borderCrisp),
                    left:
                        BorderSide(color: AppDesignTokens.borderCrisp),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((s) {
                        final trt = series.treatments[s.barIndex];
                        return LineTooltipItem(
                          '${trt.treatmentLabel}: ${s.y.toStringAsFixed(1)}',
                          TextStyle(
                            fontSize: 11,
                            color: _treatmentColor(
                                s.barIndex, trt.treatmentNumber),
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (var i = 0; i < series.treatments.length; i++)
              _LegendItem(
                color: _treatmentColor(i, series.treatments[i].treatmentNumber),
                label: series.treatments[i].treatmentLabel,
                isCheck:
                    checkTreatmentNumbers.contains(
                        series.treatments[i].treatmentNumber),
              ),
          ],
        ),
      ],
    );
  }

  Color _treatmentColor(int index, int treatmentNumber) {
    return AppDesignTokens.treatmentPalette[
        index % AppDesignTokens.treatmentPalette.length];
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.isCheck = false,
  });

  final Color color;
  final String label;
  final bool isCheck;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppDesignTokens.primaryText,
            fontWeight: isCheck ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// Interpretation panel below the trajectory chart.
class TrajectoryInterpretationPanel extends StatelessWidget {
  const TrajectoryInterpretationPanel({
    super.key,
    required this.interpretation,
    this.audpsValues,
  });

  final TrajectoryInterpretation interpretation;
  final Map<String, double>? audpsValues;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppDesignTokens.sectionHeaderBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            interpretation.header,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            interpretation.body,
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          if (audpsValues != null && audpsValues!.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppDesignTokens.borderCrisp),
            const SizedBox(height: 6),
            ...audpsValues!.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${e.key}: ${e.value.toStringAsFixed(1)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppDesignTokens.primaryText,
                    ),
                  ),
                )),
            const SizedBox(height: 4),
            const Text(
              'Trajectory summary (trial-internal, not comparable across trials)',
              style: TextStyle(
                fontSize: 9,
                fontStyle: FontStyle.italic,
                color: AppDesignTokens.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
