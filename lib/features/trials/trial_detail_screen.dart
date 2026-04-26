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
import '../../core/workspace/workspace_config.dart';
import '../sessions/create_session_screen.dart';
import '../sessions/session_repository.dart';
import '../sessions/domain/session_close_attention_summary.dart';
import '../sessions/domain/session_close_policy_result.dart';
import '../sessions/domain/session_completeness_report.dart';
import '../sessions/session_summary_screen.dart';
import '../plots/plot_queue_screen.dart';
import 'full_protocol_details_screen.dart';
import '../../core/providers.dart';
import '../../core/design/app_design_tokens.dart';
import 'plot_layout_model.dart';
import '../diagnostics/trial_readiness.dart';
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
import 'tabs/timeline_tab.dart';
import 'trial_data_screen.dart';
import 'trial_setup_screen.dart';
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

/// Key for persisting that the trial module hub one-time scroll hint was seen or dismissed.
const String _kTrialHubHintDismissedKey = 'trial_module_hub_hint_dismissed';

/// Maps visible TrialTab values to their fixed IndexedStack indices.
/// Excludes timeline and sessions.
List<int> _visibleFixedIndices(WorkspaceConfig config) {
  const tabToIndex = {
    TrialTab.plots: 0,
    TrialTab.seeding: 1,
    TrialTab.applications: 2,
    TrialTab.assessments: 3,
    TrialTab.treatments: 4,
    TrialTab.photos: 5,
    TrialTab.timeline: 6,
  };
  return config.visibleTabs.map((t) => tabToIndex[t]).whereType<int>().toList();
}

/// Fixed stack index for the Overview tab (Phase A scaffold).
const int _overviewTabIndex = 8;

/// Fixed stack index for the ARM Protocol tab (ARM-linked trials only).
const int _armProtocolTabIndex = 9;

/// Computes effective selected index: prefers candidate if visible, else first visible, else Overview.
/// [candidate] == [_overviewTabIndex] always passes through (Overview is not in [visibleIndices]).
/// [candidate] == [_armProtocolTabIndex] always passes through (ARM Protocol is not in [visibleIndices]).
int _effectiveSelectedIndex({
  required int candidate,
  required List<int> visibleIndices,
}) {
  if (candidate == _overviewTabIndex) return _overviewTabIndex;
  if (candidate == _armProtocolTabIndex) return _armProtocolTabIndex;
  if (visibleIndices.isEmpty) return _overviewTabIndex;
  if (visibleIndices.contains(candidate)) return candidate;
  return visibleIndices.first;
}

/// Sanitizes a tab index for the given trial: visible module tab, Overview (8), or ARM Protocol (9).
int _sanitizeTabIndexForTrial(int index, Trial trial) {
  if (index == _overviewTabIndex) return _overviewTabIndex;
  if (index == _armProtocolTabIndex) return _armProtocolTabIndex;
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
class _OverviewDashboardCard extends StatelessWidget {
  const _OverviewDashboardCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: _kOverviewDashboardCardMargin,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        side: const BorderSide(color: AppDesignTokens.borderCrisp),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing12,
          vertical: AppDesignTokens.spacing8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: _overviewDashboardCardTitleStyle()),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }
}

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
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ExportFormatSheet(
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
        final useCase = ref.read(exportTrialUseCaseProvider);
        final readinessReport =
            await ref.read(trialReadinessProvider(widget.trial.id).future);
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
      isScrollControlled: true,
      builder: (ctx) => _TrialReadinessSheet(
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

  /// Export control for the white toolbar under the green header (primary colors + badge).
  Widget _buildExportToolbarControl(
      BuildContext context, WidgetRef ref, Trial trial) {
    final trialArmLinked = ref
            .watch(armTrialMetadataStreamProvider(trial.id))
            .valueOrNull
            ?.isArmLinked ??
        false;
    final sheetFormats = exportFormatsForTrialSheet(
      trial.workspaceType,
      isArmLinked: trialArmLinked,
    );
    if (sheetFormats.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final readinessAsync = ref.watch(trialReadinessProvider(trial.id));
    final showBadge = readinessAsync.valueOrNull != null &&
        (readinessAsync.value!.blockerCount > 0 ||
            readinessAsync.value!.warningCount > 0);
    final isBlocker = (readinessAsync.valueOrNull?.blockerCount ?? 0) > 0;

    return Tooltip(
      message: exportEntryTooltipMessage(
        trial.workspaceType,
        isArmLinked: trialArmLinked,
      ),
      child: InkWell(
        onTap: _isExporting ? null : () => _onExportTapped(context, ref, trial),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.ios_share_outlined,
                size: 20,
                color: AppDesignTokens.primary,
              ),
              const SizedBox(width: 6),
              const Text(
                'Export',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.primary,
                ),
              ),
              if (showBadge) ...[
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isBlocker
                        ? theme.colorScheme.error
                        : Colors.amber.shade700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
            if (showExport) ...[
              Container(
                width: 1,
                height: 28,
                color: AppDesignTokens.divider,
              ),
              Expanded(
                child: _buildExportToolbarControl(context, ref, trial),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Opens [FieldNotesListScreen]; badge when the trial has at least one note.
  Widget _buildTrialNotesHeaderButton(BuildContext context, Trial trial) {
    final notesAsync = ref.watch(notesForTrialProvider(trial.id));
    final hasNotes = notesAsync.maybeWhen(
      data: (list) => list.isNotEmpty,
      orElse: () => false,
    );
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: 'Field notes',
          iconSize: 24,
          padding: const EdgeInsets.all(8),
          style: IconButton.styleFrom(foregroundColor: Colors.white),
          icon: const Icon(Icons.sticky_note_2_outlined),
          onPressed: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => FieldNotesListScreen(trial: trial),
              ),
            );
          },
        ),
        if (hasNotes)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTrialOverflowMenu(BuildContext context, Trial trial) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      iconSize: 24,
      tooltip: 'More',
      padding: const EdgeInsets.all(8),
      onSelected: (value) {
        if (value == 'activity') {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AuditLogScreen(trialId: trial.id),
            ),
          );
        } else if (value == 'trial_data') {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => TrialDataScreen(trial: trial),
            ),
          );
        } else if (value == 'delete_trial') {
          _confirmAndSoftDeleteTrial(context, trial);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'trial_data',
          child: Text('Trial data'),
        ),
        const PopupMenuItem<String>(
          value: 'activity',
          child: Text('Activity'),
        ),
        const PopupMenuItem<String>(
          value: 'delete_trial',
          child: Text('Delete trial'),
        ),
      ],
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
                      _buildTrialNotesHeaderButton(context, currentTrial),
                      _buildTrialOverflowMenu(context, currentTrial),
                    ],
                  ),
                ),
              ),
            ),
            _buildTrialDetailActionsBar(context, ref, currentTrial),
          ],
        ),
        _PinnedTrialStatusBar(
          trial: currentTrial,
          onTransitionStatus: _transitionTrialStatus,
          onOpenSessions: () => setState(() {
            _previousTabIndex = _selectedTabIndex;
            _selectedTabIndex = _sessionsIndex;
          }),
        ),
        SizedBox(
          height: 90,
          child: _TrialModuleHub(
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
              _OverviewTabBody(
                trial: currentTrial,
                onAttentionTap: _handleAttentionTap,
                onOpenSessions: () => setState(() {
                  _previousTabIndex = _selectedTabIndex;
                  _selectedTabIndex = _sessionsIndex;
                }),
              ),
              // ARM Protocol tab at index 9 — only reachable when ARM-linked.
              armTabBuilder(currentTrial.id),
            ],
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
class _PinnedTrialStatusBar extends ConsumerStatefulWidget {
  const _PinnedTrialStatusBar({
    required this.trial,
    required this.onTransitionStatus,
    required this.onOpenSessions,
  });

  final Trial trial;
  final Future<void> Function(
      BuildContext context, WidgetRef ref, String newStatus) onTransitionStatus;
  final VoidCallback onOpenSessions;

  @override
  ConsumerState<_PinnedTrialStatusBar> createState() =>
      _PinnedTrialStatusBarState();
}

class _PinnedTrialStatusBarState extends ConsumerState<_PinnedTrialStatusBar> {
  bool _standaloneOpenSessionPromoteInFlight = false;

  @override
  void didUpdateWidget(covariant _PinnedTrialStatusBar oldWidget) {
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
              _ActiveCloseToggle(
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
            _SessionsStatusBarButton(onTap: widget.onOpenSessions),
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
class _ActiveCloseToggle extends StatefulWidget {
  const _ActiveCloseToggle({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_ActiveCloseToggle> createState() => _ActiveCloseToggleState();
}

class _ActiveCloseToggleState extends State<_ActiveCloseToggle> {
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

/// Compact, neutral "Sessions" shortcut inside [_PinnedTrialStatusBar].
/// Opens the trial's Sessions tab (same screen reachable via the module
/// dock). Deliberately different in shape and color from the status pill
/// and lifecycle CTA so it reads as a separate navigation affordance:
/// white card surface, rectangular 8pt corners, neutral border and text,
/// trailing chevron.
class _SessionsStatusBarButton extends StatelessWidget {
  const _SessionsStatusBarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppDesignTokens.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppDesignTokens.borderCrisp),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(10, 4, 6, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sessions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppDesignTokens.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewPlotSummary extends ConsumerWidget {
  const _OverviewPlotSummary({required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final treatmentsAsync = ref.watch(treatmentsForTrialProvider(trial.id));
    final ratedAsync = ref.watch(ratedPlotsCountForTrialProvider(trial.id));
    final completionAsync =
        ref.watch(trialAssessmentCompletionProvider(trial.id));

    return _OverviewDashboardCard(
      title: 'Plots',
      child: plotsAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (e, st) => Text(
          'Could not load plots',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        data: (plots) {
          final treatments = treatmentsAsync.value ?? [];
          final rated = ratedAsync.valueOrNull ?? 0;
          final dataPlotCount = plots.where((p) => !p.isGuardRow).length;
          final analyzableCount = plots.where(isAnalyzablePlot).length;
          final excludedFromData =
              (dataPlotCount - analyzableCount).clamp(0, dataPlotCount);
          final repCount = () {
            if (plots.isEmpty) return 0;
            final blocks = buildRepBasedLayout(plots);
            final repNumbers = <int>{};
            for (final block in blocks) {
              for (final row in block.repRows) {
                for (final p in row.plots) {
                  if (p.rep != null) repNumbers.add(p.rep!);
                }
              }
            }
            return repNumbers.length;
          }();
          final summaryLine =
              '$dataPlotCount data plots · ${treatments.length} treatments · $repCount reps';

          // Whole-trial coverage: rated plot-assessments / (nAssessments ×
          // analyzable plots). Labelled "coverage" because the metric is
          // non-monotonic — it honestly drops when scope expands (new
          // assessment or new plots). Denominator is surfaced in the
          // secondary line so a drop caused by scope growth is visible.
          final completionMap = completionAsync.valueOrNull;
          final nAssess = completionMap?.length ?? 0;
          double? trialCoverage;
          String? coveragePrimaryLine;
          String? coverageDetailLine;
          if (completionMap != null && nAssess > 0) {
            final completeAssess =
                completionMap.values.where((c) => c.isComplete).length;
            final sumPairs = completionMap.values
                .fold<int>(0, (s, c) => s + c.ratedPlotCount);
            final denomPairs = nAssess * analyzableCount;
            trialCoverage = denomPairs <= 0
                ? 0.0
                : (sumPairs / denomPairs).clamp(0.0, 1.0);
            final pct = (trialCoverage * 100).round();
            coveragePrimaryLine = '$pct% coverage';
            coverageDetailLine = nAssess == 1
                ? '$sumPairs of $denomPairs plot-assessments rated'
                : '$sumPairs of $denomPairs plot-assessments rated · $completeAssess of $nAssess assessments done';
          }

          final remaining =
              (analyzableCount - rated).clamp(0, analyzableCount);
          final ratedLine = analyzableCount <= 0
              ? '$rated rated · no analyzable plots'
              : '$rated rated · $remaining remaining · $analyzableCount analyzable';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                summaryLine,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              if (trialCoverage != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: trialCoverage,
                    backgroundColor: const Color(0xFFE8E5E0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      trialCoverage >= 1.0
                          ? AppDesignTokens.successFg
                          : AppDesignTokens.primary,
                    ),
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  coveragePrimaryLine!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  coverageDetailLine!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    color:
                        AppDesignTokens.secondaryText.withValues(alpha: 0.9),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                ratedLine,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
              if (excludedFromData > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '$excludedFromData data plot${excludedFromData == 1 ? '' : 's'} excluded from analysis (not counted in progress).',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                    color: AppDesignTokens.secondaryText.withValues(alpha: 0.9),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => PlotsTab.openPlotLayoutView(context, trial),
                icon: const Icon(Icons.grid_view, size: 20),
                label: const Text('View Plot Layout'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrialInsightsCard extends ConsumerWidget {
  const _TrialInsightsCard({required this.trialId});

  final int trialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(trialInsightsProvider(trialId));

    return insightsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (insights) {
        if (insights.isEmpty) return const SizedBox.shrink();
        final hasTrends = insights
            .any((i) => i.type == InsightType.treatmentTrend);
        return _OverviewDashboardCard(
          title: 'Trial insights',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Early or developing readouts — not proof of treatment '
                'effects. Not for final trial conclusions, registration, or '
                'substitute for approved analysis software.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppDesignTokens.borderCrisp),
              for (var i = 0; i < insights.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, color: AppDesignTokens.borderCrisp),
                _InsightRow(insight: insights[i]),
              ],
              if (hasTrends) ...[
                const Divider(height: 1, color: AppDesignTokens.borderCrisp),
                const SizedBox(height: 6),
                const Text(
                  'Treatment trends: arithmetic mean per treatment per session.',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'All insights here are exploratory. Labels like '
                '"Developing" describe how much history the row has — not '
                'that a trend is proven. Formal inference stays outside the app.',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.35,
                  color:
                      AppDesignTokens.secondaryText.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// TODO: replace with InsightRow from
// lib/features/trials/widgets/insight_row.dart
// when this screen is next refactored.
class _InsightRow extends StatefulWidget {
  const _InsightRow({required this.insight});

  final TrialInsight insight;

  @override
  State<_InsightRow> createState() => _InsightRowState();
}

class _InsightRowState extends State<_InsightRow> {
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
                insight.title,
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

class _OverviewTabBody extends ConsumerWidget {
  const _OverviewTabBody({
    required this.trial,
    required this.onAttentionTap,
    required this.onOpenSessions,
  });

  final Trial trial;
  final void Function(AttentionItem item) onAttentionTap;
  final VoidCallback onOpenSessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(trialProvider(trial.id));

    return SingleChildScrollView(
      key: ValueKey<String>('overview_tab_${trial.id}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1 — Hero: resume work right now.
          _CurrentSessionHero(
            trial: trial,
            onOpenSessions: onOpenSessions,
          ),
          // 2 — What needs attention (single source of truth = attention
          // provider; full readiness lives behind Review issues).
          _NeedsAttentionCard(
            trial: trial,
            onAttentionTap: onAttentionTap,
          ),
          // 3 — Physical structure & progress (incl. whole-trial %).
          _OverviewPlotSummary(trial: trial),
          // 4 — Location / metadata.
          SiteDetailsCard(trial: trial),
          // 5 — Analytical insights (hidden when empty).
          _TrialInsightsCard(trialId: trial.id),
          // 6 — Minor status text.
          _AutoBackupStatusLine(),
        ],
      ),
    );
  }
}

/// Resume-work hero for Overview. Intentionally compact: one status chip,
/// one progress line, and one primary CTA that routes straight to the most
/// useful next action (Continue Rating / Start Session / Open Sessions).
class _CurrentSessionHero extends ConsumerWidget {
  const _CurrentSessionHero({
    required this.trial,
    required this.onOpenSessions,
  });

  final Trial trial;
  final VoidCallback onOpenSessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsForTrialProvider(trial.id));
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final ratedAsync = ref.watch(ratedPlotsCountForTrialProvider(trial.id));

    return _OverviewDashboardCard(
      title: 'Current Session',
      child: sessionsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Loading session…',
            style: TextStyle(
              fontSize: 12,
              color: AppDesignTokens.secondaryText,
            ),
          ),
        ),
        error: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Session data unavailable.',
            style: TextStyle(
              fontSize: 12,
              color: AppDesignTokens.secondaryText,
            ),
          ),
        ),
        data: (sessions) {
          final open = sessions.where(isSessionOpenForFieldWork).toList();
          final primary =
              open.isNotEmpty ? open.first : (sessions.isNotEmpty ? sessions.first : null);
          final isActive = primary != null && isSessionOpenForFieldWork(primary);

          // Status pill label + coloring.
          final String statusLabel;
          final Color statusFg;
          final Color statusBg;
          if (sessions.isEmpty) {
            statusLabel = 'Not started';
            statusFg = AppDesignTokens.emptyBadgeFg;
            statusBg = AppDesignTokens.emptyBadgeBg;
          } else if (isActive) {
            statusLabel = 'Active';
            statusFg = AppDesignTokens.openSessionBg;
            statusBg = AppDesignTokens.openSessionBgLight;
          } else {
            statusLabel = 'Closed';
            statusFg = AppDesignTokens.secondaryText;
            statusBg = AppDesignTokens.emptyBadgeBg;
          }

          // Plots rated progress (single line).
          final plots = plotsAsync.valueOrNull ?? const <Plot>[];
          final analyzable = plots.where(isAnalyzablePlot).length;
          final rated = ratedAsync.valueOrNull ?? 0;
          final progressValue =
              analyzable > 0 ? (rated / analyzable).clamp(0.0, 1.0) : 0.0;
          final progressLine = analyzable > 0
              ? '$rated of $analyzable plots rated'
              : 'No analyzable plots yet';

          // Secondary meta line: date + session label.
          final dateText = primary != null
              ? _formatSessionDateLocal(primary.sessionDateLocal)
              : null;
          final sessionLabel =
              primary != null ? _sessionDisplayLabel(primary) : null;

          // Primary CTA: one action only.
          final String ctaLabel;
          final IconData ctaIcon;
          final VoidCallback ctaAction;
          if (isActive) {
            ctaLabel = 'Continue Rating';
            ctaIcon = Icons.play_arrow_rounded;
            ctaAction = () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PlotQueueScreen(
                    trial: trial,
                    session: primary,
                  ),
                ),
              );
            };
          } else if (sessions.isEmpty) {
            ctaLabel = 'Start Session';
            ctaIcon = Icons.play_circle_outline_rounded;
            ctaAction = () => tryOpenCreateSessionScreen(
                  context: context,
                  ref: ref,
                  trial: trial,
                );
          } else {
            ctaLabel = 'Open Sessions';
            ctaIcon = Icons.folder_open_outlined;
            ctaAction = onOpenSessions;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusFg,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (dateText != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      dateText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppDesignTokens.primaryText,
                      ),
                    ),
                  ],
                  if (sessionLabel != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sessionLabel.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                          color: AppDesignTokens.primaryText
                              .withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                progressLine,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
              if (analyzable > 0) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: const Color(0xFFE8E5E0),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppDesignTokens.primary,
                    ),
                    minHeight: 5,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: ctaAction,
                icon: Icon(ctaIcon, size: 18),
                label: Text(ctaLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: AppDesignTokens.primary,
                  foregroundColor: AppDesignTokens.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Compact Needs Attention card. Inline rows come from a single source
/// (`trialAttentionProvider`) to avoid merge/dedup complexity; readiness
/// detail lives behind Review issues → `CompletenessDashboardScreen`.
/// The whole card is hidden when there is nothing pending.
class _NeedsAttentionCard extends ConsumerWidget {
  const _NeedsAttentionCard({
    required this.trial,
    required this.onAttentionTap,
  });

  final Trial trial;
  final void Function(AttentionItem item) onAttentionTap;

  static int _severityRank(AttentionSeverity s) => switch (s) {
        AttentionSeverity.high => 0,
        AttentionSeverity.medium => 1,
        AttentionSeverity.low => 2,
        AttentionSeverity.info => 3,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attentionAsync = ref.watch(trialAttentionProvider(trial.id));

    return attentionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        // All-clear state: title + subtle acknowledgement + the same
        // adaptive CTA (labelled "View readiness") so Overview always
        // has one entry point to the Trial Readiness dashboard.
        if (items.isEmpty) {
          return _OverviewDashboardCard(
            title: 'Needs Attention',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'All clear — nothing needs attention right now.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppDesignTokens.secondaryText
                        .withValues(alpha: 0.85),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        _openCompletenessDashboard(context, trial),
                    icon: const Icon(Icons.fact_check_outlined, size: 16),
                    label: const Text('View readiness'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppDesignTokens.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final sorted = [...items]
          ..sort((a, b) => _severityRank(a.severity)
              .compareTo(_severityRank(b.severity)));
        final top = sorted.take(3).toList();
        final remaining = items.length - top.length;

        return _OverviewDashboardCard(
          title: 'Needs Attention',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                items.length == 1
                    ? '1 item needs attention'
                    : '${items.length} items need attention',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              for (final item in top)
                _AttentionRow(
                  item: item,
                  onTap: () => onAttentionTap(item),
                ),
              if (remaining > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDesignTokens.spacing16,
                    vertical: 6,
                  ),
                  child: Text(
                    '+$remaining more',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      _openCompletenessDashboard(context, trial),
                  icon: const Icon(Icons.fact_check_outlined, size: 16),
                  label: const Text('Review issues'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppDesignTokens.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AutoBackupStatusLine extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(autoBackupStatusProvider);
    return statusAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (status) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Icon(
              status.enabled
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              size: 14,
              color: status.enabled
                  ? AppDesignTokens.successFg
                  : AppDesignTokens.secondaryText,
            ),
            const SizedBox(width: 6),
            Text(
              status.label,
              style: TextStyle(
                fontSize: 11,
                color: status.enabled
                    ? AppDesignTokens.secondaryText
                    : AppDesignTokens.warningFg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrialModuleHub extends StatelessWidget {
  final ScrollController scrollController;
  final WorkspaceConfig workspaceConfig;
  final bool isArmLinked;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onUserScroll;

  const _TrialModuleHub({
    required this.scrollController,
    required this.workspaceConfig,
    required this.isArmLinked,
    required this.selectedIndex,
    required this.onSelected,
    this.onUserScroll,
  });

  @override
  Widget build(BuildContext context) {
    // All possible hub items mapped to their fixed IndexedStack index.
    // Overview (8) is always shown; module tabs use TrialTab for visibility.
    // ARM Protocol (9) is shown only for ARM-linked trials.
    const allItems = <(int, IconData, String, TrialTab?)>[
      (_overviewTabIndex, Icons.dashboard_outlined, 'Overview', null),
      (6, Icons.timeline, 'Timeline', TrialTab.timeline),
      (0, Icons.grid_on, 'Plots', TrialTab.plots),
      (1, Icons.agriculture, 'Seeding', TrialTab.seeding),
      (3, Icons.assessment, 'Assessments', TrialTab.assessments),
      (4, Icons.science_outlined, 'Treatments', TrialTab.treatments),
      (2, Icons.science, 'Applications', TrialTab.applications),
      (5, Icons.photo_library, 'Photos', TrialTab.photos),
    ];

    final items = [
      ...allItems.where((item) =>
          item.$4 == null || workspaceConfig.visibleTabs.contains(item.$4!)),
      if (isArmLinked)
        (_armProtocolTabIndex, Icons.biotech_outlined, 'Field Plan',
            null as TrialTab?),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 380;
        final padLeft = narrow ? 8.0 : AppDesignTokens.spacing16;
        final padRight = narrow ? 12.0 : 48.0;
        final sepW = narrow ? 6.0 : AppDesignTokens.spacing12;

        final listView = ListView.separated(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.hardEdge,
          padding: EdgeInsets.only(left: padLeft, right: padRight),
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => SizedBox(width: sepW),
          itemBuilder: (context, index) {
            final item = items[index];
            return _DockTile(
              icon: item.$2,
              label: item.$3,
              compact: narrow,
              selected: selectedIndex == item.$1,
              onTap: () => onSelected(item.$1),
            );
          },
        );

        final content = onUserScroll != null
            ? NotificationListener<ScrollStartNotification>(
                onNotification: (ScrollStartNotification notification) {
                  if (notification.dragDetails != null) {
                    onUserScroll!();
                  }
                  return false;
                },
                child: listView,
              )
            : listView;

        return ClipRect(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppDesignTokens.backgroundSurface,
              border: Border(
                bottom: BorderSide(
                  color: AppDesignTokens.borderCrisp.withValues(alpha: 0.45),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppDesignTokens.spacing8,
                bottom: AppDesignTokens.spacing8,
              ),
              child: content,
            ),
          ),
        );
      },
    );
  }
}

class _DockTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _DockTile({
    required this.icon,
    required this.label,
    this.compact = false,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = compact ? 6.0 : AppDesignTokens.spacing12;
    final vPad = compact ? 6.0 : AppDesignTokens.spacing8;
    final iconSize =
        selected ? (compact ? 22.0 : 26.0) : (compact ? 19.0 : 22.0);
    final fontSize =
        selected ? (compact ? 11.5 : 13.0) : (compact ? 11.0 : 12.0);

    return AnimatedScale(
      alignment: Alignment.center,
      scale: selected ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected
                    ? AppDesignTokens.primary
                    : AppDesignTokens.primaryText,
                size: iconSize,
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? AppDesignTokens.primary
                      : AppDesignTokens.primaryText,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: fontSize,
                ),
              ),
              SizedBox(height: compact ? 2 : 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 2,
                width: selected ? (compact ? 16 : 20) : 0,
                decoration: BoxDecoration(
                  color: AppDesignTokens.primary,
                  borderRadius: BorderRadius.circular(1),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SESSIONS VIEW (navigated from bottom bar)
// ─────────────────────────────────────────────

class _SessionListEntry {
  final bool isHeader;
  final String? date;
  final Session? session;
  const _SessionListEntry({required this.isHeader, this.date, this.session});
}

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

enum _SessionIncompleteAction { keepOpen, reviewSession, plotQueue }

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
class _SessionPill extends StatelessWidget {
  const _SessionPill({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing12,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foregroundColor),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens [CreateSessionScreen] unless the trial is closed/archived.
void tryOpenCreateSessionScreen({
  required BuildContext context,
  required WidgetRef ref,
  required Trial trial,
}) {
  final latest = ref.read(trialProvider(trial.id)).valueOrNull ?? trial;
  if (latest.status == kTrialStatusClosed ||
      latest.status == kTrialStatusArchived) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This trial is closed — no new sessions can be started. Reopen the trial if further data collection is needed.',
        ),
      ),
    );
    return;
  }
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => CreateSessionScreen(trial: latest),
    ),
  );
}

class SessionsView extends ConsumerWidget {
  final Trial trial;
  final VoidCallback? onBack;

  const SessionsView({super.key, required this.trial, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsForTrialProvider(trial.id));

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      body: Column(
        children: [
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                ),
              Expanded(
                child: Text(
                  'Sessions',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.download_for_offline),
                tooltip: 'Export closed sessions (ZIP per session)',
                onSelected: (value) async {
                  final guard = ref.read(exportGuardProvider);
                  final ran = await guard.runExclusive(() async {
                    final user = await ref.read(currentUserProvider.future);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(value == 'arm_xml'
                              ? 'Exporting XML...'
                              : 'Exporting...')),
                    );
                    final result = value == 'arm_xml'
                        ? await ref
                            .read(
                                exportTrialClosedSessionsArmXmlUsecaseProvider)
                            .execute(
                              trialId: trial.id,
                              trialName: trial.name,
                              exportedByDisplayName: user?.displayName,
                            )
                        : await ref
                            .read(exportTrialClosedSessionsUsecaseProvider)
                            .execute(
                              trialId: trial.id,
                              trialName: trial.name,
                              exportedByDisplayName: user?.displayName,
                            );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).clearSnackBars();
                    if (result.success) {
                      final box = context.findRenderObject() as RenderBox?;
                      await Share.shareXFiles(
                        [XFile(result.filePath!)],
                        text:
                            '${trial.name} – ${result.sessionCount} closed sessions',
                        sharePositionOrigin: box == null
                            ? const Rect.fromLTWH(0, 0, 100, 100)
                            : box.localToGlobal(Offset.zero) & box.size,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Exported ${result.sessionCount} sessions')),
                      );
                    } else {
                      final scheme = Theme.of(context).colorScheme;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result.errorMessage ?? 'Export failed',
                            style: TextStyle(color: scheme.onError),
                          ),
                          backgroundColor: scheme.error,
                        ),
                      );
                    }
                  });
                  if (!ran && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text(ExportGuard.busyMessage)),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'csv',
                    child: Text('Closed Sessions (CSV ZIP)'),
                  ),
                  const PopupMenuItem(
                    value: 'arm_xml',
                    child: Text('Closed Sessions (XML ZIP)'),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: sessionsAsync.when(
              loading: () => const AppLoadingView(),
              error: (e, st) => AppErrorView(
                error: e,
                stackTrace: st,
                onRetry: () =>
                    ref.invalidate(sessionsForTrialProvider(trial.id)),
              ),
              data: (sessions) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: sessions.isEmpty
                          ? _buildEmptySessions(context, ref)
                          : _buildSessionsList(context, ref, sessions),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySessions(BuildContext context, WidgetRef ref) {
    return AppEmptyState(
      icon: Icons.folder_open,
      title: 'No Sessions Yet',
      subtitle: 'Start a session to begin collecting field data.',
      action: FilledButton.icon(
        onPressed: () => tryOpenCreateSessionScreen(
          context: context,
          ref: ref,
          trial: trial,
        ),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Session'),
      ),
    );
  }

  /// Normalize to YYYY-MM-DD so grouping and header formatting never see a full datetime string.
  static String _normalizeSessionDateKey(String sessionDateLocal) {
    if (sessionDateLocal.length >= 10) return sessionDateLocal.substring(0, 10);
    final space = sessionDateLocal.indexOf(' ');
    if (space > 0) return sessionDateLocal.substring(0, space);
    final t = sessionDateLocal.indexOf('T');
    if (t > 0) return sessionDateLocal.substring(0, t);
    return sessionDateLocal;
  }

  Widget _buildSessionsList(
      BuildContext context, WidgetRef ref, List<Session> sessions) {
    final groups = <String, List<Session>>{};
    for (final session in sessions) {
      final key = _normalizeSessionDateKey(session.sessionDateLocal);
      groups.putIfAbsent(key, () => []).add(session);
    }
    final sortedDates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final entries = <_SessionListEntry>[];
    for (final date in sortedDates) {
      entries.add(_SessionListEntry(isHeader: true, date: date));
      for (final session in groups[date]!) {
        entries.add(_SessionListEntry(isHeader: false, session: session));
      }
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final e = entries[index];
            if (e.isHeader) {
              return _buildSessionDateHeader(context, e.date!);
            }
            return _buildSessionListTile(context, ref, e.session!);
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'new_session',
            onPressed: () => tryOpenCreateSessionScreen(
              context: context,
              ref: ref,
              trial: trial,
            ),
            backgroundColor: AppDesignTokens.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionDateHeader(BuildContext context, String date) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing16,
          vertical: AppDesignTokens.spacing8),
      decoration: const BoxDecoration(
        color: AppDesignTokens.sectionHeaderBg,
        border: Border(bottom: BorderSide(color: AppDesignTokens.borderCrisp)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today,
              size: 14, color: AppDesignTokens.secondaryText),
          const SizedBox(width: 6),
          Text(
            _formatDateHeader(date),
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppDesignTokens.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionListTile(
      BuildContext context, WidgetRef ref, Session session) {
    if (session.status == kSessionStatusPlanned) {
      return _buildPlannedSessionTile(context, ref, session);
    }
    final isOpen = isSessionOpenForFieldWork(session);
    final ratings =
        ref.watch(sessionRatingsProvider(session.id)).valueOrNull ?? [];
    final flaggedIds =
        ref.watch(flaggedPlotIdsForSessionProvider(session.id)).valueOrNull ??
            <int>{};
    final hasFlags = flaggedIds.isNotEmpty;
    final issuePlotIds = ratings
        .where((r) => r.resultStatus != 'RECORDED')
        .map((r) => r.plotPk)
        .toSet();
    final hasIssues = issuePlotIds.isNotEmpty;
    final needsAttention = hasFlags || hasIssues;
    final correctionSessionIds = ref
            .watch(sessionIdsWithCorrectionsForTrialProvider(trial.id))
            .valueOrNull ??
        <int>{};
    final hasEdited = ratings.any((r) => r.amended || (r.previousId != null)) ||
        correctionSessionIds.contains(session.id);

    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing16, vertical: 4),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isOpen) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          PlotQueueScreen(trial: trial, session: session)));
            } else {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SessionSummaryScreen(
                          trial: trial, session: session)));
            }
          },
          onLongPress:
              isOpen ? () => _confirmCloseSession(context, ref, session) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDesignTokens.spacing8),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? AppDesignTokens.openSessionBgLight
                        : AppDesignTokens.emptyBadgeBg,
                    borderRadius:
                        BorderRadius.circular(AppDesignTokens.radiusXSmall),
                  ),
                  child: Icon(
                    isOpen ? Icons.play_circle : Icons.check_circle,
                    color: isOpen
                        ? AppDesignTokens.openSessionBg
                        : AppDesignTokens.emptyBadgeFg,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _shortSessionName(
                            session.name, session.sessionDateLocal),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppDesignTokens.primaryText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatSessionTimes(session),
                        style: subtitleStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      ref
                          .watch(sessionTimingContextProvider(session.id))
                          .maybeWhen(
                            data: (t) {
                              if (t.displayLine.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  t.displayLine,
                                  style: subtitleStyle?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                            orElse: () => const SizedBox.shrink(),
                          ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: AppDesignTokens.spacing8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (hasEdited)
                            const _SessionPill(
                              label: 'Edited',
                              backgroundColor: AppDesignTokens.sectionHeaderBg,
                              foregroundColor: AppDesignTokens.secondaryText,
                            ),
                          ..._sessionStatusChips(isOpen, needsAttention),
                          if (ref
                                  .watch(weatherSnapshotForSessionProvider(
                                      session.id))
                                  .valueOrNull !=
                              null)
                            const Icon(
                              Icons.cloud,
                              size: 16,
                              color: AppDesignTokens.secondaryText,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 20,
                    color: AppDesignTokens.secondaryText,
                  ),
                  tooltip: 'More actions',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  onSelected: (value) {
                    if (value == 'delete_session') {
                      _confirmAndSoftDeleteSession(context, ref, session);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'delete_session',
                      child: Text('Move to Recovery'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Specialized tile for a [kSessionStatusPlanned] session.
  ///
  /// Planned sessions carry no ratings or timings; what matters is the ARM
  /// schedule they represent and a clear "Start" affordance. The tile reads
  /// optional ARM metadata through [armSessionMetadataProvider]; when the
  /// provider returns null (non-ARM planned session, or ARM trial imported
  /// before Phase 1b) only the planned date renders.
  Widget _buildPlannedSessionTile(
      BuildContext context, WidgetRef ref, Session session) {
    final armMeta =
        ref.watch(armSessionMetadataProvider(session.id)).valueOrNull;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    final metadataLine = _formatPlannedMetadataLine(armMeta);
    final hasOpenSessionElsewhere =
        ref.watch(openSessionProvider(trial.id)).valueOrNull != null;

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing16, vertical: 4),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasOpenSessionElsewhere
              ? null
              : () => _startPlannedSession(context, ref, session),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDesignTokens.spacing8),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.sectionHeaderBg,
                    borderRadius:
                        BorderRadius.circular(AppDesignTokens.radiusXSmall),
                  ),
                  child: const Icon(
                    Icons.event_outlined,
                    color: AppDesignTokens.secondaryText,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Primary: what will be rated (session.name is now the
                      // comma-joined assessment names from ARM import).
                      // Fall back to the date when the name is empty or still
                      // the legacy "Planned — date" pattern that slipped past
                      // the back-fill.
                      Text(
                        _sessionHeadline(session),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppDesignTokens.primaryText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateHeader(session.sessionDateLocal),
                        style: subtitleStyle?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                      ),
                      if (metadataLine.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          metadataLine,
                          style: subtitleStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const _SessionPill(
                            label: 'Planned',
                            backgroundColor: AppDesignTokens.sectionHeaderBg,
                            foregroundColor: AppDesignTokens.secondaryText,
                            icon: Icons.schedule,
                          ),
                          const Spacer(),
                          FilledButton.tonalIcon(
                            onPressed: hasOpenSessionElsewhere
                                ? null
                                : () =>
                                    _startPlannedSession(context, ref, session),
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('Start'),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                            ),
                          ),
                        ],
                      ),
                      if (hasOpenSessionElsewhere) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Close the open session on this trial before starting a planned one.',
                          style: subtitleStyle?.copyWith(
                              color: AppDesignTokens.warningFg),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 20,
                    color: AppDesignTokens.secondaryText,
                  ),
                  tooltip: 'More actions',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  onSelected: (value) {
                    if (value == 'delete_session') {
                      _confirmAndSoftDeleteSession(context, ref, session);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'delete_session',
                      child: Text('Move to Recovery'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Headline text for a session tile: the session name, with a date fallback
  /// when the name is empty or still the legacy "Planned — $date" form.
  String _sessionHeadline(Session session) {
    final raw = session.name.trim();
    if (raw.isEmpty) return _formatDateHeader(session.sessionDateLocal);
    if (RegExp(r'^Planned\s*[—-]\s*').hasMatch(raw)) {
      return _formatDateHeader(session.sessionDateLocal);
    }
    return raw;
  }

  /// Composes "Timing · Stage · Interval" from ARM session metadata.
  /// Each segment is included only when present; returns empty when nothing
  /// ARM-specific is available.
  String _formatPlannedMetadataLine(ArmSessionMetadataData? m) {
    if (m == null) return '';
    final parts = <String>[];
    final timing = m.timingCode?.trim();
    if (timing != null && timing.isNotEmpty) {
      parts.add(timing);
    }
    final stage = _composeCropStage(
        m.cropStageScale, m.cropStageMaj, m.cropStageMin);
    if (stage.isNotEmpty) {
      parts.add(stage);
    }
    final trt = m.trtEvalInterval?.trim();
    if (trt != null && trt.isNotEmpty) {
      parts.add(trt);
    }
    final plant = m.plantEvalInterval?.trim();
    if (plant != null && plant.isNotEmpty) {
      parts.add(plant);
    }
    return parts.join(' · ');
  }

  String _composeCropStage(String? scale, String? major, String? minor) {
    final maj = major?.trim() ?? '';
    final min = minor?.trim() ?? '';
    final sc = scale?.trim() ?? '';
    if (maj.isEmpty && min.isEmpty) return '';
    final stage = min.isEmpty ? maj : (maj.isEmpty ? min : '$maj–$min');
    return sc.isEmpty ? stage : '$sc $stage';
  }

  Future<void> _startPlannedSession(
    BuildContext context,
    WidgetRef ref,
    Session session,
  ) async {
    final latest = ref.read(trialProvider(trial.id)).valueOrNull ?? trial;
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    final fieldWorkKey = 'field_work_started_${trial.id}';
    final fieldWorkSeen = prefs.getBool(fieldWorkKey) ?? false;

    if (latest.status == kTrialStatusDraft && !fieldWorkSeen) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Starting Field Work'),
          content: const Text(
            'Once you begin rating or recording applications, the trial '
            'structure will be locked:\n'
            '• Treatments cannot be added or removed\n'
            '• Plot layout cannot be changed\n'
            '• Assessment types cannot be changed\n\n'
            'Ratings and notes can always be added.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not Yet'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Begin Field Work'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      await prefs.setBool(fieldWorkKey, true);
    }

    try {
      final user = await ref.read(currentUserProvider.future);
      final userId = await ref.read(currentUserIdProvider.future);
      final armMeta =
          ref.read(armSessionMetadataProvider(session.id)).valueOrNull;
      final cropStageBbch =
          int.tryParse(armMeta?.cropStageMaj?.trim() ?? '');
      final started =
          await ref.read(sessionRepositoryProvider).startPlannedSession(
                session.id,
                raterName: session.raterName ?? user?.displayName,
                startedByUserId: userId,
                cropStageBbch: cropStageBbch,
              );
      if (!context.mounted) return;
      ref.invalidate(sessionsForTrialProvider(trial.id));
      ref.invalidate(openSessionProvider(trial.id));
      ref.invalidate(armSessionMetadataProvider(session.id));
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlotQueueScreen(trial: trial, session: started),
        ),
      );
    } on OpenSessionExistsException catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Another session is already open on this trial. Close it first.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Could not start session'),
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

  List<Widget> _sessionStatusChips(bool isOpen, bool needsAttention) {
    if (isOpen && !needsAttention) {
      return const [
        _SessionPill(
          label: 'Open',
          backgroundColor: AppDesignTokens.openSessionBg,
          foregroundColor: Colors.white,
        ),
      ];
    }
    if (needsAttention) {
      return [
        if (isOpen)
          const _SessionPill(
            label: 'Open',
            backgroundColor: AppDesignTokens.openSessionBg,
            foregroundColor: Colors.white,
          ),
        const _SessionPill(
          label: 'Warnings',
          backgroundColor: AppDesignTokens.warningBg,
          foregroundColor: AppDesignTokens.warningFg,
          icon: Icons.warning_amber_outlined,
        ),
      ];
    }
    return [
      const Text(
        'Closed',
        style: TextStyle(
          color: AppDesignTokens.secondaryText,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ];
  }

  Future<void> _confirmAndSoftDeleteSession(
    BuildContext context,
    WidgetRef ref,
    Session session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session'),
        content: const Text(
          'This session moves to Recovery. Ratings in this session move to Recovery too. '
          'The trial and its plots are unchanged. You can restore this session later from Recovery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete session'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final user = await ref.read(currentUserProvider.future);
      final userId = await ref.read(currentUserIdProvider.future);
      await ref.read(sessionRepositoryProvider).softDeleteSession(
            session.id,
            deletedBy: user?.displayName,
            deletedByUserId: userId,
          );
      if (!context.mounted) return;
      final trialId = trial.id;
      ref.invalidate(sessionsForTrialProvider(trialId));
      ref.invalidate(deletedSessionsProvider);
      ref.invalidate(deletedSessionsForTrialRecoveryProvider(trialId));
      ref.invalidate(openSessionProvider(trialId));
      ref.invalidate(sessionRatingsProvider(session.id));
      ref.invalidate(sessionAssessmentsProvider(session.id));
      ref.invalidate(ratedPlotPksProvider(session.id));
      ref.invalidate(derivedSnapshotForSessionProvider(session.id));
      ref.invalidate(lastSessionContextProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session moved to Recovery')),
      );
    } catch (e) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Could not delete session'),
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

  String _formatSessionTimes(Session session) {
    String fmtTime(DateTime dt) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    final start = fmtTime(session.startedAt);
    final rater = session.raterName != null ? ' · ${session.raterName}' : '';
    if (session.endedAt != null) {
      final end = fmtTime(session.endedAt!);
      return '$start – $end$rater';
    }
    return 'Started $start$rater';
  }

  String _shortSessionName(String name, String dateLocal) {
    if (name.startsWith(dateLocal)) {
      return name.substring(dateLocal.length).trim();
    }
    return name;
  }

  String _formatDateHeader(String dateStr) {
    try {
      // Use only the date part (YYYY-MM-DD); handle "YYYY-MM-DD HH:mm:ss" or "YYYY-MM-DDTHH:mm:ss".
      final dateOnly = dateStr.length >= 10
          ? dateStr.substring(0, 10)
          : (dateStr.contains(' ')
              ? dateStr.split(' ').first
              : (dateStr.contains('T') ? dateStr.split('T').first : dateStr));
      final parts = dateOnly.split('-');
      if (parts.length != 3) return dateStr;
      final months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final day = int.tryParse(parts[2]);
      final monthIdx = int.tryParse(parts[1]);
      if (day == null || monthIdx == null || monthIdx < 1 || monthIdx > 12) {
        return dateStr;
      }
      final month = months[monthIdx];
      final year = parts[0];
      return '$day $month $year';
    } catch (_) {
      return dateStr;
    }
  }

  Future<_SessionIncompleteAction?> _showSessionIncompleteBlockerDialog(
    BuildContext context,
    Session session,
    SessionCompletenessReport report,
  ) {
    final issueLines =
        report.issues.map(_sessionCloseCompletenessIssueLine).take(15).toList();
    return showDialog<_SessionIncompleteAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Session incomplete'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Incomplete target plots: ${report.incompletePlots} of '
                '${report.expectedPlots}.',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Resolve these before closing:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...issueLines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.start,
        actionsOverflowAlignment: OverflowBarAlignment.start,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, _SessionIncompleteAction.keepOpen),
            child: const Text('Keep open'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, _SessionIncompleteAction.reviewSession),
            child: const Text('Review session'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, _SessionIncompleteAction.plotQueue),
            child: const Text('Open Plot Queue'),
          ),
        ],
      ),
    );
  }

  Future<_SessionCloseAttentionAction?> _showSessionCloseCombinedWarningDialog(
    BuildContext context,
    Session session,
    SessionCompletenessReport report,
    SessionCloseAttentionSummary summary, {
    required bool hasCompletenessWarnings,
    required bool legacyNeedsAttention,
    required List<DiagnosticFinding> contextInfoFindings,
  }) {
    final completenessLines = report.issues
        .where(
          (i) => i.severity == SessionCompletenessIssueSeverity.warning,
        )
        .map(_sessionCloseCompletenessIssueLine)
        .toList();
    final legacyLines = legacyNeedsAttention
        ? _legacySessionCloseAttentionLines(summary)
        : <String>[];

    return showDialog<_SessionCloseAttentionAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close session?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This session still has items you may want to review before closing.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              if (hasCompletenessWarnings) ...[
                const Text(
                  'Completeness',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ...completenessLines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (legacyNeedsAttention) const SizedBox(height: 12),
              ],
              if (legacyNeedsAttention) ...[
                const Text(
                  'Navigation and data signals',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ...legacyLines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
              if (contextInfoFindings.isNotEmpty) ...[
                if (hasCompletenessWarnings || legacyNeedsAttention)
                  const SizedBox(height: 12),
                const Text(
                  'For your records',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ...contextInfoFindings.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      f.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.start,
        actionsOverflowAlignment: OverflowBarAlignment.start,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, _SessionCloseAttentionAction.keepOpen),
            child: const Text('Keep open'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, _SessionCloseAttentionAction.reviewSummary),
            child: const Text('Review summary'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, _SessionCloseAttentionAction.plotQueue),
            child: const Text('Open Plot Queue'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, _SessionCloseAttentionAction.closeAnyway),
            child: const Text('Close anyway'),
          ),
        ],
      ),
    );
  }

  Future<void> _runCloseSessionUseCase(
    BuildContext context,
    WidgetRef ref,
    Session session, {
    bool forceClose = false,
  }) async {
    final userId = await ref.read(currentUserIdProvider.future);
    final useCase = ref.read(closeSessionUseCaseProvider);
    final result = await useCase.execute(
      sessionId: session.id,
      trialId: trial.id,
      raterName: session.raterName,
      closedByUserId: userId,
      forceClose: forceClose,
    );
    if (context.mounted) {
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
      if (result.success && context.mounted) {
        // Auto-open session summary (with data grid) so researcher sees their data.
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SessionSummaryScreen(
              trial: trial,
              session: session,
            ),
          ),
        );
        _checkBackupReminder(context);
      }
    }
  }

  Future<void> _checkBackupReminder(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final store = BackupReminderStore(prefs);
    if (store.mode != BackupReminderMode.afterSessionClose) return;
    if (!store.shouldRemind()) return;
    await store.recordReminderShown();
    if (!context.mounted) return;
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
              // Navigate to More tab which has the backup action.
              // The user taps Backup from there.
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

  Future<void> _confirmCloseSession(
      BuildContext context, WidgetRef ref, Session session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Session'),
        content: Text(
            'Close session "${session.name}"? You can still view ratings but cannot add new ones.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Close Session')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    late final SessionClosePolicyResult policy;
    try {
      policy =
          await ref.read(evaluateSessionClosePolicyUseCaseProvider).execute(
                sessionId: session.id,
                trialId: trial.id,
              );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not verify session before closing.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final report = policy.completenessReport;
    final summary = policy.attentionSummary;
    final hasCompletenessWarnings = report.issues.any(
      (i) => i.severity == SessionCompletenessIssueSeverity.warning,
    );
    final legacyNeedsAttention = summary.needsAttention;

    if (policy.decision == SessionClosePolicyDecision.blocked) {
      final action = await _showSessionIncompleteBlockerDialog(
        context,
        session,
        report,
      );
      if (!context.mounted) return;
      switch (action) {
        case _SessionIncompleteAction.keepOpen:
        case null:
          return;
        case _SessionIncompleteAction.reviewSession:
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => SessionSummaryScreen(
                trial: trial,
                session: session,
              ),
            ),
          );
          return;
        case _SessionIncompleteAction.plotQueue:
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PlotQueueScreen(
                trial: trial,
                session: session,
              ),
            ),
          );
          return;
      }
    }

    if (!context.mounted) return;

    var forceCloseAfterWarningAck = false;

    if (policy.decision == SessionClosePolicyDecision.warnBeforeClose) {
      final action = await _showSessionCloseCombinedWarningDialog(
        context,
        session,
        report,
        summary,
        hasCompletenessWarnings: hasCompletenessWarnings,
        legacyNeedsAttention: legacyNeedsAttention,
        contextInfoFindings: policy.contextInfoFindings,
      );
      if (!context.mounted) return;
      switch (action) {
        case _SessionCloseAttentionAction.keepOpen:
        case null:
          return;
        case _SessionCloseAttentionAction.reviewSummary:
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => SessionSummaryScreen(
                trial: trial,
                session: session,
              ),
            ),
          );
          return;
        case _SessionCloseAttentionAction.plotQueue:
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PlotQueueScreen(
                trial: trial,
                session: session,
              ),
            ),
          );
          return;
        case _SessionCloseAttentionAction.closeAnyway:
          forceCloseAfterWarningAck = true;
          break;
      }
    }

    if (!context.mounted) return;

    if (policy.decision == SessionClosePolicyDecision.proceedToClose &&
        policy.contextInfoFindings.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Session record'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'For your records:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...policy.contextInfoFindings.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      f.message,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (!context.mounted) return;
    }

    await _runCloseSessionUseCase(
      context,
      ref,
      session,
      forceClose: forceCloseAfterWarningAck,
    );
  }
}

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

class _TrialReadinessSheet extends ConsumerWidget {
  const _TrialReadinessSheet({
    required this.trialId,
    required this.report,
    required this.showExportAnyway,
    required this.onExport,
    required this.onClose,
  });

  final int trialId;
  final TrialReadinessReport report;
  final bool showExportAnyway;
  final VoidCallback onExport;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final readinessCodes = report.checks.map((c) => c.code).toSet();
    final diagnosticExtras = ref
        .watch(trialDiagnosticsProvider(trialId))
        .where(
          (f) =>
              f.source != DiagnosticSource.readiness &&
              !readinessCodes.contains(f.code),
        )
        .toList();
    final exportSnapshot =
        ref.watch(trialExportDiagnosticsSnapshotProvider(trialId));

    List<_ReadinessCheckRow> rowsForSeverity(UnifiedSeverity severity) {
      final fromReport = report.checks
          .where((c) => mapTrialCheckSeverity(c.severity) == severity)
          .map((c) => _ReadinessCheckRow(check: c))
          .toList();
      final fromDiag = diagnosticExtras
          .where((f) => mapFindingDiagnosticSeverity(f.severity) == severity)
          .map((f) => _ReadinessCheckRow.fromFinding(f))
          .toList();
      return [...fromReport, ...fromDiag];
    }

    final blockers = rowsForSeverity(UnifiedSeverity.blocker);
    final warnings = rowsForSeverity(UnifiedSeverity.warning);
    final infos = rowsForSeverity(UnifiedSeverity.info);
    final passes = report.checks
        .where(
          (c) => mapTrialCheckSeverity(c.severity) == UnifiedSeverity.pass,
        )
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Trial readiness',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (diagnosticExtras.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  exportSnapshot != null
                      ? 'From last trial export attempt — ${exportSnapshot.attemptLabel} · Recorded ${DateFormat.yMMMd().add_jm().format(exportSnapshot.publishedAt.toLocal())}. Run export again for current status.'
                      : 'From last trial export attempt',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  shrinkWrap: true,
                  children: [
                    ...blockers,
                    ...warnings,
                    ...infos,
                    if (passes.isNotEmpty)
                      ExpansionTile(
                        initiallyExpanded: false,
                        title: Text(
                          'Show ${passes.length} passed checks',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        children: passes
                            .map((c) => _ReadinessCheckRow(check: c))
                            .toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (showExportAnyway) ...[
                FilledButton(
                  onPressed: onExport,
                  child: const Text('Export anyway'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: onClose,
                  child: const Text('Cancel'),
                ),
              ] else ...[
                FilledButton.tonal(
                  onPressed: onClose,
                  child: const Text('Close'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ReadinessCheckRow extends StatelessWidget {
  const _ReadinessCheckRow({
    required this.check,
    // Reserved for readiness rows that need a source hint; callers use default today.
    // ignore: unused_element_parameter
    this.source,
  })  : _findingSeverity = null,
        _message = null,
        _findingDetail = null,
        _findingSource = null;

  factory _ReadinessCheckRow.fromFinding(DiagnosticFinding f) {
    return _ReadinessCheckRow._finding(
      severity: _mapDiagnosticSeverity(f.severity),
      message: f.message,
      detail: f.detail,
      findingSource: f.source,
    );
  }

  const _ReadinessCheckRow._finding({
    required UnifiedSeverity severity,
    required String message,
    String? detail,
    required DiagnosticSource findingSource,
  })  : check = null,
        source = null,
        _findingSeverity = severity,
        _message = message,
        _findingDetail = detail,
        _findingSource = findingSource;

  final TrialReadinessCheck? check;
  final DiagnosticSource? source;
  final UnifiedSeverity? _findingSeverity;
  final String? _message;
  final String? _findingDetail;
  final DiagnosticSource? _findingSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unified = check != null
        ? mapTrialCheckSeverity(check!.severity)
        : _findingSeverity!;
    final label = check?.label ?? _message!;
    final detailText = check?.detail ?? _findingDetail;
    final hintSource = check != null ? source : _findingSource;
    IconData icon;
    Color color;
    switch (unified) {
      case UnifiedSeverity.blocker:
        icon = Icons.close;
        color = scheme.error;
        break;
      case UnifiedSeverity.warning:
        icon = Icons.warning_amber_outlined;
        color = AppDesignTokens.warningFg;
        break;
      case UnifiedSeverity.pass:
        icon = Icons.check;
        color = AppDesignTokens.successFg;
        break;
      case UnifiedSeverity.info:
        icon = Icons.info_outline;
        color = AppDesignTokens.primary;
        break;
    }
    final hintText = hintSource != null &&
            hintSource != DiagnosticSource.readiness &&
            _sourceLabel(hintSource).isNotEmpty
        ? _sourceLabel(hintSource)
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (detailText != null && detailText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detailText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hintText != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                hintText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExportFormatSheet extends ConsumerStatefulWidget {
  const _ExportFormatSheet({
    required this.trial,
    required this.allowedFormats,
  });
  final Trial trial;
  final List<ExportFormat> allowedFormats;

  @override
  ConsumerState<_ExportFormatSheet> createState() => _ExportFormatSheetState();
}

class _ExportFormatSheetState extends ConsumerState<_ExportFormatSheet> {
  ExportFormat _selected = ExportFormat.armHandoff;

  @override
  void initState() {
    super.initState();
    _initSelected(widget.allowedFormats);
  }

  @override
  void didUpdateWidget(covariant _ExportFormatSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.allowedFormats != widget.allowedFormats) {
      _initSelected(widget.allowedFormats);
    }
  }

  void _initSelected(List<ExportFormat> allowed) {
    if (allowed.isEmpty) {
      _selected = ExportFormat.flatCsv;
      return;
    }
    _selected = allowed.contains(_selected) ? _selected : allowed.first;
  }

  @override
  Widget build(BuildContext context) {
    final allowed = widget.allowedFormats;
    if (allowed.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'No export options available for this trial.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'Export',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            'Choose a format for ${widget.trial.name}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ),
        ...allowed.map((format) {
          final isSelected = _selected == format;
          return InkWell(
            onTap: () => setState(() => _selected = format),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE8F5EE) : Colors.white,
                border: const Border(
                  bottom: BorderSide(
                    color: Color(0xFFF0EDE8),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    format.icon,
                    color: isSelected
                        ? const Color(0xFF2D5A40)
                        : Colors.grey.shade400,
                    size: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              format.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? const Color(0xFF2D5A40)
                                    : const Color(0xFF1A1A1A),
                              ),
                            ),
                            if (format.badge.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2D5A40),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  format.badge,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          format.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF2D5A40),
                      size: 20,
                    ),
                ],
              ),
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5A40),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context, _selected),
              child: const Text(
                'Export',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.item,
    required this.onTap,
  });

  final AttentionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color dot;
    final Color label;

    switch (item.severity) {
      case AttentionSeverity.high:
        dot = AppDesignTokens.flagColor;
        label = AppDesignTokens.warningFg;
        break;
      case AttentionSeverity.medium:
        dot = AppDesignTokens.flagColor;
        label = AppDesignTokens.partialFg;
        break;
      case AttentionSeverity.low:
        dot = AppDesignTokens.secondaryText;
        label = AppDesignTokens.secondaryText;
        break;
      case AttentionSeverity.info:
        dot = AppDesignTokens.appliedColor;
        label = AppDesignTokens.successFg;
        break;
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing16,
          vertical: AppDesignTokens.spacing8,
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppDesignTokens.spacing12),
            Expanded(
              child: Text(
                item.label,
                style: AppDesignTokens.bodyStyle(
                  fontSize: 13,
                  color: label,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: AppDesignTokens.iconSubtle,
            ),
          ],
        ),
      ),
    );
  }
}
