import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/plot_analysis_eligibility.dart';
import '../../core/plot_display.dart';
import '../../core/ui/assessment_display_helper.dart';
import '../ratings/rating_lineage_sheet.dart';

/// Read-only data grid: plots × assessments with rating values.
/// Frozen first column (plot label) and frozen header row (assessment names).
/// Synchronized horizontal + vertical scrolling.
class SessionDataGrid extends ConsumerStatefulWidget {
  const SessionDataGrid({
    super.key,
    required this.plots,
    required this.assessments,
    required this.ratings,
    required this.trialId,
    required this.sessionId,
    this.onPlotTap,
    this.assessmentDisplayNames,
  });

  final List<Plot> plots;
  final List<Assessment> assessments;
  final List<RatingRecord> ratings;
  final int trialId;
  final int sessionId;

  /// Called when the plot label in the frozen column is tapped.
  final void Function(Plot plot)? onPlotTap;

  /// Human-readable display names keyed by Assessment.id.
  /// When provided, used instead of Assessment.name for column headers.
  final Map<int, String>? assessmentDisplayNames;

  @override
  ConsumerState<SessionDataGrid> createState() => _SessionDataGridState();
}

class _SessionDataGridState extends ConsumerState<SessionDataGrid> {
  final _horizontalController = ScrollController();
  final _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assessments = widget.assessments;
    final plots = widget.plots;

    void showLineage({
      required int plotPk,
      required int assessmentId,
      required String plotLabel,
      required String assessmentName,
    }) {
      showRatingLineageBottomSheet(
        context: context,
        ref: ref,
        trialId: widget.trialId,
        plotPk: plotPk,
        assessmentId: assessmentId,
        sessionId: widget.sessionId,
        assessmentName: assessmentName,
        plotLabel: plotLabel,
      );
    }

    if (assessments.isEmpty || plots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          assessments.isEmpty ? 'No assessments in this session.' : 'No plots.',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final dataPlots = plots.where(isAnalyzablePlot).toList();
    if (dataPlots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No data plots.', style: TextStyle(fontSize: 14)),
      );
    }

    // Build lookup: (plotPk, assessmentId) → RatingRecord
    final ratingMap = <(int, int), RatingRecord>{};
    for (final r in widget.ratings) {
      if (!r.isCurrent || r.isDeleted) continue;
      ratingMap[(r.plotPk, r.assessmentId)] = r;
    }

    // Compute column stats (mean, min, max) per assessment
    final colStats = <int, ({double mean, double min, double max, int n})>{};
    for (final a in assessments) {
      final values = <double>[];
      for (final p in dataPlots) {
        final r = ratingMap[(p.id, a.id)];
        if (r != null && r.resultStatus == 'RECORDED' && r.numericValue != null) {
          values.add(r.numericValue!);
        }
      }
      if (values.isNotEmpty) {
        values.sort();
        final sum = values.reduce((a, b) => a + b);
        colStats[a.id] = (
          mean: sum / values.length,
          min: values.first,
          max: values.last,
          n: values.length,
        );
      }
    }

    // Sizing
    final colCount = assessments.length;
    final screenWidth = MediaQuery.sizeOf(context).width;
    const plotColWidth = 64.0;
    const minCellWidth = 72.0;
    const maxCellWidth = 110.0;
    const headerHeight = 52.0;
    const rowHeight = 40.0;
    const statsRowHeight = 48.0;

    final availableWidth = screenWidth - plotColWidth - 16;
    var cellWidth = colCount > 0 ? availableWidth / colCount : maxCellWidth;
    cellWidth = cellWidth.clamp(minCellWidth, maxCellWidth);
    final totalDataWidth = cellWidth * colCount;

    final scheme = Theme.of(context).colorScheme;

    // Resolve human-readable assessment name
    String displayName(Assessment a) {
      if (widget.assessmentDisplayNames != null &&
          widget.assessmentDisplayNames!.containsKey(a.id)) {
        return widget.assessmentDisplayNames![a.id]!;
      }
      return AssessmentDisplayHelper.legacyAssessmentDisplayName(a.name);
    }

    // Build the scrollable data content (no frozen column/header)
    Widget buildDataContent() {
      return SizedBox(
        width: totalDataWidth,
        child: Column(
          children: [
            // Header row (assessment names)
            SizedBox(
              height: headerHeight,
              child: Row(
                children: [
                  for (final a in assessments)
                    Container(
                      width: cellWidth,
                      height: headerHeight,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        border: const Border(
                          bottom: BorderSide(color: AppDesignTokens.borderCrisp),
                          right: BorderSide(color: AppDesignTokens.borderCrisp),
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
            for (var i = 0; i < dataPlots.length; i++)
              SizedBox(
                height: rowHeight,
                child: Row(
                  children: [
                    for (final a in assessments)
                      _DataCell(
                        width: cellWidth,
                        height: rowHeight,
                        rating: ratingMap[(dataPlots[i].id, a.id)],
                        isEvenRow: i.isEven,
                        onShowLineage: () => showLineage(
                          plotPk: dataPlots[i].id,
                          assessmentId: a.id,
                          plotLabel: getDisplayPlotLabel(dataPlots[i], plots),
                          assessmentName: displayName(a),
                        ),
                      ),
                  ],
                ),
              ),
            // Stats footer row
            if (colStats.isNotEmpty)
              SizedBox(
                height: statsRowHeight,
                child: Row(
                  children: [
                    for (final a in assessments)
                      _StatsCell(
                        width: cellWidth,
                        height: statsRowHeight,
                        stats: colStats[a.id],
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    // Frozen plot column (header corner + plot labels)
    Widget buildFrozenColumn() {
      return SizedBox(
        width: plotColWidth,
        child: Column(
          children: [
            // Corner cell
            Container(
              width: plotColWidth,
              height: headerHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                border: const Border(
                  bottom: BorderSide(color: AppDesignTokens.borderCrisp),
                  right: BorderSide(color: AppDesignTokens.borderCrisp),
                ),
              ),
              child: const Text(
                'Plot',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            // Plot label rows
            for (var i = 0; i < dataPlots.length; i++)
              GestureDetector(
                onTap: widget.onPlotTap != null
                    ? () => widget.onPlotTap!(dataPlots[i])
                    : null,
                child: Container(
                  width: plotColWidth,
                  height: rowHeight,
                  alignment: Alignment.center,
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
                    getDisplayPlotLabel(dataPlots[i], plots),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.onPlotTap != null
                          ? AppDesignTokens.primary
                          : null,
                    ),
                  ),
                ),
              ),
            // Stats label in frozen column
            if (colStats.isNotEmpty)
              Container(
                width: plotColWidth,
                height: statsRowHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  border: const Border(
                    top: BorderSide(color: AppDesignTokens.borderCrisp),
                    right: BorderSide(color: AppDesignTokens.borderCrisp),
                  ),
                ),
                child: const Text(
                  'Stats',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // The total content height for vertical scrolling
    final statsExtra = colStats.isNotEmpty ? statsRowHeight : 0.0;
    final totalHeight =
        headerHeight + (dataPlots.length * rowHeight) + statsExtra;

    return NotificationListener<ScrollNotification>(
      onNotification: (_) => false,
      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: plotColWidth + totalDataWidth,
          child: SingleChildScrollView(
            controller: _verticalController,
            child: SizedBox(
              height: totalHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildFrozenColumn(),
                  SizedBox(
                    width: totalDataWidth,
                    child: buildDataContent(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  const _DataCell({
    required this.width,
    required this.height,
    required this.rating,
    required this.isEvenRow,
    required this.onShowLineage,
  });

  final double width;
  final double height;
  final RatingRecord? rating;
  final bool isEvenRow;
  final VoidCallback onShowLineage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = rating;

    String text;
    Color textColor;
    FontWeight weight = FontWeight.w500;

    if (r == null) {
      text = '—';
      textColor = scheme.onSurfaceVariant.withValues(alpha: 0.4);
    } else if (r.resultStatus == 'VOID') {
      text = 'VOID';
      textColor = scheme.error;
      weight = FontWeight.w600;
    } else if (r.resultStatus != 'RECORDED') {
      text = _statusAbbrev(r.resultStatus);
      textColor = Colors.orange.shade700;
      weight = FontWeight.w600;
    } else {
      text = r.numericValue != null
          ? _formatNumber(r.numericValue!)
          : (r.textValue ?? '—');
      textColor = AppDesignTokens.primaryText;
    }

    final isEdited = r != null && (r.amended || r.previousId != null);

    final bg = isEvenRow
        ? scheme.surface
        : scheme.surfaceContainerHighest.withValues(alpha: 0.4);

    final cell = Container(
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
      child: Stack(
        children: [
          Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: weight,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isEdited)
            Positioned(
              top: 0,
              right: 0,
              child: CustomPaint(
                size: const Size(8, 8),
                painter: _CornerTrianglePainter(Colors.blueGrey.shade500),
              ),
            ),
        ],
      ),
    );

    if (!isEdited) return cell;

    return GestureDetector(
      onTap: onShowLineage,
      child: cell,
    );
  }

  static String _statusAbbrev(String status) => switch (status) {
        'NOT_OBSERVED' => 'N/O',
        'NOT_APPLICABLE' => 'N/A',
        'MISSING_CONDITION' => 'M/C',
        'TECHNICAL_ISSUE' => 'T/I',
        _ => status,
      };

  static String _formatNumber(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

class _StatsCell extends StatelessWidget {
  const _StatsCell({
    required this.width,
    required this.height,
    required this.stats,
  });

  final double width;
  final double height;
  final ({double mean, double min, double max, int n})? stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (stats == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          border: const Border(
            top: BorderSide(color: AppDesignTokens.borderCrisp),
            right: BorderSide(color: AppDesignTokens.borderCrisp),
          ),
        ),
      );
    }
    final s = stats!;
    final meanStr = _fmt(s.mean);
    final rangeStr = '${_fmt(s.min)}–${_fmt(s.max)} n=${s.n}';

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: const Border(
          top: BorderSide(color: AppDesignTokens.borderCrisp),
          right: BorderSide(color: AppDesignTokens.borderCrisp),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'x̄ $meanStr',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            rangeStr,
            style: TextStyle(
              fontSize: 9,
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

/// Paints a small filled triangle in the top-right corner of a cell,
/// similar to Excel's comment indicator.
class _CornerTrianglePainter extends CustomPainter {
  _CornerTrianglePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerTrianglePainter old) =>
      old.color != color;
}
