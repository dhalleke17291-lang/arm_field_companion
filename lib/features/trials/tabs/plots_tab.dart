import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../domain/models/trial_insight.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/plot_display.dart';
import '../../../core/providers.dart';
import '../../../core/protocol_edit_blocked_exception.dart';
import '../../../core/trial_state.dart';
import '../../../core/workspace/workspace_filter.dart';
import 'add_treatment_sheet.dart';
import '../standalone/standalone_generate_plot_layout_sheet.dart';
import '../../../core/widgets/loading_error_widgets.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../plot_layout_model.dart';
import '../../plots/plot_detail_screen.dart';

void _plotsTabLockDebugPrint(
  Trial trial,
  bool hasSessionData,
  bool trialIsArmLinked,
) {
  debugPrint(
    'PLOTS_LOCK_DEBUG: canEdit=${canEditTrialStructure(trial, hasSessionData: hasSessionData, trialIsArmLinked: trialIsArmLinked)}, '
    'hasSessionData=$hasSessionData, status=${trial.status}, workspace=${trial.workspaceType}, '
    'isArmLinked=$trialIsArmLinked',
  );
}

enum _LayoutLayer { treatments, applications, ratings }

const double _kGridMinScale = 0.3;
const double _kGridMaxScale = 3.0;

/// Left gutter for "Rep n" labels — same width on layout grid and ratings overlay.
const double _kRepLabelWidth = 52.0;

/// Plot-number badge on the plots list (keep compact; large squares dominate the row).
const double _kPlotListLeadingBadgeSize = 34.0;

/// Swatch size for plot layout legends (Treats / Apps / Ratings).
const double _kPlotLayoutLegendSwatch = 12.0;

TextStyle _plotDetailsRepLabelStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.12,
    height: 1.25,
    color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
  );
}

BoxDecoration _plotLayoutLegendPanelDecoration(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(
      color: scheme.outlineVariant.withValues(alpha: 0.28),
      width: 1,
    ),
  );
}

Future<void> _runGenerateRepGuardPlots(
  BuildContext context,
  WidgetRef ref,
  int trialId,
) async {
  final uc = ref.read(generateRepGuardPlotsUseCaseProvider);
  final int n;
  try {
    n = await uc.countToInsert(trialId);
  } on ProtocolEditBlockedException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
    return;
  }
  if (!context.mounted) return;
  if (n == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'All rep guard plots already exist. Nothing to add.',
        ),
      ),
    );
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Add Rep Guard Plots'),
      content: Text(
        'Add $n guard plot${n == 1 ? '' : 's'}? '
        'Each rep gets flank plots G{rep}-L (left) and G{rep}-R (right). '
        'Existing research plots are not modified.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Add'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final int added;
  try {
    added = await uc.execute(trialId);
  } on ProtocolEditBlockedException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
    return;
  }
  ref.invalidate(plotsForTrialProvider(trialId));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        added == 1 ? 'Added 1 guard plot.' : 'Added $added guard plots.',
      ),
    ),
  );
}

Widget _buildAddRepGuardsRow(
  BuildContext context,
  WidgetRef ref,
  Trial trial, {
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(
    AppDesignTokens.spacing16,
    0,
    AppDesignTokens.spacing16,
    4,
  ),
}) {
  final hasData =
      ref.watch(trialHasSessionDataProvider(trial.id)).valueOrNull ?? false;
  final trialIsArmLinked =
      ref.watch(armTrialMetadataStreamProvider(trial.id)).valueOrNull?.isArmLinked ==
          true;
  final enabled = canEditTrialStructure(
    trial,
    hasSessionData: hasData,
    trialIsArmLinked: trialIsArmLinked,
  );
  return Padding(
    padding: padding,
    child: Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: enabled
            ? () => _runGenerateRepGuardPlots(context, ref, trial.id)
            : null,
        icon: const Icon(Icons.add_moderator_outlined, size: 18),
        label: const Text('Add Rep Guards'),
        style: TextButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    ),
  );
}

const double _kHeatMapMinSpread = 5.0;

/// Interpolates a heat map color from blue (low) → yellow (mid) → red (high)
/// relative to session min/max. When spread < 5 pts, returns mid color
/// to avoid exaggerating trivial differences.
Color _heatMapColor(double value, double min, double max) {
  if (max - min < _kHeatMapMinSpread) return AppDesignTokens.heatMapMid;
  final t = ((value - min) / (max - min)).clamp(0.0, 1.0);
  if (t < 0.5) {
    final localT = t * 2;
    return Color.lerp(
        AppDesignTokens.heatMapLow, AppDesignTokens.heatMapMid, localT)!;
  } else {
    final localT = (t - 0.5) * 2;
    return Color.lerp(
        AppDesignTokens.heatMapMid, AppDesignTokens.heatMapHigh, localT)!;
  }
}

bool _isLowSpread(double min, double max) => max - min < _kHeatMapMinSpread;

/// Explains how many layout plots have a numeric rating for the selected
/// assessment—important when the session is incomplete so "—" is not mistaken
/// for a display bug.
String _heatMapLayoutCoverageCaption({
  required List<Plot> plots,
  required Map<int, RatingRecord> ratingByPlot,
}) {
  final layoutPlots = plots.where((p) => !p.isGuardRow).toList();
  final total = layoutPlots.length;
  if (total == 0) return '';
  var withNumeric = 0;
  for (final p in layoutPlots) {
    final r = ratingByPlot[p.id];
    if (r != null && r.resultStatus == 'RECORDED' && r.numericValue != null) {
      withNumeric++;
    }
  }
  if (withNumeric == 0) {
    return 'No layout plots have a numeric value for this assessment yet (—).';
  }
  if (withNumeric == total) {
    return 'All $total layout plots have a numeric value for this assessment.';
  }
  return '$withNumeric of $total layout plots have a numeric value; others show — until rated.';
}

/// One current rating per plot PK for [assessmentId] (non-VOID rows only).
Map<int, RatingRecord> _ratingByPlotForAssessment(
  List<RatingRecord> allRatings,
  int assessmentId,
) {
  final out = <int, RatingRecord>{};
  for (final r in allRatings) {
    if (r.resultStatus == 'VOID' || r.assessmentId != assessmentId) continue;
    out.putIfAbsent(r.plotPk, () => r);
  }
  return out;
}

Color _ratingCellColor(String? status) {
  switch (status) {
    case 'RECORDED':
      return const Color(0xFF2D5A40);
    case 'NOT_OBSERVED':
      return Colors.grey.shade400;
    case 'NOT_APPLICABLE':
      return Colors.grey.shade400;
    case 'MISSING_CONDITION':
      return const Color(0xFFF59E0B);
    case 'TECHNICAL_ISSUE':
      return const Color(0xFFEA580C);
    default:
      return Colors.white;
  }
}

Color _ratingTextColor(String? status) {
  if (status == null) return Colors.grey.shade400;
  return Colors.white;
}

String _ratingCellLabel(RatingRecord? rating) {
  if (rating == null) return '';
  switch (rating.resultStatus) {
    case 'RECORDED':
      if (rating.numericValue != null) {
        final v = rating.numericValue!;
        return v == v.truncateToDouble()
            ? v.toInt().toString()
            : v.toStringAsFixed(1);
      }
      return rating.textValue ?? '';
    case 'NOT_OBSERVED':
      return 'N/O';
    case 'NOT_APPLICABLE':
      return 'N/A';
    case 'MISSING_CONDITION':
      return '!';
    case 'TECHNICAL_ISSUE':
      return 'T';
    default:
      return '';
  }
}

Widget _ratingOverlayLegendChip(
    BuildContext context, Color color, String label) {
  final scheme = Theme.of(context).colorScheme;
  final borderColor = color == Colors.white
      ? scheme.outlineVariant.withValues(alpha: 0.45)
      : const Color(0xFFE0DDD6);
  return Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: _kPlotLayoutLegendSwatch,
        height: _kPlotLayoutLegendSwatch,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: borderColor),
        ),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppDesignTokens.primaryText,
        ),
      ),
    ],
  );
}

/// Single-line treatment line for Treats legend (matches Apps chip density).
Widget _compactTreatmentLegendLine(
  BuildContext context,
  Color color,
  String code,
  String name, [
  String? description,
]) {
  final line = '$code - $name';
  final row = Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: _kPlotLayoutLegendSwatch,
        height: _kPlotLayoutLegendSwatch,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          line,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppDesignTokens.primaryText,
          ),
        ),
      ),
    ],
  );
  if (description != null && description.trim().isNotEmpty) {
    return Tooltip(
      message: description.trim(),
      child: row,
    );
  }
  return row;
}

/// Plot layout Ratings layer: one [Assessment] at a time so heat map and cells
/// are not silently taken from mixed multi-trait session data.
class _PlotLayoutRatingsOverlay extends ConsumerStatefulWidget {
  const _PlotLayoutRatingsOverlay({
    required this.trial,
    required this.plots,
    required this.sessions,
    required this.selectedRatingSession,
    required this.onSessionChanged,
    required this.heatMapEnabled,
    required this.onHeatMapToggled,
  });

  final Trial trial;
  final List<Plot> plots;
  final List<Session> sessions;
  final Session? selectedRatingSession;
  final ValueChanged<Session> onSessionChanged;
  final bool heatMapEnabled;
  final ValueChanged<bool> onHeatMapToggled;

  @override
  ConsumerState<_PlotLayoutRatingsOverlay> createState() =>
      _PlotLayoutRatingsOverlayState();
}

class _PlotLayoutRatingsOverlayState
    extends ConsumerState<_PlotLayoutRatingsOverlay> {
  /// Cleared when the selected session changes; until then defaults to first assessment.
  int? _pickedAssessmentId;

  /// Shared with [InteractiveViewer] so we can snap back to the top-left after
  /// heat / session / assessment changes. Otherwise pan/zoom can leave the
  /// viewport over the bottom rows only (e.g. Rep 4) while Reps 1–3 sit
  /// above the clipped area — not a data / zero-value issue.
  final TransformationController _ratingsPanZoomController =
      TransformationController();

  void _resetRatingsLayoutViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ratingsPanZoomController.value = Matrix4.identity();
    });
  }

  @override
  void dispose() {
    _ratingsPanZoomController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PlotLayoutRatingsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSid = oldWidget.selectedRatingSession?.id ??
        (oldWidget.sessions.isNotEmpty ? oldWidget.sessions.first.id : null);
    final newSid = widget.selectedRatingSession?.id ??
        (widget.sessions.isNotEmpty ? widget.sessions.first.id : null);
    if (oldSid != newSid) {
      _pickedAssessmentId = null;
      _resetRatingsLayoutViewport();
    }
    if (oldWidget.trial.id != widget.trial.id) {
      _resetRatingsLayoutViewport();
    }
    if (oldWidget.heatMapEnabled != widget.heatMapEnabled) {
      _resetRatingsLayoutViewport();
    }
  }

  int _resolveAssessmentId(List<Assessment> assessments) {
    final ids = assessments.map((a) => a.id).toSet();
    final picked = _pickedAssessmentId;
    if (picked != null && ids.contains(picked)) return picked;
    return assessments.first.id;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sessions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_outlined, size: 48, color: Color(0xFFBBBBBB)),
            SizedBox(height: 12),
            Text(
              'No sessions yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFBBBBBB),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Start a rating session to see the overlay',
              style: TextStyle(fontSize: 12, color: Color(0xFFCCCCCC)),
            ),
          ],
        ),
      );
    }

    var activeSession = widget.sessions.first;
    final sel = widget.selectedRatingSession;
    if (sel != null) {
      for (final s in widget.sessions) {
        if (s.id == sel.id) {
          activeSession = s;
          break;
        }
      }
    }

    final assessmentsAsync =
        ref.watch(sessionAssessmentsProvider(activeSession.id));

    // Key only trial + session so changing the assessment dropdown does not
    // replace the whole subtree (that remount broke heat-map cells vs provider).
    return Column(
      key: ValueKey<Object>(
        Object.hash(widget.trial.id, activeSession.id),
      ),
      children: [
        if (widget.sessions.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: DropdownButtonFormField<int>(
              // ignore: deprecated_member_use
              value: activeSession.id,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE0DDD6)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE0DDD6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF2D5A40),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: widget.sessions
                  .map(
                    (s) => DropdownMenuItem<int>(
                      value: s.id,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                if (id == null) return;
                final s = widget.sessions.firstWhere((e) => e.id == id);
                widget.onSessionChanged(s);
              },
            ),
          ),
        Expanded(
          child: assessmentsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFF2D5A40)),
            ),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (assessments) {
              if (assessments.isEmpty) {
                return const Center(
                  child: Text(
                    'This session has no assessments.',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              final resolvedAssessmentId = _resolveAssessmentId(assessments);
              final selectedAssessment =
                  assessments.firstWhere((a) => a.id == resolvedAssessmentId);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (assessments.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: DropdownButtonFormField<int>(
                        // ignore: deprecated_member_use
                        value: resolvedAssessmentId,
                        decoration: InputDecoration(
                          labelText: 'Assessment',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFE0DDD6)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFE0DDD6)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF2D5A40),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: assessments
                            .map(
                              (a) => DropdownMenuItem<int>(
                                value: a.id,
                                child: Text(
                                  a.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (id) {
                          if (id == null) return;
                          setState(() => _pickedAssessmentId = id);
                          _resetRatingsLayoutViewport();
                        },
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: Text(
                      'Assessment: ${selectedAssessment.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppDesignTokens.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.thermostat,
                            size: 16, color: AppDesignTokens.secondaryText),
                        const SizedBox(width: 6),
                        const Text(
                          'Heat map',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppDesignTokens.secondaryText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 28,
                          child: Switch.adaptive(
                            value: widget.heatMapEnabled,
                            onChanged: widget.onHeatMapToggled,
                            activeTrackColor:
                                AppDesignTokens.primary.withValues(alpha: 0.55),
                            activeThumbColor: AppDesignTokens.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _buildRatingsGridForAssessment(
                      context: context,
                      ref: ref,
                      trial: widget.trial,
                      plots: widget.plots,
                      activeSession: activeSession,
                      assessmentId: resolvedAssessmentId,
                      heatMapEnabled: widget.heatMapEnabled,
                      panZoomController: _ratingsPanZoomController,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

Widget _buildRatingsGridForAssessment({
  required BuildContext context,
  required WidgetRef ref,
  required Trial trial,
  required List<Plot> plots,
  required Session activeSession,
  required int assessmentId,
  required bool heatMapEnabled,
  required TransformationController panZoomController,
}) {
  final ratingsAsync = ref.watch(sessionRatingsProvider(activeSession.id));

  return ratingsAsync.when(
    loading: () => const Center(
      child: CircularProgressIndicator(color: Color(0xFF2D5A40)),
    ),
    error: (e, _) => Center(child: Text('Error: $e')),
    data: (allRatings) {
      final ratings = allRatings
          .where(
              (r) => r.resultStatus != 'VOID' && r.assessmentId == assessmentId)
          .toList();

      final ratingByPlot = _ratingByPlotForAssessment(allRatings, assessmentId);
      final assessmentCountByPlot = <int, int>{};

      for (final r in ratings) {
        assessmentCountByPlot[r.plotPk] =
            (assessmentCountByPlot[r.plotPk] ?? 0) + 1;
      }

      // Heat map: compute min/max for relative gradient (single assessment only).
      double heatMin = double.infinity;
      double heatMax = double.negativeInfinity;
      var hasNumericHeat = false;
      if (heatMapEnabled) {
        for (final r in ratingByPlot.values) {
          if (r.resultStatus == 'RECORDED' && r.numericValue != null) {
            hasNumericHeat = true;
            if (r.numericValue! < heatMin) heatMin = r.numericValue!;
            if (r.numericValue! > heatMax) heatMax = r.numericValue!;
          }
        }
        // Keep legend math safe; cells already use heatMapEmpty when no numeric.
        if (!hasNumericHeat) {
          heatMin = 0;
          heatMax = 100;
        }
      }

      // Rep variability insight for amber border
      final insightsAsync = ref.watch(trialInsightsProvider(trial.id));
      final outlierReps = <int>{};
      if (heatMapEnabled) {
        final insights = insightsAsync.valueOrNull ?? [];
        for (final i in insights) {
          if (i.type == InsightType.repVariability &&
              i.detail.contains('Outlier')) {
            outlierReps.addAll(i.relatedPlotIds);
          }
        }
      }

      final byRep = <int?, List<Plot>>{};
      for (final p in plots) {
        byRep.putIfAbsent(p.rep, () => []).add(p);
      }

      final sortedReps = byRep.keys.toList()
        ..sort((a, b) {
          if (a == null) return 1;
          if (b == null) return -1;
          return a.compareTo(b);
        });

      const tileSize = 56.0;
      const tileSpacing = 6.0;

      return InteractiveViewer(
        key: ValueKey<Object>(Object.hash(activeSession.id, assessmentId)),
        transformationController: panZoomController,
        constrained: false,
        minScale: 0.3,
        maxScale: 3.0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...sortedReps.map((rep) {
                final repPlots = List<Plot>.from(byRep[rep]!);
                repPlots.sort((a, b) =>
                    (a.fieldColumn ?? 0).compareTo(b.fieldColumn ?? 0));

                // Outlier rep border from intelligence
                final isOutlierRep = heatMapEnabled &&
                    rep != null &&
                    repPlots.any((p) => outlierReps.contains(p.id));

                return Padding(
                  padding: const EdgeInsets.only(bottom: tileSpacing),
                  child: Container(
                    decoration: isOutlierRep
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppDesignTokens.warningFg
                                  .withValues(alpha: 0.5),
                              width: 2,
                            ),
                          )
                        : null,
                    padding: isOutlierRep ? const EdgeInsets.all(2) : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: _kRepLabelWidth,
                          child: Text(
                            'Rep ${rep ?? '?'}',
                            style: _plotDetailsRepLabelStyle(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...repPlots.map((plot) {
                          final rating = ratingByPlot[plot.id];
                          final count = assessmentCountByPlot[plot.id] ?? 0;

                          // Heat map mode: gradient color from value
                          final Color cellColor;
                          final Color textColor;
                          final String label;
                          if (heatMapEnabled) {
                            final val = (rating?.resultStatus == 'RECORDED')
                                ? rating?.numericValue
                                : null;
                            cellColor = val != null
                                ? _heatMapColor(val, heatMin, heatMax)
                                : AppDesignTokens.heatMapEmpty;
                            textColor = val != null
                                ? Colors.white
                                : AppDesignTokens.secondaryText;
                            label = val != null ? val.round().toString() : '—';
                          } else {
                            cellColor = _ratingCellColor(rating?.resultStatus);
                            textColor = _ratingTextColor(rating?.resultStatus);
                            label = _ratingCellLabel(rating);
                          }

                          return Padding(
                            padding: const EdgeInsets.only(right: tileSpacing),
                            child: Stack(
                              children: [
                                Container(
                                  width: tileSize,
                                  height: tileSize,
                                  decoration: BoxDecoration(
                                    color: cellColor,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: rating == null
                                          ? const Color(0xFFE0DDD6)
                                          : cellColor,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: heatMapEnabled
                                      ? Stack(
                                          children: [
                                            // Plot number top-left
                                            Positioned(
                                              left: 3,
                                              top: 2,
                                              child: Text(
                                                getDisplayPlotLabel(
                                                    plot, plots),
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w600,
                                                  color: textColor.withValues(
                                                      alpha: 0.7),
                                                ),
                                              ),
                                            ),
                                            // Value centered
                                            Center(
                                              child: Text(
                                                label,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  color: textColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              getDisplayPlotLabel(plot, plots),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: rating == null
                                                    ? Colors.grey.shade400
                                                    : textColor.withValues(
                                                        alpha: 0.78,
                                                      ),
                                              ),
                                            ),
                                            if (label.isNotEmpty)
                                              Text(
                                                label,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: textColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                ),
                                if (!heatMapEnabled && count > 1)
                                  Positioned(
                                    top: 3,
                                    right: 3,
                                    child: Tooltip(
                                      message:
                                          '$count rating rows for this assessment',
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '+${count - 1}A',
                                          style: const TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }),
              if (heatMapEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    _heatMapLayoutCoverageCaption(
                      plots: plots,
                      ratingByPlot: ratingByPlot,
                    ),
                    style: const TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (heatMapEnabled)
                DecoratedBox(
                  decoration: _plotLayoutLegendPanelDecoration(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!hasNumericHeat)
                          const Text(
                            'No recorded numeric values for this assessment.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                              color: AppDesignTokens.secondaryText,
                            ),
                          )
                        else if (_isLowSpread(heatMin, heatMax))
                          Text(
                            'Low spread — values range ${heatMin.round()}–${heatMax.round()}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                              color: AppDesignTokens.secondaryText,
                            ),
                          )
                        else
                          Row(
                            children: [
                              Text(
                                'Low ${heatMin.round()}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppDesignTokens.secondaryText,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Container(
                                  height: 10,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppDesignTokens.heatMapLow,
                                        AppDesignTokens.heatMapMid,
                                        AppDesignTokens.heatMapHigh,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'High ${heatMax.round()}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppDesignTokens.secondaryText,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                )
              else
                DecoratedBox(
                  decoration: _plotLayoutLegendPanelDecoration(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _ratingOverlayLegendChip(
                          context,
                          const Color(0xFF2D5A40),
                          'Recorded',
                        ),
                        _ratingOverlayLegendChip(
                          context,
                          Colors.grey.shade400,
                          'Not observed',
                        ),
                        _ratingOverlayLegendChip(
                          context,
                          const Color(0xFFF59E0B),
                          'Missing',
                        ),
                        _ratingOverlayLegendChip(
                          context,
                          const Color(0xFFEA580C),
                          'Tech issue',
                        ),
                        _ratingOverlayLegendChip(
                          context,
                          Colors.white,
                          'No record',
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildRatingsOverlay({
  required BuildContext context,
  required WidgetRef ref,
  required Trial trial,
  required List<Plot> plots,
  required List<Session> sessions,
  required Session? selectedRatingSession,
  required ValueChanged<Session> onSessionChanged,
  required bool heatMapEnabled,
  required ValueChanged<bool> onHeatMapToggled,
}) {
  return _PlotLayoutRatingsOverlay(
    trial: trial,
    plots: plots,
    sessions: sessions,
    selectedRatingSession: selectedRatingSession,
    onSessionChanged: onSessionChanged,
    heatMapEnabled: heatMapEnabled,
    onHeatMapToggled: onHeatMapToggled,
  );
}

/// Minimap: 48x32 thumbnail of full grid with white viewport rect showing current pan/zoom.
class _LayoutMinimap extends StatelessWidget {
  const _LayoutMinimap({
    required this.gridWidth,
    required this.gridHeight,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.panDx,
    required this.panDy,
    required this.scale,
  });

  final double gridWidth;
  final double gridHeight;
  final double viewportWidth;
  final double viewportHeight;
  final double panDx;
  final double panDy;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const double w = 48;
    const double h = 32;
    if (gridWidth <= 0 || gridHeight <= 0) return const SizedBox.shrink();
    final vw = (viewportWidth / scale).clamp(0.0, gridWidth);
    final vh = (viewportHeight / scale).clamp(0.0, gridHeight);
    final vx = (-panDx / scale).clamp(0.0, gridWidth - vw);
    final vy = (-panDy / scale).clamp(0.0, gridHeight - vh);
    final rx = (vx / gridWidth) * w;
    final ry = (vy / gridHeight) * h;
    final rw = (vw / gridWidth) * w;
    final rh = (vh / gridHeight) * h;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: scheme.surfaceContainerHighest,
              ),
            ),
            Positioned(
              left: rx,
              top: ry,
              width: rw.clamp(2.0, w),
              height: rh.clamp(2.0, h),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: 0.6),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAssignTreatmentDialogForTrial({
  required Trial trial,
  required BuildContext context,
  required WidgetRef ref,
  required Plot plot,
  required List<Plot> plots,
}) async {
  final treatments = ref.read(treatmentsForTrialProvider(trial.id)).value ?? [];

  if (treatments.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No treatments defined yet. Add treatments first.'),
      ),
    );
    return;
  }

  final assignmentsList =
      ref.read(assignmentsForTrialProvider(trial.id)).value ?? [];
  final a = assignmentsList.where((x) => x.plotId == plot.id).firstOrNull;
  int? selectedId = a?.treatmentId ?? plot.treatmentId;
  final displayLabel = getDisplayPlotLabel(plot, plots);

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(
          plot.isGuardRow
              ? 'Assign Treatment — $displayLabel'
              : 'Assign Treatment — Plot $displayLabel',
        ),
        content: DropdownButtonFormField<int>(
          initialValue: selectedId,
          decoration: const InputDecoration(
            labelText: 'Treatment',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Unassigned')),
            ...treatments.map((t) => DropdownMenuItem(
                  value: t.id,
                  child: Text('${t.code}  —  ${t.name}'),
                )),
          ],
          onChanged: (v) => setDialogState(() => selectedId = v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final useCase = ref.read(updatePlotAssignmentUseCaseProvider);
              final result = await useCase.updateOne(
                trial: trial,
                plotPk: plot.id,
                treatmentId: selectedId,
              );
              if (!ctx.mounted) return;
              if (!result.success) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(result.errorMessage ?? 'Update failed'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

/// Extra actions when [trial] is standalone, has no plots, and structure is editable.
Widget? _standalonePlotsEmptyExtra(
  BuildContext context,
  WidgetRef ref,
  Trial trial,
  int treatmentCount,
) {
  final hasData =
      ref.watch(trialHasSessionDataProvider(trial.id)).valueOrNull ?? false;
  final trialIsArmLinked =
      ref.watch(armTrialMetadataStreamProvider(trial.id)).valueOrNull?.isArmLinked ==
          true;
  if (!canEditTrialStructure(
    trial,
    hasSessionData: hasData,
    trialIsArmLinked: trialIsArmLinked,
  )) {
    return null;
  }
  if (!isStandalone(trial.workspaceType)) return null;
  if (treatmentCount >= 2) {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'No plots yet. Generate your plot layout from your treatments and study design.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppDesignTokens.secondaryText,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FilledButton(
            onPressed: () => showStandaloneGeneratePlotLayoutDialog(
              context: context,
              ref: ref,
              trial: trial,
            ),
            child: const Text('Generate Plot Layout'),
          ),
        ),
      ],
    );
  }
  return Column(
    children: [
      const SizedBox(height: 16),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'No plots yet. Add treatments first, then generate your plot layout.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppDesignTokens.secondaryText,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: FilledButton(
          onPressed: () => showAddTreatmentSheet(context, ref, trial: trial),
          child: const Text('Add Treatment'),
        ),
      ),
    ],
  );
}

/// Fixed [IndexedStack] index for [TreatmentsTab] in trial detail (hub order).
const int kTrialTreatmentsStackIndex = 4;

class PlotsTab extends ConsumerStatefulWidget {
  const PlotsTab({
    super.key,
    required this.trial,
    this.embeddedInScroll = false,
    this.onSelectStackIndex,
  });

  final Trial trial;
  final bool embeddedInScroll;

  /// Optional: parent trial screen switches IndexedStack (e.g. Treatments tab).
  final ValueChanged<int>? onSelectStackIndex;

  /// Same navigation as opening layout-first plot surface (e.g. Overview shortcut).
  static void openPlotLayoutView(BuildContext context, Trial trial) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _PlotDetailsScreen(
          trial: trial,
          initialShowLayoutView: true,
        ),
      ),
    );
  }

  @override
  ConsumerState<PlotsTab> createState() => _PlotsTabState();
}

class _PlotsTabState extends ConsumerState<PlotsTab> {
  /// Strip above List/Layout: data counts (left) and treatment **assignment** progress (right).
  Widget _buildCompactPlotStatsStrip({
    required int dataPlotCount,
    required int replicateCount,
    required int treatmentCount,
    required int assignedDataPlotCount,
  }) {
    final allAssigned =
        dataPlotCount > 0 && assignedDataPlotCount == dataPlotCount;
    final noneAssigned =
        dataPlotCount > 0 && assignedDataPlotCount == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatChip(label: '$dataPlotCount', sub: 'plots'),
              const SizedBox(width: 12),
              _StatChip(label: '$treatmentCount', sub: 'trt'),
              const SizedBox(width: 12),
              _StatChip(label: '$replicateCount', sub: 'reps'),
            ],
          ),
          Semantics(
            label: dataPlotCount == 0
                ? 'No data plots'
                : allAssigned
                    ? 'All $dataPlotCount data plots have a treatment assigned'
                    : '$assignedDataPlotCount of $dataPlotCount data plots have a treatment assigned',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  allAssigned
                      ? Icons.check_circle
                      : noneAssigned
                          ? Icons.remove_circle_outline
                          : Icons.warning_amber_rounded,
                  size: 14,
                  color: allAssigned
                      ? AppDesignTokens.successFg
                      : AppDesignTokens.warningFg,
                ),
                const SizedBox(width: 4),
                Text(
                  dataPlotCount == 0
                      ? '—'
                      : '$assignedDataPlotCount/$dataPlotCount',
                  style: AppDesignTokens.bodyCrispStyle(
                    fontSize: 12,
                    color: allAssigned
                        ? AppDesignTokens.successFg
                        : AppDesignTokens.primary,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 40,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: dataPlotCount > 0
                          ? assignedDataPlotCount / dataPlotCount
                          : 0,
                      backgroundColor: AppDesignTokens.borderCrisp,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        allAssigned
                            ? AppDesignTokens.successFg
                            : AppDesignTokens.primary,
                      ),
                      minHeight: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trial = widget.trial;
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final treatmentsAsync = ref.watch(treatmentsForTrialProvider(trial.id));
    return plotsAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, st) => AppErrorView(
        error: e,
        stackTrace: st,
        onRetry: () => ref.invalidate(plotsForTrialProvider(trial.id)),
      ),
      data: (plots) {
        final treatments = treatmentsAsync.value ?? [];
        final treatmentCount = treatments.length;
        final dataPlotCount = plots.where((p) => !p.isGuardRow).length;
        final assignmentsList =
            ref.watch(assignmentsForTrialProvider(trial.id)).value ?? [];
        final assignmentByPlotId = {
          for (final a in assignmentsList) a.plotId: a,
        };
        final dataPlots = plots.where((p) => !p.isGuardRow);
        final assignedDataPlotCount = dataPlots
            .where((p) =>
                (assignmentByPlotId[p.id]?.treatmentId ?? p.treatmentId) !=
                null)
            .length;
        var replicateCount = 0;
        if (plots.isNotEmpty) {
          final repNumbers = <int>{};
          for (final block in buildRepBasedLayout(plots)) {
            for (final row in block.repRows) {
              for (final p in row.plots) {
                if (p.rep != null) repNumbers.add(p.rep!);
              }
            }
          }
          replicateCount = repNumbers.length;
        }
        final plotStatsStrip = _buildCompactPlotStatsStrip(
          dataPlotCount: dataPlotCount,
          replicateCount: replicateCount,
          treatmentCount: treatmentCount,
          assignedDataPlotCount: assignedDataPlotCount,
        );
        final surface = _TrialPlotsWorkingSurface(
          trial: trial,
          compactSurroundings: true,
          statsStrip: plotStatsStrip,
          onTreatmentsShortcut: widget.onSelectStackIndex == null
              ? null
              : () => widget.onSelectStackIndex!(kTrialTreatmentsStackIndex),
        );
        final head = <Widget>[];
        if (plots.isEmpty) {
          final extra = _standalonePlotsEmptyExtra(
            context,
            ref,
            trial,
            treatmentCount,
          );
          if (widget.embeddedInScroll) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...head,
                SizedBox(height: 420, child: surface),
                if (extra != null) extra,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...head,
              Expanded(child: surface),
              if (extra != null) extra,
            ],
          );
        }
        if (widget.embeddedInScroll) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...head,
              SizedBox(height: 520, child: surface),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...head,
            Expanded(child: surface),
          ],
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildProtocolHeader(BuildContext context, Trial trial) {
    final lines = <String>[];
    if (trial.sponsor != null && trial.sponsor!.trim().isNotEmpty) {
      lines.add('Sponsor: ${trial.sponsor!.trim()}');
    }
    if (trial.protocolNumber != null &&
        trial.protocolNumber!.trim().isNotEmpty) {
      lines.add('Protocol: ${trial.protocolNumber!.trim()}');
    }
    if (trial.investigatorName != null &&
        trial.investigatorName!.trim().isNotEmpty) {
      lines.add('Investigator: ${trial.investigatorName!.trim()}');
    }
    if (lines.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing12,
          vertical: AppDesignTokens.spacing8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: lines
            .map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ignore: unused_element
  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(width: AppDesignTokens.spacing16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _applicationsSummaryRow(
      BuildContext context, Trial trial, int applicationCount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Applications',
            style: TextStyle(
              fontSize: 14,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(width: AppDesignTokens.spacing16),
          Text(
            '$applicationCount',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _lastApplicationSummaryRow(
      BuildContext context, TrialApplicationEvent? lastApplication) {
    String value = 'None';
    if (lastApplication != null) {
      value = DateFormat('MMM d, yyyy').format(lastApplication.applicationDate);
      if (lastApplication.applicationMethod != null &&
          lastApplication.applicationMethod!.trim().isNotEmpty) {
        value = '$value · ${lastApplication.applicationMethod!.trim()}';
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last application',
            style: TextStyle(
              fontSize: 14,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(width: AppDesignTokens.spacing16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: lastApplication != null
                    ? AppDesignTokens.primaryText
                    : AppDesignTokens.secondaryText,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _seedingDateSummaryRow(DateTime? seedingDate) {
    final value = seedingDate == null
        ? 'Not recorded'
        : DateFormat('MMM d, yyyy').format(seedingDate.toLocal());
    final isMuted = seedingDate == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seeding date',
            style: TextStyle(
              fontSize: 14,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(width: AppDesignTokens.spacing16),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isMuted
                  ? AppDesignTokens.secondaryText
                  : AppDesignTokens.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pushes the plot working surface with a back bar (kept for route safety).
class _PlotDetailsScreen extends ConsumerStatefulWidget {
  final Trial trial;

  /// When true, open with Layout (grid) tab selected instead of List.
  final bool initialShowLayoutView;

  const _PlotDetailsScreen({
    required this.trial,
    this.initialShowLayoutView = false,
  });

  @override
  ConsumerState<_PlotDetailsScreen> createState() => _PlotDetailsScreenState();
}

class _PlotDetailsScreenState extends ConsumerState<_PlotDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plot Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
          top: false,
          child: _TrialPlotsWorkingSurface(
            trial: widget.trial,
            initialShowLayoutView: widget.initialShowLayoutView,
            compactSurroundings: false,
            onTreatmentsShortcut: null,
          )),
    );
  }
}

/// Plot working surface: List/Layout, tools, guards, layer switcher, list or layout grid.
class _TrialPlotsWorkingSurface extends ConsumerStatefulWidget {
  final Trial trial;

  /// When true, open with Layout (grid) selected instead of List.
  final bool initialShowLayoutView;

  /// When true, omit plot-count header row (parent shows summary) and inline toolbar extras.
  final bool compactSurroundings;

  /// Plots tab: jump to Treatments stack index (caller supplies navigation).
  final VoidCallback? onTreatmentsShortcut;

  /// Optional stats strip rendered above the toolbar chrome (compact mode only).
  final Widget? statsStrip;

  const _TrialPlotsWorkingSurface({
    required this.trial,
    this.initialShowLayoutView = false,
    this.compactSurroundings = false,
    this.onTreatmentsShortcut,
    this.statsStrip,
  });

  @override
  ConsumerState<_TrialPlotsWorkingSurface> createState() =>
      _TrialPlotsWorkingSurfaceState();
}

class _TrialPlotsWorkingSurfaceState
    extends ConsumerState<_TrialPlotsWorkingSurface> {
  bool _armTrialIsLinked(WidgetRef ref) =>
      ref.watch(armTrialMetadataStreamProvider(widget.trial.id)).valueOrNull?.isArmLinked ==
          true;

  late bool _showLayoutView;

  @override
  void initState() {
    super.initState();
    _showLayoutView = widget.initialShowLayoutView;
    _loadPlotLayoutHintDismissed();
    _gridTransformController.addListener(_onGridTransformChanged);
  }

  bool? _plotLayoutHintDismissed;
  static const String _kPlotLayoutHintDismissedKey =
      'plot_layout_hint_dismissed';

  Future<void> _loadPlotLayoutHintDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _plotLayoutHintDismissed =
          prefs.getBool(_kPlotLayoutHintDismissedKey) ?? false;
    });
  }

  double? _layoutGridWidth;
  double? _layoutGridHeight;
  double? _layoutViewportWidth;
  double? _layoutViewportHeight;
  double _panDx = 0;
  double _panDy = 0;
  double _scale = 1.0;

  void _onGridTransformChanged() {
    final m = _gridTransformController.value;
    if (!mounted) return;
    setState(() {
      _scale = m.entry(0, 0).abs();
      _panDx = m.entry(0, 3);
      _panDy = m.entry(1, 3);
    });
  }

  _LayoutLayer _layoutLayer = _LayoutLayer.treatments;
  ApplicationEvent? _selectedAppEvent;
  Session? _selectedRatingSession;
  bool _heatMapEnabled = false;
  List<ApplicationPlotRecord> _appPlotRecords = [];
  bool _loadingAppRecords = false;
  final TransformationController _gridTransformController =
      TransformationController();
  final GlobalKey _plotViewportKey = GlobalKey();
  final GlobalKey _gridContentKey = GlobalKey();
  bool _gridCenterScheduled = false;

  /// Display-only: when false, guard plots are hidden from list and layout in this screen.
  bool _showGuardPlots = false;

  List<Plot> _plotsVisibleInPlotsTab(List<Plot> all) => _showGuardPlots
      ? List<Plot>.from(all)
      : all.where((p) => !p.isGuardRow).toList();

  @override
  void dispose() {
    _gridTransformController.removeListener(_onGridTransformChanged);
    _gridTransformController.dispose();
    super.dispose();
  }

  void _centerGridOnFirstFrame(BuildContext context, List<Plot> plots) {
    if (!mounted) return;
    final viewportBox =
        _plotViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize) return;
    final viewportWidth = viewportBox.size.width;
    final viewportHeight = viewportBox.size.height;
    final gridBox =
        _gridContentKey.currentContext?.findRenderObject() as RenderBox?;
    double gridWidth;
    double gridHeight;
    if (gridBox != null && gridBox.hasSize) {
      gridWidth = gridBox.size.width;
      gridHeight = gridBox.size.height;
    } else {
      final blocks = buildRepBasedLayout(plots);
      int columnCount = 0;
      int rowCount = 0;
      for (final block in blocks) {
        for (final row in block.repRows) {
          if (row.plots.length > columnCount) columnCount = row.plots.length;
          rowCount++;
        }
      }
      if (columnCount == 0) return;
      const double rowHeight = 58.0;
      const double rowSpacing = 6.0;
      gridWidth = columnCount * 56.0;
      gridHeight = rowCount * (rowHeight + rowSpacing) + 24;
    }
    if (mounted) {
      setState(() {
        _layoutGridWidth = gridWidth;
        _layoutGridHeight = gridHeight;
        _layoutViewportWidth = viewportWidth;
        _layoutViewportHeight = viewportHeight;
      });
    }
    // Start at left when grid overflows; center when grid fits.
    final dx =
        gridWidth > viewportWidth ? 0.0 : (viewportWidth - gridWidth) / 2;
    final dy =
        gridHeight > viewportHeight ? 0.0 : (viewportHeight - gridHeight) / 2;
    _gridTransformController.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0.0, 1.0);
  }

  Future<void> _loadAppRecords(ApplicationEvent event) async {
    setState(() {
      _selectedAppEvent = event;
      _loadingAppRecords = true;
    });
    final repo = ref.read(applicationRepositoryProvider);
    final records = await repo.getPlotRecordsForEvent(event.id);
    if (mounted) {
      setState(() {
        _appPlotRecords = records;
        _loadingAppRecords = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trial = widget.trial;
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final treatmentsAsync = ref.watch(treatmentsForTrialProvider(trial.id));
    final sessionsAsync = ref.watch(sessionsForTrialProvider(trial.id));
    final hasSessionDataAsync =
        ref.watch(trialHasSessionDataProvider(trial.id));
    final assignmentsAsync = ref.watch(assignmentsForTrialProvider(trial.id));
    final trialApplicationsAsync =
        ref.watch(trialApplicationsForTrialProvider(trial.id));
    return plotsAsync.when(
      loading: () => widget.compactSurroundings
          ? const Center(child: AppLoadingView())
          : const AppLoadingView(),
      error: (e, st) => AppErrorView(
        error: e,
        stackTrace: st,
        onRetry: () => ref.invalidate(plotsForTrialProvider(trial.id)),
      ),
      data: (plots) => plots.isEmpty
          ? _PlotDetailsEmptyContent(trial: trial)
          : _buildPlotDetailsContent(
              context,
              ref,
              plots,
              treatments: treatmentsAsync.value ?? [],
              sessions: sessionsAsync.value ?? [],
              hasSessionData: hasSessionDataAsync.valueOrNull ?? false,
              assignmentsList: assignmentsAsync.value ?? [],
              applicationsList: trialApplicationsAsync.value ?? [],
            ),
    );
  }

  Widget _buildPlotDetailsContent(
    BuildContext context,
    WidgetRef ref,
    List<Plot> plots, {
    required List<Treatment> treatments,
    required List<Session> sessions,
    required bool hasSessionData,
    required List<Assignment> assignmentsList,
    required List<TrialApplicationEvent> applicationsList,
  }) {
    final trialIsArmLinked = _armTrialIsLinked(ref);
    final displayPlots = _plotsVisibleInPlotsTab(plots);
    final plotAssignmentsLocked =
        plotAssignmentsEditLocked(widget.trial, hasSessionData,
            trialIsArmLinked: trialIsArmLinked);
    const double maxTopSectionHeight = 380;
    final colorScheme = Theme.of(context).colorScheme;
    final unifiedPlotsChrome =
        widget.compactSurroundings && widget.statsStrip != null;
    final toolbarChildren = <Widget>[
      if (!widget.compactSurroundings) ...[
        _buildPlotsHeaderForDetails(context, ref, plots, hasSessionData),
        const SizedBox(height: 12),
        Divider(
          height: 1,
          thickness: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 4),
      ],
      if (widget.compactSurroundings && !unifiedPlotsChrome) ...[
        const SizedBox(height: 2),
      ],
      _buildListLayoutToggleForDetails(
        context,
        ref,
        displayPlots,
        hasSessionData,
        allTrialPlots: plots,
      ),
      if (_showLayoutView) ...[
        const SizedBox(height: 6),
        Divider(
          height: 1,
          thickness: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 8),
        _buildLayerSwitcherForDetails(context),
        if (_plotLayoutHintDismissed == false) _buildPanZoomHint(context),
        if (_layoutLayer == _LayoutLayer.applications)
          _buildAppEventSelectorForDetails(context, ref),
      ],
    ];
    final toolbarColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: toolbarChildren,
    );
    final compactToolbarOnly = Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: toolbarColumn,
    );
    final nonCompactToolbarChrome = Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.38),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: toolbarColumn,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.compactSurroundings)
          unifiedPlotsChrome
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppDesignTokens.cardSurface,
                      borderRadius:
                          BorderRadius.circular(AppDesignTokens.radiusCard),
                      border: Border.all(
                        color: AppDesignTokens.borderCrisp,
                        width: AppDesignTokens.borderWidthCrisp,
                      ),
                      boxShadow: AppDesignTokens.cardShadow,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        widget.statsStrip!,
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: AppDesignTokens.borderCrisp,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
                          child: toolbarColumn,
                        ),
                      ],
                    ),
                  ),
                )
              : compactToolbarOnly
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: maxTopSectionHeight),
            child: SingleChildScrollView(
              child: nonCompactToolbarChrome,
            ),
          ),
        if (_showLayoutView)
          Expanded(
            child: _layoutLayer == _LayoutLayer.ratings
                ? _buildRatingsOverlay(
                    context: context,
                    ref: ref,
                    trial: widget.trial,
                    plots: displayPlots,
                    sessions: sessions,
                    selectedRatingSession: _selectedRatingSession,
                    onSessionChanged: (s) =>
                        setState(() => _selectedRatingSession = s),
                    heatMapEnabled: _heatMapEnabled,
                    onHeatMapToggled: (v) =>
                        setState(() => _heatMapEnabled = v),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (!_gridCenterScheduled) {
                        _gridCenterScheduled = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _centerGridOnFirstFrame(context, displayPlots);
                        });
                      }
                      final size = MediaQuery.sizeOf(context);
                      final viewportWidth = constraints.maxWidth.isFinite &&
                              constraints.maxWidth > 0
                          ? constraints.maxWidth
                          : size.width;
                      final viewportHeight = constraints.maxHeight.isFinite &&
                              constraints.maxHeight > 0
                          ? constraints.maxHeight
                          : size.height;
                      final blocks = buildRepBasedLayout(plots);
                      int columnCount = 0;
                      for (final block in blocks) {
                        for (final row in block.repRows) {
                          if (row.plots.length > columnCount) {
                            columnCount = row.plots.length;
                          }
                        }
                      }
                      const double repLabelW = 52.0;
                      const double tileSpace = 6.0;
                      const double cellW = 56.0;
                      const double gridHorizontalPadding = 24.0;
                      const double gridWidthBuffer = 8.0;
                      final double rowContentWidth = columnCount > 0
                          ? repLabelW +
                              tileSpace +
                              columnCount * cellW +
                              (columnCount - 1) * tileSpace
                          : viewportWidth;
                      final double totalGridWidth = rowContentWidth +
                          gridHorizontalPadding +
                          gridWidthBuffer;
                      final double gridContentWidth =
                          totalGridWidth > viewportWidth
                              ? totalGridWidth
                              : viewportWidth;
                      final plotIdToTreatmentIdMap = {
                        for (var a in assignmentsList) a.plotId: a.treatmentId
                      };
                      final treatmentIdsWithApp = applicationsList
                          .map((e) => e.treatmentId)
                          .whereType<int>()
                          .toSet();
                      final plotPksWithTrialApplication = <int>{};
                      for (final p in plots) {
                        final tid =
                            plotIdToTreatmentIdMap[p.id] ?? p.treatmentId;
                        if (tid != null && treatmentIdsWithApp.contains(tid)) {
                          plotPksWithTrialApplication.add(p.id);
                        }
                      }
                      final scheme = Theme.of(context).colorScheme;
                      final gridW = _layoutGridWidth ?? gridContentWidth;
                      final gridH = _layoutGridHeight ?? (viewportHeight * 0.5);
                      final vw = _layoutViewportWidth ?? viewportWidth;
                      final vh = _layoutViewportHeight ?? viewportHeight;
                      final showRightFade =
                          gridW * _scale > vw && _panDx > vw - gridW * _scale;
                      final showBottomFade =
                          gridH * _scale > vh && _panDy > vh - gridH * _scale;
                      return ClipRect(
                        child: Stack(
                          children: [
                            SizedBox(
                              key: _plotViewportKey,
                              width: viewportWidth,
                              height: viewportHeight,
                              child: InteractiveViewer(
                                transformationController:
                                    _gridTransformController,
                                boundaryMargin: EdgeInsets.zero,
                                constrained: false,
                                minScale: _kGridMinScale,
                                maxScale: _kGridMaxScale,
                                panEnabled: true,
                                scaleEnabled: true,
                                child: SizedBox(
                                  key: _gridContentKey,
                                  width: gridContentWidth,
                                  child: _PlotLayoutGrid(
                                    plots: displayPlots,
                                    plotLabelContextPlots: plots,
                                    treatments: treatments,
                                    trial: widget.trial,
                                    layer: _layoutLayer,
                                    appPlotRecords: _appPlotRecords,
                                    plotPksWithTrialApplication:
                                        plotPksWithTrialApplication,
                                    plotIdToTreatmentId: plotIdToTreatmentIdMap,
                                    onLongPressPlot: plotAssignmentsLocked
                                        ? null
                                        : (plot) =>
                                            _showAssignTreatmentDialogForDetails(
                                                context, ref, plot, plots),
                                  ),
                                ),
                              ),
                            ),
                            if (showRightFade)
                              Positioned(
                                right: 0,
                                top: 0,
                                bottom: 0,
                                width: 32,
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Colors.transparent,
                                          scheme.surface.withValues(alpha: 0.8),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (showBottomFade)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                height: 32,
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          scheme.surface.withValues(alpha: 0.8),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (gridW > 0 && gridH > 0)
                              Positioned(
                                left: 12,
                                bottom: 12,
                                child: _LayoutMinimap(
                                  gridWidth: gridW,
                                  gridHeight: gridH,
                                  viewportWidth: vw,
                                  viewportHeight: vh,
                                  panDx: _panDx,
                                  panDy: _panDy,
                                  scale: _scale,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          )
        else
          Expanded(
              child: _buildPlotsListBodyForDetails(
                  context, ref, displayPlots, plots, hasSessionData)),
      ],
    );
  }

  Widget _buildPanZoomHint(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kPlotLayoutHintDismissedKey, true);
        if (!mounted) return;
        setState(() => _plotLayoutHintDismissed = true);
      },
      behavior: HitTestBehavior.deferToChild,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swipe,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              'Pan to explore · Pinch to zoom',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayerSwitcherForDetails(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SegmentedButton<_LayoutLayer>(
        showSelectedIcon: false,
        style: const ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
          minimumSize: WidgetStatePropertyAll(Size(0, 34)),
        ),
        segments: const [
          ButtonSegment(
              value: _LayoutLayer.treatments,
              label: Text('Treats'),
              icon: Icon(Icons.science, size: 14)),
          ButtonSegment(
              value: _LayoutLayer.applications,
              label: Text('Apps'),
              icon: Icon(Icons.water_drop, size: 14)),
          ButtonSegment(
              value: _LayoutLayer.ratings,
              label: Text('Ratings'),
              icon: Icon(Icons.bar_chart, size: 14)),
        ],
        selected: {_layoutLayer},
        onSelectionChanged: (val) => setState(() => _layoutLayer = val.first),
      ),
    );
  }

  /// Legacy selector for application_events (slot-based). Hidden when empty.
  Widget _buildAppEventSelectorForDetails(BuildContext context, WidgetRef ref) {
    final eventsAsync =
        ref.watch(applicationsForTrialProvider(widget.trial.id));
    return eventsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => AppErrorHint(error: e),
      data: (events) {
        final completed = events.where((e) => e.status == 'completed').toList();
        if (events.isEmpty || completed.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ApplicationEvent>(
                  key: ValueKey<ApplicationEvent?>(_selectedAppEvent),
                  decoration: const InputDecoration(
                    labelText: 'Select Application Event',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  initialValue: _selectedAppEvent == null
                      ? null
                      : completed
                              .where((e) => e.id == _selectedAppEvent!.id)
                              .firstOrNull ??
                          completed.first,
                  items: completed
                      .map((e) => DropdownMenuItem<ApplicationEvent>(
                            value: e,
                            child: Text(
                                'A${e.applicationNumber} — ${e.timingLabel ?? e.method}'),
                          ))
                      .toList(),
                  onChanged: (e) {
                    if (e != null) _loadAppRecords(e);
                  },
                ),
              ),
              if (_loadingAppRecords)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ),
        );
      },
    );
  }

  String _plotsAssignmentDetailLine(
    WidgetRef ref,
    List<Plot> allTrialPlots,
    bool hasSessionData,
  ) {
    final trial = widget.trial;
    final trialIsArmLinked = _armTrialIsLinked(ref);
    final structureLocked =
        !canEditTrialStructure(
      trial,
      hasSessionData: hasSessionData,
      trialIsArmLinked: trialIsArmLinked,
    );
    final assignmentsList =
        ref.watch(assignmentsForTrialProvider(trial.id)).value ?? [];
    final assignmentByPlotId = {for (var a in assignmentsList) a.plotId: a};
    final dataPlots =
        allTrialPlots.where((p) => !p.isGuardRow).toList(growable: false);
    final assignedCount = dataPlots
        .where((p) =>
            (assignmentByPlotId[p.id]?.treatmentId ?? p.treatmentId) != null)
        .length;
    final unassignedCount = dataPlots.length - assignedCount;
    final summaryLine = allTrialPlots.isEmpty
        ? 'No plots'
        : unassignedCount == 0
            ? 'All $assignedCount assigned'
            : '$assignedCount assigned · $unassignedCount unassigned';

    if (structureLocked) {
      _plotsTabLockDebugPrint(trial, hasSessionData, trialIsArmLinked);
      return structureEditBlockedMessage(
        trial,
        hasSessionData: hasSessionData,
        trialIsArmLinked: trialIsArmLinked,
      );
    }
    if (!canEditAssignmentsForTrial(
      trial,
      hasSessionData: hasSessionData,
      trialIsArmLinked: trialIsArmLinked,
    )) {
      return structureEditBlockedMessage(
        trial,
        hasSessionData: hasSessionData,
        trialIsArmLinked: trialIsArmLinked,
      );
    }
    return summaryLine;
  }

  Widget? _buildShowGuardsToggleStrip(BuildContext context, int guardCount) {
    if (guardCount <= 0) return null;
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 4, top: 4, bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Show guards',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Transform.scale(
              scale: 0.9,
              alignment: Alignment.centerRight,
              child: Switch.adaptive(
                value: _showGuardPlots,
                onChanged: (v) {
                  setState(() {
                    _showGuardPlots = v;
                    _gridCenterScheduled = false;
                  });
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// List vs Layout: same flat look as the trial "Setup / Trial Info / Export" bar (no fill, no border).
  Widget _listLayoutViewModeTextButton({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final fg = selected
        ? AppDesignTokens.primary
        : AppDesignTokens.secondaryText;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildListLayoutToggleForDetails(
    BuildContext context,
    WidgetRef ref,
    List<Plot> plotsForBulkAssign,
    bool hasSessionData, {
    required List<Plot> allTrialPlots,
  }) {
    final cs = Theme.of(context).colorScheme;
    final trialIsArmLinked = _armTrialIsLinked(ref);
    final plotAssignmentsLocked =
        plotAssignmentsEditLocked(widget.trial, hasSessionData,
            trialIsArmLinked: trialIsArmLinked);
    final guardCount = allTrialPlots.where((p) => p.isGuardRow).length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _listLayoutViewModeTextButton(
                  selected: !_showLayoutView,
                  icon: Icons.view_list_rounded,
                  label: 'List',
                  onPressed: () => setState(() => _showLayoutView = false),
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: AppDesignTokens.divider,
              ),
              Expanded(
                child: _listLayoutViewModeTextButton(
                  selected: _showLayoutView,
                  icon: Icons.grid_view_rounded,
                  label: 'Layout',
                  onPressed: () => setState(() => _showLayoutView = true),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        if (widget.onTreatmentsShortcut != null)
          IconButton(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              foregroundColor: cs.onSurfaceVariant,
            ),
            tooltip: 'Treatments',
            icon: const Icon(Icons.science_outlined, size: 22),
            onPressed: widget.onTreatmentsShortcut,
          ),
        IconButton(
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            foregroundColor: cs.onSurfaceVariant,
          ),
          icon: const Icon(Icons.fullscreen),
          tooltip: 'Full screen',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => _PlotsFullScreenPage(
                  trial: widget.trial,
                  isLayoutView: _showLayoutView,
                  initialLayoutLayer: _layoutLayer,
                  selectedAppEvent: _selectedAppEvent,
                  appPlotRecords: _appPlotRecords,
                ),
              ),
            );
          },
        ),
        PopupMenuButton<String>(
          tooltip: 'Tools',
          icon: const Icon(Icons.more_vert_rounded, size: 22),
          style: IconButton.styleFrom(
            foregroundColor: cs.onSurfaceVariant,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          onSelected: (value) {
            if (value == 'bulk') {
              _showBulkAssignSheet(
                context,
                ref,
                widget.trial,
                plotsForBulkAssign,
              );
            } else if (value == 'repGuards') {
              _runGenerateRepGuardPlots(context, ref, widget.trial.id);
            } else if (value == 'toggleGuards') {
              setState(() => _showGuardPlots = !_showGuardPlots);
            }
          },
          itemBuilder: (ctx) => [
            if (guardCount > 0)
              CheckedPopupMenuItem<String>(
                value: 'toggleGuards',
                checked: _showGuardPlots,
                child: const Text('Show guard plots'),
              ),
            PopupMenuItem<String>(
              value: 'bulk',
              enabled: !plotAssignmentsLocked,
              child: Row(
                children: [
                  Icon(
                    Icons.grid_view_rounded,
                    size: 20,
                    color: plotAssignmentsLocked
                        ? AppDesignTokens.iconSubtle
                        : AppDesignTokens.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Bulk Assign')),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'repGuards',
              enabled: canEditTrialStructure(
                widget.trial,
                hasSessionData: hasSessionData,
                trialIsArmLinked: trialIsArmLinked,
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_moderator_outlined, size: 20),
                  SizedBox(width: 12),
                  Expanded(child: Text('Add Rep Guards')),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlotsHeaderForDetails(
    BuildContext context,
    WidgetRef ref,
    List<Plot> allTrialPlots,
    bool hasSessionData,
  ) {
    final dataPlots =
        allTrialPlots.where((p) => !p.isGuardRow).toList(growable: false);
    final guardCount = allTrialPlots.length - dataPlots.length;

    final detailLine =
        _plotsAssignmentDetailLine(ref, allTrialPlots, hasSessionData);

    final countTitle = allTrialPlots.isEmpty
        ? 'No plots'
        : guardCount > 0
            ? '${dataPlots.length} data plots · $guardCount guards'
            : '${allTrialPlots.length} plots';

    final guardsControl = _buildShowGuardsToggleStrip(context, guardCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    countTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppDesignTokens.primaryText,
                      letterSpacing: -0.25,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detailLine,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppDesignTokens.secondaryText,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (guardsControl != null) ...[
              const SizedBox(width: 10),
              guardsControl,
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPlotsListBodyForDetails(BuildContext context, WidgetRef ref,
      List<Plot> visiblePlots, List<Plot> allPlots, bool hasSessionData) {
    final trialIsArmLinked = _armTrialIsLinked(ref);
    if (!canEditTrialStructure(
      widget.trial,
      hasSessionData: hasSessionData,
      trialIsArmLinked: trialIsArmLinked,
    )) {
      _plotsTabLockDebugPrint(widget.trial, hasSessionData, trialIsArmLinked);
    }
    final plotAssignmentsLocked =
        plotAssignmentsEditLocked(widget.trial, hasSessionData,
            trialIsArmLinked: trialIsArmLinked);
    final longPressBlockMessage = !canEditTrialStructure(
      widget.trial,
      hasSessionData: hasSessionData,
      trialIsArmLinked: trialIsArmLinked,
    )
        ? structureEditBlockedMessage(
            widget.trial,
            hasSessionData: hasSessionData,
            trialIsArmLinked: trialIsArmLinked,
          )
        : getAssignmentsLockMessage(widget.trial.status, hasSessionData);
    final treatments =
        ref.watch(treatmentsForTrialProvider(widget.trial.id)).value ?? [];
    final treatmentMap = {for (final t in treatments) t.id: t};
    final assignmentsList =
        ref.watch(assignmentsForTrialProvider(widget.trial.id)).value ?? [];
    final assignmentByPlotId = {for (var a in assignmentsList) a.plotId: a};
    return ListView.builder(
      itemCount: visiblePlots.length,
      itemBuilder: (context, index) {
        final plot = visiblePlots[index];
        final assignment = assignmentByPlotId[plot.id];
        final effectiveTreatmentId =
            assignment?.treatmentId ?? plot.treatmentId;
        final effectiveSource =
            assignment?.assignmentSource ?? plot.assignmentSource;
        final displayLabel = getDisplayPlotLabel(plot, allPlots);
        final treatmentLabel = getTreatmentDisplayLabel(plot, treatmentMap,
            treatmentIdOverride: effectiveTreatmentId);
        final sourceLabel = getAssignmentSourceLabel(
            treatmentId: effectiveTreatmentId,
            assignmentSource: effectiveSource);
        final isGuardUnused = plot.isGuardRow && effectiveTreatmentId == null;
        final leadingBg = isGuardUnused
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : AppDesignTokens.primary;
        final leadingFg =
            isGuardUnused ? AppDesignTokens.secondaryText : Colors.white;
        return Container(
          margin: const EdgeInsets.only(
            left: AppDesignTokens.spacing16,
            right: AppDesignTokens.spacing16,
            top: 6,
            bottom: 6,
          ),
          decoration: BoxDecoration(
            color: AppDesignTokens.cardSurface,
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
            border: Border.all(color: AppDesignTokens.borderCrisp),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDesignTokens.spacing16,
              vertical: AppDesignTokens.spacing12,
            ),
            minLeadingWidth: _kPlotListLeadingBadgeSize,
            minVerticalPadding: 6,
            leading: Container(
              width: _kPlotListLeadingBadgeSize,
              height: _kPlotListLeadingBadgeSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: leadingBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                displayLabel,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    color: leadingFg),
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            title: Text(
                plot.isGuardRow
                    ? getGuardRowListTitle(plot)
                    : 'Plot $displayLabel',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isGuardUnused
                        ? AppDesignTokens.secondaryText
                        : AppDesignTokens.primaryText)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          treatmentLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: effectiveTreatmentId != null
                                ? AppDesignTokens.primary
                                : AppDesignTokens.secondaryText,
                            fontWeight: effectiveTreatmentId != null
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (sourceLabel != 'Unknown' &&
                          sourceLabel != 'Unassigned')
                        Text(
                          sourceLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppDesignTokens.secondaryText,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                  if (!plot.isGuardRow && plot.excludeFromAnalysis == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Excluded from analysis',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppDesignTokens.warningFg,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                size: 22, color: AppDesignTokens.iconSubtle),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        PlotDetailScreen(trial: widget.trial, plot: plot))),
            onLongPress: () {
              if (plotAssignmentsLocked) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      longPressBlockMessage.isNotEmpty
                          ? longPressBlockMessage
                          : structureEditBlockedMessage(
                              widget.trial,
                              hasSessionData: hasSessionData,
                              trialIsArmLinked: trialIsArmLinked,
                            ),
                    ),
                  ),
                );
                return;
              }
              _showAssignTreatmentDialogForDetails(
                  context, ref, plot, allPlots);
            },
          ),
        );
      },
    );
  }

  Future<void> _showAssignTreatmentDialogForDetails(
      BuildContext context, WidgetRef ref, Plot plot, List<Plot> plots) async {
    return showAssignTreatmentDialogForTrial(
      trial: widget.trial,
      context: context,
      ref: ref,
      plot: plot,
      plots: plots,
    );
  }

  void _showBulkAssignSheet(
      BuildContext context, WidgetRef ref, Trial trial, List<Plot> plots) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BulkAssignSheet(trial: trial, plots: plots),
    );
  }
}

/// Bottom sheet: Mode 1 — RCBD randomisation; Mode 2 — Manual multi-select.
class _BulkAssignSheet extends ConsumerStatefulWidget {
  const _BulkAssignSheet({required this.trial, required this.plots});

  final Trial trial;
  final List<Plot> plots;

  @override
  ConsumerState<_BulkAssignSheet> createState() => _BulkAssignSheetState();
}

class _BulkAssignSheetState extends ConsumerState<_BulkAssignSheet> {
  bool _showManualSelect = false;
  String? _rcbdError;
  final Set<int> _selectedPlotIds = {};
  int? _selectedTreatmentId;

  @override
  Widget build(BuildContext context) {
    if (_showManualSelect) {
      return _buildManualSelectContent(context);
    }
    return _buildModeChoiceContent(context);
  }

  Widget _buildModeChoiceContent(BuildContext context) {
    final treatments =
        ref.read(treatmentsForTrialProvider(widget.trial.id)).value ?? [];
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.25,
      maxChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(AppDesignTokens.spacing16),
          child: ListView(
            controller: scrollController,
            shrinkWrap: true,
            children: [
              Text(
                'Bulk Assign',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (_rcbdError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Theme.of(context).colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _rcbdError!,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _runRcbdRandomisation(context, treatments),
                icon: const Icon(Icons.shuffle, size: 20),
                label: const Text('Randomise assignments'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showManualSelect = true;
                    _rcbdError = null;
                  });
                },
                icon: const Icon(Icons.checklist_rtl, size: 20),
                label: const Text('Select plots manually'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runRcbdRandomisation(
      BuildContext context, List<Treatment> treatments) async {
    if (treatments.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No treatments defined yet. Add treatments first.')),
      );
      return;
    }
    final blocks = buildRepBasedLayout(widget.plots);
    if (blocks.isEmpty) return;
    int? plotsPerRep;
    for (final block in blocks) {
      for (final repRow in block.repRows) {
        final n = repRow.plots.length;
        if (plotsPerRep != null && n != plotsPerRep) {
          setState(() {
            _rcbdError =
                'Plot count per rep must be equal across all reps for RCBD randomisation.';
          });
          return;
        }
        plotsPerRep = n;
      }
    }
    if (plotsPerRep == null || plotsPerRep != treatments.length) {
      setState(() {
        _rcbdError =
            'Plot count per rep must equal treatment count for RCBD randomisation. Currently $plotsPerRep plots per rep, ${treatments.length} treatments.';
      });
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Overwrite assignments?'),
        content: const Text(
          'This will overwrite all existing assignments. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final treatmentIds = treatments.map((t) => t.id).toList();
    final plotPkToTreatmentId = <int, int?>{};
    for (final block in blocks) {
      for (final repRow in block.repRows) {
        final shuffled = List<int>.from(treatmentIds)
          ..shuffle(Random(repRow.repNumber + widget.trial.id));
        for (var i = 0; i < repRow.plots.length; i++) {
          plotPkToTreatmentId[repRow.plots[i].id] = shuffled[i];
        }
      }
    }
    final useCase = ref.read(updatePlotAssignmentUseCaseProvider);
    final result = await useCase.updateBulk(
      trial: widget.trial,
      plotPkToTreatmentId: plotPkToTreatmentId,
    );
    if (!context.mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Update failed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    ref.invalidate(trialReadinessProvider(widget.trial.id));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Assignments randomised (RCBD)')),
    );
  }

  Widget _buildManualSelectContent(BuildContext context) {
    final treatments =
        ref.read(treatmentsForTrialProvider(widget.trial.id)).value ?? [];
    final assignmentsList =
        ref.read(assignmentsForTrialProvider(widget.trial.id)).value ?? [];
    final assignmentByPlotId = {for (var a in assignmentsList) a.plotId: a};
    final treatmentMap = {for (final t in treatments) t.id: t};
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(AppDesignTokens.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() {
                        _showManualSelect = false;
                        _selectedPlotIds.clear();
                        _selectedTreatmentId = null;
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      'Select plots manually',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: widget.plots.length,
                  itemBuilder: (context, index) {
                    final plot = widget.plots[index];
                    final assignment = assignmentByPlotId[plot.id];
                    final currentId =
                        assignment?.treatmentId ?? plot.treatmentId;
                    final currentCode = currentId != null
                        ? (treatmentMap[currentId]?.code ?? '(removed)')
                        : '—';
                    final selected = _selectedPlotIds.contains(plot.id);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedPlotIds.add(plot.id);
                          } else {
                            _selectedPlotIds.remove(plot.id);
                          }
                        });
                      },
                      title: Text(
                        getDisplayPlotLabel(plot, widget.plots),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        currentCode,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey<int?>(_selectedTreatmentId),
                      initialValue: _selectedTreatmentId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Assign to selected',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('—')),
                        ...treatments.map((t) => DropdownMenuItem<int?>(
                              value: t.id,
                              child: Text('${t.code} — ${t.name}',
                                  overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedTreatmentId = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _applyManualSelection(
                        context, treatments, treatmentMap),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _applyManualSelection(
    BuildContext context,
    List<Treatment> treatments,
    Map<int, Treatment> treatmentMap,
  ) async {
    if (_selectedPlotIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one plot')),
      );
      return;
    }
    if (_selectedTreatmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a treatment')),
      );
      return;
    }
    final assignmentsList =
        ref.read(assignmentsForTrialProvider(widget.trial.id)).value ?? [];
    final assignmentByPlotId = {for (var a in assignmentsList) a.plotId: a};
    final plotById = {for (final p in widget.plots) p.id: p};
    final anyHasExistingAssignment = _selectedPlotIds.any((id) {
      final assignment = assignmentByPlotId[id];
      final plot = plotById[id];
      final effectiveTreatmentId = assignment?.treatmentId ?? plot?.treatmentId;
      return effectiveTreatmentId != null;
    });
    if (anyHasExistingAssignment) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Overwrite assignments?'),
          content: const Text(
            'One or more selected plots already have assignments. These will be overwritten. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (confirm != true || !context.mounted) return;
    }
    final plotPkToTreatmentId = {
      for (final id in _selectedPlotIds) id: _selectedTreatmentId
    };
    final useCase = ref.read(updatePlotAssignmentUseCaseProvider);
    final result = await useCase.updateBulk(
      trial: widget.trial,
      plotPkToTreatmentId: plotPkToTreatmentId,
    );
    if (!context.mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Update failed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final code = treatmentMap[_selectedTreatmentId]?.code ??
        (_selectedTreatmentId != null ? '(removed)' : '?');
    ref.invalidate(trialReadinessProvider(widget.trial.id));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('${_selectedPlotIds.length} plots assigned to $code')),
    );
  }
}

/// Empty state for PlotDetailsScreen when trial has no plots.
class _PlotDetailsEmptyContent extends ConsumerWidget {
  final Trial trial;

  const _PlotDetailsEmptyContent({required this.trial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSessionData =
        ref.watch(trialHasSessionDataProvider(trial.id)).valueOrNull ?? false;
    final trialIsArmLinked =
        ref.watch(armTrialMetadataStreamProvider(trial.id)).valueOrNull?.isArmLinked ==
            true;
    final canEditStructure =
        canEditTrialStructure(
      trial,
      hasSessionData: hasSessionData,
      trialIsArmLinked: trialIsArmLinked,
    );
    final treatmentsAsync = ref.watch(treatmentsForTrialProvider(trial.id));
    final treatmentCount = treatmentsAsync.value?.length ?? 0;
    final String subtitle;
    if (!canEditStructure) {
      _plotsTabLockDebugPrint(trial, hasSessionData, trialIsArmLinked);
      subtitle = structureEditBlockedMessage(
        trial,
        hasSessionData: hasSessionData,
        trialIsArmLinked: trialIsArmLinked,
      );
    } else if (isStandalone(trial.workspaceType)) {
      subtitle =
          '${trialTypeAndStructureCompactLine(trial, hasSessionData: hasSessionData, trialIsArmLinked: trialIsArmLinked)}. Open Trial Setup to configure site details, or use the actions below to build your plot layout.';
    } else {
      subtitle =
          '${trialTypeAndStructureCompactLine(trial, hasSessionData: hasSessionData, trialIsArmLinked: trialIsArmLinked)}. Import plots via CSV.';
    }
    final extra = canEditStructure
        ? _standalonePlotsEmptyExtra(
            context,
            ref,
            trial,
            treatmentCount,
          )
        : null;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppEmptyState(
          icon: Icons.grid_on,
          title: 'No Plots Yet',
          subtitle: subtitle,
        ),
        if (extra != null) ...[
          const SizedBox(height: 24),
          extra,
        ],
      ],
    );
  }
}

/// Bird's-eye grid: plot position (layout number) and treatment assignment are separate.
/// Order is always by rep and plot position; never by treatment.
class _PlotLayoutGrid extends StatelessWidget {
  final List<Plot> plots;

  /// Full trial plot list for stable display labels when [plots] is a filtered subset.
  final List<Plot>? plotLabelContextPlots;
  final List<Treatment> treatments;
  final Trial trial;
  final _LayoutLayer layer;
  final List<ApplicationPlotRecord> appPlotRecords;

  /// For Applications layer v1: plot ids whose assigned treatment has at least one application event.
  final Set<int>? plotPksWithTrialApplication;
  final Map<int, int?>? plotIdToTreatmentId;
  final void Function(Plot plot)? onLongPressPlot;

  const _PlotLayoutGrid({
    required this.plots,
    this.plotLabelContextPlots,
    required this.treatments,
    required this.trial,
    required this.layer,
    required this.appPlotRecords,
    this.plotPksWithTrialApplication,
    this.plotIdToTreatmentId,
    this.onLongPressPlot,
  });

  Widget _legendChip(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: _kPlotLayoutLegendSwatch,
          height: _kPlotLayoutLegendSwatch,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppDesignTokens.primaryText,
            ),
          ),
        ),
      ],
    );
  }

  Color _tileColorFor(BuildContext context, Plot plot) {
    final effectiveTid = plotIdToTreatmentId?[plot.id] ?? plot.treatmentId;
    if (plot.isGuardRow && effectiveTid == null) {
      return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
    if (layer == _LayoutLayer.applications) {
      // v1 model: green = treatment has application, grey = unassigned, else treatment color.
      if (plotPksWithTrialApplication != null) {
        if (effectiveTid == null) return AppDesignTokens.unassignedColor;
        if (plotPksWithTrialApplication!.contains(plot.id)) {
          return AppDesignTokens.appliedColor;
        }
        final treatmentIndex =
            treatments.indexWhere((t) => t.id == effectiveTid);
        return treatmentIndex >= 0
            ? AppDesignTokens.treatmentPalette[
                treatmentIndex % AppDesignTokens.treatmentPalette.length]
            : AppDesignTokens.unassignedColor;
      }
      final record =
          appPlotRecords.where((r) => r.plotPk == plot.id).firstOrNull;
      if (record == null) return AppDesignTokens.noRecordColor;
      if (record.status == 'applied') return AppDesignTokens.appliedColor;
      if (record.status == 'skipped') return AppDesignTokens.skippedColor;
      if (record.status == 'missed') return AppDesignTokens.missedColor;
      return AppDesignTokens.noRecordColor;
    }
    if (effectiveTid == null) return AppDesignTokens.unassignedColor;
    final treatmentIndex = treatments.indexWhere((t) => t.id == effectiveTid);
    return treatmentIndex >= 0
        ? AppDesignTokens.treatmentPalette[
            treatmentIndex % AppDesignTokens.treatmentPalette.length]
        : AppDesignTokens.unassignedColor;
  }

  @override
  Widget build(BuildContext context) {
    final treatmentMap = {for (final t in treatments) t.id: t};
    final gridWidget = plots.isEmpty
        ? const SizedBox.shrink()
        : _buildRepBasedGrid(context, treatmentMap);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        gridWidget,
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: DecoratedBox(
            decoration: _plotLayoutLegendPanelDecoration(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: layer == _LayoutLayer.applications
                  ? Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: plotPksWithTrialApplication != null
                          ? [
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 150),
                                child: _legendChip(
                                  context,
                                  AppDesignTokens.appliedColor,
                                  'Applied',
                                ),
                              ),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 150),
                                child: _legendChip(
                                  context,
                                  AppDesignTokens.unassignedColor,
                                  'Unassigned',
                                ),
                              ),
                            ]
                          : [
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 150),
                                child: _legendChip(
                                  context,
                                  AppDesignTokens.appliedColor,
                                  'Applied',
                                ),
                              ),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 150),
                                child: _legendChip(
                                  context,
                                  AppDesignTokens.skippedColor,
                                  'Skipped',
                                ),
                              ),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 150),
                                child: _legendChip(
                                  context,
                                  AppDesignTokens.missedColor,
                                  'Missed',
                                ),
                              ),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 150),
                                child: _legendChip(
                                  context,
                                  AppDesignTokens.noRecordColor,
                                  'No record',
                                ),
                              ),
                            ],
                    )
                  : Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ...treatments.asMap().entries.map((entry) {
                          final color = AppDesignTokens.treatmentPalette[
                              entry.key %
                                  AppDesignTokens.treatmentPalette.length];
                          return ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: _compactTreatmentLegendLine(
                              context,
                              color,
                              entry.value.code,
                              entry.value.name,
                              entry.value.description,
                            ),
                          );
                        }),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: _legendChip(
                            context,
                            AppDesignTokens.unassignedColor,
                            'Unassigned',
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  static const double _tileSpacing = 6.0;
  // ignore: unused_field - kept for consistency with fixed 56px cell size
  static const double _minTileSize = 56.0;
  // ignore: unused_field - kept for consistency with fixed 56px cell size
  static const double _maxTileSize = 56.0;
  // ignore: unused_field - kept for consistency with fixed 56px cell size
  static const double _tileSizeScale = 1.0;
  static const double _minCellSize = 56.0;
  // ignore: unused_field - kept for consistency with fixed 56px cell size
  static const double _maxCellSize = 56.0;

  Widget _buildRepBasedGrid(
      BuildContext context, Map<int, Treatment> treatmentMap) {
    final labelPlots = plotLabelContextPlots ?? plots;
    final blocks = buildRepBasedLayout(plots);
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0;
        final contentHeight =
            hasBoundedHeight ? constraints.maxHeight - 16 : null;
        final column = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (blocks.length > 1)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Field Layout — Rep-based',
                  style: TextStyle(
                      color: AppDesignTokens.secondaryText, fontSize: 11),
                ),
              ),
            ...blocks.expand((block) {
              final blockHeader = blocks.length > 1
                  ? [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          'Block ${block.blockIndex}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ]
                  : <Widget>[];
              final repRows = block.repRows.reversed.map((repRow) {
                const cellSize = _minCellSize;
                const rowHeight = _minCellSize + 2;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    height: rowHeight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: _kRepLabelWidth,
                          height: rowHeight,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Rep ${repRow.repNumber}',
                              style: _plotDetailsRepLabelStyle(context),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: _tileSpacing),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < repRow.plots.length; i++) ...[
                              if (i > 0) const SizedBox(width: _tileSpacing),
                              SizedBox(
                                width: cellSize,
                                height: cellSize,
                                child: _PlotGridTile(
                                  plot: repRow.plots[i],
                                  treatmentMap: treatmentMap,
                                  treatments: treatments,
                                  trial: trial,
                                  tileColor:
                                      _tileColorFor(context, repRow.plots[i]),
                                  treatmentIdOverride: plotIdToTreatmentId?[
                                          repRow.plots[i].id] ??
                                      repRow.plots[i].treatmentId,
                                  displayLabel: getDisplayPlotLabel(
                                      repRow.plots[i], labelPlots),
                                  onLongPress: onLongPressPlot != null
                                      ? () => onLongPressPlot!(repRow.plots[i])
                                      : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              });
              return [...blockHeader, ...repRows];
            }),
          ],
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: contentHeight != null && contentHeight > 0
              ? SizedBox(
                  height: contentHeight,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    clipBehavior: Clip.hardEdge,
                    child: column,
                  ),
                )
              : column,
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.sub});

  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppDesignTokens.primaryText,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          sub,
          style: const TextStyle(
            fontSize: 10,
            color: AppDesignTokens.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _PlotGridTile extends StatefulWidget {
  final Plot plot;
  final Map<int, Treatment> treatmentMap;
  final List<Treatment> treatments;
  final Trial trial;
  final Color tileColor;
  final int? treatmentIdOverride;
  final String? displayLabel;
  final VoidCallback? onLongPress;

  const _PlotGridTile({
    required this.plot,
    required this.treatmentMap,
    required this.treatments,
    required this.trial,
    required this.tileColor,
    this.treatmentIdOverride,
    this.displayLabel,
    this.onLongPress,
  });

  @override
  State<_PlotGridTile> createState() => _PlotGridTileState();
}

class _PlotGridTileState extends State<_PlotGridTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final plot = widget.plot;
    final effectiveTid = widget.treatmentIdOverride ?? plot.treatmentId;
    final treatment =
        effectiveTid != null ? widget.treatmentMap[effectiveTid] : null;
    final label = widget.displayLabel ?? plot.plotId;
    final isGuardUnused = plot.isGuardRow && effectiveTid == null;
    final labelColor =
        isGuardUnused ? AppDesignTokens.secondaryText : Colors.white;
    final subColor = isGuardUnused
        ? AppDesignTokens.secondaryText.withValues(alpha: 0.8)
        : Colors.white.withValues(alpha: 0.85);
    final borderColor = isGuardUnused
        ? AppDesignTokens.borderCrisp
        : Colors.white.withValues(alpha: 0.2);
    final scheme = Theme.of(context).colorScheme;
    final pressedBorderColor = scheme.primary.withValues(alpha: 0.55);
    return Container(
      decoration: BoxDecoration(
        color: widget.tileColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _pressed ? pressedBorderColor : borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _pressed ? 0.2 : 0.12),
            blurRadius: _pressed ? 8 : 4,
            offset: Offset(0, _pressed ? 3 : 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onHighlightChanged: (highlighted) {
            setState(() => _pressed = highlighted);
          },
          onLongPress: widget.onLongPress,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlotDetailScreen(trial: widget.trial, plot: plot),
            ),
          ),
          splashColor: Colors.white.withValues(alpha: 0.2),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            width: double.infinity,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
                Text(
                  treatment != null
                      ? treatment.code
                      : (effectiveTid != null ? '(removed)' : ''),
                  style: TextStyle(
                    color: subColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen page for Plots list or layout (opened from List/Layout toggle button).
class _PlotsFullScreenPage extends ConsumerStatefulWidget {
  final Trial trial;
  final bool isLayoutView;
  final _LayoutLayer initialLayoutLayer;
  final ApplicationEvent? selectedAppEvent;
  final List<ApplicationPlotRecord> appPlotRecords;

  const _PlotsFullScreenPage({
    required this.trial,
    required this.isLayoutView,
    required this.initialLayoutLayer,
    this.selectedAppEvent,
    this.appPlotRecords = const [],
  });

  @override
  ConsumerState<_PlotsFullScreenPage> createState() =>
      _PlotsFullScreenPageState();
}

class _PlotsFullScreenPageState extends ConsumerState<_PlotsFullScreenPage> {
  bool _armTrialIsLinked(WidgetRef ref) =>
      ref.watch(armTrialMetadataStreamProvider(widget.trial.id)).valueOrNull?.isArmLinked ==
          true;

  late _LayoutLayer _layoutLayer;
  ApplicationEvent? _selectedAppEvent;
  Session? _selectedRatingSession;
  bool _heatMapEnabled = false;
  List<ApplicationPlotRecord> _appPlotRecords = [];
  bool _loadingAppRecords = false;
  final TransformationController _gridTransformController =
      TransformationController();
  final GlobalKey _plotViewportKey = GlobalKey();
  final GlobalKey _gridContentKey = GlobalKey();
  bool _gridCenterScheduled = false;
  bool _showGuardPlots = false;

  List<Plot> _plotsVisibleInPlotsTab(List<Plot> all) => _showGuardPlots
      ? List<Plot>.from(all)
      : all.where((p) => !p.isGuardRow).toList();

  @override
  void initState() {
    super.initState();
    _layoutLayer = widget.initialLayoutLayer;
    _selectedAppEvent = widget.selectedAppEvent;
    _appPlotRecords = List.from(widget.appPlotRecords);
  }

  @override
  void dispose() {
    _gridTransformController.dispose();
    super.dispose();
  }

  void _centerGridOnFirstFrame(BuildContext context, List<Plot> plots) {
    if (!mounted) return;
    final viewportBox =
        _plotViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize) return;
    final viewportWidth = viewportBox.size.width;
    final viewportHeight = viewportBox.size.height;
    final gridBox =
        _gridContentKey.currentContext?.findRenderObject() as RenderBox?;
    double gridWidth;
    double gridHeight;
    if (gridBox != null && gridBox.hasSize) {
      gridWidth = gridBox.size.width;
      gridHeight = gridBox.size.height;
    } else {
      final blocks = buildRepBasedLayout(plots);
      int columnCount = 0;
      int rowCount = 0;
      for (final block in blocks) {
        for (final row in block.repRows) {
          if (row.plots.length > columnCount) columnCount = row.plots.length;
          rowCount++;
        }
      }
      if (columnCount == 0) return;
      const double cellWidth = 56.0;
      const double rowHeight = 58.0;
      const double rowSpacing = 6.0;
      gridWidth = columnCount * cellWidth;
      gridHeight = rowCount * (rowHeight + rowSpacing) + 24;
    }
    final dx = (viewportWidth - gridWidth) / 2;
    final dy = (viewportHeight - gridHeight) / 2;
    final dxClamped = dx > 0 ? dx : 0.0;
    final dyClamped = dy > 0 ? dy : 0.0;
    _gridTransformController.value = Matrix4.identity()
      ..translateByDouble(dxClamped, dyClamped, 0.0, 1.0);
  }

  Future<void> _loadAppRecords(ApplicationEvent event) async {
    setState(() {
      _selectedAppEvent = event;
      _loadingAppRecords = true;
    });
    final repo = ref.read(applicationRepositoryProvider);
    final records = await repo.getPlotRecordsForEvent(event.id);
    if (mounted) {
      setState(() {
        _appPlotRecords = records;
        _loadingAppRecords = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trial = widget.trial;
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final hasSessionDataAsync =
        ref.watch(trialHasSessionDataProvider(trial.id));
    final sessionsAsync = ref.watch(sessionsForTrialProvider(trial.id));
    final treatmentsAsync = ref.watch(treatmentsForTrialProvider(trial.id));
    final assignmentsAsync = ref.watch(assignmentsForTrialProvider(trial.id));
    final trialApplicationsAsync =
        ref.watch(trialApplicationsForTrialProvider(trial.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isLayoutView ? 'Plots — Layout' : 'Plots — List'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
          top: false,
          child: plotsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (plots) {
              if (plots.isEmpty) {
                return _PlotDetailsEmptyContent(trial: widget.trial);
              }
              final hasSessionData = hasSessionDataAsync.valueOrNull ?? false;
              final trialIsArmLinked = _armTrialIsLinked(ref);
              final plotAssignmentsLocked =
                  plotAssignmentsEditLocked(widget.trial, hasSessionData,
                      trialIsArmLinked: trialIsArmLinked);
              final sessions = sessionsAsync.value ?? [];
              final guardCount = plots.where((p) => p.isGuardRow).length;
              final displayPlots = _plotsVisibleInPlotsTab(plots);
              if (!widget.isLayoutView) {
                final scheme = Theme.of(context).colorScheme;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (guardCount > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Show guards',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            Switch.adaptive(
                              value: _showGuardPlots,
                              onChanged: (v) =>
                                  setState(() => _showGuardPlots = v),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ),
                    _buildAddRepGuardsRow(context, ref, widget.trial),
                    Expanded(
                      child: _buildListBody(
                        context,
                        ref,
                        displayPlots,
                        plots,
                        hasSessionData,
                        treatments: treatmentsAsync.value ?? [],
                        assignmentsList: assignmentsAsync.value ?? [],
                      ),
                    ),
                  ],
                );
              }
              final treatments = treatmentsAsync.value ?? [];
              final assignments = assignmentsAsync.value ?? [];
              final Map<int, int?> plotIdToTreatmentId = {
                for (final a in assignments) a.plotId: a.treatmentId
              };
              const double maxTopHeight = 240;
              final scheme = Theme.of(context).colorScheme;
              final topSection = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (guardCount > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Show guards',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: _showGuardPlots,
                            onChanged: (v) {
                              setState(() {
                                _showGuardPlots = v;
                                _gridCenterScheduled = false;
                              });
                            },
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  _buildAddRepGuardsRow(context, ref, widget.trial),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: SegmentedButton<_LayoutLayer>(
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(
                            value: _LayoutLayer.treatments,
                            label: Text('Treats'),
                            icon: Icon(Icons.science, size: 14)),
                        ButtonSegment(
                            value: _LayoutLayer.applications,
                            label: Text('Apps'),
                            icon: Icon(Icons.water_drop, size: 14)),
                        ButtonSegment(
                            value: _LayoutLayer.ratings,
                            label: Text('Ratings'),
                            icon: Icon(Icons.bar_chart, size: 14)),
                      ],
                      selected: {_layoutLayer},
                      onSelectionChanged: (val) =>
                          setState(() => _layoutLayer = val.first),
                    ),
                  ),
                  if (_layoutLayer == _LayoutLayer.applications)
                    _buildAppEventSelector(context, ref),
                ],
              );
              return Column(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: maxTopHeight),
                    child: SingleChildScrollView(
                      child: topSection,
                    ),
                  ),
                  Expanded(
                    child: _layoutLayer == _LayoutLayer.ratings
                        ? _buildRatingsOverlay(
                            context: context,
                            ref: ref,
                            trial: widget.trial,
                            plots: displayPlots,
                            sessions: sessions,
                            selectedRatingSession: _selectedRatingSession,
                            onSessionChanged: (s) =>
                                setState(() => _selectedRatingSession = s),
                            heatMapEnabled: _heatMapEnabled,
                            onHeatMapToggled: (v) =>
                                setState(() => _heatMapEnabled = v),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              if (!_gridCenterScheduled) {
                                _gridCenterScheduled = true;
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  _centerGridOnFirstFrame(
                                      context, displayPlots);
                                });
                              }
                              final size = MediaQuery.sizeOf(context);
                              final viewportWidth =
                                  constraints.maxWidth.isFinite &&
                                          constraints.maxWidth > 0
                                      ? constraints.maxWidth
                                      : size.width;
                              final viewportHeight =
                                  constraints.maxHeight.isFinite &&
                                          constraints.maxHeight > 0
                                      ? constraints.maxHeight
                                      : size.height;
                              final blocks = buildRepBasedLayout(displayPlots);
                              int columnCount = 0;
                              for (final block in blocks) {
                                for (final row in block.repRows) {
                                  if (row.plots.length > columnCount) {
                                    columnCount = row.plots.length;
                                  }
                                }
                              }
                              const double repLabelW = 52.0;
                              const double tileSpace = 6.0;
                              const double cellW = 56.0;
                              const double gridHorizontalPadding =
                                  24.0; // 12 + 12 from Padding in _buildRepBasedGrid
                              const double gridWidthBuffer =
                                  8.0; // avoid last column clipping from rounding
                              final double rowContentWidth = columnCount > 0
                                  ? repLabelW +
                                      tileSpace +
                                      columnCount * cellW +
                                      (columnCount - 1) * tileSpace
                                  : viewportWidth;
                              final double totalGridWidth = rowContentWidth +
                                  gridHorizontalPadding +
                                  gridWidthBuffer;
                              final double gridContentWidth =
                                  totalGridWidth > viewportWidth
                                      ? totalGridWidth
                                      : viewportWidth;
                              final applicationsList =
                                  trialApplicationsAsync.value ?? [];
                              final treatmentIdsWithApp = applicationsList
                                  .map((e) => e.treatmentId)
                                  .whereType<int>()
                                  .toSet();
                              final plotPksWithTrialApplication = <int>{};
                              for (final p in displayPlots) {
                                final tid =
                                    plotIdToTreatmentId[p.id] ?? p.treatmentId;
                                if (tid != null &&
                                    treatmentIdsWithApp.contains(tid)) {
                                  plotPksWithTrialApplication.add(p.id);
                                }
                              }
                              return ClipRect(
                                child: Stack(
                                  children: [
                                    SizedBox(
                                      key: _plotViewportKey,
                                      width: viewportWidth,
                                      height: viewportHeight,
                                      child: InteractiveViewer(
                                        transformationController:
                                            _gridTransformController,
                                        boundaryMargin: EdgeInsets.zero,
                                        constrained: false,
                                        minScale: _kGridMinScale,
                                        maxScale: _kGridMaxScale,
                                        panEnabled: true,
                                        scaleEnabled: true,
                                        child: SizedBox(
                                          key: _gridContentKey,
                                          width: gridContentWidth,
                                          child: _PlotLayoutGrid(
                                            plots: displayPlots,
                                            plotLabelContextPlots: plots,
                                            treatments: treatments,
                                            trial: widget.trial,
                                            layer: _layoutLayer,
                                            appPlotRecords: _appPlotRecords,
                                            plotPksWithTrialApplication:
                                                plotPksWithTrialApplication,
                                            plotIdToTreatmentId:
                                                plotIdToTreatmentId,
                                            onLongPressPlot:
                                                plotAssignmentsLocked
                                                    ? null
                                                    : (plot) =>
                                                        _showAssignDialog(
                                                            context,
                                                            ref,
                                                            plot,
                                                            plots),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          )),
    );
  }

  /// Legacy selector for application_events (slot-based). Hidden when empty.
  Widget _buildAppEventSelector(BuildContext context, WidgetRef ref) {
    final eventsAsync =
        ref.watch(applicationsForTrialProvider(widget.trial.id));
    return eventsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => AppErrorHint(error: e),
      data: (events) {
        final completed = events.where((e) => e.status == 'completed').toList();
        if (events.isEmpty || completed.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ApplicationEvent>(
                  key: ValueKey<ApplicationEvent?>(_selectedAppEvent),
                  decoration: const InputDecoration(
                    labelText: 'Select Application Event',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  initialValue: _selectedAppEvent == null
                      ? null
                      : completed
                              .where((e) => e.id == _selectedAppEvent!.id)
                              .firstOrNull ??
                          completed.first,
                  items: completed
                      .map((e) => DropdownMenuItem<ApplicationEvent>(
                            value: e,
                            child: Text(
                                'A${e.applicationNumber} — ${e.timingLabel ?? e.method}'),
                          ))
                      .toList(),
                  onChanged: (e) {
                    if (e != null) _loadAppRecords(e);
                  },
                ),
              ),
              if (_loadingAppRecords)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListBody(
    BuildContext context,
    WidgetRef ref,
    List<Plot> visiblePlots,
    List<Plot> allPlots,
    bool hasSessionData, {
    required List<Treatment> treatments,
    required List<Assignment> assignmentsList,
  }) {
    final trialIsArmLinked = _armTrialIsLinked(ref);
    if (!canEditTrialStructure(
      widget.trial,
      hasSessionData: hasSessionData,
      trialIsArmLinked: trialIsArmLinked,
    )) {
      _plotsTabLockDebugPrint(widget.trial, hasSessionData, trialIsArmLinked);
    }
    final plotAssignmentsLocked =
        plotAssignmentsEditLocked(widget.trial, hasSessionData,
            trialIsArmLinked: trialIsArmLinked);
    final longPressBlockMessage = !canEditTrialStructure(
      widget.trial,
      hasSessionData: hasSessionData,
      trialIsArmLinked: trialIsArmLinked,
    )
        ? structureEditBlockedMessage(
            widget.trial,
            hasSessionData: hasSessionData,
            trialIsArmLinked: trialIsArmLinked,
          )
        : getAssignmentsLockMessage(widget.trial.status, hasSessionData);
    final treatmentMap = {for (final t in treatments) t.id: t};
    final assignmentByPlotId = {for (var a in assignmentsList) a.plotId: a};
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: visiblePlots.length,
      itemBuilder: (context, index) {
        final plot = visiblePlots[index];
        final assignment = assignmentByPlotId[plot.id];
        final effectiveTreatmentId =
            assignment?.treatmentId ?? plot.treatmentId;
        final effectiveSource =
            assignment?.assignmentSource ?? plot.assignmentSource;
        final displayLabel = getDisplayPlotLabel(plot, allPlots);
        final treatmentLabel = getTreatmentDisplayLabel(plot, treatmentMap,
            treatmentIdOverride: effectiveTreatmentId);
        final sourceLabel = getAssignmentSourceLabel(
            treatmentId: effectiveTreatmentId,
            assignmentSource: effectiveSource);
        final isGuardUnused = plot.isGuardRow && effectiveTreatmentId == null;
        final leadingBg = isGuardUnused
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.primary;
        final leadingFg =
            isGuardUnused ? AppDesignTokens.secondaryText : Colors.white;
        return AppCard(
          margin: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDesignTokens.spacing16,
                vertical: AppDesignTokens.spacing12),
            dense: true,
            minLeadingWidth: _kPlotListLeadingBadgeSize,
            leading: Container(
              width: _kPlotListLeadingBadgeSize,
              height: _kPlotListLeadingBadgeSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: leadingBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                displayLabel,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: plot.isGuardRow ? 9 : 10,
                    color: leadingFg),
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            title: Text(
                plot.isGuardRow
                    ? getGuardRowListTitle(plot)
                    : 'Plot $displayLabel',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color:
                        isGuardUnused ? AppDesignTokens.secondaryText : null)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        treatmentLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: effectiveTreatmentId != null
                              ? Theme.of(context).colorScheme.primary
                              : AppDesignTokens.secondaryText,
                          fontWeight: effectiveTreatmentId != null
                              ? FontWeight.w600
                              : null,
                        ),
                      ),
                    ),
                    if (sourceLabel != 'Unknown' && sourceLabel != 'Unassigned')
                      Text(sourceLabel,
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppDesignTokens.secondaryText,
                              fontStyle: FontStyle.italic)),
                  ],
                ),
                if (!plot.isGuardRow && plot.excludeFromAnalysis == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Excluded from analysis',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppDesignTokens.warningFg,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      PlotDetailScreen(trial: widget.trial, plot: plot)),
            ),
            onLongPress: () {
              if (plotAssignmentsLocked) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      longPressBlockMessage.isNotEmpty
                          ? longPressBlockMessage
                          : structureEditBlockedMessage(
                              widget.trial,
                              hasSessionData: hasSessionData,
                              trialIsArmLinked: trialIsArmLinked,
                            ),
                    ),
                  ),
                );
                return;
              }
              _showAssignDialog(context, ref, plot, allPlots);
            },
          ),
        );
      },
    );
  }

  Future<void> _showAssignDialog(
      BuildContext context, WidgetRef ref, Plot plot, List<Plot> plots) async {
    return showAssignTreatmentDialogForTrial(
      trial: widget.trial,
      context: context,
      ref: ref,
      plot: plot,
      plots: plots,
    );
  }
}
