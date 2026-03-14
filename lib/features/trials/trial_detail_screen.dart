import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/trial_state.dart';
import '../sessions/create_session_screen.dart';
import '../sessions/session_detail_screen.dart';
import '../plots/plot_queue_screen.dart';
import 'full_protocol_details_screen.dart';
import '../../core/providers.dart';
import '../../core/design/app_design_tokens.dart';
import '../diagnostics/trial_readiness.dart';
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

  Future<void> _runExport(
      BuildContext context, WidgetRef ref, Trial trial) async {
    setState(() => _isExporting = true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exporting...')),
      );
    }
    try {
      final useCase = ref.read(exportTrialUseCaseProvider);
      final bundle = await useCase.execute(trial.id.toString());
      final dir = await getTemporaryDirectory();
      final base = '${trial.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}_export';
      final files = <XFile>[];
      final names = [
        'observations',
        'treatments',
        'plot_assignments',
        'applications',
        'seeding',
        'sessions',
        'data_dictionary',
      ];
      final contents = [
        bundle.observationsCsv,
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
      if (!context.mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        files,
        text: '${trial.name} – trial export (${files.length} CSV files)',
        sharePositionOrigin: box == null
            ? const Rect.fromLTWH(0, 0, 100, 100)
            : box.localToGlobal(Offset.zero) & box.size,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export ready to share')),
      );
    } catch (e) {
      if (!context.mounted) return;
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
    _runExport(context, ref, trial);
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
        onExport: () {
          Navigator.pop(ctx);
          _runExport(context, ref, trial);
        },
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  Widget _buildReadinessCard(BuildContext context, WidgetRef ref, Trial trial) {
    final async = ref.watch(trialReadinessProvider(trial.id));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (report) {
        final status = report.status;
        String statusLabel;
        Color borderColor;
        switch (status) {
          case TrialReadinessStatus.ready:
            statusLabel = 'Ready to export';
            borderColor = AppDesignTokens.successFg;
            break;
          case TrialReadinessStatus.readyWithWarnings:
            statusLabel = 'Ready with warnings';
            borderColor = Colors.amber.shade700;
            break;
          case TrialReadinessStatus.notReady:
            statusLabel = 'Not ready to export';
            borderColor = Theme.of(context).colorScheme.error;
            break;
        }
        final parts = <String>[];
        if (report.warningCount > 0) {
          parts.add('${report.warningCount} warnings');
        }
        if (report.blockerCount > 0) {
          parts.add('${report.blockerCount} blockers');
        }
        final countsLine =
            parts.isEmpty ? 'All checks passed' : parts.join(' · ');

        return Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDesignTokens.spacing16, vertical: 6),
          child: Material(
            color: AppDesignTokens.cardSurface,
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
            child: InkWell(
              onTap: () {
                _showReadinessSheet(
                  context,
                  ref,
                  trial,
                  report,
                  showExportAnyway: report.canExport && report.warningCount > 0,
                );
              },
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDesignTokens.spacing16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(AppDesignTokens.radiusCard),
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: borderColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            countsLine,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppDesignTokens.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _showReadinessSheet(
                          context,
                          ref,
                          trial,
                          report,
                          showExportAnyway:
                              report.canExport && report.warningCount > 0,
                        );
                      },
                      child: const Text('View details'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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

  Widget _buildUnifiedScrollBody(
      BuildContext context, WidgetRef ref, Trial currentTrial) {
    return SingleChildScrollView(
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
                            'Trial',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.7),
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentTrial.name,
                            style: AppDesignTokens.headerTitleStyle(
                              fontSize: 17,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (currentTrial.crop != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              currentTrial.crop!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (currentTrial.status.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          currentTrial.status,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.white, size: 22),
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
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              FullProtocolDetailsScreen(trial: currentTrial),
                        ),
                      ),
                      tooltip: 'View full protocol',
                    ),
                    IconButton(
                      icon: const Icon(Icons.ios_share_outlined,
                          color: Colors.white, size: 22),
                      onPressed: _isExporting
                          ? null
                          : () => _onExportTapped(
                              context, ref, currentTrial),
                      tooltip: 'Export trial (CSV bundle)',
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildTrialStatusBar(context, ref, currentTrial),
          const SizedBox(height: AppDesignTokens.spacing12),
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
          const SizedBox(height: AppDesignTokens.spacing12),
          _buildCropLocationSection(context, currentTrial),
          _buildSessionsBar(
            context,
            ref.watch(sessionsForTrialProvider(widget.trial.id)),
            ref.watch(seedingEventForTrialProvider(widget.trial.id)),
          ),
          _buildReadinessCard(context, ref, currentTrial),
          const SizedBox(height: AppDesignTokens.spacing12),
          PlotsTab(trial: currentTrial, embeddedInScroll: true),
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
                                  'Trial',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white
                                        .withValues(alpha: 0.7),
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentTrial.name,
                                  style: AppDesignTokens.headerTitleStyle(
                                    fontSize: 17,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (currentTrial.crop != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    currentTrial.crop!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (currentTrial.status.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                currentTrial.status,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: Colors.white, size: 22),
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
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => FullProtocolDetailsScreen(
                                    trial: currentTrial),
                              ),
                            ),
                            tooltip: 'View full protocol',
                          ),
                          IconButton(
                            icon: const Icon(Icons.ios_share_outlined,
                                color: Colors.white, size: 22),
                            onPressed: _isExporting
                                ? null
                                : () => _onExportTapped(
                                    context, ref, currentTrial),
                            tooltip: 'Export trial (CSV bundle)',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildTrialStatusBar(context, ref, currentTrial),
                const SizedBox(height: AppDesignTokens.spacing12),
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
                const SizedBox(height: AppDesignTokens.spacing12),
                if (_selectedTabIndex != _sessionsIndex) ...[
                  _buildCropLocationSection(context, currentTrial),
                  _buildSessionsBar(
                    context,
                    ref.watch(sessionsForTrialProvider(widget.trial.id)),
                    ref.watch(
                        seedingEventForTrialProvider(widget.trial.id)),
                  ),
                  _buildReadinessCard(context, ref, currentTrial),
                  const SizedBox(height: AppDesignTokens.spacing12),
                ],
              ],
            ),
          ),
        ),
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

  static const List<String> _stepperStatuses = [
    kTrialStatusDraft,
    kTrialStatusReady,
    kTrialStatusActive,
    kTrialStatusClosed,
  ];

  int _stepperIndexForStatus(String? status) {
    if (status == null) return 0;
    final i = _stepperStatuses.indexOf(status);
    return i >= 0 ? i : 0;
  }

  Widget _buildTrialStatusBar(
      BuildContext context, WidgetRef ref, Trial trial) {
    final currentIndex = _stepperIndexForStatus(trial.status);
    final nextStatuses = allowedNextTrialStatuses(trial.status);
    final nextStatus = nextStatuses.isNotEmpty ? nextStatuses.first : null;
    final buttonLabel = nextStatus == kTrialStatusReady
        ? 'Mark Ready'
        : nextStatus == kTrialStatusActive
            ? 'Mark Active'
            : nextStatus == kTrialStatusClosed
                ? 'Close Trial'
                : null;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing16,
          vertical: AppDesignTokens.spacing12),
      decoration: const BoxDecoration(
        color: AppDesignTokens.sectionHeaderBg,
        border: Border(bottom: BorderSide(color: AppDesignTokens.borderCrisp)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (int i = 0; i < _stepperStatuses.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 20),
                      color: i <= currentIndex
                          ? AppDesignTokens.primary
                          : AppDesignTokens.divider,
                    ),
                  ),
                _buildStepperDot(context, i, currentIndex),
                if (i < _stepperStatuses.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 20),
                      color: i < currentIndex
                          ? AppDesignTokens.primary
                          : AppDesignTokens.divider,
                    ),
                  ),
              ],
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < _stepperStatuses.length; i++)
                Expanded(
                  child: Text(
                    labelForTrialStatus(_stepperStatuses[i]),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          i == currentIndex ? FontWeight.w700 : FontWeight.w500,
                      color: i <= currentIndex
                          ? AppDesignTokens.primaryText
                          : AppDesignTokens.secondaryText,
                    ),
                  ),
                ),
            ],
          ),
          if (buttonLabel != null && nextStatus != null) ...[
            const SizedBox(height: AppDesignTokens.spacing12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    _transitionTrialStatus(context, ref, nextStatus),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignTokens.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDesignTokens.radiusSmall),
                  ),
                ),
                child: Text(buttonLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepperDot(
      BuildContext context, int stepIndex, int currentIndex) {
    const double size = 28;
    final isCompleted = stepIndex < currentIndex;
    final isCurrent = stepIndex == currentIndex;
    final isFuture = stepIndex > currentIndex;
    return SizedBox(
      width: size + 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? AppDesignTokens.primary
                  : isCurrent
                      ? AppDesignTokens.primary
                      : null,
              border: Border.all(
                color: isCurrent
                    ? AppDesignTokens.primary
                    : isFuture
                        ? AppDesignTokens.divider
                        : AppDesignTokens.primary,
                width: isCurrent ? 3 : 1.5,
              ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: AppDesignTokens.primary.withValues(alpha: 0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : isFuture
                    ? Center(
                        child: Text(
                          '${stepIndex + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppDesignTokens.secondaryText,
                          ),
                        ),
                      )
                    : null,
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

  Widget _buildCropLocationSection(BuildContext context, Trial trial) {
    final cropPart = trial.crop?.trim();
    final seasonPart = trial.season?.trim();
    final locationPart = trial.location?.trim();
    final hasCropYear = (cropPart != null && cropPart.isNotEmpty) ||
        (seasonPart != null && seasonPart.isNotEmpty);
    final hasLocation = locationPart != null && locationPart.isNotEmpty;
    if (!hasCropYear && !hasLocation) return const SizedBox.shrink();
    final cropYearText = [
      if (cropPart != null && cropPart.isNotEmpty) cropPart,
      if (seasonPart != null && seasonPart.isNotEmpty) seasonPart,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing16,
          vertical: AppDesignTokens.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasCropYear)
            Text(
              cropYearText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.primaryText,
              ),
            ),
          if (hasCropYear && hasLocation) const SizedBox(height: 4),
          if (locationPart != null && locationPart.isNotEmpty)
            Text(
              locationPart,
              style: const TextStyle(
                fontSize: 12,
                color: AppDesignTokens.secondaryText,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionsBar(
    BuildContext context,
    AsyncValue<List<Session>> sessionsAsync,
    AsyncValue<SeedingEvent?> seedingEventAsync,
  ) {
    final subtitle = sessionsAsync.when(
      loading: () => 'Start or continue a session',
      error: (_, __) => 'Start or continue a session',
      data: (sessions) {
        final base = _sessionsBarSubtitle(sessions);
        final event = seedingEventAsync.valueOrNull;
        if (event == null) return base;
        final days =
            DateTime.now().difference(event.seedingDate.toLocal()).inDays;
        return '$base · $days days since seeding';
      },
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing16,
          vertical: AppDesignTokens.spacing8),
      child: Material(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          key: const Key('trial_detail_sessions_bar'),
          onTap: () => setState(() {
            _previousTabIndex = _selectedTabIndex;
            _selectedTabIndex = _sessionsIndex;
          }),
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDesignTokens.spacing16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
              border: Border.all(color: AppDesignTokens.borderCrisp),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDesignTokens.spacing8),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primaryTint,
                    borderRadius:
                        BorderRadius.circular(AppDesignTokens.radiusXSmall),
                  ),
                  child: const Icon(
                    Icons.assignment_outlined,
                    color: AppDesignTokens.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppDesignTokens.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Sessions',
                        style: TextStyle(
                          color: AppDesignTokens.primaryText,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppDesignTokens.secondaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppDesignTokens.iconSubtle,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _sessionsBarSubtitle(List<Session> sessions) {
    if (sessions.isEmpty) {
      return 'Start a session to begin collecting field data';
    }
    final activeCount = sessions.where((s) => s.endedAt == null).length;
    if (activeCount == 0) {
      return '${sessions.length} sessions recorded';
    }
    if (activeCount == 1) {
      return '1 active session';
    }
    return '$activeCount active sessions';
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
        borderRadius: BorderRadius.circular(14),
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
                tooltip: 'Export all closed sessions',
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
                      value: 'csv', child: Text('Export all to CSV (ZIP)')),
                  const PopupMenuItem(
                      value: 'arm_xml',
                      child: Text('Export all as ARM XML (ZIP)')),
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
    final isOpen = session.endedAt == null;
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
        trailing: _buildSessionTrailing(isOpen, needsAttention),
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
    if (confirm != true) return;
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
