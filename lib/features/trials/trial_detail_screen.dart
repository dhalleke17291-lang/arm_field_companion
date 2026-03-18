import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/session_state.dart';
import '../../core/trial_state.dart';
import '../sessions/create_session_screen.dart';
import '../sessions/session_detail_screen.dart';
import '../sessions/session_summary_screen.dart';
import '../plots/plot_queue_screen.dart';
import 'full_protocol_details_screen.dart';
import '../../core/providers.dart';
import '../../core/design/app_design_tokens.dart';
import '../diagnostics/trial_readiness.dart';
import '../export/export_format.dart';
import '../../core/widgets/loading_error_widgets.dart';
import '../../shared/widgets/app_empty_state.dart';
import 'tabs/assessments_tab.dart';
import 'tabs/applications_tab.dart';
import 'tabs/treatments_tab.dart';
import 'tabs/seeding_tab.dart';
import 'tabs/plots_tab.dart';
import 'tabs/photos_tab.dart';
import 'tabs/timeline_tab.dart';
import 'trial_setup_screen.dart';
import '../diagnostics/edited_items_screen.dart';
import '../recovery/recovery_screen.dart';

/// Key for persisting that the trial module hub one-time scroll hint was seen or dismissed.
const String _kTrialHubHintDismissedKey = 'trial_module_hub_hint_dismissed';

class TrialDetailScreen extends ConsumerStatefulWidget {
  final Trial trial;

  const TrialDetailScreen({super.key, required this.trial});

  @override
  ConsumerState<TrialDetailScreen> createState() => _TrialDetailScreenState();
}

class _TrialDetailScreenState extends ConsumerState<TrialDetailScreen> {
  int _selectedTabIndex = 0;
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
    _hubScrollController = ScrollController();
    _hubScrollController.addListener(_onHubScroll);
    _scheduleHubHintOnce();
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

  Future<ExportFormat?> _showExportSheet() async {
    return showModalBottomSheet<ExportFormat>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ExportFormatSheet(trial: widget.trial),
    );
  }

  Future<void> _runExport(ExportFormat format) async {
    setState(() => _isExporting = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exporting...')),
      );
    }
    try {
      final useCase = ref.read(exportTrialUseCaseProvider);
      final bundle = await useCase.execute(
        trial: widget.trial,
        format: format,
      );
      if (!mounted) return;
      // Flat CSV path unchanged: write files and share
      if (format == ExportFormat.flatCsv) {
        final trial = widget.trial;
        final dir = await getTemporaryDirectory();
        final base =
            '${trial.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}_export';
        final files = <XFile>[];
        final names = [
          'observations',
          'observations_arm_transfer',
          'treatments',
          'plot_assignments',
          'applications',
          'seeding',
          'sessions',
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _onExportTapped(
      BuildContext context, WidgetRef ref, Trial trial) async {
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
    final format = await _showExportSheet();
    if (!mounted || format == null) return;
    _runExport(format);
  }

  Future<void> _openReadinessReview(
      BuildContext context, WidgetRef ref, Trial trial) async {
    final report = await ref.read(trialReadinessProvider(trial.id).future);
    if (!context.mounted) return;
    _showReadinessSheet(
      context,
      ref,
      trial,
      report,
      showExportAnyway: report.blockerCount == 0,
    );
  }

  void _showReadinessSheet(
    BuildContext context,
    WidgetRef ref,
    Trial trial,
    TrialReadinessReport report, {
    required bool showExportAnyway,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TrialReadinessSheet(
        report: report,
        showExportAnyway: showExportAnyway,
        onExport: () async {
          Navigator.pop(ctx);
          final format = await _showExportSheet();
          if (!mounted || format == null) return;
          _runExport(format);
        },
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  /// Informational trust signals only; does not affect export or readiness logic.
  Widget _buildTrialTrustSummaryCard(
      BuildContext context, WidgetRef ref, Trial trial) {
    final theme = Theme.of(context);
    final readinessAsync = ref.watch(trialReadinessProvider(trial.id));
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final ratedAsync = ref.watch(ratedPlotsCountForTrialProvider(trial.id));
    final correctionsAsync =
        ref.watch(sessionIdsWithCorrectionsForTrialProvider(trial.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          border: Border.all(color: AppDesignTokens.borderCrisp),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: readinessAsync.when(
            loading: () => const Text(
              'Updating trust summary…',
              style: TextStyle(
                fontSize: 13,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            error: (_, __) => const Text(
              'Trust summary unavailable.',
              style: TextStyle(
                fontSize: 13,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            data: (report) {
              final ({Color bg, Color fg}) statusStyle =
                  switch (report.status) {
                TrialReadinessStatus.ready => (
                    bg: const Color(0xFFE8F5E9),
                    fg: const Color(0xFF2E7D32),
                  ),
                TrialReadinessStatus.readyWithWarnings => (
                    bg: const Color(0xFFFFF8E6),
                    fg: const Color(0xFFB45309),
                  ),
                TrialReadinessStatus.notReady => (
                    bg: theme.colorScheme.errorContainer,
                    fg: theme.colorScheme.onErrorContainer,
                  ),
              };
              final statusLabel = switch (report.status) {
                TrialReadinessStatus.ready => 'Ready',
                TrialReadinessStatus.readyWithWarnings =>
                  'Ready with warnings',
                TrialReadinessStatus.notReady => 'Not ready',
              };

              final totalPlots = plotsAsync.valueOrNull?.length;
              final rated = ratedAsync.valueOrNull;
              final int? unrated = totalPlots != null &&
                      rated != null &&
                      totalPlots > 0
                  ? (totalPlots - rated).clamp(0, totalPlots)
                  : null;

              final corrections =
                  correctionsAsync.valueOrNull?.length ?? 0;
              final correctionsLoaded = correctionsAsync.hasValue;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Trust summary',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusStyle.bg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: statusStyle.fg,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (unrated != null && unrated > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '$unrated plot${unrated == 1 ? '' : 's'} without ratings',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppDesignTokens.primaryText,
                      ),
                    ),
                  ],
                  if (correctionsLoaded && corrections > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '$corrections session${corrections == 1 ? '' : 's'} with corrections',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppDesignTokens.primaryText,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 4,
                    runSpacing: 0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () =>
                            _openReadinessReview(context, ref, trial),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Review Readiness'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  EditedItemsScreen(trialId: trial.id),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Edited Items'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => RecoveryScreen(trialId: trial.id),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Recovery'),
                      ),
                    ],
                  ),
                  Text(
                    'Edited Items and Recovery are app-wide.',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.3,
                      color: AppDesignTokens.secondaryText.withValues(
                          alpha: 0.85),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildExportIconWithBadge(
      BuildContext context, WidgetRef ref, Trial trial) {
    final theme = Theme.of(context);
    final readinessAsync = ref.watch(trialReadinessProvider(trial.id));
    final showBadge = readinessAsync.valueOrNull != null &&
        (readinessAsync.value!.blockerCount > 0 ||
            readinessAsync.value!.warningCount > 0);
    final isBlocker = (readinessAsync.valueOrNull?.blockerCount ?? 0) > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isExporting
            ? null
            : () => _onExportTapped(context, ref, trial),
        borderRadius: BorderRadius.circular(20),
        child: Tooltip(
          message: 'Export trial data (bundle or ARM package)',
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.ios_share_outlined,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Export',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
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
                          : const Color(0xFFEF9F27),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrialOverflowMenu(BuildContext context, Trial trial) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      tooltip: 'More',
      padding: const EdgeInsets.all(8),
      onSelected: (value) {
        if (value == 'delete_trial') {
          _confirmAndSoftDeleteTrial(context, trial);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
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

    final viewportHeight = MediaQuery.sizeOf(context).height;
    final maxHeaderHeight = viewportHeight * 0.45;

    final isPlotsTab = _selectedTabIndex == 0;
    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      body: Stack(
        children: [
          isPlotsTab
              ? _buildUnifiedScrollBody(context, ref, currentTrial)
              : _buildSplitBody(
                  context,
                  ref,
                  currentTrial,
                  maxHeaderHeight,
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
      bottomNavigationBar: isPlotsTab
          ? PlotDetailsBar(trial: currentTrial)
          : null,
    );
  }

  String? _effectiveTrialStatus(WidgetRef ref, Trial trial) {
    final sessions =
        ref.watch(sessionsForTrialProvider(trial.id)).valueOrNull ?? [];
    final hasOpenSession = sessions.any(isSessionOpenForFieldWork);
    if (hasOpenSession &&
        trial.status != kTrialStatusClosed &&
        trial.status != kTrialStatusArchived) {
      return kTrialStatusActive;
    }
    return null;
  }

  Widget _buildUnifiedScrollBody(
      BuildContext context, WidgetRef ref, Trial currentTrial) {
    final effectiveStatus =
        _effectiveTrialStatus(ref, currentTrial) ?? currentTrial.status;
    return SingleChildScrollView(
      controller: _hubScrollController,
      child: Column(
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentTrial.name,
                            style: AppDesignTokens.headerTitleStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (currentTrial.crop != null)
                                Expanded(
                                  child: Text(
                                    currentTrial.crop!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.92),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                    if (effectiveStatus.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    labelForTrialStatus(effectiveStatus),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.9),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.white, size: 22),
                      iconSize: 22,
                      padding: const EdgeInsets.all(8),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              TrialSetupScreen(trial: currentTrial),
                        ),
                      ),
                      tooltip: 'Trial setup',
                    ),
                    IconButton(
                      icon: const Icon(Icons.description_outlined,
                          color: Colors.white, size: 22),
                      iconSize: 22,
                      padding: const EdgeInsets.all(8),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              FullProtocolDetailsScreen(trial: currentTrial),
                        ),
                      ),
                      tooltip: 'View full protocol',
                    ),
                    _buildExportIconWithBadge(context, ref, currentTrial),
                    const SizedBox(width: 4),
                    _buildTrialOverflowMenu(context, currentTrial),
                  ],
                ),
              ),
            ),
          ),
          _buildTrialStatusBar(context, ref, currentTrial,
              displayStatus: effectiveStatus),
          const SizedBox(height: AppDesignTokens.spacing8),
          SizedBox(
            height: 110,
            child: _TrialModuleHub(
              scrollController: _hubScrollController,
              selectedIndex: _selectedTabIndex == _sessionsIndex
                  ? _previousTabIndex
                  : _selectedTabIndex,
              onSelected: (index) {
                setState(() => _selectedTabIndex = index);
              },
              onUserScroll: _dismissHubHint,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing8),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildSessionsBar(
              context,
              ref,
              widget.trial.id,
              ref.watch(sessionsForTrialProvider(widget.trial.id)),
              ref.watch(seedingEventForTrialProvider(widget.trial.id)),
            ),
          ),
          _buildTrialTrustSummaryCard(context, ref, currentTrial),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: PlotsTab(trial: currentTrial, embeddedInScroll: true),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSplitBody(
    BuildContext context,
    WidgetRef ref,
    Trial currentTrial,
    double maxHeaderHeight,
  ) {
    final effectiveStatus =
        _effectiveTrialStatus(ref, currentTrial) ?? currentTrial.status;
    return Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeaderHeight),
          child: SingleChildScrollView(
            child: Column(
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
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () =>
                                Navigator.of(context).maybePop(),
                            tooltip: 'Back',
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currentTrial.name,
                                  style: AppDesignTokens.headerTitleStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (currentTrial.crop != null)
                                      Expanded(
                                        child: Text(
                                          currentTrial.crop!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white
                                                .withValues(alpha: 0.92),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    if (effectiveStatus.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          labelForTrialStatus(
                                              effectiveStatus),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white
                                                .withValues(alpha: 0.9),
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: Colors.white, size: 22),
                            iconSize: 22,
                            padding: const EdgeInsets.all(8),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    TrialSetupScreen(trial: currentTrial),
                              ),
                            ),
                            tooltip: 'Trial setup',
                          ),
                          IconButton(
                            icon: const Icon(Icons.description_outlined,
                                color: Colors.white, size: 22),
                            iconSize: 22,
                            padding: const EdgeInsets.all(8),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => FullProtocolDetailsScreen(
                                    trial: currentTrial),
                              ),
                            ),
                            tooltip: 'View full protocol',
                          ),
                          _buildExportIconWithBadge(
                              context, ref, currentTrial),
                          const SizedBox(width: 4),
                          _buildTrialOverflowMenu(context, currentTrial),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildTrialStatusBar(context, ref, currentTrial,
                    displayStatus: effectiveStatus),
                const SizedBox(height: AppDesignTokens.spacing8),
                SizedBox(
                  height: 110,
                  child: _TrialModuleHub(
                    scrollController: _hubScrollController,
                    selectedIndex: _selectedTabIndex == _sessionsIndex
                        ? _previousTabIndex
                        : _selectedTabIndex,
                    onSelected: (index) {
                      setState(() => _selectedTabIndex = index);
                    },
                    onUserScroll: _dismissHubHint,
                  ),
                ),
                const SizedBox(height: AppDesignTokens.spacing8),
                if (_selectedTabIndex != _sessionsIndex) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildSessionsBar(
                      context,
                      ref,
                      widget.trial.id,
                      ref.watch(sessionsForTrialProvider(widget.trial.id)),
                      ref.watch(
                          seedingEventForTrialProvider(widget.trial.id)),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ),
        _buildTrialTrustSummaryCard(context, ref, currentTrial),
        Expanded(
          child: IndexedStack(
            index: _selectedTabIndex,
            children: [
              PlotsTab(trial: currentTrial),
              SeedingTab(trial: currentTrial),
              ApplicationsTab(trial: currentTrial),
              AssessmentsTab(trial: currentTrial),
              TreatmentsTab(trial: currentTrial),
              PhotosTab(trial: currentTrial),
              TimelineTab(trial: currentTrial),
              SessionsView(
                trial: currentTrial,
                onBack: () =>
                    setState(() => _selectedTabIndex = _previousTabIndex),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static ({Color bg, Color fg, Color border}) _trialStatusPillStyle(String status) {
    switch (status) {
      case kTrialStatusDraft:
        return (
          bg: AppDesignTokens.emptyBadgeBg,
          fg: AppDesignTokens.emptyBadgeFg,
          border: AppDesignTokens.borderCrisp,
        );
      case kTrialStatusReady:
        return (
          bg: AppDesignTokens.primaryTint,
          fg: AppDesignTokens.primary,
          border: AppDesignTokens.primary.withValues(alpha: 0.35),
        );
      case kTrialStatusActive:
        return (
          bg: AppDesignTokens.openSessionBgLight,
          fg: AppDesignTokens.openSessionBg,
          border: AppDesignTokens.openSessionBg.withValues(alpha: 0.4),
        );
      case kTrialStatusClosed:
      case kTrialStatusArchived:
        return (
          bg: const Color(0xFFF3F4F6),
          fg: const Color(0xFF6B7280),
          border: AppDesignTokens.borderCrisp,
        );
      default:
        return (
          bg: AppDesignTokens.emptyBadgeBg,
          fg: AppDesignTokens.primaryText,
          border: AppDesignTokens.borderCrisp,
        );
    }
  }

  Widget _buildTrialStatusBar(
    BuildContext context,
    WidgetRef ref,
    Trial trial, {
    String? displayStatus,
  }) {
    final statusForDisplay = displayStatus ?? trial.status;
    // Next action must follow *effective* status so UI never shows Active + "Mark Active".
    final nextStatuses = allowedNextTrialStatuses(statusForDisplay);
    final nextStatus = nextStatuses.isNotEmpty ? nextStatuses.first : null;
    final bool hideLifecycleCta = statusForDisplay == kTrialStatusClosed ||
        statusForDisplay == kTrialStatusArchived;
    final buttonLabel = hideLifecycleCta
        ? null
        : nextStatus == kTrialStatusReady
            ? 'Mark Ready'
            : nextStatus == kTrialStatusActive
                ? 'Mark Active'
                : nextStatus == kTrialStatusClosed
                    ? 'Close Trial'
                    : nextStatus == kTrialStatusArchived
                        ? 'Archive'
                        : null;
    final pill = _trialStatusPillStyle(statusForDisplay);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppDesignTokens.sectionHeaderBg,
        border: Border(bottom: BorderSide(color: AppDesignTokens.borderCrisp)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Trial status',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: pill.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: pill.border, width: 1),
            ),
            child: Text(
              labelForTrialStatus(statusForDisplay),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: pill.fg,
              ),
            ),
          ),
          const Spacer(),
          if (buttonLabel != null && nextStatus != null)
            FilledButton(
              onPressed: () => _transitionTrialStatus(context, ref, nextStatus),
              style: FilledButton.styleFrom(
                backgroundColor: AppDesignTokens.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
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
            'Activating this trial will lock the protocol structure. '
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
    }
    final repo = ref.read(trialRepositoryProvider);
    final ok = await repo.updateTrialStatus(widget.trial.id, newStatus);
    if (!context.mounted) return;
    if (ok) {
      ref.invalidate(trialProvider(widget.trial.id));
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update trial status')),
      );
    }
  }

  /// Single date format for session bar (e.g. "Mar 17"). Never show raw ISO.
  static String _formatSessionDateLocal(String sessionDateLocal) {
    try {
      final dt = DateTime.parse(sessionDateLocal);
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return '';
    }
  }

  /// Session label for strip: strip leading ISO date so we don't duplicate date.
  static String _sessionDisplayLabel(Session session) {
    final name = session.name.trim();
    final stripped = name.replaceFirst(RegExp(r'^\d{4}-\d{2}-\d{2}\s*'), '').trim();
    return stripped.isNotEmpty ? stripped : 'Session';
  }

  Widget _buildSessionsBar(
    BuildContext context,
    WidgetRef ref,
    int trialId,
    AsyncValue<List<Session>> sessionsAsync,
    AsyncValue<SeedingEvent?> seedingEventAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing16,
        vertical: AppDesignTokens.spacing4,
      ),
      child: Material(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusXSmall),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          key: const Key('trial_detail_sessions_bar'),
          onTap: () => setState(() {
            _previousTabIndex = _selectedTabIndex;
            _selectedTabIndex = _sessionsIndex;
          }),
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusXSmall),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDesignTokens.spacing12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusXSmall),
              border: Border.all(color: AppDesignTokens.borderCrisp),
            ),
            child: sessionsAsync.when(
              loading: () => _buildSessionStripRow(
                context,
                statusLabel: '…',
                sessionLabel: 'Sessions',
                progressText: null,
                dateText: null,
                actionLabel: 'Start or continue',
                isActive: false,
              ),
              error: (_, __) => _buildSessionStripRow(
                context,
                statusLabel: '…',
                sessionLabel: 'Sessions',
                progressText: null,
                dateText: null,
                actionLabel: 'Start or continue',
                isActive: false,
              ),
              data: (sessions) {
                final active =
                    sessions.where(isSessionOpenForFieldWork).toList();
                final primary = active.isNotEmpty
                    ? active.first
                    : (sessions.isNotEmpty ? sessions.first : null);
                final isActive =
                    primary != null && isSessionOpenForFieldWork(primary);
                String? progressText;
                if (primary != null) {
                  final ratings = ref
                      .watch(sessionRatingsProvider(primary.id))
                      .valueOrNull ?? [];
                  final plots =
                      ref.watch(plotsForTrialProvider(trialId)).valueOrNull ?? [];
                  final ratedCount =
                      ratings.map((r) => r.plotPk).toSet().length;
                  final totalCount = plots.length;
                  if (totalCount > 0) {
                    progressText = '$ratedCount/$totalCount rated';
                  }
                }
                final dateText = primary != null
                    ? _formatSessionDateLocal(primary.sessionDateLocal)
                    : null;
                final actionLabel = sessions.isEmpty
                    ? 'Start or continue'
                    : active.isEmpty
                        ? (sessions.length == 1 ? 'Open' : '${sessions.length} sessions')
                        : (active.length == 1 ? 'Open' : '${active.length} active');
                return _buildSessionStripRow(
                  context,
                  statusLabel: isActive ? 'Active' : 'Closed',
                  sessionLabel: primary != null
                      ? _sessionDisplayLabel(primary)
                      : 'Sessions',
                  progressText: progressText,
                  dateText: dateText,
                  actionLabel: actionLabel,
                  isActive: isActive,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionStripRow(
    BuildContext context, {
    required String statusLabel,
    required String sessionLabel,
    required String? progressText,
    required String? dateText,
    required String actionLabel,
    required bool isActive,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line 1: status + date
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppDesignTokens.openSessionBgLight
                            : AppDesignTokens.emptyBadgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? AppDesignTokens.openSessionBg
                                  : AppDesignTokens.emptyBadgeFg,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? AppDesignTokens.openSessionBg
                                  : AppDesignTokens.emptyBadgeFg,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (dateText != null && dateText.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Text(
                        dateText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppDesignTokens.primaryText,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                // Line 2: progress · session label (or actionLabel when no session)
                Row(
                  children: [
                    if (progressText != null)
                      Text(
                        progressText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppDesignTokens.secondaryText,
                        ),
                      ),
                    if (progressText != null && sessionLabel != 'Sessions')
                      Text(
                        '   ·   ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppDesignTokens.secondaryText.withValues(alpha: 0.7),
                        ),
                      ),
                    if (sessionLabel != 'Sessions')
                      Expanded(
                        child: Text(
                          sessionLabel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppDesignTokens.primaryText.withValues(alpha: 0.75),
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      Text(
                        actionLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppDesignTokens.secondaryText,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppDesignTokens.iconSubtle,
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _TrialModuleHub extends StatelessWidget {
  final ScrollController scrollController;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onUserScroll;

  const _TrialModuleHub({
    required this.scrollController,
    required this.selectedIndex,
    required this.onSelected,
    this.onUserScroll,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      (0, Icons.grid_on, 'Plots'),
      (1, Icons.agriculture, 'Seeding'),
      (2, Icons.science, 'Applications'),
      (3, Icons.assessment, 'Assessments'),
      (4, Icons.science_outlined, 'Treatments'),
      (5, Icons.photo_library, 'Photos'),
      (6, Icons.timeline_outlined, 'Timeline'),
    ];

    final listView = ListView.separated(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      padding:
          const EdgeInsets.only(left: AppDesignTokens.spacing16, right: 48),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          const SizedBox(width: AppDesignTokens.spacing12),
      itemBuilder: (context, index) {
        final item = items[index];
        return _DockTile(
          icon: item.$2,
          label: item.$3,
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

    return Container(
      height: 110,
      width: double.infinity,
      padding: const EdgeInsets.only(
          top: AppDesignTokens.spacing8, bottom: AppDesignTokens.spacing8),
      child: content,
    );
  }
}

class _DockTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DockTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.12 : 0.96,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDesignTokens.spacing12,
              vertical: AppDesignTokens.spacing8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected
                    ? AppDesignTokens.primary
                    : AppDesignTokens.iconSubtle,
                size: selected ? 26 : 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppDesignTokens.primary
                      : AppDesignTokens.secondaryText,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: selected ? 13 : 12,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 2,
                width: selected ? 20 : 0,
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

/// Compact pill for session status (Open, Needs attention). Professional, consistent styling.
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
                  final user = await ref.read(currentUserProvider.future);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(value == 'arm_xml'
                            ? 'Exporting ARM XML...'
                            : 'Exporting...')),
                  );
                  final result = value == 'arm_xml'
                      ? await ref
                          .read(exportTrialClosedSessionsArmXmlUsecaseProvider)
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
                          content:
                              Text('Exported ${result.sessionCount} sessions')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.errorMessage ?? 'Export failed'),
                        backgroundColor: Colors.red,
                      ),
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
                    child: Text('Closed Sessions (ARM XML ZIP)'),
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
                          ? _buildEmptySessions(context)
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

  Widget _buildEmptySessions(BuildContext context) {
    return AppEmptyState(
      icon: Icons.folder_open,
      title: 'No Sessions Yet',
      subtitle: 'Start a session to begin collecting field data.',
      action: FilledButton.icon(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CreateSessionScreen(trial: trial))),
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
          child: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CreateSessionScreen(trial: trial))),
            icon: const Icon(Icons.add),
            label: const Text('New Session'),
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
    final hasEdited = ratings.any(
            (r) => r.amended || (r.previousId != null)) ||
        correctionSessionIds.contains(session.id);

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
      child: ListTile(
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
                    builder: (_) =>
                        SessionDetailScreen(trial: trial, session: session)));
          }
        },
        onLongPress:
            isOpen ? () => _confirmCloseSession(context, ref, session) : null,
        leading: Container(
          padding: const EdgeInsets.all(AppDesignTokens.spacing8),
          decoration: BoxDecoration(
            color: isOpen
                ? AppDesignTokens.openSessionBgLight
                : AppDesignTokens.emptyBadgeBg,
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusXSmall),
          ),
          child: Icon(
            isOpen ? Icons.play_circle : Icons.check_circle,
            color: isOpen
                ? AppDesignTokens.openSessionBg
                : AppDesignTokens.emptyBadgeFg,
            size: 20,
          ),
        ),
        title: Text(_shortSessionName(session.name, session.sessionDateLocal),
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppDesignTokens.primaryText)),
        subtitle: Text(_formatSessionTimes(session)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasEdited) ...[
              const _SessionPill(
                label: 'Edited',
                backgroundColor: AppDesignTokens.sectionHeaderBg,
                foregroundColor: AppDesignTokens.secondaryText,
              ),
              const SizedBox(width: AppDesignTokens.spacing8),
            ],
            _buildSessionTrailing(isOpen, needsAttention),
          ],
        ),
      ),
    );
  }

  /// Elegant trailing: Open pill, or Needs attention pill, or Closed.
  Widget _buildSessionTrailing(bool isOpen, bool needsAttention) {
    if (isOpen && !needsAttention) {
      return const _SessionPill(
        label: 'Open',
        backgroundColor: AppDesignTokens.openSessionBg,
        foregroundColor: Colors.white,
      );
    }
    if (needsAttention) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOpen) ...[
            const _SessionPill(
              label: 'Open',
              backgroundColor: AppDesignTokens.openSessionBg,
              foregroundColor: Colors.white,
            ),
            const SizedBox(width: AppDesignTokens.spacing8),
          ],
          const _SessionPill(
            label: 'Needs attention',
            backgroundColor: AppDesignTokens.warningBg,
            foregroundColor: AppDesignTokens.warningFg,
            icon: Icons.info_outline_rounded,
          ),
        ],
      );
    }
    return const Text(
      'Closed',
      style: TextStyle(
        color: AppDesignTokens.secondaryText,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
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

  /// Matches plot-queue / session summary semantics for pre-close warning only.
  _SessionCloseAttentionSummary _computeSessionCloseAttentionSummary({
    required List<Plot> plots,
    required Set<int> ratedPks,
    required Set<int> flaggedIds,
    required List<RatingRecord> ratings,
    required Set<int> corrections,
  }) {
    final totalPlots = plots.length;
    final ratedPlots = ratedPks.length;
    final unratedPlots = plots.where((p) => !ratedPks.contains(p.id)).length;
    final flaggedPlots = flaggedIds.length;
    final ratingsByPlot = <int, List<RatingRecord>>{};
    for (final r in ratings) {
      ratingsByPlot.putIfAbsent(r.plotPk, () => []).add(r);
    }
    var issuesPlots = 0;
    var editedPlots = 0;
    for (final plot in plots) {
      final pr = ratingsByPlot[plot.id] ?? [];
      if (pr.any((r) => r.resultStatus != 'RECORDED')) {
        issuesPlots++;
      }
      if (pr.any((r) => r.amended || (r.previousId != null)) ||
          corrections.contains(plot.id)) {
        editedPlots++;
      }
    }
    return _SessionCloseAttentionSummary(
      totalPlots: totalPlots,
      ratedPlots: ratedPlots,
      unratedPlots: unratedPlots,
      flaggedPlots: flaggedPlots,
      issuesPlots: issuesPlots,
      editedPlots: editedPlots,
    );
  }

  Future<_SessionCloseAttentionAction?> _showSessionCloseAttentionDialog(
    BuildContext context,
    Session session,
    _SessionCloseAttentionSummary s,
  ) {
    final lines = <String>[
      'Rated plots: ${s.ratedPlots} of ${s.totalPlots}',
      if (s.unratedPlots > 0) 'Unrated plots: ${s.unratedPlots}',
      if (s.flaggedPlots > 0) 'Flagged plots: ${s.flaggedPlots}',
      if (s.issuesPlots > 0) 'Plots with issues: ${s.issuesPlots}',
      if (s.editedPlots > 0) 'Edited plots: ${s.editedPlots}',
    ];
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
              ...lines.map(
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
    Session session,
  ) async {
    final userId = await ref.read(currentUserIdProvider.future);
    final useCase = ref.read(closeSessionUseCaseProvider);
    final result = await useCase.execute(
      sessionId: session.id,
      trialId: trial.id,
      raterName: session.raterName,
      closedByUserId: userId,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            result.success ? 'Session closed' : result.errorMessage ?? 'Error'),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ));
    }
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

    _SessionCloseAttentionSummary? summary;
    try {
      final plots = await ref.read(plotsForTrialProvider(trial.id).future);
      final ratedPks =
          await ref.read(ratedPlotPksProvider(session.id).future);
      final flaggedIds =
          await ref.read(flaggedPlotIdsForSessionProvider(session.id).future);
      final ratings =
          await ref.read(sessionRatingsProvider(session.id).future);
      final corrections =
          await ref.read(plotPksWithCorrectionsForSessionProvider(session.id).future);
      summary = _computeSessionCloseAttentionSummary(
        plots: plots,
        ratedPks: ratedPks,
        flaggedIds: flaggedIds,
        ratings: ratings,
        corrections: corrections,
      );
    } catch (_) {
      summary = null;
    }

    if (!context.mounted) return;

    if (summary != null && summary.needsAttention) {
      final action = await _showSessionCloseAttentionDialog(
        context,
        session,
        summary,
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
          break;
      }
    }

    if (!context.mounted) return;
    await _runCloseSessionUseCase(context, ref, session);
  }
}

class _SessionCloseAttentionSummary {
  const _SessionCloseAttentionSummary({
    required this.totalPlots,
    required this.ratedPlots,
    required this.unratedPlots,
    required this.flaggedPlots,
    required this.issuesPlots,
    required this.editedPlots,
  });

  final int totalPlots;
  final int ratedPlots;
  final int unratedPlots;
  final int flaggedPlots;
  final int issuesPlots;
  final int editedPlots;

  bool get needsAttention =>
      unratedPlots > 0 ||
      flaggedPlots > 0 ||
      issuesPlots > 0 ||
      editedPlots > 0;
}

enum _SessionCloseAttentionAction {
  keepOpen,
  reviewSummary,
  plotQueue,
  closeAnyway,
}

class _TrialReadinessSheet extends StatelessWidget {
  const _TrialReadinessSheet({
    required this.report,
    required this.showExportAnyway,
    required this.onExport,
    required this.onClose,
  });

  final TrialReadinessReport report;
  final bool showExportAnyway;
  final VoidCallback onExport;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blockers = report.checks
        .where((c) => c.severity == TrialCheckSeverity.blocker)
        .toList();
    final warnings = report.checks
        .where((c) => c.severity == TrialCheckSeverity.warning)
        .toList();
    final passes = report.checks
        .where((c) => c.severity == TrialCheckSeverity.pass)
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
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  shrinkWrap: true,
                  children: [
                    ...blockers.map((c) => _ReadinessCheckRow(check: c)),
                    ...warnings.map((c) => _ReadinessCheckRow(check: c)),
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
  const _ReadinessCheckRow({required this.check});

  final TrialReadinessCheck check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    IconData icon;
    Color color;
    switch (check.severity) {
      case TrialCheckSeverity.blocker:
        icon = Icons.close;
        color = scheme.error;
        break;
      case TrialCheckSeverity.warning:
        icon = Icons.warning_amber_outlined;
        color = Colors.amber.shade700;
        break;
      case TrialCheckSeverity.pass:
        icon = Icons.check;
        color = AppDesignTokens.successFg;
        break;
    }
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
                  check.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (check.detail != null && check.detail!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    check.detail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportFormatSheet extends ConsumerStatefulWidget {
  const _ExportFormatSheet({required this.trial});
  final Trial trial;

  @override
  ConsumerState<_ExportFormatSheet> createState() => _ExportFormatSheetState();
}

class _ExportFormatSheetState extends ConsumerState<_ExportFormatSheet> {
  ExportFormat _selected = ExportFormat.armHandoff;

  @override
  Widget build(BuildContext context) {
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
        ...ExportFormat.values.map((format) {
          final isSelected = _selected == format;
          return InkWell(
            onTap: () => setState(() => _selected = format),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE8F5EE)
                    : Colors.white,
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
