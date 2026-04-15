import 'dart:math' show sqrt;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/plot_display.dart';
import '../../core/ui/assessment_display_helper.dart';
import '../../core/edit_recency_display.dart';
import '../../core/plot_sort.dart';
import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../../core/widgets/loading_error_widgets.dart';
import '../../shared/widgets/app_card.dart';
import '../diagnostics/edited_items_screen.dart';
import '../plots/plot_queue_screen.dart';
import '../ratings/rating_screen.dart';
import 'domain/session_completeness_report.dart';
import 'session_completeness_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backup/backup_reminder_store.dart';
import 'session_data_grid.dart';
import 'session_summary_assessment_coverage.dart';
import 'session_treatment_summary.dart';

/// Bottom sheet showing full rating context for a tapped grid cell.
void _showCellDetailSheet({
  required BuildContext context,
  required Plot plot,
  required Assessment assessment,
  required RatingRecord? rating,
  required List<Plot> allPlots,
  required List<Assessment> assessments,
  required String assessmentDisplayName,
  String? treatmentLabel,
  VoidCallback? onGoToRating,
}) {
  final scheme = Theme.of(context).colorScheme;
  final plotLabel = getDisplayPlotLabel(plot, allPlots);
  final hasRating = rating != null && rating.resultStatus == 'RECORDED';

  String valueText;
  if (rating == null) {
    valueText = 'Not rated';
  } else if (rating.resultStatus == 'VOID') {
    valueText = 'VOID';
  } else if (rating.resultStatus != 'RECORDED') {
    valueText = _statusLabel(rating.resultStatus);
  } else {
    valueText = rating.numericValue != null
        ? _formatRatingValue(rating.numericValue!)
        : (rating.textValue ?? '—');
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title: Plot × Assessment
            Text(
              'Plot $plotLabel  ·  $assessmentDisplayName',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            // Value
            _DetailRow(label: 'Value', value: valueText),
            if (hasRating && rating.confidence != null)
              _DetailRow(label: 'Confidence', value: rating.confidence!),
            if (hasRating && rating.ratingMethod != null)
              _DetailRow(label: 'Method', value: rating.ratingMethod!),
            if (plot.rep != null)
              _DetailRow(label: 'Rep', value: plot.rep.toString()),
            if (treatmentLabel != null)
              _DetailRow(label: 'Treatment', value: treatmentLabel),
            if (hasRating && rating.raterName != null)
              _DetailRow(label: 'Rater', value: rating.raterName!),
            if (hasRating)
              _DetailRow(
                label: 'Time',
                value: rating.ratingTime ??
                    DateFormat.yMd().add_Hm().format(rating.createdAt),
              ),
            if (rating != null && (rating.amended || rating.previousId != null))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.edit_note,
                        size: 16, color: Colors.blueGrey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'Edited — long-press cell for history',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // Go to Rating button
            if (onGoToRating != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onGoToRating();
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Go to Rating'),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

String _statusLabel(String status) => switch (status) {
      'NOT_OBSERVED' => 'Not observed',
      'NOT_APPLICABLE' => 'Not applicable',
      'MISSING_CONDITION' => 'Missing condition',
      'TECHNICAL_ISSUE' => 'Technical issue',
      _ => status.replaceAll('_', ' ').toLowerCase(),
    };

String _formatRatingValue(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

void _navigatePlotQueue(
  BuildContext context,
  Trial trial,
  Session session, [
  PlotQueueInitialFilters? initialFilters,
]) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => PlotQueueScreen(
        trial: trial,
        session: session,
        initialFilters: initialFilters,
      ),
    ),
  );
}

void _navigateSessionCompleteness(
    BuildContext context, Trial trial, Session session) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => SessionCompletenessScreen(trial: trial, session: session),
    ),
  );
}

const int _kSessionSummaryMaxCompletenessIssuesPreview = 5;

/// Blockers first, then warnings; capped with optional "see all" link.
List<Widget> _completenessIssuePreviewRows({
  required BuildContext context,
  required int trialId,
  required int sessionId,
  required List<SessionCompletenessIssue> issues,
  required VoidCallback onSeeAll,
}) {
  final ordered = <SessionCompletenessIssue>[
    ...issues.where((i) =>
        i.severity == SessionCompletenessIssueSeverity.blocker),
    ...issues.where((i) =>
        i.severity == SessionCompletenessIssueSeverity.warning),
  ];
  if (ordered.isEmpty) return const [];

  final preview =
      ordered.take(_kSessionSummaryMaxCompletenessIssuesPreview).toList();
  final out = <Widget>[
    const SizedBox(height: AppDesignTokens.spacing12),
    Text(
      'Completeness Issues',
      style: AppDesignTokens.headingStyle(
        fontSize: 14,
        color: AppDesignTokens.primaryText,
      ),
    ),
  ];
  for (final issue in preview) {
    final isBlocker =
        issue.severity == SessionCompletenessIssueSeverity.blocker;
    final message = issue
        .toDiagnosticFinding(trialId: trialId, sessionId: sessionId)
        .message;
    out.add(
      Padding(
        padding: const EdgeInsets.only(top: AppDesignTokens.spacing8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 10),
              child: Icon(
                Icons.fiber_manual_record,
                size: 12,
                color: isBlocker
                    ? AppDesignTokens.missedColor
                    : AppDesignTokens.warningFg,
              ),
            ),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  if (ordered.length > _kSessionSummaryMaxCompletenessIssuesPreview) {
    out.add(
      Padding(
        padding: const EdgeInsets.only(top: AppDesignTokens.spacing8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onSeeAll,
            child: const Text('See All in Session Completeness'),
          ),
        ),
      ),
    );
  }
  return out;
}

/// Session data view — toggles between full-screen data grid and detail cards.
class SessionSummaryScreen extends ConsumerStatefulWidget {
  const SessionSummaryScreen({
    super.key,
    required this.trial,
    required this.session,
  });

  final Trial trial;
  final Session session;

  @override
  ConsumerState<SessionSummaryScreen> createState() =>
      _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  bool _isClosing = false;
  /// false = plots grid (default), true = treatment summary
  bool _showTreatments = false;

  void _invalidate() {
    ref.invalidate(plotsForTrialProvider(widget.trial.id));
    ref.invalidate(sessionRatingsProvider(widget.session.id));
    ref.invalidate(ratedPlotPksProvider(widget.session.id));
    ref.invalidate(sessionCompletenessReportProvider(widget.session.id));
    ref.invalidate(flaggedPlotIdsForSessionProvider(widget.session.id));
    ref.invalidate(plotPksWithCorrectionsForSessionProvider(widget.session.id));
    ref.invalidate(sessionAssessmentsProvider(widget.session.id));
  }

  Future<void> _checkBackupReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final store = BackupReminderStore(prefs);
    if (store.mode != BackupReminderMode.afterSessionClose) return;
    if (!store.shouldRemind()) return;
    await store.recordReminderShown();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Back Up Your Data?'),
        content: Text(
          'Last backup: ${store.lastBackupLabel}\n\n'
          'Back up now to keep your trial data safe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Go to More → Backup to save your data'),
                  duration: Duration(seconds: 4),
                ),
              );
            },
            child: const Text('Back Up'),
          ),
        ],
      ),
    );
  }

  Future<void> _closeSession({bool force = false}) async {
    setState(() => _isClosing = true);
    try {
      final userId = await ref.read(currentUserIdProvider.future);
      final useCase = ref.read(closeSessionUseCaseProvider);
      final result = await useCase.execute(
        sessionId: widget.session.id,
        trialId: widget.trial.id,
        raterName: widget.session.raterName,
        closedByUserId: userId,
        forceClose: force,
      );
      if (!mounted) return;
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          result.success ? 'Session closed' : result.errorMessage ?? 'Error',
          style: TextStyle(
            color: result.success ? AppDesignTokens.successFg : scheme.onError,
          ),
        ),
        backgroundColor:
            result.success ? AppDesignTokens.successBg : scheme.error,
      ));
      if (result.success) {
        _invalidate();
        _checkBackupReminder();
      }
      // If warnings blocked the close, offer force close
      if (!result.success &&
          result.errorMessage != null &&
          result.errorMessage!.contains('warnings')) {
        _showForceCloseDialog();
      }
    } finally {
      if (mounted) setState(() => _isClosing = false);
    }
  }

  void _showForceCloseDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close anyway?'),
        content: const Text(
          'There are warnings but no blockers. Close the session anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _closeSession(force: true);
            },
            child: const Text('Close Session'),
          ),
        ],
      ),
    );
  }

  void _openRatingForPlot(Plot plot, List<Plot> allPlots,
      List<Assessment> assessments) {
    _openRatingForPlotAtAssessment(plot, allPlots, assessments, null);
  }

  void _openRatingForPlotAtAssessment(Plot plot, List<Plot> allPlots,
      List<Assessment> assessments, int? assessmentIndex) {
    // Sort plots in walk order for proper navigation inside rating screen
    final walkPlots = sortPlotsByWalkOrder(allPlots, WalkOrderMode.serpentine);
    final plotIndex = walkPlots.indexWhere((p) => p.id == plot.id);
    if (plotIndex < 0) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RatingScreen(
          trial: widget.trial,
          session: widget.session,
          plot: plot,
          assessments: assessments,
          allPlots: walkPlots,
          currentPlotIndex: plotIndex,
          initialAssessmentIndex: assessmentIndex,
        ),
      ),
    ).then((_) => _invalidate());
  }

  @override
  Widget build(BuildContext context) {
    final plotsAsync = ref.watch(plotsForTrialProvider(widget.trial.id));
    final assessmentsAsync =
        ref.watch(sessionAssessmentsProvider(widget.session.id));
    final ratingsAsync =
        ref.watch(sessionRatingsProvider(widget.session.id));
    final reportAsync =
        ref.watch(sessionCompletenessReportProvider(widget.session.id));
    final assignmentsAsync =
        ref.watch(assignmentsForTrialProvider(widget.trial.id));
    final liveSession =
        ref.watch(sessionByIdProvider(widget.session.id)).valueOrNull;
    final isOpen = liveSession?.endedAt == null;

    // Build plot → treatmentId map from assignments (reliable, not async per-plot)
    final assignments = assignmentsAsync.valueOrNull ?? [];
    final plotTreatmentMap = <int, int>{};
    for (final a in assignments) {
      if (a.treatmentId != null) {
        plotTreatmentMap[a.plotId] = a.treatmentId!;
      }
    }

    // Treatment name lookup for cell detail sheet
    final treatments =
        ref.watch(treatmentsForTrialProvider(widget.trial.id)).valueOrNull ??
            [];
    final treatmentNames = <int, String>{
      for (final t in treatments) t.id: '${t.code} — ${t.name}',
    };

    // Build human-readable assessment names from TrialAssessment metadata
    final trialAssessments = ref
        .watch(trialAssessmentsForTrialProvider(widget.trial.id))
        .valueOrNull;
    final assessmentDisplayNames = <int, String>{};
    if (trialAssessments != null) {
      for (final ta in trialAssessments) {
        final lid = ta.legacyAssessmentId;
        if (lid != null) {
          assessmentDisplayNames[lid] =
              AssessmentDisplayHelper.compactName(ta);
        }
      }
    }

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: GradientScreenHeader(
        title: widget.session.name,
        subtitle: widget.session.sessionDateLocal,
        titleFontSize: 17,
        actions: [
          // Tools menu — advanced screens
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: 'Tools',
            onSelected: (value) {
              switch (value) {
                case 'completeness':
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SessionCompletenessScreen(
                        trial: widget.trial,
                        session: widget.session,
                      ),
                    ),
                  );
                case 'plot_queue':
                  _navigatePlotQueue(
                      context, widget.trial, widget.session);
                case 'edited':
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const EditedItemsScreen(),
                    ),
                  );
                case 'details':
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => _SessionDetailsFullScreen(
                        trial: widget.trial,
                        session: widget.session,
                      ),
                    ),
                  );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'plot_queue',
                child: ListTile(
                  leading: Icon(Icons.list_alt, size: 20),
                  title: Text('Plot Queue', style: TextStyle(fontSize: 14)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const PopupMenuItem(
                value: 'completeness',
                child: ListTile(
                  leading: Icon(Icons.fact_check_outlined, size: 20),
                  title: Text('Completeness', style: TextStyle(fontSize: 14)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const PopupMenuItem(
                value: 'details',
                child: ListTile(
                  leading: Icon(Icons.analytics_outlined, size: 20),
                  title: Text('Session Details', style: TextStyle(fontSize: 14)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'edited',
                child: ListTile(
                  leading: Icon(Icons.edit_note, size: 20),
                  title: Text('Edited Items', style: TextStyle(fontSize: 14)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: plotsAsync.when(
          loading: () => const AppLoadingView(),
          error: (e, st) =>
              AppErrorView(error: e, stackTrace: st, onRetry: _invalidate),
          data: (plots) => assessmentsAsync.when(
            loading: () => const AppLoadingView(),
            error: (e, st) =>
                AppErrorView(error: e, stackTrace: st, onRetry: _invalidate),
            data: (assessments) => ratingsAsync.when(
              loading: () => const AppLoadingView(),
              error: (e, st) =>
                  AppErrorView(error: e, stackTrace: st, onRetry: _invalidate),
              data: (ratings) {
                final editedCount = ratings
                    .where((r) => r.amended || r.previousId != null)
                    .length;
                final dataPlots = plots
                    .where((p) =>
                        !p.isGuardRow && p.excludeFromAnalysis != true)
                    .toList();
                final dataPlotCount = dataPlots.length;
                final report = reportAsync.valueOrNull;
                final canClose = report?.canClose ?? false;
                final blockerCount = report?.issues
                        .where((i) =>
                            i.severity ==
                            SessionCompletenessIssueSeverity.blocker)
                        .length ??
                    0;

                // Outlier detection: >2 SD from treatment mean
                final outlierKeys = _computeOutliers(
                  dataPlots: dataPlots,
                  assessments: assessments,
                  ratings: ratings,
                  plotTreatmentMap: plotTreatmentMap,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status bar with close session
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: const BoxDecoration(
                        color: AppDesignTokens.sectionHeaderBg,
                        border: Border(
                            bottom: BorderSide(
                                color: AppDesignTokens.borderCrisp)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${assessments.length} assessment${assessments.length == 1 ? '' : 's'} · '
                                  '$dataPlotCount plots',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (editedCount > 0) ...[
                                      Text(
                                        '▲ $editedCount edited',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                Colors.blueGrey.shade600),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    if (outlierKeys.isNotEmpty) ...[
                                      Text(
                                        '● ${outlierKeys.length} outlier${outlierKeys.length == 1 ? '' : 's'}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                Colors.amber.shade800),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    if (!isOpen)
                                      Text(
                                        'Session closed',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green.shade700),
                                      )
                                    else if (blockerCount > 0)
                                      Text(
                                        '$blockerCount blocker${blockerCount == 1 ? '' : 's'}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red.shade700),
                                      )
                                    else if (canClose)
                                      Text(
                                        'Ready to close',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green.shade700),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isOpen && canClose)
                            SizedBox(
                              height: 32,
                              child: FilledButton.icon(
                                onPressed:
                                    _isClosing ? null : _closeSession,
                                icon: _isClosing
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(Icons.lock_outline,
                                        size: 16),
                                label: const Text('Close Session',
                                    style: TextStyle(fontSize: 12)),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  backgroundColor:
                                      AppDesignTokens.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // View toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: const BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: AppDesignTokens.borderCrisp)),
                      ),
                      child: Row(
                        children: [
                          _ViewToggleChip(
                            label: 'Plots',
                            selected: !_showTreatments,
                            onTap: () =>
                                setState(() => _showTreatments = false),
                          ),
                          const SizedBox(width: 8),
                          _ViewToggleChip(
                            label: 'Treatments',
                            selected: _showTreatments,
                            onTap: () =>
                                setState(() => _showTreatments = true),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Expanded(
                      child: _showTreatments
                          ? _buildTreatmentView(plots, assessments,
                              ratings, assessmentDisplayNames)
                          : SessionDataGrid(
                              plots: plots,
                              assessments: assessments,
                              ratings: ratings,
                              trialId: widget.trial.id,
                              sessionId: widget.session.id,
                              onPlotTap: (plot) => _openRatingForPlot(
                                  plot, plots, assessments),
                              onCellTap: (plot, assessment, rating) {
                                final tid =
                                    plotTreatmentMap[plot.id] ??
                                        plot.treatmentId;
                                final assessIdx = assessments
                                    .indexWhere((a) => a.id == assessment.id);
                                _showCellDetailSheet(
                                  context: context,
                                  plot: plot,
                                  assessment: assessment,
                                  rating: rating,
                                  allPlots: plots,
                                  assessments: assessments,
                                  assessmentDisplayName:
                                      assessmentDisplayNames[assessment.id] ??
                                          AssessmentDisplayHelper
                                              .legacyAssessmentDisplayName(
                                                  assessment.name),
                                  treatmentLabel: tid != null
                                      ? treatmentNames[tid]
                                      : null,
                                  onGoToRating: () {
                                    _openRatingForPlotAtAssessment(
                                      plot,
                                      plots,
                                      assessments,
                                      assessIdx >= 0 ? assessIdx : 0,
                                    );
                                  },
                                );
                              },
                              assessmentDisplayNames:
                                  assessmentDisplayNames.isNotEmpty
                                      ? assessmentDisplayNames
                                      : null,
                              outlierKeys: outlierKeys,
                              plotTreatmentMap: plotTreatmentMap,
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Returns set of (plotPk, assessmentId) keys where value is >2 SD from treatment mean.
  static Set<(int, int)> _computeOutliers({
    required List<Plot> dataPlots,
    required List<Assessment> assessments,
    required List<RatingRecord> ratings,
    required Map<int, int> plotTreatmentMap,
  }) {
    if (plotTreatmentMap.isEmpty) return {};

    // Build rating lookup
    final ratingMap = <(int, int), double>{};
    for (final r in ratings) {
      if (!r.isCurrent || r.isDeleted) continue;
      if (r.resultStatus == 'RECORDED' && r.numericValue != null) {
        ratingMap[(r.plotPk, r.assessmentId)] = r.numericValue!;
      }
    }

    // Also check legacy plot.treatmentId as fallback
    final effectiveTreatment = <int, int>{};
    for (final p in dataPlots) {
      final tid = plotTreatmentMap[p.id] ?? p.treatmentId;
      if (tid != null) effectiveTreatment[p.id] = tid;
    }

    final outliers = <(int, int)>{};

    for (final a in assessments) {
      // Group values by treatment
      final byTreatment = <int, List<(int plotPk, double value)>>{};
      for (final p in dataPlots) {
        final tid = effectiveTreatment[p.id];
        if (tid == null) continue;
        final v = ratingMap[(p.id, a.id)];
        if (v == null) continue;
        byTreatment.putIfAbsent(tid, () => []).add((p.id, v));
      }

      // For each treatment, flag values >2 SD from mean
      for (final entries in byTreatment.values) {
        if (entries.length < 3) continue;
        final values = entries.map((e) => e.$2).toList();
        final mean = values.reduce((a, b) => a + b) / values.length;
        final variance = values
                .map((v) => (v - mean) * (v - mean))
                .reduce((a, b) => a + b) /
            (values.length - 1);
        final sd = variance > 0 ? sqrt(variance) : 0.0;
        if (sd < 1e-9) continue;

        for (final entry in entries) {
          if ((entry.$2 - mean).abs() > 2 * sd) {
            outliers.add((entry.$1, a.id));
          }
        }
      }
    }

    return outliers;
  }

  Widget _buildTreatmentView(
    List<Plot> plots,
    List<Assessment> assessments,
    List<RatingRecord> ratings,
    Map<int, String> displayNames,
  ) {
    final treatmentsAsync =
        ref.watch(treatmentsForTrialProvider(widget.trial.id));
    final assignmentsAsync =
        ref.watch(assignmentsForTrialProvider(widget.trial.id));

    return treatmentsAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, st) =>
          AppErrorView(error: e, stackTrace: st, onRetry: _invalidate),
      data: (treatments) => assignmentsAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, st) =>
            AppErrorView(error: e, stackTrace: st, onRetry: _invalidate),
        data: (assignments) => SessionTreatmentSummary(
          plots: plots,
          assessments: assessments,
          ratings: ratings,
          treatments: treatments,
          assignments: assignments,
          assessmentDisplayNames:
              displayNames.isNotEmpty ? displayNames : null,
        ),
      ),
    );
  }
}

class _ViewToggleChip extends StatelessWidget {
  const _ViewToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppDesignTokens.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppDesignTokens.primary
                : AppDesignTokens.borderCrisp,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppDesignTokens.secondaryText,
          ),
        ),
      ),
    );
  }
}

/// Full-screen wrapper for the old detail cards (accessible from tools menu).
class _SessionDetailsFullScreen extends ConsumerWidget {
  const _SessionDetailsFullScreen({
    required this.trial,
    required this.session,
  });

  final Trial trial;
  final Session session;

  void _invalidate(WidgetRef ref) {
    ref.invalidate(plotsForTrialProvider(trial.id));
    ref.invalidate(sessionRatingsProvider(session.id));
    ref.invalidate(ratedPlotPksProvider(session.id));
    ref.invalidate(sessionCompletenessReportProvider(session.id));
    ref.invalidate(flaggedPlotIdsForSessionProvider(session.id));
    ref.invalidate(plotPksWithCorrectionsForSessionProvider(session.id));
    ref.invalidate(sessionAssessmentsProvider(session.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: GradientScreenHeader(
        title: 'Session Details',
        subtitle: '${session.name} · ${session.sessionDateLocal}',
        titleFontSize: 17,
      ),
      body: SafeArea(
        top: false,
        child: _SessionDetailsBody(
          trial: trial,
          session: session,
          onInvalidate: () => _invalidate(ref),
        ),
      ),
    );
  }
}

/// The old detailed session summary (Progress, Coverage, Completeness, Attention)
/// accessible via the info icon.
class _SessionDetailsBody extends ConsumerWidget {
  const _SessionDetailsBody({
    required this.trial,
    required this.session,
    required this.onInvalidate,
  });

  final Trial trial;
  final Session session;
  final VoidCallback onInvalidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final reportAsync =
        ref.watch(sessionCompletenessReportProvider(session.id));
    final ratingsAsync = ref.watch(sessionRatingsProvider(session.id));
    final ratedPksAsync = ref.watch(ratedPlotPksProvider(session.id));
    final flaggedAsync =
        ref.watch(flaggedPlotIdsForSessionProvider(session.id));
    final correctionsAsync =
        ref.watch(plotPksWithCorrectionsForSessionProvider(session.id));
    final assessmentsAsync = ref.watch(sessionAssessmentsProvider(session.id));

    return plotsAsync.when(
          loading: () => const AppLoadingView(),
          error: (e, st) => AppErrorView(
            error: e,
            stackTrace: st,
            onRetry: onInvalidate,
          ),
          data: (rawPlots) => reportAsync.when(
            loading: () => const AppLoadingView(),
            error: (e, st) => AppErrorView(
              error: e,
              stackTrace: st,
              onRetry: onInvalidate,
            ),
            data: (report) => ratingsAsync.when(
              loading: () => const AppLoadingView(),
              error: (e, st) => AppErrorView(
                error: e,
                stackTrace: st,
                onRetry: onInvalidate,
              ),
              data: (ratings) => ratedPksAsync.when(
                loading: () => const AppLoadingView(),
                error: (e, st) => AppErrorView(
                  error: e,
                  stackTrace: st,
                  onRetry: onInvalidate,
                ),
                data: (ratedPks) => flaggedAsync.when(
                  loading: () => const AppLoadingView(),
                  error: (e, st) => AppErrorView(
                    error: e,
                    stackTrace: st,
                    onRetry: onInvalidate,
                  ),
                  data: (flaggedIds) => correctionsAsync.when(
                    loading: () => const AppLoadingView(),
                    error: (e, st) => AppErrorView(
                      error: e,
                      stackTrace: st,
                      onRetry: onInvalidate,
                    ),
                    data: (correctionPlotPks) => assessmentsAsync.when(
                      loading: () => const AppLoadingView(),
                      error: (e, st) => AppErrorView(
                        error: e,
                        stackTrace: st,
                        onRetry: onInvalidate,
                      ),
                      data: (assessments) {
                        final ratingsByPlot = <int, List<RatingRecord>>{};
                        for (final r in ratings) {
                          ratingsByPlot.putIfAbsent(r.plotPk, () => []).add(r);
                        }

                        var ratedCount = 0;
                        var notRatedCount = 0;
                        var flaggedCount = 0;
                        var issuesPlotCount = 0;
                        var editedPlotCount = 0;

                        for (final plot in rawPlots) {
                          final plotRatings = ratingsByPlot[plot.id] ?? [];
                          if (ratedPks.contains(plot.id)) {
                            ratedCount++;
                          } else {
                            notRatedCount++;
                          }
                          if (flaggedIds.contains(plot.id)) flaggedCount++;
                          if (plotRatings
                              .any((r) => r.resultStatus != 'RECORDED')) {
                            issuesPlotCount++;
                          }
                          if (plotRatings.any(
                                  (r) => r.amended || (r.previousId != null)) ||
                              correctionPlotPks.contains(plot.id)) {
                            editedPlotCount++;
                          }
                        }

                        final latestEditAmongEdited =
                            latestEditRecencyAcrossEditedPlots(
                          plots: rawPlots,
                          ratingsByPlot: ratingsByPlot,
                          correctionPlotPks: correctionPlotPks,
                        );

                        final total = rawPlots.length;
                        final progressPct = total > 0
                            ? ((100 * ratedCount) / total).round()
                            : null;

                        final blockerCount = report.issues
                            .where((i) =>
                                i.severity ==
                                SessionCompletenessIssueSeverity.blocker)
                            .length;
                        final warningCount = report.issues
                            .where((i) =>
                                i.severity ==
                                SessionCompletenessIssueSeverity.warning)
                            .length;

                        final coverageRows =
                            computeSessionSummaryAssessmentCoverage(
                          plotsForTrial: rawPlots,
                          sessionAssessments: assessments,
                          currentSessionRatings: ratings,
                        );

                        return ListView(
                          padding:
                              const EdgeInsets.all(AppDesignTokens.spacing16),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppCard(
                                padding: const EdgeInsets.all(
                                    AppDesignTokens.spacing16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Semantics(
                                      button: true,
                                      label: 'Open full plot queue',
                                      child: InkWell(
                                        onTap: () => _navigatePlotQueue(
                                            context, trial, session),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const _CardHeaderRow(
                                                title: 'Progress'),
                                            const SizedBox(height: 6),
                                            const _CaptionHint(
                                              'Full plot queue — total trial plots vs plots with any current rating (navigation only)',
                                            ),
                                            const SizedBox(height: 10),
                                            _MetricRow('Total plots', '$total'),
                                            _MetricRow(
                                                'Rated plots', '$ratedCount'),
                                          ],
                                        ),
                                      ),
                                    ),
                                    _MetricRow(
                                      'Not rated plots',
                                      '$notRatedCount',
                                      onTap: () => _navigatePlotQueue(
                                        context,
                                        trial,
                                        session,
                                        const PlotQueueInitialFilters(
                                            unratedOnly: true),
                                      ),
                                      semanticsLabel:
                                          'Open Plot Queue, unrated plots only',
                                    ),
                                    Semantics(
                                      button: true,
                                      label: 'Open full plot queue',
                                      child: InkWell(
                                        onTap: () => _navigatePlotQueue(
                                            context, trial, session),
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 10),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const _CaptionHint(
                                                  'Share of trial plots with at least one current rating'),
                                              const SizedBox(height: 4),
                                              Text(
                                                progressPct != null
                                                    ? 'Plots with any rating: $progressPct%'
                                                    : 'Plots with any rating: —',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppCard(
                                padding: const EdgeInsets.all(
                                    AppDesignTokens.spacing16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _CardHeaderRow(
                                        title: 'Assessment Coverage'),
                                    const SizedBox(height: 6),
                                    const _CaptionHint(
                                      'Recorded ratings per assessment across target plots (non-guard)',
                                    ),
                                    const SizedBox(height: 10),
                                    if (assessments.isEmpty)
                                      Text(
                                        'No assessments in this session.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      )
                                    else ...[
                                      for (var i = 0;
                                          i < coverageRows.length;
                                          i++) ...[
                                        if (i > 0)
                                          const SizedBox(
                                              height:
                                                  AppDesignTokens.spacing12),
                                        Text(
                                          coverageRows[i].assessmentName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppDesignTokens.primaryText,
                                          ),
                                        ),
                                        const SizedBox(
                                            height: AppDesignTokens.spacing4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${coverageRows[i].recordedCount} / ${coverageRows[i].targetPlotCount}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: coverageRows[i]
                                                          .isIncomplete
                                                      ? AppDesignTokens
                                                          .warningFg
                                                      : AppDesignTokens
                                                          .successFg,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(
                                            height: AppDesignTokens.spacing8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                              AppDesignTokens.radiusSmall),
                                          child: LinearProgressIndicator(
                                            value: coverageRows[i]
                                                        .targetPlotCount >
                                                    0
                                                ? coverageRows[i]
                                                    .progressFraction
                                                : 0,
                                            minHeight: AppDesignTokens.spacing8,
                                            backgroundColor:
                                                AppDesignTokens.divider,
                                            color: coverageRows[i].isIncomplete
                                                ? AppDesignTokens.warningFg
                                                : AppDesignTokens.primary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Semantics(
                                button: true,
                                label: 'Open Session Completeness',
                                child: GestureDetector(
                                  onTap: () => _navigateSessionCompleteness(
                                      context, trial, session),
                                  behavior: HitTestBehavior.opaque,
                                  child: AppCard(
                                    padding: const EdgeInsets.all(
                                        AppDesignTokens.spacing16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const _CardHeaderRow(
                                            title: 'Session completeness'),
                                        const SizedBox(height: 10),
                                        if (report.issues.any((i) =>
                                            i.code ==
                                            SessionCompletenessIssueCode
                                                .sessionNotFound))
                                          Text(
                                            'Session could not be loaded for completeness.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          )
                                        else if (report.issues.any((i) =>
                                            i.code ==
                                            SessionCompletenessIssueCode
                                                .noSessionAssessments))
                                          Text(
                                            'No assessments in this session.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          )
                                        else ...[
                                          _MetricRow('Expected plots',
                                              '${report.expectedPlots}'),
                                          _MetricRow('Complete plots',
                                              '${report.completedPlots}'),
                                          _MetricRow('Incomplete plots',
                                              '${report.incompletePlots}'),
                                          if (assessments.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              '${assessments.length} assessments per target plot',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          if (!report.canClose)
                                            Text(
                                              '$blockerCount blocker issue(s). '
                                              'Not ready to close — open Session Completeness for details.',
                                              style: TextStyle(
                                                fontSize: 13,
                                                height: 1.35,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error,
                                              ),
                                            )
                                          else if (report.expectedPlots > 0 &&
                                              report.incompletePlots == 0)
                                            Text(
                                              'Ready to close from a completeness standpoint — '
                                              'end the session when field work is finished.',
                                              style: TextStyle(
                                                fontSize: 13,
                                                height: 1.35,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                            )
                                          else if (report.expectedPlots == 0)
                                            Text(
                                              'No target plots in this trial for completeness.',
                                              style: TextStyle(
                                                fontSize: 13,
                                                height: 1.35,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          if (warningCount > 0) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              '$warningCount warning(s) — review in Session Completeness.',
                                              style: TextStyle(
                                                fontSize: 12,
                                                height: 1.35,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                          ..._completenessIssuePreviewRows(
                                            context: context,
                                            trialId: trial.id,
                                            sessionId: session.id,
                                            issues: report.issues,
                                            onSeeAll: () =>
                                                _navigateSessionCompleteness(
                                              context,
                                              trial,
                                              session,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Text(
                                          'Open Session Completeness for plot-by-plot coverage.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1.35,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: AppCard(
                                padding: const EdgeInsets.all(
                                    AppDesignTokens.spacing16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Semantics(
                                      button: true,
                                      label: 'Open full plot queue',
                                      child: InkWell(
                                        onTap: () => _navigatePlotQueue(
                                            context, trial, session),
                                        child: const Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _CardHeaderRow(title: 'Attention'),
                                            SizedBox(height: 6),
                                            _CaptionHint('Full plot queue'),
                                            SizedBox(height: 8),
                                          ],
                                        ),
                                      ),
                                    ),
                                    _MetricRow(
                                      'Flagged plots',
                                      '$flaggedCount',
                                      onTap: () => _navigatePlotQueue(
                                        context,
                                        trial,
                                        session,
                                        const PlotQueueInitialFilters(
                                            flaggedOnly: true),
                                      ),
                                      semanticsLabel:
                                          'Open Plot Queue, flagged plots only',
                                    ),
                                    _MetricRow(
                                      'Plots with issues',
                                      '$issuesPlotCount',
                                      onTap: () => _navigatePlotQueue(
                                        context,
                                        trial,
                                        session,
                                        const PlotQueueInitialFilters(
                                            issuesOnly: true),
                                      ),
                                      semanticsLabel:
                                          'Open Plot Queue, plots with issues only',
                                    ),
                                    _MetricRow(
                                      'Edited plots',
                                      '$editedPlotCount',
                                      onTap: () => _navigatePlotQueue(
                                        context,
                                        trial,
                                        session,
                                        const PlotQueueInitialFilters(
                                            editedOnly: true),
                                      ),
                                      semanticsLabel:
                                          'Open Plot Queue, edited plots only',
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 4, right: 4, bottom: 4),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Includes amended, corrected, and re-saved values',
                                            style: TextStyle(
                                              fontSize: 11,
                                              height: 1.3,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Tap to review edited plots in this session',
                                            style: TextStyle(
                                              fontSize: 11,
                                              height: 1.3,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.85),
                                            ),
                                          ),
                                          if (editedPlotCount > 0 &&
                                              latestEditAmongEdited !=
                                                  null) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              'Recent edit activity: ${formatEditRecencyWithYear(latestEditAmongEdited)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                height: 1.25,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant
                                                    .withValues(alpha: 0.88),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Semantics(
                                      button: true,
                                      label: 'Open Plot Queue',
                                      child: InkWell(
                                        onTap: () => _navigatePlotQueue(
                                            context, trial, session),
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Text(
                                            'Tap Flagged or Issues above for those filters. Open Plot Queue below for the full list.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              height: 1.35,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Text(
                              'Open related screens',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const _CaptionHint(
                              'Plot Queue opens the full list (same as card areas above).',
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => _navigateSessionCompleteness(
                                    context, trial, session),
                                child: const Text('Open Session Completeness'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () =>
                                    _navigatePlotQueue(context, trial, session),
                                child: const Text('Open Plot Queue'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => const EditedItemsScreen(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Edited Items (all sessions)',
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Below: helper widgets used by _SessionDetailsBody
// ---------------------------------------------------------------------------

class _CaptionHint extends StatelessWidget {
  const _CaptionHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        height: 1.3,
        color: Theme.of(context)
            .colorScheme
            .onSurfaceVariant
            .withValues(alpha: 0.88),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: AppDesignTokens.primaryText,
      ),
    );
  }
}

class _CardHeaderRow extends StatelessWidget {
  const _CardHeaderRow({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _SectionTitle(title)),
        Icon(
          Icons.chevron_right,
          size: 22,
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.65),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(
    this.label,
    this.value, {
    this.onTap,
    this.semanticsLabel,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (onTap != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.45),
                ),
              ],
            )
          else
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.primaryText,
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      child: InkWell(
        onTap: onTap,
        child: row,
      ),
    );
  }
}
