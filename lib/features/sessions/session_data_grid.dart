import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/plot_analysis_eligibility.dart';
import '../../core/plot_display.dart';
import '../../core/ui/assessment_display_helper.dart';
import '../ratings/rating_lineage_sheet.dart';

/// Read-only data grid: plots × assessments with rating values.
/// Frozen first column (plot labels) and frozen header row (assessment names).
/// Synchronized scrolling: horizontal header ↔ data, vertical labels ↔ data.
class SessionDataGrid extends ConsumerStatefulWidget {
  const SessionDataGrid({
    super.key,
    required this.plots,
    required this.assessments,
    required this.ratings,
    required this.trialId,
    required this.sessionId,
    this.onPlotTap,
    this.onCellTap,
    this.assessmentDisplayNames,
    this.outlierKeys,
    this.plotTreatmentMap,
  });

  final List<Plot> plots;
  final List<Assessment> assessments;
  final List<RatingRecord> ratings;
  final int trialId;
  final int sessionId;
  final void Function(Plot plot)? onPlotTap;

  /// Called when a data cell is tapped. Receives plot, assessment, and rating.
  final void Function(Plot plot, Assessment assessment, RatingRecord? rating)?
      onCellTap;
  final Map<int, String>? assessmentDisplayNames;
  final Set<(int, int)>? outlierKeys;

  /// Pre-resolved plot → treatment ID map. Used for treatment highlighting.
  final Map<int, int>? plotTreatmentMap;

  @override
  ConsumerState<SessionDataGrid> createState() => _SessionDataGridState();
}

class _SessionDataGridState extends ConsumerState<SessionDataGrid> {
  final _hScrollData = ScrollController();
  final _hScrollHeader = ScrollController();
  final _vScrollData = ScrollController();
  final _vScrollPlots = ScrollController();

  bool _syncingH = false;
  bool _syncingV = false;

  /// Treatment ID currently highlighted; null = no highlight active.
  int? _highlightedTreatmentId;

  /// Sort state: assessment ID to sort by, and direction.
  int? _sortByAssessmentId;
  bool _sortAscending = true;

  /// Pinch-to-zoom: multiplies cell/row dimensions and font sizes.
  /// 1.0 = default. Clamped to [_kMinZoom, _kMaxZoom].
  static const double _kMinZoom = 0.75;
  static const double _kMaxZoom = 2.0;
  double _zoomLevel = 1.0;
  double _zoomAtGestureStart = 1.0;

  @override
  void initState() {
    super.initState();
    _hScrollData.addListener(_onHScrollData);
    _hScrollHeader.addListener(_onHScrollHeader);
    _vScrollData.addListener(_onVScrollData);
    _vScrollPlots.addListener(_onVScrollPlots);
  }

  void _onHScrollData() {
    if (_syncingH) return;
    _syncingH = true;
    if (_hScrollHeader.hasClients) {
      _hScrollHeader.jumpTo(_hScrollData.offset);
    }
    _syncingH = false;
  }

  void _onHScrollHeader() {
    if (_syncingH) return;
    _syncingH = true;
    if (_hScrollData.hasClients) {
      _hScrollData.jumpTo(_hScrollHeader.offset);
    }
    _syncingH = false;
  }

  void _onVScrollData() {
    if (_syncingV) return;
    _syncingV = true;
    if (_vScrollPlots.hasClients) {
      _vScrollPlots.jumpTo(_vScrollData.offset);
    }
    _syncingV = false;
  }

  void _onVScrollPlots() {
    if (_syncingV) return;
    _syncingV = true;
    if (_vScrollData.hasClients) {
      _vScrollData.jumpTo(_vScrollPlots.offset);
    }
    _syncingV = false;
  }

  @override
  void dispose() {
    _hScrollData.removeListener(_onHScrollData);
    _hScrollHeader.removeListener(_onHScrollHeader);
    _vScrollData.removeListener(_onVScrollData);
    _vScrollPlots.removeListener(_onVScrollPlots);
    _hScrollData.dispose();
    _hScrollHeader.dispose();
    _vScrollData.dispose();
    _vScrollPlots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assessments = widget.assessments;
    final plots = widget.plots;

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

    final unsortedDataPlots = plots.where(isAnalyzablePlot).toList();
    if (unsortedDataPlots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No data plots.', style: TextStyle(fontSize: 14)),
      );
    }

    // Rating lookup (build before sorting since sort uses it)
    final ratingMap = <(int, int), RatingRecord>{};
    for (final r in widget.ratings) {
      if (!r.isCurrent || r.isDeleted) continue;
      ratingMap[(r.plotPk, r.assessmentId)] = r;
    }

    // Apply sorting
    final dataPlots = List<Plot>.from(unsortedDataPlots);
    if (_sortByAssessmentId != null) {
      dataPlots.sort((a, b) {
        final ra = ratingMap[(a.id, _sortByAssessmentId!)];
        final rb = ratingMap[(b.id, _sortByAssessmentId!)];
        final va = ra?.numericValue;
        final vb = rb?.numericValue;
        // Nulls go to bottom
        if (va == null && vb == null) return 0;
        if (va == null) return 1;
        if (vb == null) return -1;
        return _sortAscending ? va.compareTo(vb) : vb.compareTo(va);
      });
    }

    // Build rep boundary set for visual grouping
    final repBoundaryIndices = <int>{};
    if (_sortByAssessmentId == null) {
      // Only show rep lines when not sorted (natural order)
      for (var i = 1; i < dataPlots.length; i++) {
        if (dataPlots[i].rep != null &&
            dataPlots[i - 1].rep != null &&
            dataPlots[i].rep != dataPlots[i - 1].rep) {
          repBoundaryIndices.add(i);
        }
      }
    }

    // Plot → treatment map for highlighting (from pre-resolved assignments)
    final plotTreatmentId = <int, int?>{};
    if (widget.plotTreatmentMap != null) {
      for (final p in dataPlots) {
        plotTreatmentId[p.id] = widget.plotTreatmentMap![p.id] ?? p.treatmentId;
      }
    } else {
      for (final p in dataPlots) {
        plotTreatmentId[p.id] = p.treatmentId;
      }
    }

    // Set of plot PKs that match the highlighted treatment
    final highlightedPlotPks = <int>{};
    if (_highlightedTreatmentId != null) {
      for (final e in plotTreatmentId.entries) {
        if (e.value == _highlightedTreatmentId) {
          highlightedPlotPks.add(e.key);
        }
      }
    }

    // Column stats
    final colStats = <int, ({double mean, double min, double max, int n})>{};
    for (final a in assessments) {
      final values = <double>[];
      for (final p in dataPlots) {
        final r = ratingMap[(p.id, a.id)];
        if (r != null &&
            r.resultStatus == 'RECORDED' &&
            r.numericValue != null) {
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

    // Lineage callback
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

    // Sizing — base values (zoom 1.0), then multiplied by _zoomLevel.
    final colCount = assessments.length;
    final screenWidth = MediaQuery.sizeOf(context).width;
    const basePlotColWidth = 64.0;
    const baseMinCellWidth = 72.0;
    const baseMaxCellWidth = 110.0;
    const baseHeaderHeight = 52.0;
    const baseRowHeight = 40.0;
    const baseStatsRowHeight = 48.0;

    final z = _zoomLevel;
    final plotColWidth = basePlotColWidth * z;
    final headerHeight = baseHeaderHeight * z;
    final rowHeight = baseRowHeight * z;
    final statsRowHeight = baseStatsRowHeight * z;

    // At zoom 1.0, cellWidth auto-fits; at other zoom, we scale the auto-fit width.
    final availableWidth = screenWidth - basePlotColWidth - 16;
    var baseCellWidth =
        colCount > 0 ? availableWidth / colCount : baseMaxCellWidth;
    baseCellWidth = baseCellWidth.clamp(baseMinCellWidth, baseMaxCellWidth);
    final cellWidth = baseCellWidth * z;
    final totalDataWidth = cellWidth * colCount;
    final hasStats = colStats.isNotEmpty;

    final scheme = Theme.of(context).colorScheme;

    String displayName(Assessment a) {
      if (widget.assessmentDisplayNames != null &&
          widget.assessmentDisplayNames!.containsKey(a.id)) {
        return widget.assessmentDisplayNames![a.id]!;
      }
      return AssessmentDisplayHelper.legacyAssessmentDisplayName(a.name);
    }

    // ---- 4-quadrant layout ----
    // Top-left: frozen corner
    final corner = Container(
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
      child: Text(
        'Plot',
        style: TextStyle(fontSize: 11 * z, fontWeight: FontWeight.w700),
      ),
    );

    // Top-right: assessment headers (scrolls horizontally)
    final headerRow = SizedBox(
      height: headerHeight,
      child: ListView.builder(
        controller: _hScrollHeader,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        itemCount: colCount,
        itemExtent: cellWidth,
        itemBuilder: (_, i) {
          final a = assessments[i];
          final isSorted = _sortByAssessmentId == a.id;
          return GestureDetector(
            onTap: () {
              setState(() {
                if (_sortByAssessmentId == a.id) {
                  if (_sortAscending) {
                    _sortAscending = false; // second tap: reverse
                  } else {
                    _sortByAssessmentId = null; // third tap: reset
                    _sortAscending = true;
                  }
                } else {
                  _sortByAssessmentId = a.id;
                  _sortAscending = true;
                }
              });
            },
            child: Container(
              width: cellWidth,
              height: headerHeight,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSorted
                    ? AppDesignTokens.primary.withValues(alpha: 0.08)
                    : scheme.surfaceContainerHighest,
                border: const Border(
                  bottom: BorderSide(color: AppDesignTokens.borderCrisp),
                  right: BorderSide(color: AppDesignTokens.borderCrisp),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayName(a),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10 * z,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  if (isSorted)
                    Icon(
                      _sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 10 * z,
                      color: AppDesignTokens.primary,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );

    // ---- BOTTOM HALF: plot labels (left) + data cells (right) ----
    // Both scroll vertically in sync. Data also scrolls horizontally.
    // Stats footer is pinned below the scrollable area.

    return GestureDetector(
      onScaleStart: (_) => _zoomAtGestureStart = _zoomLevel,
      onScaleUpdate: (details) {
        // Only react to pinch (2+ pointers). Single-finger drag passes
        // through to the inner scroll controllers via the gesture arena.
        if (details.pointerCount < 2) return;
        final next = (_zoomAtGestureStart * details.scale)
            .clamp(_kMinZoom, _kMaxZoom);
        if (next != _zoomLevel) {
          setState(() => _zoomLevel = next);
        }
      },
      onDoubleTap: () {
        if (_zoomLevel != 1.0) {
          setState(() => _zoomLevel = 1.0);
        }
      },
      child: Column(
        children: [
          // TOP: corner + assessment headers
          Row(
            children: [
              corner,
              Expanded(child: headerRow),
            ],
          ),
        // MIDDLE: scrollable plot labels + data cells
        Expanded(
          child: Row(
            children: [
              // Frozen plot column
              SizedBox(
                width: plotColWidth,
                child: ListView.builder(
                  controller: _vScrollPlots,
                  physics: const ClampingScrollPhysics(),
                  itemCount: dataPlots.length,
                  itemExtent: rowHeight,
                  itemBuilder: (_, i) {
                    final plot = dataPlots[i];
                    final isHighlighted =
                        highlightedPlotPks.contains(plot.id);
                    final isRepBoundary = repBoundaryIndices.contains(i);
                    return GestureDetector(
                      onTap: widget.onPlotTap != null
                          ? () => widget.onPlotTap!(plot)
                          : null,
                      onLongPress: () {
                        final tid = plotTreatmentId[plot.id];
                        if (tid == null) return;
                        setState(() {
                          _highlightedTreatmentId =
                              _highlightedTreatmentId == tid ? null : tid;
                        });
                      },
                      child: Container(
                        width: plotColWidth,
                        height: rowHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? AppDesignTokens.primary
                                  .withValues(alpha: 0.12)
                              : (i.isEven
                                  ? scheme.surface
                                  : scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.4)),
                          border: Border(
                            top: isRepBoundary
                                ? BorderSide(
                                    color: AppDesignTokens.primary
                                        .withValues(alpha: 0.4),
                                    width: 2)
                                : BorderSide.none,
                            bottom: BorderSide(
                                color: AppDesignTokens.borderCrisp
                                    .withValues(alpha: 0.5)),
                            right: const BorderSide(
                                color: AppDesignTokens.borderCrisp),
                            left: isHighlighted
                                ? const BorderSide(
                                    color: AppDesignTokens.primary,
                                    width: 3)
                                : BorderSide.none,
                          ),
                        ),
                        child: Text(
                          getDisplayPlotLabel(plot, plots),
                          style: TextStyle(
                            fontSize: 12 * z,
                            fontWeight: FontWeight.w700,
                            color: isHighlighted
                                ? AppDesignTokens.primary
                                : (widget.onPlotTap != null
                                    ? AppDesignTokens.primary
                                    : null),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Scrollable data area
              Expanded(
                child: SingleChildScrollView(
                  controller: _hScrollData,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: totalDataWidth,
                    child: ListView.builder(
                      controller: _vScrollData,
                      physics: const ClampingScrollPhysics(),
                      itemCount: dataPlots.length,
                      itemExtent: rowHeight,
                      itemBuilder: (_, rowIndex) {
                        final plot = dataPlots[rowIndex];
                        final rowHighlighted =
                            highlightedPlotPks.contains(plot.id);
                        return SizedBox(
                          height: rowHeight,
                          child: Row(
                            children: [
                              for (final a in assessments)
                                _DataCell(
                                  width: cellWidth,
                                  height: rowHeight,
                                  fontSize: 12 * z,
                                  rating: ratingMap[(plot.id, a.id)],
                                  isEvenRow: rowIndex.isEven,
                                  isOutlier: widget.outlierKeys?.contains(
                                          (plot.id, a.id)) ??
                                      false,
                                  isHighlighted: rowHighlighted,
                                  onTap: widget.onCellTap != null
                                      ? () => widget.onCellTap!(
                                            plot,
                                            a,
                                            ratingMap[(plot.id, a.id)],
                                          )
                                      : null,
                                  onShowLineage: () => showLineage(
                                    plotPk: plot.id,
                                    assessmentId: a.id,
                                    plotLabel: getDisplayPlotLabel(
                                        plot, plots),
                                    assessmentName: displayName(a),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // BOTTOM: stats footer (pinned, not scrollable vertically)
        if (hasStats)
          Row(
            children: [
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
                child: Text(
                  'Stats',
                  style:
                      TextStyle(fontSize: 10 * z, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: totalDataWidth,
                    child: SizedBox(
                      height: statsRowHeight,
                      child: Row(
                        children: [
                          for (final a in assessments)
                            _StatsCell(
                              width: cellWidth,
                              height: statsRowHeight,
                              stats: colStats[a.id],
                              meanFontSize: 11 * z,
                              rangeFontSize: 9 * z,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cell widgets
// ---------------------------------------------------------------------------

class _DataCell extends StatelessWidget {
  const _DataCell({
    required this.width,
    required this.height,
    required this.rating,
    required this.isEvenRow,
    required this.onShowLineage,
    this.onTap,
    this.isOutlier = false,
    this.isHighlighted = false,
    this.fontSize = 12,
  });

  final double width;
  final double height;
  final RatingRecord? rating;
  final bool isEvenRow;
  final VoidCallback onShowLineage;
  final VoidCallback? onTap;
  final bool isOutlier;
  final bool isHighlighted;
  final double fontSize;

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

    final baseBg = isHighlighted
        ? AppDesignTokens.primary.withValues(alpha: 0.08)
        : (isEvenRow
            ? scheme.surface
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4));
    final bg = isOutlier ? Colors.amber.shade50 : baseBg;

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
                fontSize: fontSize,
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

    if (onTap == null && !isEdited) return cell;

    return GestureDetector(
      onTap: onTap,
      onLongPress: isEdited ? onShowLineage : null,
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
    this.meanFontSize = 11,
    this.rangeFontSize = 9,
  });

  final double width;
  final double height;
  final ({double mean, double min, double max, int n})? stats;
  final double meanFontSize;
  final double rangeFontSize;

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
            style: TextStyle(
              fontSize: meanFontSize,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            rangeStr,
            style: TextStyle(
              fontSize: rangeFontSize,
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

/// Paints a small filled triangle in the top-right corner of a cell.
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
