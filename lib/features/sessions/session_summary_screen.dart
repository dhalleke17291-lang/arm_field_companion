import 'dart:io';
import 'dart:math' show sqrt;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
import 'package:shared_preferences/shared_preferences.dart';
import '../backup/backup_reminder_store.dart';
import 'session_completeness_sheet.dart';
import '../../data/repositories/weather_snapshot_repository.dart';
import '../weather/weather_capture_form.dart';
import 'session_data_grid.dart';
import 'session_grid_pdf_export.dart';
import 'session_summary_assessment_coverage.dart';
import '../../core/connectivity/gps_service.dart';
import '../../domain/models/trial_insight.dart';
import '../../domain/interpretation/behavioral_signature_interpreter.dart';
import '../../domain/interpretation/protocol_divergence_interpreter.dart';
import '../../domain/relationships/behavioral_signature_provider.dart';
import '../../domain/relationships/evidence_anchors_provider.dart';
import '../../domain/relationships/protocol_divergence_provider.dart';
import 'session_export_actions.dart';
import 'session_export_trust_dialog.dart';
import 'session_hub_review_filters.dart';
import 'session_plot_predicates.dart';
import 'session_summary_share.dart';
import 'session_treatment_summary.dart';
import 'session_close_signal_writers.dart';
import 'widgets/session_close_diagnostic.dart';

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
            child: const Text('View all plots'),
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

  // Hub review filter state
  int? _repFilter;
  bool _filterUnratedOnly = false;
  bool _filterIssuesOnly = false;
  bool _filterEditedOnly = false;
  bool _filterFlaggedOnly = false;

  // Treatment highlight state — null means no highlight active
  int? _selectedTreatmentId;

  bool get _anyHubFilterActive =>
      _repFilter != null ||
      _filterUnratedOnly ||
      _filterIssuesOnly ||
      _filterEditedOnly ||
      _filterFlaggedOnly;

  void _clearHubFilters() => setState(() {
        _repFilter = null;
        _filterUnratedOnly = false;
        _filterIssuesOnly = false;
        _filterEditedOnly = false;
        _filterFlaggedOnly = false;
      });

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
    // Weather soft prompt — ask before closing if no weather recorded
    if (!force) {
      final weatherRepo = ref.read(weatherSnapshotRepositoryProvider);
      final snap = await weatherRepo.getWeatherSnapshotForParent(
        kWeatherParentTypeRatingSession,
        widget.session.id,
      );
      if (snap == null && mounted) {
        final addWeather = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Add weather conditions?'),
            content: const Text(
              'No weather recorded for this session. Adding weather '
              'improves your evidence report score.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Skip'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add Weather'),
              ),
            ],
          ),
        );
        if (addWeather == true && mounted) {
          await showWeatherCaptureBottomSheet(
            context,
            trial: widget.trial,
            session: widget.session,
          );
        }
        if (!mounted) return;
      }

      // Crop injury prompt — ask before closing if not yet recorded
      final liveSession =
          ref.read(sessionByIdProvider(widget.session.id)).valueOrNull ??
              widget.session;
      if (liveSession.cropInjuryStatus == null && mounted) {
        final result = await _showCropInjuryPrompt();
        if (result != null && mounted) {
          await ref.read(sessionRepositoryProvider).updateSessionCropInjury(
                widget.session.id,
                status: result.status,
                notes: result.notes,
              );
          ref.invalidate(sessionByIdProvider(widget.session.id));
        }
        if (!mounted) return;
      }
    }

    // Fire session-close writers before surfacing the diagnostic.
    if (!mounted) return;
    await runSessionCloseSignalWriters(
      ref,
      trialId: widget.trial.id,
      sessionId: widget.session.id,
    );

    // Diagnostic step — surfaces open signals before close.
    if (!mounted) return;
    var proceedAfterDiagnostic = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SessionCloseDiagnostic(
        sessionId: widget.session.id,
        trialId: widget.trial.id,
        onAllClear: () {
          proceedAfterDiagnostic = true;
          Navigator.of(ctx).pop();
        },
        onProceedAnyway: () {
          proceedAfterDiagnostic = true;
          Navigator.of(ctx).pop();
        },
      ),
    );
    if (!proceedAfterDiagnostic || !mounted) return;

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
        _offerShareSummary();
        _checkBackupReminder();
        ref.read(autoBackupServiceProvider).performAutoBackup();
        _queueWeatherBackfillIfNeeded();
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

  Future<_CropInjuryResult?> _showCropInjuryPrompt() {
    return showDialog<_CropInjuryResult>(
      context: context,
      builder: (ctx) {
        String? notes;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Any crop injury observed?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Recording crop injury status is required by GLP and efficacy trial standards. '
                  '"None observed" is positive evidence that the crop was checked.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
                const SizedBox(height: 16),
                _CropInjuryOption(
                  label: 'None observed',
                  subtitle: 'Crop looks healthy, no injury symptoms',
                  icon: Icons.check_circle_outline,
                  color: AppDesignTokens.successFg,
                  onTap: () => Navigator.pop(
                    ctx,
                    const _CropInjuryResult(status: 'none_observed'),
                  ),
                ),
                const SizedBox(height: 8),
                _CropInjuryOption(
                  label: 'Symptoms observed',
                  subtitle: 'Describe symptoms below',
                  icon: Icons.warning_amber_rounded,
                  color: AppDesignTokens.warningFg,
                  onTap: () {
                    if (notes == null || notes!.trim().isEmpty) {
                      setDialogState(() => notes = '');
                    } else {
                      Navigator.pop(
                        ctx,
                        _CropInjuryResult(
                          status: 'symptoms_observed',
                          notes: notes?.trim(),
                        ),
                      );
                    }
                  },
                ),
                if (notes != null) ...[
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Describe symptoms (type, severity, affected treatments)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => notes = v,
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      ctx,
                      _CropInjuryResult(
                        status: 'symptoms_observed',
                        notes: notes?.trim(),
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
                const SizedBox(height: 8),
                _CropInjuryOption(
                  label: 'Not assessed',
                  subtitle: 'Crop injury check not applicable this session',
                  icon: Icons.remove_circle_outline,
                  color: AppDesignTokens.secondaryText,
                  onTap: () => Navigator.pop(
                    ctx,
                    const _CropInjuryResult(status: 'not_assessed'),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Skip'),
              ),
            ],
          ),
        );
      },
    );
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

  Future<void> _offerShareSummary() async {
    if (!mounted) return;
    final share = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share session summary?'),
        content: const Text(
          'Send a plain-text summary of this session via text, email, or any app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Share'),
          ),
        ],
      ),
    );
    if (share != true || !mounted) return;

    try {
      final plots =
          await ref.read(plotsForTrialProvider(widget.trial.id).future);
      final assessments =
          await ref.read(sessionAssessmentsProvider(widget.session.id).future);
      final ratings =
          await ref.read(sessionRatingsProvider(widget.session.id).future);
      final treatments =
          await ref.read(treatmentsForTrialProvider(widget.trial.id).future);
      final assignments =
          await ref.read(assignmentsForTrialProvider(widget.trial.id).future);
      final timing = await ref
          .read(sessionTimingContextProvider(widget.session.id).future);
      final weatherRepo = ref.read(weatherSnapshotRepositoryProvider);
      final weather = await weatherRepo.getWeatherSnapshotForParent(
        kWeatherParentTypeRatingSession, widget.session.id);
      final insights = await ref
          .read(trialInsightsProvider(widget.trial.id).future)
          .catchError((_) => <TrialInsight>[]);

      final text = composeSessionSummary(
        trial: widget.trial,
        session: widget.session,
        plots: plots,
        assessments: assessments,
        ratings: ratings,
        treatments: treatments,
        assignments: assignments,
        timing: timing,
        weather: weather,
        insights: insights,
      );

      if (!mounted) return;
      await Share.share(text, subject: '${widget.trial.name} — ${widget.session.name}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }

  Future<void> _queueWeatherBackfillIfNeeded() async {
    try {
      final weatherRepo = ref.read(weatherSnapshotRepositoryProvider);
      final snap = await weatherRepo.getWeatherSnapshotForParent(
        kWeatherParentTypeRatingSession, widget.session.id);
      if (snap != null) return;

      final pos = await GpsService.getCurrentPosition(
          timeout: const Duration(seconds: 3));
      if (pos == null) return;

      await ref.read(weatherBackfillServiceProvider).queueBackfill(
        latitude: pos.latitude,
        longitude: pos.longitude,
        eventTimestamp: widget.session.startedAt,
        parentType: kWeatherParentTypeRatingSession,
        parentId: widget.session.id,
        trialId: widget.trial.id,
      );
    } catch (_) {}
  }

  bool _isExporting = false;

  Future<void> _exportGridPdf({
    required List<Plot> plots,
    required List<Assessment> assessments,
    required List<RatingRecord> ratings,
    required Map<int, String> assessmentDisplayNames,
    required Map<int, int> plotTreatmentMap,
    required Map<int, String> treatmentNames,
    int? completedPlots,
    int? expectedPlots,
  }) async {
    setState(() => _isExporting = true);
    try {
      final exporter = SessionGridPdfExport(
        trial: widget.trial,
        session: widget.session,
        plots: plots,
        assessments: assessments,
        ratings: ratings,
        assessmentDisplayNames:
            assessmentDisplayNames.isNotEmpty ? assessmentDisplayNames : null,
        plotTreatmentMap:
            plotTreatmentMap.isNotEmpty ? plotTreatmentMap : null,
        treatmentNames: treatmentNames.isNotEmpty ? treatmentNames : null,
        completedPlots: completedPlots,
        expectedPlots: expectedPlots,
      );
      final bytes = await exporter.build();
      final dir = await getTemporaryDirectory();
      final sanitizedName =
          widget.session.name.replaceAll(RegExp(r'[^\w\-]'), '_');
      final file = File('${dir.path}/grid_$sanitizedName.pdf');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      try {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(file.path)],
          text:
              '${widget.trial.name} — ${widget.session.name} grid export',
          sharePositionOrigin: box != null
              ? box.localToGlobal(Offset.zero) & box.size
              : const Rect.fromLTWH(0, 0, 100, 100),
        );
      } catch (_) {
        // Share sheet dismissed or unavailable — PDF file is still saved.
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Trial-wide CSV share: long-format ratings across every session.
  Future<void> _exportTrialRatingsCsv() async {
    setState(() => _isExporting = true);
    try {
      final usecase = ref.read(exportTrialRatingsShareUsecaseProvider);
      final csv = await usecase.buildCsv(widget.trial);
      final dir = await getTemporaryDirectory();
      final sanitizedTrial =
          widget.trial.name.replaceAll(RegExp(r'[^\w\-]'), '_');
      final file = File('${dir.path}/${sanitizedTrial}_ratings.csv');
      await file.writeAsString(csv);
      if (!mounted) return;
      try {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(file.path)],
          text: '${widget.trial.name} — ratings (CSV)',
          sharePositionOrigin: box != null
              ? box.localToGlobal(Offset.zero) & box.size
              : const Rect.fromLTWH(0, 0, 100, 100),
        );
      } catch (_) {
        // Share sheet dismissed — file is still saved.
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Trial-wide TSV copy: same data as CSV, tab-delimited, placed on the
  /// clipboard. Researchers can paste directly into Excel/Sheets/Numbers.
  Future<void> _copyTrialRatingsTsv() async {
    setState(() => _isExporting = true);
    try {
      final usecase = ref.read(exportTrialRatingsShareUsecaseProvider);
      final tsv = await usecase.buildTsv(widget.trial);
      await Clipboard.setData(ClipboardData(text: tsv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ratings copied — paste into Excel or Sheets.'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copy failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
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

    // Filter-support providers — valueOrNull so they don't block the main grid
    final ratedPks =
        ref.watch(ratedPlotPksProvider(widget.session.id)).valueOrNull ??
            const <int>{};
    final flaggedIds =
        ref.watch(flaggedPlotIdsForSessionProvider(widget.session.id))
                .valueOrNull ??
            const <int>{};
    final correctionPks =
        ref.watch(plotPksWithCorrectionsForSessionProvider(widget.session.id))
                .valueOrNull ??
            const <int>{};

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
      for (final t in treatments) t.id: '${t.code} ${t.name}',
    };

    // Build human-readable assessment names from TrialAssessment metadata
    final trialAssessments = ref
        .watch(trialAssessmentsForTrialProvider(widget.trial.id))
        .valueOrNull;
    final aamMap = ref
            .watch(armAssessmentMetadataMapForTrialProvider(widget.trial.id))
            .valueOrNull ??
        const <int, ArmAssessmentMetadataData>{};
    final assessmentDisplayNames = <int, String>{};
    if (trialAssessments != null) {
      for (final ta in trialAssessments) {
        final lid = ta.legacyAssessmentId;
        if (lid != null) {
          assessmentDisplayNames[lid] = AssessmentDisplayHelper.compactName(
            ta,
            aam: aamMap[ta.id],
          );
        }
      }
    }
    // Include unlinked assessments so downstream fallbacks fire only for
    // assessments absent from the data set entirely.
    final sessionAssessments = assessmentsAsync.valueOrNull ?? <Assessment>[];
    for (final a in sessionAssessments) {
      if (!assessmentDisplayNames.containsKey(a.id)) {
        assessmentDisplayNames[a.id] =
            AssessmentDisplayHelper.legacyAssessmentDisplayName(a.name);
      }
    }

    // DAT/DAS timing for header subtitle.
    final timing = ref
        .watch(sessionTimingContextProvider(widget.session.id))
        .valueOrNull;
    final datDas =
        timing != null && !timing.isEmpty ? ' · ${timing.displayLine}' : '';
    final subtitle = '${widget.session.sessionDateLocal}$datDas';

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: GradientScreenHeader(
        title: widget.session.name,
        subtitle: subtitle,
        titleFontSize: 17,
        actions: [
          // Tools menu — advanced screens
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: 'Tools',
            onSelected: (value) async {
              switch (value) {
                case 'completeness':
                  showSessionCompletenessSheet(context, widget.trial, widget.session);
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
                case 'share_summary':
                  _offerShareSummary();
                case 'fer_pdf':
                  final ok = await confirmSessionExportTrust(
                    context: context,
                    ref: ref,
                    trialId: widget.trial.id,
                    sessionId: widget.session.id,
                  );
                  if (!context.mounted) return;
                  if (!ok) return;
                  await runFieldExecutionReportExport(
                    context,
                    ref,
                    trial: widget.trial,
                    session: ref
                            .read(sessionByIdProvider(widget.session.id))
                            .valueOrNull ??
                        widget.session,
                  );
                case 'session_csv':
                  final ok = await confirmSessionExportTrust(
                    context: context,
                    ref: ref,
                    trialId: widget.trial.id,
                    sessionId: widget.session.id,
                  );
                  if (!context.mounted) return;
                  if (!ok) return;
                  await runSessionCsvExport(
                    context,
                    ref,
                    trial: widget.trial,
                    session: ref
                            .read(sessionByIdProvider(widget.session.id))
                            .valueOrNull ??
                        widget.session,
                  );
                case 'session_xml':
                  final ok = await confirmSessionExportTrust(
                    context: context,
                    ref: ref,
                    trialId: widget.trial.id,
                    sessionId: widget.session.id,
                  );
                  if (!context.mounted) return;
                  if (!ok) return;
                  await runSessionArmXmlExport(
                    context,
                    ref,
                    trial: widget.trial,
                    session: ref
                            .read(sessionByIdProvider(widget.session.id))
                            .valueOrNull ??
                        widget.session,
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
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'share_summary',
                child: ListTile(
                  leading: Icon(Icons.text_snippet_outlined, size: 20),
                  title: Text('Share text summary', style: TextStyle(fontSize: 14)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const PopupMenuItem(
                value: 'fer_pdf',
                child: ListTile(
                  leading: Icon(Icons.summarize_outlined, size: 20),
                  title: Text('Field execution report (PDF)', style: TextStyle(fontSize: 14)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const PopupMenuItem(
                value: 'session_csv',
                child: ListTile(
                  leading: Icon(Icons.table_chart_outlined, size: 20),
                  title: Text('Export session data (CSV)', style: TextStyle(fontSize: 14)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              if (isSessionXmlExportAvailable(liveSession ?? widget.session))
                const PopupMenuItem(
                  value: 'session_xml',
                  child: ListTile(
                    leading: Icon(Icons.code_outlined, size: 20),
                    title: Text('Export session (XML)', style: TextStyle(fontSize: 14)),
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

                // Hub grid + filters use [dataPlots] only — same set as the header
                // "N plots" count (guard rows and excludeFromAnalysis plots are omitted).
                final hubPlots = dataPlots;

                // Per-plot rating map for hub filters
                final ratingsByPlot = <int, List<RatingRecord>>{};
                for (final r in ratings) {
                  ratingsByPlot.putIfAbsent(r.plotPk, () => []).add(r);
                }

                // Unique reps among data plots (matches filter / grid scope)
                final reps = hubPlots
                    .map((p) => p.rep)
                    .whereType<int>()
                    .toSet()
                    .toList()
                  ..sort();

                final filteredPlots = _anyHubFilterActive
                    ? applyPlotQueueFilters(
                        plotsInWalkOrder: hubPlots,
                        ratedPks: ratedPks,
                        ratingsByPlot: ratingsByPlot,
                        flaggedIds: flaggedIds,
                        correctionPlotPks: correctionPks,
                        repFilter: _repFilter,
                        unratedOnly: _filterUnratedOnly,
                        issuesOnly: _filterIssuesOnly,
                        editedOnly: _filterEditedOnly,
                        flaggedOnly: _filterFlaggedOnly,
                      )
                    : hubPlots;

                // Stats footer counts track the visible filtered set.
                final footerCounts = countPlotStatus(
                  plots: filteredPlots,
                  ratingsByPlot: ratingsByPlot,
                  ratedPks: ratedPks,
                  flaggedIds: flaggedIds,
                  correctionPlotPks: correctionPks,
                );

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

                // Treatment codes + check IDs for grid labels
                final treatmentCodes = <int, String>{
                  for (final t in treatments)
                    t.id: t.code.isNotEmpty ? t.code : t.name,
                };
                final checkTreatmentIds = <int>{
                  for (final t in treatments)
                    if (_isCheckTreatment(t)) t.id,
                };

                // Per-assessment coverage for header bars
                final coverageRows =
                    computeSessionSummaryAssessmentCoverage(
                  plotsForTrial: plots,
                  sessionAssessments: assessments,
                  currentSessionRatings: ratings,
                );
                final assessmentCoverage = <int, double>{
                  for (final c in coverageRows)
                    c.assessmentId: c.progressFraction,
                };

                // Treatment colors from palette (same source as plot layout)
                final sortedTrts = treatments.toList()
                  ..sort((a, b) => a.code.compareTo(b.code));
                final treatmentColorMap = <int, Color>{
                  for (var i = 0; i < sortedTrts.length; i++)
                    sortedTrts[i].id: AppDesignTokens.treatmentPalette[
                        i % AppDesignTokens.treatmentPalette.length],
                };

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status bar with inline chips + close session
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: const BoxDecoration(
                        color: AppDesignTokens.sectionHeaderBg,
                        border: Border(
                            bottom: BorderSide(
                                color: AppDesignTokens.borderCrisp)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top line: counts + share + close button
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${assessments.length} assessment${assessments.length == 1 ? '' : 's'} · '
                                  '$dataPlotCount plots',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              // Share menu: session PDF (existing) or
                              // trial-wide ratings (CSV / TSV-to-clipboard).
                              SizedBox(
                                width: 32,
                                height: 28,
                                child: _isExporting
                                    ? const Padding(
                                        padding: EdgeInsets.all(7),
                                        child: SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      )
                                    : PopupMenuButton<String>(
                                        padding: EdgeInsets.zero,
                                        iconSize: 18,
                                        tooltip: 'Share',
                                        icon: const Icon(Icons.share_outlined),
                                        onSelected: (value) {
                                          switch (value) {
                                            case 'pdf':
                                              _exportGridPdf(
                                                plots: plots,
                                                assessments: assessments,
                                                ratings: ratings,
                                                assessmentDisplayNames:
                                                    assessmentDisplayNames,
                                                plotTreatmentMap:
                                                    plotTreatmentMap,
                                                treatmentNames:
                                                    treatmentNames,
                                                completedPlots:
                                                    report?.completedPlots,
                                                expectedPlots:
                                                    report?.expectedPlots,
                                              );
                                              break;
                                            case 'csv':
                                              _exportTrialRatingsCsv();
                                              break;
                                            case 'tsv':
                                              _copyTrialRatingsTsv();
                                              break;
                                          }
                                        },
                                        itemBuilder: (ctx) => const [
                                          PopupMenuItem<String>(
                                            value: 'pdf',
                                            child: ListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              leading: Icon(
                                                  Icons.picture_as_pdf_outlined,
                                                  size: 20),
                                              title: Text('Share session grid (PDF)'),
                                              subtitle: Text('This session only'),
                                            ),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'csv',
                                            child: ListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              leading: Icon(
                                                  Icons.table_chart_outlined,
                                                  size: 20),
                                              title: Text('Share ratings (CSV)'),
                                              subtitle:
                                                  Text('Whole trial · opens in Excel'),
                                            ),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'tsv',
                                            child: ListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              leading:
                                                  Icon(Icons.content_copy_outlined,
                                                      size: 20),
                                              title: Text('Copy ratings to clipboard'),
                                              subtitle: Text(
                                                  'Whole trial · paste into a sheet'),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                              const SizedBox(width: 4),
                              if (isOpen && canClose)
                                SizedBox(
                                  height: 28,
                                  child: FilledButton.icon(
                                    onPressed:
                                        _isClosing ? null : _closeSession,
                                    icon: _isClosing
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child:
                                                CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white),
                                          )
                                        : const Icon(Icons.lock_outline,
                                            size: 14),
                                    label: const Text('Close',
                                        style: TextStyle(fontSize: 11)),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      backgroundColor:
                                          AppDesignTokens.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Inline chips row
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              // Completeness chip
                              if (report != null &&
                                  report.expectedPlots > 0)
                                _StatusChip(
                                  label:
                                      '${report.completedPlots}/${report.expectedPlots} complete',
                                  color: report.incompletePlots == 0
                                      ? Colors.green
                                      : Colors.orange,
                                  onTap: () => showSessionCompletenessSheet(
                                      context, widget.trial, widget.session),
                                ),
                              // Blockers
                              if (blockerCount > 0)
                                _StatusChip(
                                  label:
                                      '$blockerCount blocker${blockerCount == 1 ? '' : 's'}',
                                  color: Colors.red,
                                  onTap: () => showSessionCompletenessSheet(
                                      context, widget.trial, widget.session),
                                ),
                              // Edited
                              if (editedCount > 0)
                                _StatusChip(
                                  label: '$editedCount edited',
                                  color: Colors.blueGrey,
                                ),
                              // Outliers
                              if (outlierKeys.isNotEmpty)
                                _StatusChip(
                                  label:
                                      '${outlierKeys.length} outlier${outlierKeys.length == 1 ? '' : 's'}',
                                  color: Colors.amber.shade800,
                                ),
                              // Session state
                              if (!isOpen)
                                const _StatusChip(
                                  label: 'Closed',
                                  color: Colors.green,
                                )
                              else if (canClose)
                                const _StatusChip(
                                  label: 'Ready to close',
                                  color: Colors.green,
                                ),
                            ],
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
                            onTap: () => setState(() {
                              _showTreatments = true;
                              _selectedTreatmentId = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                    // Hub review filter strip (plots view only)
                    if (!_showTreatments)
                      HubReviewFilterStrip(
                        reps: reps,
                        repFilter: _repFilter,
                        unratedOnly: _filterUnratedOnly,
                        issuesOnly: _filterIssuesOnly,
                        editedOnly: _filterEditedOnly,
                        flaggedOnly: _filterFlaggedOnly,
                        anyActive: _anyHubFilterActive,
                        onRepSelected: (r) => setState(
                            () => _repFilter = r == _repFilter ? null : r),
                        onUnratedToggle: () => setState(
                            () => _filterUnratedOnly = !_filterUnratedOnly),
                        onIssuesToggle: () => setState(
                            () => _filterIssuesOnly = !_filterIssuesOnly),
                        onEditedToggle: () => setState(
                            () => _filterEditedOnly = !_filterEditedOnly),
                        onFlaggedToggle: () => setState(
                            () => _filterFlaggedOnly = !_filterFlaggedOnly),
                        onReset: _clearHubFilters,
                      ),
                    // Treatment highlight strip — plots view only, when trial has treatments
                    if (!_showTreatments && treatments.isNotEmpty)
                      _TreatmentHighlightStrip(
                        treatments: treatments,
                        selectedTreatmentId: _selectedTreatmentId,
                        treatmentColors: treatmentColorMap,
                        onTreatmentSelected: (id) => setState(() {
                          _selectedTreatmentId =
                              _selectedTreatmentId == id ? null : id;
                        }),
                        onClear: () =>
                            setState(() => _selectedTreatmentId = null),
                      ),
                    if (!_showTreatments && _anyHubFilterActive)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                        child: Text(
                          'Showing ${filteredPlots.length} of ${hubPlots.length} plots',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                    // Content
                    Expanded(
                      child: _showTreatments
                          ? _buildTreatmentView(plots, assessments,
                              ratings, assessmentDisplayNames)
                          : (_anyHubFilterActive && filteredPlots.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.filter_list_off,
                                        size: 48,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outlineVariant,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No plots match these filters.',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: _clearHubFilters,
                                        child: const Text('Clear filters'),
                                      ),
                                    ],
                                  ),
                                )
                              : SessionDataGrid(
                                  plots: filteredPlots,
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
                              treatmentCodes: treatmentCodes,
                              checkTreatmentIds: checkTreatmentIds,
                              assessmentCoverage: assessmentCoverage,
                              treatmentColors: treatmentColorMap,
                              highlightedTreatmentId: _selectedTreatmentId,
                            )),
                    ),
                    // Stats footer — tracks the visible filtered set (plots view only)
                    if (!_showTreatments && filteredPlots.isNotEmpty)
                      _GridStatsFooter(counts: footerCounts),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static bool _isCheckTreatment(Treatment t) {
    final code = t.code.trim().toUpperCase();
    if (code == 'CHK' || code == 'UTC' || code == 'CONTROL') return true;
    final type = t.treatmentType?.trim().toUpperCase();
    if (type == 'CHK' || type == 'UTC' || type == 'CONTROL') return true;
    return false;
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

/// Compact single-line stats bar below the session grid.
/// Counts are derived from the currently visible (filtered) plot set so the
/// numbers always match what the grid is showing.
class _GridStatsFooter extends StatelessWidget {
  const _GridStatsFooter({required this.counts});

  final SessionPlotCounts counts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final parts = <String>[
      '${counts.rated} rated',
      '${counts.unrated} unrated',
      if (counts.withIssues > 0)
        '${counts.withIssues} ${counts.withIssues == 1 ? 'issue' : 'issues'}',
      if (counts.edited > 0) '${counts.edited} edited',
      if (counts.flagged > 0) '${counts.flagged} flagged',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: AppDesignTokens.sectionHeaderBg,
        border: Border(
          top: BorderSide(color: AppDesignTokens.borderCrisp),
        ),
      ),
      child: Text(
        parts.join(' · '),
        style: TextStyle(
          fontSize: 11,
          color: scheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
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
    final divergencesAsync =
        ref.watch(protocolDivergenceProvider(trial.id));
    final anchorsAsync = ref.watch(evidenceAnchorsProvider(trial.id));
    final ratingsAsync = ref.watch(sessionRatingsProvider(session.id));
    final ratedPksAsync = ref.watch(ratedPlotPksProvider(session.id));
    final flaggedAsync =
        ref.watch(flaggedPlotIdsForSessionProvider(session.id));
    final correctionsAsync =
        ref.watch(plotPksWithCorrectionsForSessionProvider(session.id));
    final assessmentsAsync = ref.watch(sessionAssessmentsProvider(session.id));
    final behaviourAsync =
        ref.watch(behavioralSignatureProvider(session.id));

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

                        final counts = countPlotStatus(
                          plots: rawPlots,
                          ratingsByPlot: ratingsByPlot,
                          ratedPks: ratedPks,
                          flaggedIds: flaggedIds,
                          correctionPlotPks: correctionPlotPks,
                        );
                        final ratedCount = counts.rated;
                        final notRatedCount = counts.unrated;
                        final flaggedCount = counts.flagged;
                        final issuesPlotCount = counts.withIssues;
                        final editedPlotCount = counts.edited;

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

                        final sessionAnchor = anchorsAsync.valueOrNull
                            ?.where((a) =>
                                a.eventId == session.id.toString() &&
                                a.eventType == EvidenceEventType.session)
                            .firstOrNull;

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
                                label: 'Review plot coverage',
                                child: GestureDetector(
                                  onTap: () => showSessionCompletenessSheet(
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
                                              'Not ready to close — tap to review plot coverage.',
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
                                              '${warningCount == 1 ? '1 warning' : '$warningCount warnings'} — see plot coverage.',
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
                                                showSessionCompletenessSheet(
                                              context,
                                              trial,
                                              session,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Text(
                                          'Tap to review plot-by-plot coverage.',
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
                            if (behaviourAsync.valueOrNull?.isNotEmpty ==
                                true) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppCard(
                                  padding: const EdgeInsets.all(
                                      AppDesignTokens.spacing16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _SectionTitle('Session Behaviour'),
                                      const SizedBox(height: 4),
                                      const _CaptionHint(
                                        'How ratings were recorded over the course of this session.',
                                      ),
                                      const SizedBox(height: 10),
                                      for (final signal
                                          in behaviourAsync.value!) ...[
                                        _BehaviouralSignalRow(
                                            interpretBehavioralSignal(signal)),
                                        const SizedBox(
                                            height:
                                                AppDesignTokens.spacing12),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (divergencesAsync.valueOrNull?.isNotEmpty ==
                                true) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppCard(
                                  padding: const EdgeInsets.all(
                                      AppDesignTokens.spacing16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _CardHeaderRow(
                                          title: 'Protocol Differences'),
                                      const SizedBox(height: 10),
                                      for (final d
                                          in divergencesAsync.value!) ...[
                                        _ProtocolDifferenceRow(
                                            interpretProtocolDivergence(d)),
                                        const SizedBox(
                                            height:
                                                AppDesignTokens.spacing12),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (sessionAnchor != null) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppCard(
                                  padding: const EdgeInsets.all(
                                      AppDesignTokens.spacing16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _SectionTitle(
                                          'Evidence captured'),
                                      const SizedBox(height: 10),
                                      _EvidenceRow('Photos',
                                          sessionAnchor.photoIds.isNotEmpty),
                                      _EvidenceRow(
                                          'GPS', sessionAnchor.hasGps),
                                      _EvidenceRow('Weather',
                                          sessionAnchor.hasWeather),
                                      _EvidenceRow('Timestamp',
                                          sessionAnchor.hasTimestamp),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
                                onPressed: () => showSessionCompletenessSheet(
                                    context, trial, session),
                                child: const Text('Review Plot Coverage'),
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

class _ProtocolDifferenceRow extends StatelessWidget {
  const _ProtocolDifferenceRow(this.message);

  final DivergenceMessage message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppDesignTokens.primaryText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          message.description,
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _BehaviouralSignalRow extends StatelessWidget {
  const _BehaviouralSignalRow(this.message);

  final BehavioralMessage message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppDesignTokens.primaryText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          message.description,
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

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

class _CropInjuryResult {
  const _CropInjuryResult({required this.status, this.notes});
  final String status;
  final String? notes;
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow(this.label, this.present);

  final String label;
  final bool present;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            present ? 'Yes' : 'No',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CropInjuryOption extends StatelessWidget {
  const _CropInjuryOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppDesignTokens.borderCrisp),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Treatment highlight strip
// ---------------------------------------------------------------------------

/// Compact horizontal chip strip for selecting a treatment to highlight
/// in the plots grid. Shown only in Plots view when the trial has treatments.
class _TreatmentHighlightStrip extends StatelessWidget {
  const _TreatmentHighlightStrip({
    required this.treatments,
    required this.selectedTreatmentId,
    required this.treatmentColors,
    required this.onTreatmentSelected,
    required this.onClear,
  });

  final List<Treatment> treatments;
  final int? selectedTreatmentId;
  final Map<int, Color> treatmentColors;
  final void Function(int id) onTreatmentSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sorted = treatments.toList()
      ..sort((a, b) => a.code.compareTo(b.code));

    return Container(
      height: 36,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppDesignTokens.borderCrisp),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Highlight:',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 6),
            for (final t in sorted) ...[
              _TreatmentHighlightChip(
                label: t.code.isNotEmpty ? t.code : t.name,
                selected: selectedTreatmentId == t.id,
                color: treatmentColors[t.id] ?? AppDesignTokens.primary,
                onTap: () => onTreatmentSelected(t.id),
              ),
              const SizedBox(width: 4),
            ],
            if (selectedTreatmentId != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Semantics(
                  label: 'Clear treatment highlight',
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TreatmentHighlightChip extends StatelessWidget {
  const _TreatmentHighlightChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : AppDesignTokens.borderCrisp,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected
                  ? color
                  : Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
