import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/plot_analysis_eligibility.dart';
import '../../core/diagnostics/diagnostic_finding.dart';
import '../../core/diagnostics/unified_severity.dart';
import '../../core/session_state.dart';
import '../../core/trial_state.dart';
import '../../core/trial_review_invalidation.dart';
import '../../core/workspace/workspace_config.dart';
import '../../core/providers.dart';
import '../../core/design/app_design_tokens.dart';
import '../sessions/create_session_screen.dart';
import '../sessions/session_repository.dart';
import '../sessions/domain/session_close_attention_summary.dart';
import '../sessions/domain/session_close_policy_result.dart';
import '../sessions/domain/session_completeness_report.dart';
import '../sessions/session_summary_screen.dart';
import '../plots/plot_queue_screen.dart';
import 'full_protocol_details_screen.dart';
import 'plot_layout_model.dart';
import '../diagnostics/trial_readiness.dart';
import '../../shared/layout/responsive_layout.dart';
import '../../core/export_guard.dart';
import '../export/arm_export_preflight_screen.dart';
import '../export/export_format.dart';
import '../export/export_trial_usecase.dart';
import '../../core/widgets/loading_error_widgets.dart';
import '../../shared/widgets/app_empty_state.dart';
import 'tabs/assessments_tab.dart';
import 'tabs/applications_tab.dart';
import 'tabs/treatments_tab.dart';
import 'tabs/seeding_tab.dart';
import 'tabs/plots_tab.dart';
import 'tabs/photos_tab.dart';
import 'tabs/trial_intent_sheet.dart';
import 'tabs/timeline_tab.dart';
import 'tabs/trial_overview/trial_overview_tab.dart';
import 'trial_data_screen.dart';
import 'trial_setup_screen.dart';
import 'widgets/insight_row.dart';
import 'widgets/export_format_sheet.dart';
import 'widgets/site_details_card.dart';
import '../diagnostics/completeness_dashboard_screen.dart';
import '../more/more_backup_actions.dart';
import '../diagnostics/audit_log_screen.dart';
import '../derived/derived_snapshot_provider.dart'
    show derivedSnapshotForSessionProvider;
import '../derived/trial_attention_provider.dart';
import '../derived/trial_attention_service.dart';
import '../../domain/models/trial_insight.dart';
import '../backup/backup_reminder_store.dart';
import '../notes/field_notes_list_screen.dart';
import '../../domain/relationships/protocol_divergence_provider.dart';
import '../../domain/relationships/evidence_anchors_provider.dart';
import '../../domain/trial_cognition/regulatory_context_value.dart';
import '../../domain/trial_cognition/trial_purpose_dto.dart';
import '../sessions/session_close_signal_writers.dart';
import '../sessions/widgets/session_close_diagnostic.dart';
import '../weather/weather_capture_form.dart';
import '../../data/repositories/weather_snapshot_repository.dart';

part 'widgets/sessions_view.dart';
part 'widgets/trial_module_hub.dart';
part 'widgets/pinned_trial_status_bar.dart';
part 'widgets/trial_readiness_sheet.dart';
part 'widgets/overview_identity_design_cards.dart';
part 'widgets/overview_tab_widgets.dart';
part 'widgets/trial_export_menu.dart';
part 'widgets/trial_action_menu.dart';
part 'widgets/trial_notes_header_button.dart';

/// Key for persisting that the trial module hub one-time scroll hint was seen or dismissed.
const String _kTrialHubHintDismissedKey = 'trial_module_hub_hint_dismissed';

/// Maps each TrialTab to its fixed IndexedStack position.
@visibleForTesting
const Map<TrialTab, int> kTrialTabToStackIndex = {
  TrialTab.plots: 0,
  TrialTab.seeding: 1,
  TrialTab.applications: 2,
  TrialTab.assessments: 3,
  TrialTab.treatments: 4,
  TrialTab.photos: 5,
  TrialTab.timeline: 6,
};

/// Maps visible TrialTab values to their fixed IndexedStack indices.
List<int> _visibleFixedIndices(WorkspaceConfig config) {
  return config.visibleTabs
      .map((t) => kTrialTabToStackIndex[t])
      .whereType<int>()
      .toList();
}

/// Fixed stack index for the Overview tab (Phase A scaffold).
const int _overviewTabIndex = 8;

/// Fixed stack index for the ARM Protocol tab (ARM-linked trials only).
const int _armProtocolTabIndex = 9;

/// Fixed stack index for the Trial Overview intelligence tab (Sprint A4).
const int _trialOverviewTabIndex = 10;

/// Computes effective selected index: prefers candidate if visible, else first visible, else Overview.
/// [candidate] == [_overviewTabIndex] always passes through (Overview is not in [visibleIndices]).
/// [candidate] == [_armProtocolTabIndex] always passes through (ARM Protocol is not in [visibleIndices]).
/// [candidate] == [_trialOverviewTabIndex] always passes through.
int _effectiveSelectedIndex({
  required int candidate,
  required List<int> visibleIndices,
}) {
  if (candidate == _overviewTabIndex) return _overviewTabIndex;
  if (candidate == _armProtocolTabIndex) return _armProtocolTabIndex;
  if (candidate == _trialOverviewTabIndex) return _trialOverviewTabIndex;
  if (visibleIndices.isEmpty) return _overviewTabIndex;
  if (visibleIndices.contains(candidate)) return candidate;
  return visibleIndices.first;
}

/// Sanitizes a tab index for the given trial: visible module tab, Overview (8),
/// ARM Protocol (9), or Trial Overview (10).
int _sanitizeTabIndexForTrial(int index, Trial trial) {
  if (index == _overviewTabIndex) return _overviewTabIndex;
  if (index == _armProtocolTabIndex) return _armProtocolTabIndex;
  if (index == _trialOverviewTabIndex) return _trialOverviewTabIndex;
  final config = safeConfigFromString(trial.workspaceType);
  final visible = _visibleFixedIndices(config);
  if (visible.isEmpty) return _overviewTabIndex;
  if (visible.contains(index)) return index;
  return visible.first;
}

/// Single date format for session bar (e.g. "Mar 17"). Never show raw ISO.
String _formatSessionDateLocal(String sessionDateLocal) {
  try {
    final dt = DateTime.parse(sessionDateLocal);
    return DateFormat('MMM d').format(dt);
  } catch (_) {
    return '';
  }
}

/// Session label for strip: strip leading ISO date so we don't duplicate date.
String _sessionDisplayLabel(Session session) {
  final name = session.name.trim();
  final stripped =
      name.replaceFirst(RegExp(r'^\d{4}-\d{2}-\d{2}\s*'), '').trim();
  return stripped.isNotEmpty ? stripped : 'Session';
}

/// Pill colors for the pinned trial status chrome (filled chip, no border).
({Color bg, Color fg}) _trialStatusChromePillColors(String status) {
  switch (status) {
    case kTrialStatusDraft:
      return (
        bg: const Color(0xFFE5E7EB),
        fg: AppDesignTokens.primaryText,
      );
    case kTrialStatusReady:
      return (
        bg: const Color(0xFF2563EB),
        fg: Colors.white,
      );
    case kTrialStatusActive:
      return (
        bg: AppDesignTokens.primaryGreen,
        fg: Colors.white,
      );
    case kTrialStatusClosed:
    case kTrialStatusArchived:
      return (
        bg: const Color(0xFF4B5563),
        fg: Colors.white,
      );
    default:
      return (
        bg: AppDesignTokens.emptyBadgeBg,
        fg: AppDesignTokens.primaryText,
      );
  }
}

/// Single entry point for the Trial Readiness dashboard. Both states of
/// the Needs Attention card's CTA ("Review issues" / "View readiness")
/// route here — kept in one helper so the navigation target can't drift
/// between callers.
void _openCompletenessDashboard(BuildContext context, Trial trial) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => CompletenessDashboardScreen(trial: trial),
    ),
  );
}

/// Shared title style for Overview dashboard cards (Trial Completion, Readiness, Session, Plots).
TextStyle _overviewDashboardCardTitleStyle() => AppDesignTokens.headingStyle(
      fontSize: 15,
      color: AppDesignTokens.primaryText,
    );

/// Vertical margin for each Overview dashboard card (keep rhythm consistent).
const EdgeInsets _kOverviewDashboardCardMargin = EdgeInsets.fromLTRB(
  AppDesignTokens.spacing16,
  AppDesignTokens.spacing8,
  AppDesignTokens.spacing16,
  AppDesignTokens.spacing8,
);

/// White bordered card with internal top-left title + body (Overview tab only).

class TrialDetailScreen extends ConsumerStatefulWidget {
  final Trial trial;

  /// Optional tab to select on mount. Sanitized for trial's visible tabs.
  final int? initialTabIndex;

  const TrialDetailScreen({
    super.key,
    required this.trial,
    this.initialTabIndex,
  });

  @override
  ConsumerState<TrialDetailScreen> createState() => _TrialDetailScreenState();
}

class _TrialDetailScreenState extends ConsumerState<TrialDetailScreen> {
  int _selectedTabIndex = _overviewTabIndex;
  int _previousTabIndex = 0;
  static const int _sessionsIndex = 7;

  static const Duration _hubHintDelay = Duration(milliseconds: 600);
  static const Duration _hubHintScrollDuration = Duration(milliseconds: 450);
  static const Duration _hubHintPause = Duration(milliseconds: 400);
  static const double _hubHintRevealOffset = 140.0;

  late final ScrollController _hubScrollController;
  bool _programmaticScroll = false;
  bool _hintCancelled = false;
  Timer? _hintSchedule;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTabIndex != null) {
      _selectedTabIndex = _sanitizeTabIndexForTrial(
        widget.initialTabIndex!,
        widget.trial,
      );
    }
    _hubScrollController = ScrollController();
    _hubScrollController.addListener(_onHubScroll);
    _scheduleHubHintOnce();
    _backfillArmSessionNamesOnce();
  }

  /// Eager one-shot rename of legacy "Planned — $date" session names for this
  /// trial so the session tiles show assessment-based labels without waiting
  /// for the user to open each session. Invalidates sessions provider on
  /// success so the list rebuilds with the new names.
  Future<void> _backfillArmSessionNamesOnce() async {
    try {
      final renamed = await ref
          .read(sessionRepositoryProvider)
          .backfillArmPlannedSessionNames(widget.trial.id);
      if (!mounted || renamed == 0) return;
      ref.invalidate(sessionsForTrialProvider(widget.trial.id));
    } catch (_) {
      // Best-effort cleanup; never block the screen on this.
    }
  }

  void _onHubScroll() {
    if (_programmaticScroll) return;
    _dismissHubHint();
  }

  void _dismissHubHint() {
    if (_hintCancelled) return;
    _hintCancelled = true;
    _persistHubHintDismissed();
  }

  Future<void> _persistHubHintDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTrialHubHintDismissedKey, true);
  }

  void _scheduleHubHintOnce() {
    SharedPreferences.getInstance().then((prefs) {
      final alreadySeen = prefs.getBool(_kTrialHubHintDismissedKey) ?? false;
      if (!mounted || alreadySeen) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _hintSchedule = Timer(_hubHintDelay, () {
          if (mounted && !_hintCancelled) _runHubHintAnimation();
        });
      });
    });
  }

  Future<void> _runHubHintAnimation() async {
    if (_hintCancelled || !mounted) return;
    if (!_hubScrollController.hasClients) return;
    final position = _hubScrollController.position;
    final targetOffset =
        _hubHintRevealOffset.clamp(0.0, position.maxScrollExtent);
    if (targetOffset <= 0) return;

    setState(() => _programmaticScroll = true);
    try {
      await _hubScrollController.animateTo(
        targetOffset,
        duration: _hubHintScrollDuration,
        curve: Curves.easeInOut,
      );
      if (_hintCancelled || !mounted) return;
      await Future<void>.delayed(_hubHintPause);
      if (_hintCancelled || !mounted) return;
      await _hubScrollController.animateTo(
        0,
        duration: _hubHintScrollDuration,
        curve: Curves.easeInOut,
      );
    } finally {
      if (mounted) {
        setState(() => _programmaticScroll = false);
        _persistHubHintDismissed();
      }
    }
  }

  @override
  void dispose() {
    _hintSchedule?.cancel();
    _hubScrollController.removeListener(_onHubScroll);
    _hubScrollController.dispose();
    super.dispose();
  }

  Future<ExportFormat?> _showExportSheet(
      List<ExportFormat> allowedFormats) async {
    return showModalBottomSheet<ExportFormat>(
      context: context,
      showDragHandle: false,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ExportFormatSheet(
        trial: widget.trial,
        allowedFormats: allowedFormats,
      ),
    );
  }

  Future<void> _runExport(ExportFormat format) async {
    final armLinked = ref
            .read(armTrialMetadataStreamProvider(widget.trial.id))
            .valueOrNull
            ?.isArmLinked ??
        false;
    if (format == ExportFormat.armRatingShell && !armLinked) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Excel Rating Sheet export is only available for imported trials.',
            ),
          ),
        );
      }
      return;
    }
    final readinessReport =
        await ref.read(trialReadinessProvider(widget.trial.id).future);
    if (!readinessReport.canExport) {
      if (mounted) {
        _showReadinessSheet(
          context,
          ref,
          widget.trial,
          readinessReport,
          showExportAnyway: false,
        );
      }
      return;
    }
    if (format == ExportFormat.armRatingShell) {
      if (!mounted) return;
      final result = await Navigator.push<String?>(
        context,
        MaterialPageRoute<String?>(
          builder: (_) => ArmExportPreflightScreen(trial: widget.trial),
        ),
      );
      if (!mounted) return;
      if (result == null) return;
      final trimmed = result.trim();
      if (trimmed.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export ready to share')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trimmed)),
        );
      }
      return;
    }
    final guard = ref.read(exportGuardProvider);
    final ran = await guard.runExclusive(() async {
      setState(() => _isExporting = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exporting...')),
        );
      }
      try {
        if (format == ExportFormat.pdfReport) {
          final useCase = ref.read(exportTrialPdfReportUseCaseProvider);
          await useCase.execute(trial: widget.trial);
          if (!mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export ready to share')),
          );
          return;
        }
        if (format == ExportFormat.evidenceReport) {
          final useCase = ref.read(exportEvidenceReportUseCaseProvider);
          await useCase.execute(trial: widget.trial);
          if (!mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Evidence report ready to share')),
          );
          return;
        }
        if (format == ExportFormat.trialReport) {
          final useCase = ref.read(exportTrialReportUseCaseProvider);
          await useCase.execute(trial: widget.trial);
          if (!mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trial report ready to share')),
          );
          return;
        }
        if (format == ExportFormat.trialDefensibility) {
          final useCase = ref.read(exportTrialDefensibilityUseCaseProvider);
          await useCase.execute(trial: widget.trial);
          if (!mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trial defensibility summary ready to share'),
            ),
          );
          return;
        }
        final useCase = ref.read(exportTrialUseCaseProvider);
        final bundle = await useCase.execute(
          trial: widget.trial,
          format: format,
          trialReadinessPrecheck: readinessReport,
        );
        if (!mounted) return;
        // Flat CSV path unchanged: write files and share
        if (format == ExportFormat.flatCsv) {
          final trial = widget.trial;
          final dir = await getTemporaryDirectory();
          final safeBase = trial.name.replaceAll(RegExp(r'[^\w\s-]'), '_');
          final timestamp =
              DateFormat('yyyyMMdd_HHmmss_SSS').format(DateTime.now());
          final base = '${safeBase}_export_$timestamp';
          final files = <XFile>[];
          final names = [
            'observations',
            'observations_arm_transfer',
            'treatments',
            'plot_assignments',
            'applications',
            'seeding',
            'sessions',
            'notes',
            'data_dictionary',
          ];
          final contents = [
            bundle.observationsCsv,
            bundle.observationsArmTransferCsv,
            bundle.treatmentsCsv,
            bundle.plotAssignmentsCsv,
            bundle.applicationsCsv,
            bundle.seedingCsv,
            bundle.sessionsCsv,
            bundle.notesCsv,
            bundle.dataDictionaryCsv,
          ];
          for (var i = 0; i < names.length; i++) {
            final path = '${dir.path}/${base}_${names[i]}.csv';
            await File(path).writeAsString(contents[i]);
            files.add(XFile(path));
          }
          if (!mounted) return;
          final box = context.findRenderObject() as RenderBox?;
          await Share.shareXFiles(
            files,
            text:
                '${trial.name} – trial CSV bundle (${files.length} files; see data_dictionary.csv)',
            sharePositionOrigin: box == null
                ? const Rect.fromLTWH(0, 0, 100, 100)
                : box.localToGlobal(Offset.zero) & box.size,
          );
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export ready to share')),
        );
      } on ExportBlockedByValidationException catch (e) {
        if (mounted) {
          final scheme = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Export blocked — resolve these issues first:\n${e.message}',
                style: TextStyle(color: scheme.onError),
              ),
              backgroundColor: scheme.error,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      } on ExportBlockedByReadinessException catch (e) {
        if (mounted) {
          final scheme = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Export blocked — ${e.message}',
                style: TextStyle(color: scheme.onError),
              ),
              backgroundColor: scheme.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Export failed — please try again. If the problem persists, check trial data for missing or incomplete records.',
              style: TextStyle(color: scheme.onError),
            ),
            backgroundColor: scheme.error,
          ),
        );
      } finally {
        if (mounted) setState(() => _isExporting = false);
      }
    });
    if (!ran && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(ExportGuard.busyMessage)),
      );
    }
  }

  Future<void> _onExportTapped(
      BuildContext context, WidgetRef ref, Trial trial) async {
    final trialArmLinked = ref
            .watch(armTrialMetadataStreamProvider(trial.id))
            .valueOrNull
            ?.isArmLinked ??
        false;
    final sheetFormats = exportFormatsForTrialSheet(
      trial.workspaceType,
      isArmLinked: trialArmLinked,
    );
    if (sheetFormats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No export options available for this trial.'),
          backgroundColor: Colors.amber.shade700,
        ),
      );
      return;
    }
    final report = await ref.read(trialReadinessProvider(trial.id).future);
    if (!context.mounted) return;
    if (report.blockerCount > 0) {
      _showReadinessSheet(context, ref, trial, report, showExportAnyway: false);
      return;
    }
    if (report.warningCount > 0) {
      _showReadinessSheet(context, ref, trial, report, showExportAnyway: true);
      return;
    }
    if (_trialExportPrecheckShowsInfos(report, trial) && context.mounted) {
      final go =
          await _showTrialExportPrecheckDialog(context, ref, trial, report);
      if (!context.mounted) return;
      if (go != true) return;
    }
    final format = await _showExportSheet(sheetFormats);
    if (!mounted || format == null) return;
    _runExport(format);
  }

  bool _trialExportPrecheckShowsInfos(
      TrialReadinessReport report, Trial trial) {
    final standalone = safeConfigFromString(trial.workspaceType).isStandalone;
    if (!standalone) return false;
    return report.checks.any((c) =>
        (c.code == 'no_seeding' || c.code == 'no_applications') &&
        c.severity == TrialCheckSeverity.info);
  }

  Future<bool?> _showTrialExportPrecheckDialog(
    BuildContext context,
    WidgetRef ref,
    Trial trial,
    TrialReadinessReport report,
  ) async {
    final completion =
        await ref.read(trialAssessmentCompletionProvider(trial.id).future);
    final plots = await ref.read(plotsForTrialProvider(trial.id).future);
    final rated =
        await ref.read(ratedPlotsCountForTrialProvider(trial.id).future);
    final nData = plots.where((p) => !p.isGuardRow).length;
    if (!context.mounted) return false;

    final lines = <Widget>[
      Text(
        '$rated/$nData data plots with any current rating',
        style: const TextStyle(fontSize: 14, height: 1.35),
      ),
    ];
    for (final e in ([...completion.entries]
      ..sort((a, b) => a.key.compareTo(b.key)))) {
      final c = e.value;
      final ok = c.isComplete;
      lines.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                size: 18,
                color:
                    ok ? AppDesignTokens.successFg : AppDesignTokens.warningFg,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${c.assessmentName}: ${c.ratedPlotCount}/${c.totalDataPlots} complete',
                  style: const TextStyle(fontSize: 14, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      );
    }
    for (final c in report.checks) {
      if (c.severity != TrialCheckSeverity.info) continue;
      if (c.code != 'no_seeding' && c.code != 'no_applications') continue;
      lines.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: AppDesignTokens.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.label,
                  style: const TextStyle(fontSize: 14, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ready to export'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: lines,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showReadinessSheet(
    BuildContext context,
    WidgetRef ref,
    Trial trial,
    TrialReadinessReport report, {
    required bool showExportAnyway,
  }) {
    final trialArmLinked = ref
            .watch(armTrialMetadataStreamProvider(trial.id))
            .valueOrNull
            ?.isArmLinked ??
        false;
    final sheetFormats = exportFormatsForTrialSheet(
      trial.workspaceType,
      isArmLinked: trialArmLinked,
    );
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (ctx) => TrialReadinessSheet(
        trialId: trial.id,
        report: report,
        showExportAnyway: showExportAnyway,
        onExport: () async {
          Navigator.pop(ctx);
          if (sheetFormats.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      const Text('No export options available for this trial.'),
                  backgroundColor: Colors.amber.shade700,
                ),
              );
            }
            return;
          }
          final format = await _showExportSheet(sheetFormats);
          if (!mounted || format == null) return;
          _runExport(format);
        },
        onClose: () => Navigator.pop(ctx),
        onOpenTrialReview: () {
          Navigator.pop(ctx);
          if (!mounted) return;
          setState(() {
            _selectedTabIndex = _trialOverviewTabIndex;
          });
        },
      ),
    );
  }

  /// Crop • cooperator • location under trial name (omits empty segments).
  String _trialSubtitleLine(Trial trial) {
    final parts = <String>[];
    if (trial.crop != null && trial.crop!.trim().isNotEmpty) {
      parts.add(trial.crop!.trim());
    }
    if (trial.cooperatorName != null &&
        trial.cooperatorName!.trim().isNotEmpty) {
      parts.add(trial.cooperatorName!.trim());
    }
    if (trial.location != null && trial.location!.trim().isNotEmpty) {
      parts.add(trial.location!.trim());
    }
    return parts.join(' • ');
  }

  /// White bar: Setup, Protocol, Export — trial-level actions.
  Widget _buildTrialDetailActionsBar(
    BuildContext context,
    WidgetRef ref,
    Trial trial,
  ) {
    final trialArmLinked = ref
            .watch(armTrialMetadataStreamProvider(trial.id))
            .valueOrNull
            ?.isArmLinked ??
        false;
    final showExport = exportFormatsForTrialSheet(
      trial.workspaceType,
      isArmLinked: trialArmLinked,
    ).isNotEmpty;
    final readinessAsync = ref.watch(trialReadinessProvider(trial.id));
    final showBadge = readinessAsync.valueOrNull != null &&
        (readinessAsync.value!.blockerCount > 0 ||
            readinessAsync.value!.warningCount > 0);
    final isBlocker = (readinessAsync.valueOrNull?.blockerCount ?? 0) > 0;
    final theme = Theme.of(context);
    return Material(
      color: AppDesignTokens.cardSurface,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppDesignTokens.borderCrisp),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => TrialSetupScreen(trial: trial),
                  ),
                ),
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: AppDesignTokens.primary,
                ),
                label: const Text(
                  'Setup',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppDesignTokens.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
              ),
            ),
            Container(
              width: 1,
              height: 28,
              color: AppDesignTokens.divider,
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => FullProtocolDetailsScreen(trial: trial),
                  ),
                ),
                icon: const Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: AppDesignTokens.primary,
                ),
                label: const Text(
                  'Trial Info',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppDesignTokens.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
              ),
            ),
            Container(
              width: 1,
              height: 28,
              color: AppDesignTokens.divider,
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => TrialDataScreen(trial: trial),
                  ),
                ),
                icon: const Icon(
                  Icons.bar_chart_outlined,
                  size: 20,
                  color: AppDesignTokens.primary,
                ),
                label: const Text(
                  'Data',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppDesignTokens.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
              ),
            ),
            if (showExport) ...[
              Container(
                width: 1,
                height: 28,
                color: AppDesignTokens.divider,
              ),
              Expanded(
                child: Tooltip(
                  message: exportEntryTooltipMessage(
                    trial.workspaceType,
                    isArmLinked: trialArmLinked,
                  ),
                  child: TrialExportMenu(
                    isExporting: _isExporting,
                    badgeColor: showBadge
                        ? (isBlocker
                            ? theme.colorScheme.error
                            : Colors.amber.shade700)
                        : null,
                    onExportTapped: () => _onExportTapped(context, ref, trial),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndSoftDeleteTrial(
      BuildContext context, Trial trial) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete trial'),
        content: const Text(
          'This trial will be moved to Recovery.\n\n'
          'All sessions in this trial will move to Recovery.\n\n'
          'All plots in this trial will move to Recovery.\n\n'
          'All ratings in this trial will move to Recovery.\n\n'
          'This affects the entire trial—not a single session or plot.\n\n'
          'You can restore this trial later from Recovery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete trial'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final user = await ref.read(currentUserProvider.future);
      final userId = await ref.read(currentUserIdProvider.future);
      await ref.read(trialRepositoryProvider).softDeleteTrial(
            trial.id,
            deletedBy: user?.displayName,
            deletedByUserId: userId,
          );
      if (!context.mounted) return;
      final trialId = trial.id;
      ref.invalidate(trialsStreamProvider);
      ref.invalidate(deletedTrialsProvider);
      ref.invalidate(trialProvider(trialId));
      ref.invalidate(trialSetupProvider(trialId));
      ref.invalidate(plotsForTrialProvider(trialId));
      ref.invalidate(sessionsForTrialProvider(trialId));
      ref.invalidate(openSessionProvider(trialId));
      ref.invalidate(deletedSessionsProvider);
      ref.invalidate(deletedPlotsProvider);
      ref.invalidate(lastSessionContextProvider);
      invalidateTrialReviewProviders(ref, trialId);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Trial moved to Recovery')),
      );
    } catch (e) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Could not delete trial'),
          content: SelectableText('$e'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final trialAsync = ref.watch(trialProvider(widget.trial.id));
    final currentTrial = trialAsync.valueOrNull ?? widget.trial;

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      body: Stack(
        children: [
          _buildSplitBody(
            context,
            ref,
            currentTrial,
          ),
          if (_isExporting)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      bottomNavigationBar: null,
    );
  }

  void _handleAttentionTap(AttentionItem item) {
    switch (item.type) {
      case AttentionType.openSession:
        ref
            .read(sessionsForTrialProvider(widget.trial.id).future)
            .then((sessions) {
          final open = sessions.where(isSessionOpenForFieldWork).toList();
          if (open.isNotEmpty && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => PlotQueueScreen(
                  trial: widget.trial,
                  session: open.first,
                ),
              ),
            );
          }
        });
        break;
      case AttentionType.noSessionsYet:
        tryOpenCreateSessionScreen(
          context: context,
          ref: ref,
          trial: widget.trial,
        );
        break;
      case AttentionType.seedingMissing:
      case AttentionType.seedingPending:
        setState(() => _selectedTabIndex = 1);
        break;
      case AttentionType.applicationsPending:
        setState(() => _selectedTabIndex = 2);
        break;
      case AttentionType.plotsUnassigned:
      case AttentionType.setupIncomplete:
      case AttentionType.plotsPartiallyRated:
      case AttentionType.dataCollectionComplete:
        setState(() => _selectedTabIndex = 0);
        break;
      case AttentionType.statisticalAnalysisPending:
        setState(() => _selectedTabIndex = 3);
        break;
    }
  }

  Widget _buildSplitBody(
    BuildContext context,
    WidgetRef ref,
    Trial currentTrial,
  ) {
    final workspaceConfig = safeConfigFromString(currentTrial.workspaceType);
    final visibleIndices = _visibleFixedIndices(workspaceConfig);
    final effectiveSelectedIndex = _effectiveSelectedIndex(
      candidate: _selectedTabIndex == _sessionsIndex
          ? _previousTabIndex
          : _selectedTabIndex,
      visibleIndices: visibleIndices,
    );
    final isArmLinked = ref
            .watch(armTrialMetadataStreamProvider(currentTrial.id))
            .valueOrNull
            ?.isArmLinked ==
        true;
    final armTabBuilder = ref.watch(armProtocolTabBuilderProvider);
    return Column(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppDesignTokens.primary,
                    AppDesignTokens.primaryLight,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDesignTokens.spacing16,
                    AppDesignTokens.spacing12,
                    AppDesignTokens.spacing16,
                    AppDesignTokens.spacing12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        iconSize: 24,
                        padding: const EdgeInsets.all(8),
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).maybePop(),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentTrial.name,
                              style: AppDesignTokens.headerTitleStyle(
                                fontSize: 20,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                              softWrap: true,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (currentTrial.protocolNumber != null &&
                                currentTrial.protocolNumber!
                                    .trim()
                                    .isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Protocol: ${currentTrial.protocolNumber!.trim()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.78),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (_trialSubtitleLine(currentTrial)
                                .isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _trialSubtitleLine(currentTrial),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.92),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppDesignTokens.spacing8),
                      TrialNotesHeaderButton(trial: currentTrial),
                      TrialActionMenu(
                        trial: currentTrial,
                        onDelete: () =>
                            _confirmAndSoftDeleteTrial(context, currentTrial),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildTrialDetailActionsBar(context, ref, currentTrial),
          ],
        ),
        PinnedTrialStatusBar(
          trial: currentTrial,
          onTransitionStatus: _transitionTrialStatus,
          onOpenSessions: () => setState(() {
            _previousTabIndex = _selectedTabIndex;
            _selectedTabIndex = _sessionsIndex;
          }),
        ),
        SizedBox(
          height: 90,
          child: TrialModuleHub(
            scrollController: _hubScrollController,
            workspaceConfig: workspaceConfig,
            isArmLinked: isArmLinked,
            selectedIndex: effectiveSelectedIndex,
            onSelected: (index) {
              setState(() => _selectedTabIndex = index);
            },
            onUserScroll: _dismissHubHint,
          ),
        ),
        Expanded(
          child: ResponsiveBody(
            child: IndexedStack(
              index: _selectedTabIndex == _sessionsIndex
                  ? _sessionsIndex
                  : effectiveSelectedIndex,
              children: [
                PlotsTab(
                  trial: currentTrial,
                  embeddedInScroll: false,
                  onSelectStackIndex: (index) {
                    setState(() {
                      _selectedTabIndex =
                          _sanitizeTabIndexForTrial(index, currentTrial);
                    });
                  },
                ),
                SeedingTab(trial: currentTrial),
                ApplicationsTab(trial: currentTrial),
                AssessmentsTab(trial: currentTrial),
                TreatmentsTab(trial: currentTrial),
                PhotosTab(trial: currentTrial),
                TimelineTab(trial: currentTrial),
                SessionsView(
                  trial: currentTrial,
                  onBack: () => setState(() {
                    _selectedTabIndex = _sanitizeTabIndexForTrial(
                        _previousTabIndex, currentTrial);
                  }),
                ),
                OverviewTabBody(
                  trial: currentTrial,
                  onAttentionTap: _handleAttentionTap,
                  onOpenSessions: () => setState(() {
                    _previousTabIndex = _selectedTabIndex;
                    _selectedTabIndex = _sessionsIndex;
                  }),
                ),
                // ARM Protocol tab at index 9 — only reachable when ARM-linked.
                armTabBuilder(currentTrial.id),
                // Trial Overview intelligence tab at index 10 (Sprint A4).
                TrialOverviewTab(
                  trial: currentTrial,
                  onSwitchTab: (tab) {
                    final idx = kTrialTabToStackIndex[tab];
                    if (idx == null) return;
                    setState(() {
                      _selectedTabIndex =
                          _sanitizeTabIndexForTrial(idx, currentTrial);
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _transitionTrialStatus(
      BuildContext context, WidgetRef ref, String newStatus) async {
    if (newStatus == kTrialStatusActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Activate Trial?'),
          content: const Text(
            'Activating this trial will lock trial structure. '
            'Plots, treatments, assessments, and assignments will no longer be editable. '
            'Data collection sessions can continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Activate Trial'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    if (newStatus == kTrialStatusClosed) {
      final sessions =
          await ref.read(sessionsForTrialProvider(widget.trial.id).future);
      if (sessions.any(isSessionOpenForFieldWork)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'End the active session before closing the trial.',
              ),
            ),
          );
        }
        return;
      }
      if (!context.mounted) return;

      // Run completeness check before closing.
      final report =
          await ref.read(trialReadinessProvider(widget.trial.id).future);
      if (!context.mounted) return;

      // Blockers prevent close.
      if (report.blockerCount > 0) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cannot close trial'),
            content: Text(
              '${report.blockerCount} blocker(s) must be resolved '
              'before closing.\n\nOpen Trial Readiness to review.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CompletenessDashboardScreen(trial: widget.trial),
                    ),
                  );
                },
                child: const Text('Review'),
              ),
            ],
          ),
        );
        return;
      }

      // Warnings: show but allow proceeding.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Close this trial?'),
          content: Text(
            report.warningCount > 0
                ? '${report.warningCount} advisor${report.warningCount == 1 ? 'y' : 'ies'} remain. '
                    'You can still close.\n\n'
                    'After closing:\n'
                    '• No new sessions can be started\n'
                    '• Corrections with reason still allowed\n'
                    '• Export remains available'
                : 'After closing:\n'
                    '• No new sessions can be started\n'
                    '• Corrections with reason still allowed\n'
                    '• Export remains available',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Close Trial'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;

      // Prompt for trial report generation.
      final generateReport = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Generate trial report?'),
          content: const Text(
            'Create a PDF trial report before closing?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Generate'),
            ),
          ],
        ),
      );
      if (!context.mounted) return;
      if (generateReport == true) {
        try {
          final useCase = ref.read(exportTrialReportUseCaseProvider);
          await useCase.execute(trial: widget.trial);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Report failed: $e')),
            );
          }
        }
        if (!context.mounted) return;
      }
    }
    final repo = ref.read(trialRepositoryProvider);
    final ok = await repo.updateTrialStatus(widget.trial.id, newStatus);
    if (!context.mounted) return;
    if (ok) {
      ref.invalidate(trialProvider(widget.trial.id));
      setState(() {});

      // Prompt backup after trial close.
      if (newStatus == kTrialStatusClosed && context.mounted) {
        final doBackup = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Trial closed'),
            content: const Text(
              'Create a backup now to preserve this trial?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Back Up'),
              ),
            ],
          ),
        );
        if (doBackup == true && context.mounted) {
          await runBackupFlow(context, ref);
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update trial status')),
      );
    }
  }
}

/// Pinned under the trial actions bar on every tab (split chrome).

class PinnedTrialStatusBarState extends ConsumerState<PinnedTrialStatusBar> {
  bool _standaloneOpenSessionPromoteInFlight = false;

  @override
  void didUpdateWidget(covariant PinnedTrialStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trial.id != widget.trial.id) {
      _standaloneOpenSessionPromoteInFlight = false;
    }
  }

  /// Legacy standalone Draft/Ready + open session: persist Active so the pill matches DB.
  void _maybePersistActiveWhenStandaloneOpenSession(
    Trial trial,
    bool hasOpenSession,
  ) {
    if (!hasOpenSession) {
      _standaloneOpenSessionPromoteInFlight = false;
      return;
    }
    if (!trialWorkspaceIsStandalone(trial.workspaceType)) return;
    if (trial.status != kTrialStatusDraft &&
        trial.status != kTrialStatusReady) {
      return;
    }
    if (_standaloneOpenSessionPromoteInFlight) return;
    _standaloneOpenSessionPromoteInFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        final latest = ref.read(trialProvider(trial.id)).valueOrNull ?? trial;
        if (!trialWorkspaceIsStandalone(latest.workspaceType)) return;
        if (latest.status != kTrialStatusDraft &&
            latest.status != kTrialStatusReady) {
          return;
        }
        await ref.read(trialRepositoryProvider).updateTrialStatus(
              trial.id,
              kTrialStatusActive,
            );
        if (mounted) ref.invalidate(trialProvider(trial.id));
      } finally {
        if (mounted) _standaloneOpenSessionPromoteInFlight = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final trial = widget.trial;
    final sessions =
        ref.watch(sessionsForTrialProvider(trial.id)).valueOrNull ?? [];
    final hasOpenSession = sessions.any(isSessionOpenForFieldWork);
    _maybePersistActiveWhenStandaloneOpenSession(trial, hasOpenSession);

    final statusClosedOrArchived = trial.status == kTrialStatusClosed ||
        trial.status == kTrialStatusArchived;
    final statusForDisplay = statusClosedOrArchived
        ? trial.status
        : (trial.status == kTrialStatusDraft ||
                trial.status == kTrialStatusReady ||
                hasOpenSession ||
                trial.status == kTrialStatusActive)
            ? kTrialStatusActive
            : trial.status;
    final nextStatuses = trialWorkspaceIsStandalone(trial.workspaceType)
        ? allowedNextTrialStatusesForTrial(trial.status, trial)
        : allowedNextTrialStatuses(trial.status);
    final nextStatus = nextStatuses.isNotEmpty ? nextStatuses.first : null;
    final bool hideLifecycleCta = statusClosedOrArchived;
    final buttonLabel = hideLifecycleCta
        ? null
        : nextStatus == kTrialStatusActive
            ? 'Begin Field Work'
            : nextStatus == kTrialStatusClosed
                ? 'Close Trial'
                : nextStatus == kTrialStatusArchived
                    ? 'Archive'
                    : null;
    final isDisplayActive = statusForDisplay == kTrialStatusActive;
    // Tone Active down: keep the green dot as the sole bright signal,
    // but render the surrounding pill in a muted tint with neutral dark text
    // so the whole status bar reads as calm chrome, not a banner.
    final pill = isDisplayActive
        ? (
            bg: AppDesignTokens.openSessionBgLight.withValues(alpha: 0.55),
            fg: AppDesignTokens.primaryText,
          )
        : _trialStatusChromePillColors(statusForDisplay);
    return Material(
      color: AppDesignTokens.sectionHeaderBg,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(
            top: const BorderSide(color: AppDesignTokens.borderCrisp),
            bottom: BorderSide(
              color: AppDesignTokens.divider.withValues(alpha: 0.9),
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isDisplayActive && nextStatus == kTrialStatusClosed)
              // Active ↔ Closed is a binary transition, so the status and
              // its action collapse into a single toggle switch: ON = Active,
              // flipping OFF runs the Close-Trial flow (which still guards
              // against open sessions and readiness blockers via dialogs).
              ActiveCloseToggle(
                onClose: () => widget.onTransitionStatus(
                  context,
                  ref,
                  kTrialStatusClosed,
                ),
              )
            else ...[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDisplayActive ? 8 : 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: pill.bg,
                  borderRadius: BorderRadius.circular(999),
                  border: isDisplayActive
                      ? Border.all(color: AppDesignTokens.borderCrisp)
                      : null,
                ),
                child: isDisplayActive
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppDesignTokens.openSessionBg,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            labelForTrialStatus(statusForDisplay),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: pill.fg,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        labelForTrialStatus(statusForDisplay),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: pill.fg,
                        ),
                      ),
              ),
              if (buttonLabel != null && nextStatus != null) ...[
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () =>
                      widget.onTransitionStatus(context, ref, nextStatus),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppDesignTokens.primaryText,
                    backgroundColor: Colors.transparent,
                    side: const BorderSide(
                      color: AppDesignTokens.borderCrisp,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.primaryText,
                    ),
                  ),
                ),
              ],
            ],
            const Spacer(),
            SessionsStatusBarButton(onTap: widget.onOpenSessions),
          ],
        ),
      ),
    );
  }
}

/// Segmented slide toggle that collapses the `Active` status pill and
/// the `Close Trial` CTA into one control. The highlighted thumb sits
/// over `Active` while the trial is live; tapping the `Close Trial`
/// side (or sliding the thumb across) hands off to the existing close
/// flow, which surfaces its own confirmation / blocker dialogs.

class ActiveCloseToggleState extends State<ActiveCloseToggle> {
  static const double _segmentWidth = 74;
  static const double _height = 26;
  static const double _padding = 2;

  double _dragDx = 0;
  bool _dragging = false;

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragging = true;
      _dragDx = (_dragDx + details.delta.dx).clamp(0, _segmentWidth);
    });
  }

  void _handleDragEnd(DragEndDetails _) {
    // Past the halfway point → commit the close flow.
    if (_dragDx > _segmentWidth * 0.5) {
      widget.onClose();
    }
    setState(() {
      _dragDx = 0;
      _dragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Thumb position: follows drag while dragging, otherwise parked left.
    final thumbLeft = _padding + _dragDx;

    return SizedBox(
      height: _height,
      child: Stack(
        children: [
          // Track
          Container(
            width: _segmentWidth * 2 + _padding * 2,
            height: _height,
            decoration: BoxDecoration(
              color: AppDesignTokens.cardSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppDesignTokens.borderCrisp),
            ),
          ),
          // Sliding thumb under the "Active" label (transparent when dragged
          // past halfway so the destructive red on the right becomes legible).
          AnimatedPositioned(
            duration:
                _dragging ? Duration.zero : const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            left: thumbLeft,
            top: _padding,
            bottom: _padding,
            width: _segmentWidth,
            child: Container(
              decoration: BoxDecoration(
                color: _dragDx > _segmentWidth * 0.5
                    ? AppDesignTokens.missedColor.withValues(alpha: 0.16)
                    : AppDesignTokens.openSessionBgLight,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _dragDx > _segmentWidth * 0.5
                      ? AppDesignTokens.missedColor.withValues(alpha: 0.55)
                      : AppDesignTokens.openSessionBg.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
          // Drag layer sits above the thumb but below the labels/tap
          // targets — horizontal drags are owned here, vertical gestures
          // and taps fall through to the InkWell below.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: _handleDragUpdate,
              onHorizontalDragEnd: _handleDragEnd,
              onHorizontalDragCancel: () {
                setState(() {
                  _dragDx = 0;
                  _dragging = false;
                });
              },
            ),
          ),
          // Labels + tap targets. Tapping "Close Trial" runs the close
          // flow directly; sliding the thumb does the same past halfway.
          Row(
            children: [
              const SizedBox(
                width: _segmentWidth + _padding,
                height: _height,
                child: IgnorePointer(
                  child: Center(
                    child: Text(
                      'Active',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppDesignTokens.primaryText,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: _segmentWidth + _padding,
                height: _height,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: widget.onClose,
                    child: Center(
                      child: Text(
                        'Close Trial',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppDesignTokens.missedColor
                              .withValues(alpha: 0.9),
                        ),
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

/// Compact, neutral "Sessions" shortcut inside [PinnedTrialStatusBar].
/// Opens the trial's Sessions tab (same screen reachable via the module
/// dock). Deliberately different in shape and color from the status pill
/// and lifecycle CTA so it reads as a separate navigation affordance:
/// white card surface, rectangular 8pt corners, neutral border and text,
/// trailing chevron.

/// Resume-work hero for Overview. Intentionally compact: one status chip,
/// one progress line, and one primary CTA that routes straight to the most
/// useful next action (Continue Rating / Start Session / Open Sessions).

/// Compact Needs Attention card. Inline rows come from a single source
/// (`trialAttentionProvider`) to avoid merge/dedup complexity; readiness
/// detail lives behind Review issues → `CompletenessDashboardScreen`.
/// The whole card is hidden when there is nothing pending.

// ─────────────────────────────────────────────
// SESSIONS VIEW (navigated from bottom bar)
// ─────────────────────────────────────────────

String _sessionCloseCompletenessIssueLine(SessionCompletenessIssue i) {
  switch (i.code) {
    case SessionCompletenessIssueCode.sessionNotFound:
      return 'Session not found.';
    case SessionCompletenessIssueCode.noSessionAssessments:
      return 'This session has no linked assessments.';
    case SessionCompletenessIssueCode.missingCurrentRating:
      return 'Missing rating for plot ${i.plotPk} (assessment ${i.assessmentId}).';
    case SessionCompletenessIssueCode.voidRating:
      return 'Void rating on plot ${i.plotPk} (assessment ${i.assessmentId}).';
    case SessionCompletenessIssueCode.nonRecordedStatus:
      return 'Non-recorded status on plot ${i.plotPk} (assessment ${i.assessmentId}).';
  }
}

List<String> _legacySessionCloseAttentionLines(SessionCloseAttentionSummary s) {
  return [
    'Navigation — plots with any current rating: ${s.ratedPlots} of ${s.totalPlots}',
    if (s.unratedPlots > 0)
      'Navigation — plots with no current rating: ${s.unratedPlots}',
    if (s.flaggedPlots > 0) 'Flagged plots: ${s.flaggedPlots}',
    if (s.issuesPlots > 0)
      'Data quality — plots with a non-recorded status: ${s.issuesPlots}',
    if (s.editedPlots > 0) 'Edited plots: ${s.editedPlots}',
  ];
}

/// Compact pill for session status (Open, Warnings). Professional, consistent styling.

enum _SessionCloseAttentionAction {
  keepOpen,
  reviewSummary,
  plotQueue,
  closeAnyway,
}

UnifiedSeverity _mapDiagnosticSeverity(DiagnosticSeverity s) =>
    mapFindingDiagnosticSeverity(s);

String _sourceLabel(DiagnosticSource source) {
  return switch (source) {
    DiagnosticSource.exportValidation => 'export',
    DiagnosticSource.armConfidence => 'Import',
    DiagnosticSource.readiness => '',
    DiagnosticSource.sessionCompleteness => '',
    DiagnosticSource.attention => '',
  };
}
