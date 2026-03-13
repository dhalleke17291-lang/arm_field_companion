import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/plot_display.dart';
import '../../core/trial_state.dart';
import 'package:drift/drift.dart' as drift;
import '../sessions/create_session_screen.dart';
import '../sessions/session_detail_screen.dart';
import '../plots/plot_queue_screen.dart';
import '../plots/plot_detail_screen.dart';
import 'plot_layout_model.dart';
import 'assessment_library_picker_dialog.dart';
import 'full_protocol_details_screen.dart';
import '../../core/providers.dart';
import '../../core/widgets/loading_error_widgets.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/widgets/app_standard_widgets.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../photos/photo_viewer_screen.dart';

/// Key for persisting that the trial module hub one-time scroll hint was seen or dismissed.
const String _kTrialHubHintDismissedKey = 'trial_module_hub_hint_dismissed';

enum _LayoutLayer { treatments, applications, ratings }

const double _kGridMinScale = 0.15;
const double _kGridMaxScale = 5.0;
const double _kGridZoomFactor = 1.25;

void _plotGridZoom(TransformationController controller, {required bool zoomIn}) {
  final m = controller.value;
  final scale = m.entry(0, 0).abs();
  final newScale = zoomIn
      ? (scale * _kGridZoomFactor).clamp(_kGridMinScale, _kGridMaxScale)
      : (scale / _kGridZoomFactor).clamp(_kGridMinScale, _kGridMaxScale);
  if ((newScale - scale).abs() < 0.001) return;
  final tx = m.entry(0, 3);
  final ty = m.entry(1, 3);
  controller.value = Matrix4.identity()
    ..scaleByDouble(newScale, newScale, 1.0, 1.0)
    ..translateByDouble(tx, ty, 0.0, 1.0);
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

  final assignmentsList = ref.read(assignmentsForTrialProvider(trial.id)).value ?? [];
  final a = assignmentsList.where((x) => x.plotId == plot.id).firstOrNull;
  int? selectedId = a?.treatmentId ?? plot.treatmentId;
  final displayNum = getDisplayPlotLabel(plot, plots);

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text('Assign Treatment — Plot $displayNum'),
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

class _AddTestPlotsDialog extends StatefulWidget {
  const _AddTestPlotsDialog();

  @override
  State<_AddTestPlotsDialog> createState() => _AddTestPlotsDialogState();
}

class _AddTestPlotsDialogState extends State<_AddTestPlotsDialog> {
  late final TextEditingController _repsController;
  late final TextEditingController _plotsPerRepController;

  @override
  void initState() {
    super.initState();
    _repsController = TextEditingController(text: '6');
    _plotsPerRepController = TextEditingController(text: '8');
  }

  @override
  void dispose() {
    _repsController.dispose();
    _plotsPerRepController.dispose();
    super.dispose();
  }

  int get _reps => (int.tryParse(_repsController.text) ?? 6).clamp(1, 99);
  int get _plotsPerRep => (int.tryParse(_plotsPerRepController.text) ?? 8).clamp(1, 99);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Test Plots'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create plots by reps and plots per rep (e.g. 6 reps × 8 plots = 48).',
              style: TextStyle(fontSize: 13, color: AppDesignTokens.secondaryText),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Reps',
                border: OutlineInputBorder(),
                hintText: '6',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _plotsPerRepController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Plots per rep',
                border: OutlineInputBorder(),
                hintText: '8',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${_reps * _plotsPerRep} plots',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.primaryText,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (reps: _reps, plotsPerRep: _plotsPerRep)),
          child: const Text('Add Plots'),
        ),
      ],
    );
  }
}

class TrialDetailScreen extends ConsumerStatefulWidget {
  final Trial trial;

  const TrialDetailScreen({super.key, required this.trial});

  @override
  ConsumerState<TrialDetailScreen> createState() => _TrialDetailScreenState();
}

class _TrialDetailScreenState extends ConsumerState<TrialDetailScreen> {
  int _selectedTabIndex = 0;
  int _previousTabIndex = 0;
  static const int _sessionsIndex = 6;

  static const Duration _hubHintDelay = Duration(milliseconds: 600);
  static const Duration _hubHintScrollDuration = Duration(milliseconds: 450);
  static const Duration _hubHintPause = Duration(milliseconds: 400);
  static const double _hubHintRevealOffset = 140.0;

  late final ScrollController _hubScrollController;
  bool _programmaticScroll = false;
  bool _hintCancelled = false;
  Timer? _hintSchedule;

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

  @override
  Widget build(BuildContext context) {
    final trialAsync = ref.watch(trialProvider(widget.trial.id));
    final currentTrial = trialAsync.valueOrNull ?? widget.trial;

    final viewportHeight = MediaQuery.sizeOf(context).height;
    final maxHeaderHeight = viewportHeight * 0.45;

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      body: Column(
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
                        colors: [AppDesignTokens.primary, AppDesignTokens.primaryLight],
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
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                              icon: const Icon(Icons.description_outlined, color: Colors.white, size: 22),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => FullProtocolDetailsScreen(trial: currentTrial),
                                ),
                              ),
                              tooltip: 'View full protocol',
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
                      ref.watch(seedingEventForTrialProvider(widget.trial.id)),
                    ),
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
                _PlotsTab(trial: currentTrial),
                _SeedingTab(trial: currentTrial),
                _ApplicationsTab(trial: currentTrial),
                _AssessmentsTab(trial: currentTrial),
                _TreatmentsTab(trial: currentTrial),
                _PhotosTab(trial: currentTrial),
                SessionsView(
                  trial: currentTrial,
                  onBack: () =>
                      setState(() => _selectedTabIndex = _previousTabIndex),
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildTrialStatusBar(BuildContext context, WidgetRef ref, Trial trial) {
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
      padding: const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing16, vertical: AppDesignTokens.spacing12),
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
                      color: i <= currentIndex ? AppDesignTokens.primary : AppDesignTokens.divider,
                    ),
                  ),
                _buildStepperDot(context, i, currentIndex),
                if (i < _stepperStatuses.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 20),
                      color: i < currentIndex ? AppDesignTokens.primary : AppDesignTokens.divider,
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
                      fontWeight: i == currentIndex ? FontWeight.w700 : FontWeight.w500,
                      color: i <= currentIndex ? AppDesignTokens.primaryText : AppDesignTokens.secondaryText,
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
                onPressed: () => _transitionTrialStatus(context, ref, nextStatus),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignTokens.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
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

  Widget _buildStepperDot(BuildContext context, int stepIndex, int currentIndex) {
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
    final hasCropYear = (cropPart != null && cropPart.isNotEmpty) || (seasonPart != null && seasonPart.isNotEmpty);
    final hasLocation = locationPart != null && locationPart.isNotEmpty;
    if (!hasCropYear && !hasLocation) return const SizedBox.shrink();
    final cropYearText = [
      if (cropPart != null && cropPart.isNotEmpty) cropPart,
      if (seasonPart != null && seasonPart.isNotEmpty) seasonPart,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing16, vertical: AppDesignTokens.spacing4),
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
      padding: const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing16, vertical: AppDesignTokens.spacing8),
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
            padding: const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing16, vertical: 10),
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
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusXSmall),
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
    ];

    final listView = ListView.separated(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: AppDesignTokens.spacing16, right: 48),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: AppDesignTokens.spacing12),
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
      padding: const EdgeInsets.only(top: AppDesignTokens.spacing8, bottom: AppDesignTokens.spacing8),
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
          padding: const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing12, vertical: AppDesignTokens.spacing8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? AppDesignTokens.primary : AppDesignTokens.iconSubtle,
                size: selected ? 26 : 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppDesignTokens.primary : AppDesignTokens.secondaryText,
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
// PLOTS TAB
// ─────────────────────────────────────────────

class _PlotsTab extends ConsumerStatefulWidget {
  final Trial trial;

  const _PlotsTab({required this.trial});

  @override
  ConsumerState<_PlotsTab> createState() => _PlotsTabState();
}

class _PlotsTabState extends ConsumerState<_PlotsTab> {
  @override
  Widget build(BuildContext context) {
    final trial = widget.trial;
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final treatmentsAsync = ref.watch(treatmentsForTrialProvider(trial.id));
    final assignmentsAsync = ref.watch(assignmentsForTrialProvider(trial.id));
    final sessionsAsync = ref.watch(sessionsForTrialProvider(trial.id));
    final sessionCount = sessionsAsync.value?.length ?? 0;
    final applicationsList = ref.watch(trialApplicationsForTrialProvider(trial.id)).value ?? [];
    final applicationCount = applicationsList.length;
    final lastApplicationDate = applicationsList.isEmpty
        ? null
        : applicationsList.last.applicationDate;
    final treatmentComponentCount = ref
        .watch(treatmentComponentsCountForTrialProvider(trial.id))
        .valueOrNull ?? 0;
    final ratedPlotsCount =
        ref.watch(ratedPlotsCountForTrialProvider(trial.id)).valueOrNull ?? 0;
    final seedingEvent = ref.watch(seedingEventForTrialProvider(trial.id)).valueOrNull;
    final seedingDate = seedingEvent?.seedingDate;
    return plotsAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, st) => AppErrorView(
        error: e,
        stackTrace: st,
        onRetry: () => ref.invalidate(plotsForTrialProvider(trial.id)),
      ),
      data: (plots) {
        if (plots.isEmpty) {
          return _buildPlotsSummaryWithBar(
            context,
            ref,
            trial,
            0,
            0,
            0,
            0,
            0,
            0,
            treatmentsAsync.value?.length ?? 0,
            treatmentComponentCount,
            ratedPlotsCount,
            sessionCount,
            applicationCount,
            lastApplicationDate,
            seedingDate,
          );
        }
        final treatments = treatmentsAsync.value ?? [];
        final assignmentsList = assignmentsAsync.value ?? [];
        final assignmentByPlotId = {for (var a in assignmentsList) a.plotId: a};
        final assignedCount = plots.where((p) =>
            (assignmentByPlotId[p.id]?.treatmentId ?? p.treatmentId) != null).length;
        final unassignedCount = plots.length - assignedCount;
        final blocks = buildRepBasedLayout(plots);
        int rowCount = 0;
        int columnCount = 0;
        final repNumbers = <int>{};
        for (final block in blocks) {
          for (final row in block.repRows) {
            rowCount++;
            if (row.plots.length > columnCount) columnCount = row.plots.length;
            for (final p in row.plots) {
              if (p.rep != null) repNumbers.add(p.rep!);
            }
          }
        }
        return _buildPlotsSummaryWithBar(
          context,
          ref,
          trial,
          plots.length,
          rowCount,
          columnCount,
          repNumbers.length,
          assignedCount,
          unassignedCount,
          treatments.length,
          treatmentComponentCount,
          ratedPlotsCount,
          sessionCount,
          applicationCount,
          lastApplicationDate,
          seedingDate,
        );
      },
    );
  }

  Widget _buildPlotsSummaryWithBar(
    BuildContext context,
    WidgetRef ref,
    Trial trial,
    int totalPlots,
    int rowCount,
    int columnCount,
    int replicateCount,
    int assignedCount,
    int unassignedCount,
    int treatmentCount,
    int treatmentComponentCount,
    int ratedPlotsCount,
    int sessionCount,
    int applicationCount,
    DateTime? lastApplicationDate,
    DateTime? seedingDate,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDesignTokens.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Trial Summary',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppDesignTokens.spacing12),
                _summaryRow('Total plots', '$totalPlots'),
                _summaryRow('Ranges', '$rowCount'),
                _summaryRow('Columns', '$columnCount'),
                _summaryRow('Replicates', '$replicateCount'),
                _summaryRow('Assigned plots', '$assignedCount'),
                _summaryRow('Unassigned plots', '$unassignedCount'),
                _summaryRow('Treatments', '$treatmentCount'),
                _summaryRow('Treatment components', '$treatmentComponentCount'),
                _summaryRow('Rated plots', '$ratedPlotsCount of $totalPlots'),
                _summaryRow('Sessions', '$sessionCount'),
                _applicationsSummaryRow(context, trial, applicationCount),
                _lastApplicationSummaryRow(context, lastApplicationDate),
                _seedingDateSummaryRow(seedingDate),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Material(
            color: AppDesignTokens.primary,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PlotDetailsScreen(trial: trial),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDesignTokens.spacing16,
                  vertical: AppDesignTokens.spacing12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Plot Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: AppDesignTokens.spacing8),
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

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

  Widget _applicationsSummaryRow(BuildContext context, Trial trial, int applicationCount) {
    final isActiveOrClosed = trial.status == 'active' || trial.status == 'closed';
    final showWarning = isActiveOrClosed && applicationCount == 0;
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
          if (showWarning)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: AppDesignTokens.warningFg),
                const SizedBox(width: 4),
                Text(
                  '$applicationCount',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.warningFg,
                  ),
                ),
              ],
            )
          else
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

  Widget _lastApplicationSummaryRow(BuildContext context, DateTime? lastApplicationDate) {
    final value = lastApplicationDate != null
        ? DateFormat('MMM d, yyyy').format(lastApplicationDate)
        : 'None';
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
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: lastApplicationDate != null
                  ? AppDesignTokens.primaryText
                  : AppDesignTokens.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

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

/// Plot Details sub-screen: List/Layout toggle, layer switcher, and full plot list or grid.
class PlotDetailsScreen extends ConsumerStatefulWidget {
  final Trial trial;

  const PlotDetailsScreen({super.key, required this.trial});

  @override
  ConsumerState<PlotDetailsScreen> createState() => _PlotDetailsScreenState();
}

class _PlotDetailsScreenState extends ConsumerState<PlotDetailsScreen> {
  bool _showLayoutView = false;
  _LayoutLayer _layoutLayer = _LayoutLayer.treatments;
  ApplicationEvent? _selectedAppEvent;
  List<ApplicationPlotRecord> _appPlotRecords = [];
  bool _loadingAppRecords = false;
  final TransformationController _gridTransformController = TransformationController();
  final GlobalKey _plotViewportKey = GlobalKey();
  final GlobalKey _gridContentKey = GlobalKey();
  bool _gridCenterScheduled = false;

  @override
  void dispose() {
    _gridTransformController.dispose();
    super.dispose();
  }

  void _centerGridOnFirstFrame(BuildContext context, List<Plot> plots) {
    if (!mounted) return;
    final viewportBox = _plotViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize) return;
    final viewportWidth = viewportBox.size.width;
    final viewportHeight = viewportBox.size.height;
    final gridBox = _gridContentKey.currentContext?.findRenderObject() as RenderBox?;
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
    final dx = (viewportWidth - gridWidth) / 2;
    final dy = (viewportHeight - gridHeight) / 2;
    final dxClamped = dx > 0 ? dx : 0.0;
    final dyClamped = dy > 0 ? dy : 0.0;
    _gridTransformController.value = Matrix4.identity()
      ..translateByDouble(dxClamped, dyClamped, 0.0, 1.0);
  }

  void _gridZoomIn() => _plotGridZoom(_gridTransformController, zoomIn: true);
  void _gridZoomOut() => _plotGridZoom(_gridTransformController, zoomIn: false);

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plot Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: plotsAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, st) => AppErrorView(
          error: e,
          stackTrace: st,
          onRetry: () => ref.invalidate(plotsForTrialProvider(trial.id)),
        ),
        data: (plots) => plots.isEmpty
            ? _PlotDetailsEmptyContent(trial: trial)
            : _buildPlotDetailsContent(context, ref, plots),
      ),
    );
  }

  Widget _buildPlotDetailsContent(
      BuildContext context, WidgetRef ref, List<Plot> plots) {
    final treatments = ref.watch(treatmentsForTrialProvider(widget.trial.id)).value ?? [];
    final sessions = ref.watch(sessionsForTrialProvider(widget.trial.id)).value ?? [];
    final assignmentsLocked = isAssignmentsLocked(widget.trial.status, sessions.isNotEmpty);
    const double maxTopSectionHeight = 320;
    final topSection = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPlotsHeaderForDetails(context, ref, plots, assignmentsLocked),
        _buildListLayoutToggleForDetails(context, ref, plots),
        if (_showLayoutView) ...[
          _buildLayerSwitcherForDetails(context),
          if (_layoutLayer == _LayoutLayer.applications)
            _buildAppEventSelectorForDetails(context, ref),
        ],
      ],
    );
    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: maxTopSectionHeight),
          child: SingleChildScrollView(
            child: topSection,
          ),
        ),
        if (_showLayoutView)
          Expanded(
            child: _layoutLayer == _LayoutLayer.ratings
                ? const Center(child: Text('Ratings overlay coming soon', style: TextStyle(color: AppDesignTokens.secondaryText)))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (!_gridCenterScheduled) {
                        _gridCenterScheduled = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _centerGridOnFirstFrame(context, plots);
                        });
                      }
                      final size = MediaQuery.sizeOf(context);
                      final viewportWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
                          ? constraints.maxWidth
                          : size.width;
                      final viewportHeight = constraints.maxHeight.isFinite && constraints.maxHeight > 0
                          ? constraints.maxHeight
                          : size.height;
                      final blocks = buildRepBasedLayout(plots);
                      int columnCount = 0;
                      for (final block in blocks) {
                        for (final row in block.repRows) {
                          if (row.plots.length > columnCount) columnCount = row.plots.length;
                        }
                      }
                      const double repLabelW = 52.0;
                      const double tileSpace = 6.0;
                      const double cellW = 56.0;
                      const double gridHorizontalPadding = 24.0;
                      const double gridWidthBuffer = 8.0;
                      final double rowContentWidth = columnCount > 0
                          ? repLabelW + tileSpace + columnCount * cellW + (columnCount - 1) * tileSpace
                          : viewportWidth;
                      final double totalGridWidth = rowContentWidth + gridHorizontalPadding + gridWidthBuffer;
                      final double gridContentWidth = totalGridWidth > viewportWidth ? totalGridWidth : viewportWidth;
                      final assignmentsList = ref.watch(assignmentsForTrialProvider(widget.trial.id)).value ?? [];
                      final plotIdToTreatmentIdMap = {for (var a in assignmentsList) a.plotId: a.treatmentId};
                      final applicationsList = ref.watch(trialApplicationsForTrialProvider(widget.trial.id)).value ?? [];
                      final treatmentIdsWithApp = applicationsList.map((e) => e.treatmentId).whereType<int>().toSet();
                      final plotPksWithTrialApplication = <int>{};
                      for (final p in plots) {
                        final tid = plotIdToTreatmentIdMap[p.id] ?? p.treatmentId;
                        if (tid != null && treatmentIdsWithApp.contains(tid)) {
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
                                transformationController: _gridTransformController,
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
                                    plots: plots,
                                    treatments: treatments,
                                    trial: widget.trial,
                                    layer: _layoutLayer,
                                    appPlotRecords: _appPlotRecords,
                                    plotPksWithTrialApplication: plotPksWithTrialApplication,
                                    plotIdToTreatmentId: plotIdToTreatmentIdMap,
                                    onLongPressPlot: assignmentsLocked
                                        ? null
                                        : (plot) => _showAssignTreatmentDialogForDetails(context, ref, plot, plots),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: AppDesignTokens.spacing12,
                              bottom: AppDesignTokens.spacing12,
                              child: Material(
                                elevation: 2,
                                borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
                                color: AppDesignTokens.cardSurface,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.zoom_out),
                                      onPressed: _gridZoomOut,
                                      tooltip: 'Zoom out',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.zoom_in),
                                      onPressed: _gridZoomIn,
                                      tooltip: 'Zoom in',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          )
        else
          Expanded(child: _buildPlotsListBodyForDetails(context, ref, plots, assignmentsLocked)),
      ],
    );
  }

  Widget _buildLayerSwitcherForDetails(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SegmentedButton<_LayoutLayer>(
        style: const ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        segments: const [
          ButtonSegment(value: _LayoutLayer.treatments, label: Text('Treats'), icon: Icon(Icons.science, size: 14)),
          ButtonSegment(value: _LayoutLayer.applications, label: Text('Apps'), icon: Icon(Icons.water_drop, size: 14)),
          ButtonSegment(value: _LayoutLayer.ratings, label: Text('Ratings'), icon: Icon(Icons.bar_chart, size: 14)),
        ],
        selected: {_layoutLayer},
        onSelectionChanged: (val) => setState(() => _layoutLayer = val.first),
      ),
    );
  }

  Widget _buildAppEventSelectorForDetails(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(applicationsForTrialProvider(widget.trial.id));
    return eventsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (events) {
        if (events.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('No application events recorded yet', style: TextStyle(color: AppDesignTokens.secondaryText, fontSize: 13)),
          );
        }
        final completed = events.where((e) => e.status == 'completed').toList();
        if (completed.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('No completed application events yet', style: TextStyle(color: AppDesignTokens.secondaryText, fontSize: 13)),
          );
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
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  initialValue: _selectedAppEvent == null
                      ? null
                      : completed.where((e) => e.id == _selectedAppEvent!.id).firstOrNull ?? completed.first,
                  items: completed.map((e) => DropdownMenuItem<ApplicationEvent>(
                    value: e,
                    child: Text('A${e.applicationNumber} — ${e.timingLabel ?? e.method}'),
                  )).toList(),
                  onChanged: (e) { if (e != null) _loadAppRecords(e); },
                ),
              ),
              if (_loadingAppRecords)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListLayoutToggleForDetails(BuildContext context, WidgetRef ref, List<Plot> plots) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing16, vertical: AppDesignTokens.spacing8),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('List'), icon: Icon(Icons.list)),
                ButtonSegment(value: true, label: Text('Layout'), icon: Icon(Icons.grid_on)),
              ],
              selected: {_showLayoutView},
              onSelectionChanged: (Set<bool> selected) {
                setState(() => _showLayoutView = selected.first);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: 'Open in full screen',
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
        ],
      ),
    );
  }

  Widget _buildPlotsHeaderForDetails(
      BuildContext context, WidgetRef ref, List<Plot> plots, bool assignmentsLocked) {
    final sessions = ref.watch(sessionsForTrialProvider(widget.trial.id)).value ?? [];
    final message = getAssignmentsLockMessage(widget.trial.status, sessions.isNotEmpty);
    final assignmentsList = ref.watch(assignmentsForTrialProvider(widget.trial.id)).value ?? [];
    final assignmentByPlotId = {for (var a in assignmentsList) a.plotId: a};
    final assignedCount = plots.where((p) =>
        (assignmentByPlotId[p.id]?.treatmentId ?? p.treatmentId) != null).length;
    final unassignedCount = plots.length - assignedCount;
    final summaryLine = plots.isEmpty
        ? 'No plots'
        : unassignedCount == 0
            ? 'All $assignedCount assigned'
            : '$assignedCount assigned · $unassignedCount unassigned';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing16, vertical: AppDesignTokens.spacing8),
      padding: const EdgeInsets.all(AppDesignTokens.spacing16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppDesignTokens.spacing8),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.sectionHeaderBg,
                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusXSmall),
                    ),
                    child: const Icon(Icons.grid_on, size: 20, color: AppDesignTokens.primary),
                  ),
                  const SizedBox(width: AppDesignTokens.spacing12),
                  Text(
                    '${plots.length} plots',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppDesignTokens.primaryText,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: assignmentsLocked ? AppDesignTokens.secondaryText : AppDesignTokens.primary,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          assignmentsLocked ? Icons.lock_outlined : Icons.lock_open_outlined,
                          size: 14,
                          color: assignmentsLocked ? AppDesignTokens.secondaryText : AppDesignTokens.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          assignmentsLocked ? 'Locked' : 'Editable',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: assignmentsLocked ? AppDesignTokens.secondaryText : AppDesignTokens.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: assignmentsLocked ? message : 'Assign treatments to multiple plots',
                    child: OutlinedButton.icon(
                      onPressed: assignmentsLocked ? null : () => _showBulkAssignDialogForDetails(context, ref, plots),
                      icon: Icon(
                        Icons.grid_view,
                        size: 18,
                        color: assignmentsLocked ? AppDesignTokens.iconSubtle : AppDesignTokens.primary,
                      ),
                      label: const Text('Bulk Assign'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: assignmentsLocked ? AppDesignTokens.secondaryText : AppDesignTokens.primary,
                        side: BorderSide(
                          color: assignmentsLocked ? AppDesignTokens.iconSubtle : AppDesignTokens.primary,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            summaryLine,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          if (assignmentsLocked && message.isNotEmpty) ...[
            const SizedBox(height: AppDesignTokens.spacing12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppDesignTokens.secondaryText,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlotsListBodyForDetails(
      BuildContext context, WidgetRef ref, List<Plot> plots, bool assignmentsLocked) {
    final sessions = ref.watch(sessionsForTrialProvider(widget.trial.id)).value ?? [];
    final assignmentsLockMessage = getAssignmentsLockMessage(widget.trial.status, sessions.isNotEmpty);
    final treatments = ref.watch(treatmentsForTrialProvider(widget.trial.id)).value ?? [];
    final treatmentMap = {for (final t in treatments) t.id: t};
    final assignmentsList = ref.watch(assignmentsForTrialProvider(widget.trial.id)).value ?? [];
    final assignmentByPlotId = {for (var a in assignmentsList) a.plotId: a};
    return ListView.builder(
      itemCount: plots.length,
      itemBuilder: (context, index) {
        final plot = plots[index];
        final assignment = assignmentByPlotId[plot.id];
        final effectiveTreatmentId = assignment?.treatmentId ?? plot.treatmentId;
        final effectiveSource = assignment?.assignmentSource ?? plot.assignmentSource;
        final displayNum = getDisplayPlotLabel(plot, plots);
        final treatmentLabel = getTreatmentDisplayLabel(plot, treatmentMap, treatmentIdOverride: effectiveTreatmentId);
        final sourceLabel = getAssignmentSourceLabel(
            treatmentId: effectiveTreatmentId, assignmentSource: effectiveSource);
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
              vertical: AppDesignTokens.spacing8,
            ),
            leading: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDesignTokens.spacing8, vertical: AppDesignTokens.spacing4),
              decoration: BoxDecoration(
                color: AppDesignTokens.primary,
                borderRadius: BorderRadius.circular(AppDesignTokens.radiusXSmall),
              ),
              child: Text(
                displayNum,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white),
              ),
            ),
            title: Text('Plot $displayNum',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppDesignTokens.primaryText)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      treatmentLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: effectiveTreatmentId != null
                            ? AppDesignTokens.primary
                            : AppDesignTokens.secondaryText,
                        fontWeight: effectiveTreatmentId != null ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (sourceLabel != 'Unknown' && sourceLabel != 'Unassigned')
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
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                size: 22, color: AppDesignTokens.iconSubtle),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        PlotDetailScreen(trial: widget.trial, plot: plot))),
            onLongPress: () {
              if (assignmentsLocked) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(assignmentsLockMessage)),
                );
                return;
              }
              _showAssignTreatmentDialogForDetails(context, ref, plot, plots);
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

  Future<void> _showBulkAssignDialogForDetails(
      BuildContext context, WidgetRef ref, List<Plot> plots) async {
    final treatments =
        ref.read(treatmentsForTrialProvider(widget.trial.id)).value ?? [];
    if (treatments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('No treatments defined yet. Add treatments first.')),
      );
      return;
    }
    final assignmentsList = ref.read(assignmentsForTrialProvider(widget.trial.id)).value ?? [];
    final assignmentByPlotId = {for (var a in assignmentsList) a.plotId: a};
    final Map<int, int?> assignments = {
      for (final p in plots) p.id: assignmentByPlotId[p.id]?.treatmentId ?? p.treatmentId,
    };
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Bulk Assign Treatments'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: plots.length,
              itemBuilder: (context, i) {
                final plot = plots[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(getDisplayPlotLabel(plot, plots),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          isDense: true,
                          initialValue: assignments[plot.id],
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('—')),
                            ...treatments.map((t) => DropdownMenuItem(
                                  value: t.id,
                                  child: Text('${t.code} ${t.name}',
                                      overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (v) =>
                              setDialogState(() => assignments[plot.id] = v),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final useCase = ref.read(updatePlotAssignmentUseCaseProvider);
                final plotPkToTreatmentId = {
                  for (final plot in plots) plot.id: assignments[plot.id]
                };
                final result = await useCase.updateBulk(
                  trial: widget.trial,
                  plotPkToTreatmentId: plotPkToTreatmentId,
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
              child: const Text('Save All'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state for PlotDetailsScreen when trial has no plots.
class _PlotDetailsEmptyContent extends ConsumerWidget {
  final Trial trial;

  const _PlotDetailsEmptyContent({required this.trial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = isProtocolLocked(trial.status);
    return AppEmptyState(
      icon: Icons.grid_on,
      title: 'No Plots Yet',
      subtitle: locked
          ? getProtocolLockMessage(trial.status)
          : 'Import plots via CSV or add test plots from the Trial screen.',
    );
  }
}

/// Bird's-eye grid: plot position (layout number) and treatment assignment are separate.
/// Order is always by rep and plot position; never by treatment.
class _PlotLayoutGrid extends StatelessWidget {
  final List<Plot> plots;
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
    required this.treatments,
    required this.trial,
    required this.layer,
    required this.appPlotRecords,
    this.plotPksWithTrialApplication,
    this.plotIdToTreatmentId,
    this.onLongPressPlot,
  });

  Widget _legendChip(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Color _tileColorFor(Plot plot) {
    if (layer == _LayoutLayer.applications) {
      // v1 model: green = treatment has application, grey = unassigned, else treatment color.
      if (plotPksWithTrialApplication != null) {
        final effectiveTid = plotIdToTreatmentId?[plot.id] ?? plot.treatmentId;
        if (effectiveTid == null) return AppDesignTokens.unassignedColor;
        if (plotPksWithTrialApplication!.contains(plot.id)) return AppDesignTokens.appliedColor;
        final treatmentIndex = treatments.indexWhere((t) => t.id == effectiveTid);
        return treatmentIndex >= 0
            ? AppDesignTokens.treatmentPalette[
                treatmentIndex % AppDesignTokens.treatmentPalette.length]
            : AppDesignTokens.unassignedColor;
      }
      final record = appPlotRecords.where((r) => r.plotPk == plot.id).firstOrNull;
      if (record == null) return AppDesignTokens.noRecordColor;
      if (record.status == 'applied') return AppDesignTokens.appliedColor;
      if (record.status == 'skipped') return AppDesignTokens.skippedColor;
      if (record.status == 'missed') return AppDesignTokens.missedColor;
      return AppDesignTokens.noRecordColor;
    }
    final effectiveTid = plotIdToTreatmentId?[plot.id] ?? plot.treatmentId;
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
          padding: const EdgeInsets.all(12),
          child: layer == _LayoutLayer.applications
              ? Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: plotPksWithTrialApplication != null
                      ? [
                          _legendChip(AppDesignTokens.appliedColor, 'Applied'),
                          _legendChip(AppDesignTokens.unassignedColor, 'Unassigned'),
                        ]
                      : [
                          _legendChip(AppDesignTokens.appliedColor, 'Applied'),
                          _legendChip(AppDesignTokens.skippedColor, 'Skipped'),
                          _legendChip(AppDesignTokens.missedColor, 'Missed'),
                          _legendChip(AppDesignTokens.noRecordColor, 'No record'),
                        ],
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    ...treatments.asMap().entries.map((entry) {
                      final color = AppDesignTokens.treatmentPalette[
                          entry.key % AppDesignTokens.treatmentPalette.length];
                      return _legendChip(color, '${entry.value.code} ${entry.value.name}');
                    }),
                    _legendChip(AppDesignTokens.unassignedColor, 'Unassigned'),
                  ],
                ),
        ),
      ],
    );
  }

  static const double _repLabelWidth = 52.0;
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

  Widget _buildRepBasedGrid(BuildContext context, Map<int, Treatment> treatmentMap) {
    final blocks = buildRepBasedLayout(plots);
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.maxHeight.isFinite && constraints.maxHeight > 0;
        final contentHeight = hasBoundedHeight ? constraints.maxHeight - 16 : null;
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
                final repRows = block.repRows.map((repRow) {
                  const cellSize = _minCellSize;
                  const rowHeight = _minCellSize + 2;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: _tileSpacing),
                    child: SizedBox(
                      height: rowHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: _repLabelWidth,
                            child: Text(
                              'Rep ${repRow.repNumber}',
                              style: const TextStyle(
                                color: AppDesignTokens.secondaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: _tileSpacing),
                          Expanded(
                            child: ClipRect(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
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
                                          tileColor: _tileColorFor(repRow.plots[i]),
                                          treatmentIdOverride: plotIdToTreatmentId?[repRow.plots[i].id] ?? repRow.plots[i].treatmentId,
                                          displayLabel: getDisplayPlotLabel(repRow.plots[i], plots),
                                          onLongPress: onLongPressPlot != null
                                              ? () => onLongPressPlot!(repRow.plots[i])
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
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

class _PlotGridTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final effectiveTid = treatmentIdOverride ?? plot.treatmentId;
    final treatment = effectiveTid != null ? treatmentMap[effectiveTid] : null;
    final label = displayLabel ?? plot.plotId;
    return Container(
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onLongPress: onLongPress,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlotDetailScreen(trial: trial, plot: plot),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
                Text(
                  treatment != null ? treatment.code : '',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
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
  ConsumerState<_PlotsFullScreenPage> createState() => _PlotsFullScreenPageState();
}

class _PlotsFullScreenPageState extends ConsumerState<_PlotsFullScreenPage> {
  late _LayoutLayer _layoutLayer;
  ApplicationEvent? _selectedAppEvent;
  List<ApplicationPlotRecord> _appPlotRecords = [];
  bool _loadingAppRecords = false;
  final TransformationController _gridTransformController = TransformationController();
  final GlobalKey _plotViewportKey = GlobalKey();
  final GlobalKey _gridContentKey = GlobalKey();
  bool _gridCenterScheduled = false;

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
    final viewportBox = _plotViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize) return;
    final viewportWidth = viewportBox.size.width;
    final viewportHeight = viewportBox.size.height;
    final gridBox = _gridContentKey.currentContext?.findRenderObject() as RenderBox?;
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

  void _gridZoomIn() => _plotGridZoom(_gridTransformController, zoomIn: true);
  void _gridZoomOut() => _plotGridZoom(_gridTransformController, zoomIn: false);

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
    final plotsAsync = ref.watch(plotsForTrialProvider(widget.trial.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isLayoutView ? 'Plots — Layout' : 'Plots — List'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: plotsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (plots) {
          if (plots.isEmpty) {
            return const Center(child: Text('No plots'));
          }
          final sessions = ref.watch(sessionsForTrialProvider(widget.trial.id)).value ?? [];
          final assignmentsLocked = isAssignmentsLocked(widget.trial.status, sessions.isNotEmpty);
          if (!widget.isLayoutView) {
            return _buildListBody(context, ref, plots, assignmentsLocked);
          }
          final treatments = ref.watch(treatmentsForTrialProvider(widget.trial.id)).value ?? [];
          final assignments = ref.watch(assignmentsForTrialProvider(widget.trial.id)).value ?? [];
          final Map<int, int?> plotIdToTreatmentId = {
            for (final a in assignments) a.plotId: a.treatmentId
          };
          const double maxTopHeight = 200;
          final topSection = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SegmentedButton<_LayoutLayer>(
                  style: const ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(value: _LayoutLayer.treatments, label: Text('Treats'), icon: Icon(Icons.science, size: 14)),
                    ButtonSegment(value: _LayoutLayer.applications, label: Text('Apps'), icon: Icon(Icons.water_drop, size: 14)),
                    ButtonSegment(value: _LayoutLayer.ratings, label: Text('Ratings'), icon: Icon(Icons.bar_chart, size: 14)),
                  ],
                  selected: {_layoutLayer},
                  onSelectionChanged: (val) => setState(() => _layoutLayer = val.first),
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
                    ? const Center(child: Text('Ratings overlay coming soon', style: TextStyle(color: AppDesignTokens.secondaryText)))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (!_gridCenterScheduled) {
                            _gridCenterScheduled = true;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _centerGridOnFirstFrame(context, plots);
                            });
                          }
                          final size = MediaQuery.sizeOf(context);
                          final viewportWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
                              ? constraints.maxWidth
                              : size.width;
                          final viewportHeight = constraints.maxHeight.isFinite && constraints.maxHeight > 0
                              ? constraints.maxHeight
                              : size.height;
                          final blocks = buildRepBasedLayout(plots);
                          int columnCount = 0;
                          for (final block in blocks) {
                            for (final row in block.repRows) {
                              if (row.plots.length > columnCount) columnCount = row.plots.length;
                            }
                          }
                          const double repLabelW = 52.0;
                          const double tileSpace = 6.0;
                          const double cellW = 56.0;
                          const double gridHorizontalPadding = 24.0; // 12 + 12 from Padding in _buildRepBasedGrid
                          const double gridWidthBuffer = 8.0; // avoid last column clipping from rounding
                          final double rowContentWidth = columnCount > 0
                              ? repLabelW + tileSpace + columnCount * cellW + (columnCount - 1) * tileSpace
                              : viewportWidth;
                          final double totalGridWidth = rowContentWidth + gridHorizontalPadding + gridWidthBuffer;
                          final double gridContentWidth = totalGridWidth > viewportWidth ? totalGridWidth : viewportWidth;
                          final applicationsList = ref.watch(trialApplicationsForTrialProvider(widget.trial.id)).value ?? [];
                          final treatmentIdsWithApp = applicationsList.map((e) => e.treatmentId).whereType<int>().toSet();
                          final plotPksWithTrialApplication = <int>{};
                          for (final p in plots) {
                            final tid = plotIdToTreatmentId[p.id] ?? p.treatmentId;
                            if (tid != null && treatmentIdsWithApp.contains(tid)) {
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
                                    transformationController: _gridTransformController,
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
                                        plots: plots,
                                        treatments: treatments,
                                        trial: widget.trial,
                                        layer: _layoutLayer,
                                        appPlotRecords: _appPlotRecords,
                                        plotPksWithTrialApplication: plotPksWithTrialApplication,
                                        plotIdToTreatmentId: plotIdToTreatmentId,
                                        onLongPressPlot: assignmentsLocked
                                            ? null
                                            : (plot) => _showAssignDialog(context, ref, plot, plots),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: AppDesignTokens.spacing12,
                                  bottom: AppDesignTokens.spacing12,
                                  child: Material(
                                    elevation: 2,
                                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
                                    color: AppDesignTokens.cardSurface,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.zoom_out),
                                          onPressed: _gridZoomOut,
                                          tooltip: 'Zoom out',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.zoom_in),
                                          onPressed: _gridZoomIn,
                                          tooltip: 'Zoom in',
                                        ),
                                      ],
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
      ),
    );
  }

  Widget _buildAppEventSelector(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(applicationsForTrialProvider(widget.trial.id));
    return eventsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (events) {
        final completed = events.where((e) => e.status == 'completed').toList();
        if (completed.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('No completed application events yet', style: TextStyle(color: AppDesignTokens.secondaryText, fontSize: 13)),
          );
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
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  initialValue: _selectedAppEvent == null
                      ? null
                      : completed.where((e) => e.id == _selectedAppEvent!.id).firstOrNull ?? completed.first,
                  items: completed.map((e) => DropdownMenuItem<ApplicationEvent>(
                    value: e,
                    child: Text('A${e.applicationNumber} — ${e.timingLabel ?? e.method}'),
                  )).toList(),
                  onChanged: (e) { if (e != null) _loadAppRecords(e); },
                ),
              ),
              if (_loadingAppRecords)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListBody(BuildContext context, WidgetRef ref, List<Plot> plots, bool assignmentsLocked) {
    final sessions = ref.watch(sessionsForTrialProvider(widget.trial.id)).value ?? [];
    final assignmentsLockMessage = getAssignmentsLockMessage(widget.trial.status, sessions.isNotEmpty);
    final treatments = ref.watch(treatmentsForTrialProvider(widget.trial.id)).value ?? [];
    final treatmentMap = {for (final t in treatments) t.id: t};
    final assignmentsList = ref.watch(assignmentsForTrialProvider(widget.trial.id)).value ?? [];
    final assignmentByPlotId = {for (var a in assignmentsList) a.plotId: a};
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: plots.length,
      itemBuilder: (context, index) {
        final plot = plots[index];
        final assignment = assignmentByPlotId[plot.id];
        final effectiveTreatmentId = assignment?.treatmentId ?? plot.treatmentId;
        final effectiveSource = assignment?.assignmentSource ?? plot.assignmentSource;
        final displayNum = getDisplayPlotLabel(plot, plots);
        final treatmentLabel = getTreatmentDisplayLabel(plot, treatmentMap, treatmentIdOverride: effectiveTreatmentId);
        final sourceLabel = getAssignmentSourceLabel(
            treatmentId: effectiveTreatmentId, assignmentSource: effectiveSource);
        return AppCard(
          margin: const EdgeInsets.only(left: 16, right: 16, top: 6, bottom: 6),
          child: ListTile(
            dense: true,
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                displayNum,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
            ),
            title: Text('Plot $displayNum', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Row(
              children: [
                Expanded(
                  child: Text(
                    treatmentLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: effectiveTreatmentId != null
                          ? Theme.of(context).colorScheme.primary
                          : AppDesignTokens.secondaryText,
                      fontWeight: effectiveTreatmentId != null ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                if (sourceLabel != 'Unknown' && sourceLabel != 'Unassigned')
                  Text(sourceLabel, style: const TextStyle(fontSize: 10, color: AppDesignTokens.secondaryText, fontStyle: FontStyle.italic)),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PlotDetailScreen(trial: widget.trial, plot: plot)),
            ),
            onLongPress: () {
              if (assignmentsLocked) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(assignmentsLockMessage)));
                return;
              }
              _showAssignDialog(context, ref, plot, plots);
            },
          ),
        );
      },
    );
  }

  Future<void> _showAssignDialog(BuildContext context, WidgetRef ref, Plot plot, List<Plot> plots) async {
    return showAssignTreatmentDialogForTrial(
      trial: widget.trial,
      context: context,
      ref: ref,
      plot: plot,
      plots: plots,
    );
  }
}

class _AssessmentsTab extends ConsumerWidget {
  final Trial trial;

  const _AssessmentsTab({required this.trial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(trialAssessmentsWithDefinitionsForTrialProvider(trial.id));
    final legacyAsync = ref.watch(assessmentsForTrialProvider(trial.id));

    if (libraryAsync.isLoading && legacyAsync.isLoading) {
      return const AppLoadingView();
    }
    return libraryAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, st) => AppErrorView(error: e, stackTrace: st, onRetry: () => ref.invalidate(trialAssessmentsWithDefinitionsForTrialProvider(trial.id))),
      data: (libraryList) => legacyAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, st) => AppErrorView(error: e, stackTrace: st, onRetry: () => ref.invalidate(assessmentsForTrialProvider(trial.id))),
        data: (legacyList) => _buildAssessmentsContent(context, ref, libraryList, legacyList),
      ),
    );
  }

  Widget _buildAssessmentsContent(
    BuildContext context,
    WidgetRef ref,
    List<(TrialAssessment, AssessmentDefinition)> libraryList,
    List<Assessment> legacyList,
  ) {
    final locked = isProtocolLocked(trial.status);
    final total = libraryList.length + legacyList.length;
    if (total == 0) {
      final button = FilledButton(
        onPressed: locked ? null : () => _showAddAssessmentOptions(context, ref),
        child: const Text('Add Assessment'),
      );
      return AppEmptyState(
        icon: Icons.assessment,
        title: 'No Assessments Yet',
        subtitle: locked
            ? getProtocolLockMessage(trial.status)
            : 'Add from library or create a custom assessment.',
        action: locked && getProtocolLockMessage(trial.status).isNotEmpty
            ? Tooltip(message: getProtocolLockMessage(trial.status), child: button)
            : button,
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDesignTokens.spacing16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppDesignTokens.sectionHeaderBg,
            border: Border(bottom: BorderSide(color: AppDesignTokens.borderCrisp)),
          ),
          child: Row(
            children: [
              const Icon(Icons.assessment_outlined,
                  size: 16, color: AppDesignTokens.primary),
              const SizedBox(width: AppDesignTokens.spacing8),
              Expanded(
                child: Text(
                  total == 1 ? '1 assessment' : '$total assessments',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppDesignTokens.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ProtocolLockChip(isLocked: locked, status: trial.status),
              const SizedBox(width: 8),
              Tooltip(
                message: locked ? getProtocolLockMessage(trial.status) : 'Add assessment',
                child: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: locked ? null : () => _showAddAssessmentOptions(context, ref),
                ),
              ),
            ],
          ),
        ),
        if (locked)
          ProtocolLockNotice(message: getProtocolLockMessage(trial.status)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              if (libraryList.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4, bottom: 6),
                  child: Text(
                    'From library',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ...libraryList.map((pair) {
                  final ta = pair.$1;
                  final def = pair.$2;
                  final name = ta.displayNameOverride ?? def.name;
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.cardSurface,
                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
                      border: Border.all(color: AppDesignTokens.borderCrisp),
                      boxShadow: const [
                        BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppDesignTokens.spacing16, vertical: AppDesignTokens.spacing8),
                      leading: Container(
                        padding: const EdgeInsets.all(AppDesignTokens.spacing8),
                        decoration: BoxDecoration(
                          color: AppDesignTokens.sectionHeaderBg,
                          borderRadius: BorderRadius.circular(AppDesignTokens.radiusXSmall),
                        ),
                        child: const Icon(Icons.analytics_outlined,
                            size: 20, color: AppDesignTokens.primary),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppDesignTokens.primaryText),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${def.dataType}${def.unit != null ? " (${def.unit})" : ""}',
                          style: const TextStyle(
                              color: AppDesignTokens.secondaryText,
                              fontSize: 12),
                        ),
                      ),
                      trailing: ta.isActive
                          ? const Icon(Icons.check_circle_outline,
                              size: 20, color: AppDesignTokens.primary)
                          : const Icon(Icons.chevron_right,
                              size: 20, color: AppDesignTokens.iconSubtle),
                    ),
                  );
                }),
              ],
              if (legacyList.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 16, bottom: 6),
                  child: Text(
                    'Custom',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ...legacyList.map((assessment) => Container(
                  margin: const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.cardSurface,
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
                    border: Border.all(color: AppDesignTokens.borderCrisp),
                    boxShadow: const [
                      BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDesignTokens.spacing16, vertical: AppDesignTokens.spacing8),
                    leading: Container(
                      padding: const EdgeInsets.all(AppDesignTokens.spacing8),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.sectionHeaderBg,
                        borderRadius: BorderRadius.circular(AppDesignTokens.radiusXSmall),
                      ),
                      child: const Icon(Icons.analytics_outlined,
                          size: 20, color: AppDesignTokens.primary),
                    ),
                    title: Text(
                      assessment.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppDesignTokens.primaryText),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${assessment.dataType}${assessment.unit != null ? " (${assessment.unit})" : ""}',
                        style: const TextStyle(
                            color: AppDesignTokens.secondaryText,
                            fontSize: 12),
                      ),
                    ),
                    trailing: assessment.isActive
                        ? const Icon(Icons.check_circle_outline,
                            size: 20, color: AppDesignTokens.primary)
                        : const Icon(Icons.chevron_right,
                            size: 20, color: AppDesignTokens.iconSubtle),
                  ),
                )),
              ],
            ],
          ),
        ),
      ],
    );
  }


  void _showAddAssessmentOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppDesignTokens.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDesignTokens.radiusLarge)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppDesignTokens.spacing16),
                decoration: BoxDecoration(
                  color: AppDesignTokens.dragHandle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 20, bottom: AppDesignTokens.spacing8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add Assessment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.primaryText,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primaryTint,
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.library_books_outlined,
                    color: AppDesignTokens.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'From Library',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                ),
                subtitle: const Text(
                  'Choose from standard templates',
                  style: TextStyle(fontSize: 12, color: AppDesignTokens.secondaryText),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  AssessmentLibraryPickerDialog.show(context, trial.id);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primaryTint,
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: AppDesignTokens.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Custom Assessment',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                ),
                subtitle: const Text(
                  'Create your own assessment',
                  style: TextStyle(fontSize: 12, color: AppDesignTokens.secondaryText),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showAddAssessmentDialog(context, ref);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddAssessmentDialog(
      BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final unitController = TextEditingController();
    final minController = TextEditingController();
    final maxController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AppDialog(
        title: 'Add Assessment',
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Assessment Name *',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: unitController,
              decoration: const InputDecoration(
                labelText: 'Unit (e.g. %, cm, score)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min Value',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: maxController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Value',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              final db = ref.read(databaseProvider);
              await db.into(db.assessments).insert(
                    AssessmentsCompanion.insert(
                      trialId: trial.id,
                      name: nameController.text.trim(),
                      unit: drift.Value(unitController.text.isEmpty
                          ? null
                          : unitController.text),
                      minValue:
                          drift.Value(double.tryParse(minController.text)),
                      maxValue:
                          drift.Value(double.tryParse(maxController.text)),
                    ),
                  );

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SEEDING TAB
// ─────────────────────────────────────────────

const List<String> _kSeedingRateUnits = ['seeds/m²', 'kg/ha', 'lbs/ac'];

class _SeedingTab extends ConsumerWidget {
  final Trial trial;

  const _SeedingTab({required this.trial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(seedingEventForTrialProvider(trial.id));

    return eventAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDesignTokens.spacing16),
          child: Text(
            'Failed to load seeding event: $e',
            style: const TextStyle(color: AppDesignTokens.secondaryText),
          ),
        ),
      ),
      data: (event) {
        if (event == null) {
          return AppEmptyState(
            icon: Icons.agriculture,
            title: 'No Seeding Event Yet',
            subtitle: 'Record the seeding operation for this trial',
            action: FilledButton.icon(
              onPressed: () => _openSeedingEventSheet(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Add Seeding Event'),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppDesignTokens.spacing16),
          child: _SeedingEventSummaryCard(
            event: event,
            onEdit: () => _openSeedingEventSheet(context, ref, event),
          ),
        );
      },
    );
  }

  void _openSeedingEventSheet(
      BuildContext context, WidgetRef ref, SeedingEvent? existing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppDesignTokens.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDesignTokens.radiusLarge)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _SeedingEventFormSheet(
          trial: trial,
          existing: existing,
          scrollController: scrollController,
          onSaved: () {
            ref.invalidate(seedingEventForTrialProvider(trial.id));
            if (context.mounted) Navigator.pop(sheetContext);
          },
        ),
      ),
    );
  }
}

class _SeedingEventSummaryCard extends StatelessWidget {
  final SeedingEvent event;
  final VoidCallback onEdit;

  const _SeedingEventSummaryCard(
      {required this.event, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final dateText =
        event.seedingDate.toLocal().toString().split(' ')[0];

    return Container(
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000),
              blurRadius: 4,
              offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDesignTokens.spacing16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDesignTokens.spacing8),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.sectionHeaderBg,
                    borderRadius:
                        BorderRadius.circular(AppDesignTokens.radiusXSmall),
                  ),
                  child: const Icon(Icons.agriculture,
                      size: 20, color: AppDesignTokens.primary),
                ),
                const SizedBox(width: AppDesignTokens.spacing12),
                Expanded(
                  child: Text(
                    'Seeding $dateText',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppDesignTokens.primaryText),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                  color: AppDesignTokens.primary,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppDesignTokens.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (event.operatorName != null &&
                    event.operatorName!.trim().isNotEmpty)
                  _summaryRow('Operator', event.operatorName!),
                if (event.seedLotNumber != null &&
                    event.seedLotNumber!.trim().isNotEmpty)
                  _summaryRow('Seed lot', event.seedLotNumber!),
                if (event.seedingRate != null)
                  _summaryRow(
                    'Rate',
                    '${event.seedingRate} ${event.seedingRateUnit ?? ''}'
                        .trim()),
                if (event.seedingDepth != null)
                  _summaryRow('Seeding depth', '${event.seedingDepth} cm'),
                if (event.rowSpacing != null)
                  _summaryRow('Row spacing', '${event.rowSpacing} cm'),
                if (event.equipmentUsed != null &&
                    event.equipmentUsed!.trim().isNotEmpty)
                  _summaryRow('Equipment', event.equipmentUsed!),
                if (event.notes != null && event.notes!.trim().isNotEmpty)
                  _summaryRow('Notes', event.notes!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppDesignTokens.secondaryText,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, color: AppDesignTokens.primaryText),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeedingEventFormSheet extends ConsumerStatefulWidget {
  final Trial trial;
  final SeedingEvent? existing;
  final ScrollController scrollController;
  final VoidCallback onSaved;

  const _SeedingEventFormSheet({
    required this.trial,
    required this.existing,
    required this.scrollController,
    required this.onSaved,
  });

  @override
  ConsumerState<_SeedingEventFormSheet> createState() =>
      _SeedingEventFormSheetState();
}

class _SeedingEventFormSheetState extends ConsumerState<_SeedingEventFormSheet> {
  late final TextEditingController _operatorController;
  late final TextEditingController _seedLotController;
  late final TextEditingController _rateController;
  late final TextEditingController _depthController;
  late final TextEditingController _rowSpacingController;
  late final TextEditingController _equipmentController;
  late final TextEditingController _notesController;
  DateTime _seedingDate = DateTime.now();
  String? _rateUnit;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _seedingDate = e?.seedingDate.toLocal() ?? DateTime.now();
    _rateUnit = e?.seedingRateUnit;
    _operatorController =
        TextEditingController(text: e?.operatorName ?? '');
    _seedLotController =
        TextEditingController(text: e?.seedLotNumber ?? '');
    _rateController = TextEditingController(
        text: e?.seedingRate != null ? e!.seedingRate.toString() : '');
    _depthController = TextEditingController(
        text: e?.seedingDepth != null ? e!.seedingDepth.toString() : '');
    _rowSpacingController = TextEditingController(
        text: e?.rowSpacing != null ? e!.rowSpacing.toString() : '');
    _equipmentController =
        TextEditingController(text: e?.equipmentUsed ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
  }

  @override
  void dispose() {
    _operatorController.dispose();
    _seedLotController.dispose();
    _rateController.dispose();
    _depthController.dispose();
    _rowSpacingController.dispose();
    _equipmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _seedingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _seedingDate = picked);
  }

  Future<void> _save() async {
    final rate = _rateController.text.trim().isEmpty
        ? null
        : double.tryParse(_rateController.text.trim());
    final depth = _depthController.text.trim().isEmpty
        ? null
        : double.tryParse(_depthController.text.trim());
    final rowSpacing = _rowSpacingController.text.trim().isEmpty
        ? null
        : double.tryParse(_rowSpacingController.text.trim());

    final companion = widget.existing == null
        ? SeedingEventsCompanion.insert(
            trialId: widget.trial.id,
            seedingDate: _seedingDate,
            operatorName: drift.Value(_operatorController.text.trim().isEmpty
                ? null
                : _operatorController.text.trim()),
            seedLotNumber: drift.Value(_seedLotController.text.trim().isEmpty
                ? null
                : _seedLotController.text.trim()),
            seedingRate: drift.Value(rate),
            seedingRateUnit: drift.Value(_rateUnit),
            seedingDepth: drift.Value(depth),
            rowSpacing: drift.Value(rowSpacing),
            equipmentUsed: drift.Value(_equipmentController.text.trim().isEmpty
                ? null
                : _equipmentController.text.trim()),
            notes: drift.Value(_notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim()),
          )
        : SeedingEventsCompanion(
            id: drift.Value(widget.existing!.id),
            trialId: drift.Value(widget.trial.id),
            seedingDate: drift.Value(_seedingDate),
            operatorName: drift.Value(_operatorController.text.trim().isEmpty
                ? null
                : _operatorController.text.trim()),
            seedLotNumber: drift.Value(_seedLotController.text.trim().isEmpty
                ? null
                : _seedLotController.text.trim()),
            seedingRate: drift.Value(rate),
            seedingRateUnit: drift.Value(_rateUnit),
            seedingDepth: drift.Value(depth),
            rowSpacing: drift.Value(rowSpacing),
            equipmentUsed: drift.Value(_equipmentController.text.trim().isEmpty
                ? null
                : _equipmentController.text.trim()),
            notes: drift.Value(_notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim()),
          );

    setState(() => _saving = true);
    try {
      await ref.read(seedingRepositoryProvider).upsertSeedingEvent(companion);
      if (mounted) widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(
                top: AppDesignTokens.spacing12,
                bottom: AppDesignTokens.spacing16),
            decoration: BoxDecoration(
              color: AppDesignTokens.dragHandle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing16),
            child: Text(
              widget.existing == null
                  ? 'Add Seeding Event'
                  : 'Edit Seeding Event',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppDesignTokens.primaryText),
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing16),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing16),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppDesignTokens.primaryText)),
                  subtitle: Text(
                    _seedingDate.toLocal().toString().split(' ')[0],
                    style: const TextStyle(
                        color: AppDesignTokens.primary,
                        fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined,
                      color: AppDesignTokens.primary, size: 20),
                  onTap: _pickDate,
                ),
                const SizedBox(height: AppDesignTokens.spacing8),
                TextField(
                  controller: _operatorController,
                  decoration: const InputDecoration(
                    labelText: 'Operator name (optional)',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppDesignTokens.spacing12),
                TextField(
                  controller: _seedLotController,
                  decoration: const InputDecoration(
                    labelText: 'Seed lot number (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppDesignTokens.spacing12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _rateController,
                        decoration: const InputDecoration(
                          labelText: 'Seeding rate (optional)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: AppDesignTokens.spacing8),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        // ignore: deprecated_member_use
                        value: _rateUnit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('—')),
                          ..._kSeedingRateUnits.map(
                            (u) => DropdownMenuItem<String?>(
                                value: u, child: Text(u)),
                          ),
                        ],
                        onChanged: (v) => setState(() => _rateUnit = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDesignTokens.spacing12),
                TextField(
                  controller: _depthController,
                  decoration: const InputDecoration(
                    labelText: 'Seeding depth cm (optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: AppDesignTokens.spacing12),
                TextField(
                  controller: _rowSpacingController,
                  decoration: const InputDecoration(
                    labelText: 'Row spacing cm (optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: AppDesignTokens.spacing12),
                TextField(
                  controller: _equipmentController,
                  decoration: const InputDecoration(
                    labelText: 'Equipment used (optional)',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppDesignTokens.spacing12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: AppDesignTokens.spacing24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Save'),
                  ),
                ),
                const SizedBox(height: AppDesignTokens.spacing16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// APPLICATIONS TAB
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
// SEEDING DETAIL SCREEN
// ─────────────────────────────────────────────

class _SeedingDetailScreen extends ConsumerStatefulWidget {
  final SeedingRecord record;

  const _SeedingDetailScreen({required this.record});

  @override
  ConsumerState<_SeedingDetailScreen> createState() =>
      _SeedingDetailScreenState();
}

class _SeedingDetailScreenState extends ConsumerState<_SeedingDetailScreen> {
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, String?> _boolValues = {};
  final Map<String, String?> _dateValues = {};
  bool _initialized = false;
  bool _isSaving = false;
  bool _isReadOnly = true;

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveValues(List<dynamic> fields) async {
    final db = ref.read(databaseProvider);

    setState(() => _isSaving = true);

    await (db.delete(db.seedingFieldValues)
          ..where((t) => t.seedingRecordId.equals(widget.record.id)))
        .go();

    for (final f in fields) {
      final fieldKey = f.fieldKey as String;
      final fieldLabel = f.fieldLabel as String;
      final fieldType = (f.fieldType as String).toLowerCase();
      final unit = f.unit as String?;
      final sortOrder = f.sortOrder as int;

      String? valueText;
      double? valueNumber;
      String? valueDate;
      bool? valueBool;

      if (fieldType == 'number' || fieldType == 'numeric') {
        final raw = _textControllers[fieldKey]?.text.trim();
        if (raw != null && raw.isNotEmpty) {
          valueNumber = double.tryParse(raw);
        }
      } else if (fieldType == 'date') {
        valueDate = _dateValues[fieldKey];
      } else if (fieldType == 'bool' || fieldType == 'boolean') {
        final raw = _boolValues[fieldKey];
        if (raw == 'yes') valueBool = true;
        if (raw == 'no') valueBool = false;
      } else {
        final raw = _textControllers[fieldKey]?.text.trim();
        if (raw != null && raw.isNotEmpty) {
          valueText = raw;
        }
      }

      final hasAnyValue = valueText != null ||
          valueNumber != null ||
          valueDate != null ||
          valueBool != null;

      if (!hasAnyValue) continue;

      await db.into(db.seedingFieldValues).insert(
            SeedingFieldValuesCompanion.insert(
              seedingRecordId: widget.record.id,
              fieldKey: fieldKey,
              fieldLabel: fieldLabel,
              valueText: drift.Value(valueText),
              valueNumber: drift.Value(valueNumber),
              valueDate: drift.Value(valueDate),
              valueBool: drift.Value(valueBool),
              unit: drift.Value(unit),
              sortOrder: drift.Value(sortOrder),
            ),
          );
    }

    if (!mounted) return;

    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Protocol values saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final dateText =
        widget.record.seedingDate.toLocal().toString().split(' ')[0];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seeding Event'),
        actions: [
          IconButton(
            icon: Icon(_isReadOnly ? Icons.edit_outlined : Icons.done),
            tooltip: _isReadOnly ? 'Edit' : 'Done',
            onPressed: () => setState(() => _isReadOnly = !_isReadOnly),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          (db.select(db.protocolSeedingFields)
                ..where((f) => f.trialId.equals(widget.record.trialId))
                ..orderBy([(f) => drift.OrderingTerm.asc(f.sortOrder)]))
              .get(),
          (db.select(db.seedingFieldValues)
                ..where((v) => v.seedingRecordId.equals(widget.record.id))
                ..orderBy([(v) => drift.OrderingTerm.asc(v.sortOrder)]))
              .get(),
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final fields = snapshot.data![0] as List;
          final existingValues = snapshot.data![1] as List;

          if (!_initialized) {
            final existingByKey = <String, dynamic>{
              for (final v in existingValues) v.fieldKey as String: v,
            };

            for (final f in fields) {
              final fieldKey = f.fieldKey as String;
              final fieldType = (f.fieldType as String).toLowerCase();
              final existing = existingByKey[fieldKey];

              if (fieldType == 'number' || fieldType == 'numeric') {
                _textControllers[fieldKey] = TextEditingController(
                  text: existing?.valueNumber?.toString() ?? '',
                );
              } else if (fieldType == 'date') {
                _dateValues[fieldKey] = existing?.valueDate as String?;
              } else if (fieldType == 'bool' || fieldType == 'boolean') {
                if (existing?.valueBool == true) _boolValues[fieldKey] = 'yes';
                if (existing?.valueBool == false) _boolValues[fieldKey] = 'no';
              } else {
                _textControllers[fieldKey] = TextEditingController(
                  text: existing?.valueText as String? ?? '',
                );
              }
            }

            _initialized = true;
          }

          if (_isReadOnly) {
            return _buildSeedingReadOnlyView(context, dateText, existingValues);
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  dateText,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Text(
                  'Operator',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.record.operatorName ?? 'Not recorded',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                Text(
                  'Comments',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.record.comments ?? 'None',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Protocol Fields',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : () => _saveValues(fields),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: fields.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('No protocol fields defined yet.'),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () => _addProtocolField(
                                    context, ref, widget.record),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Field Manually'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: fields.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final f = fields[i];
                            final fieldKey = f.fieldKey as String;
                            final fieldType =
                                (f.fieldType as String).toLowerCase();
                            final label = f.fieldLabel as String;
                            final unit = f.unit as String?;
                            final required = f.isRequired as bool;

                            if (fieldType == 'number' ||
                                fieldType == 'numeric') {
                              return TextFormField(
                                controller: _textControllers[fieldKey],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  labelText:
                                      unit == null ? label : '$label ($unit)',
                                  border: const OutlineInputBorder(),
                                  helperText:
                                      required ? 'Required field' : null,
                                ),
                              );
                            }

                            if (fieldType == 'date') {
                              return TextFormField(
                                readOnly: true,
                                controller: TextEditingController(
                                  text: _dateValues[fieldKey] ?? '',
                                ),
                                decoration: InputDecoration(
                                  labelText: label,
                                  border: const OutlineInputBorder(),
                                  helperText:
                                      required ? 'Required field' : null,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.calendar_today),
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _dateValues[fieldKey] =
                                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                        });
                                      }
                                    },
                                  ),
                                ),
                              );
                            }

                            if (fieldType == 'bool' || fieldType == 'boolean') {
                              return DropdownButtonFormField<String>(
                                initialValue: _boolValues[fieldKey],
                                decoration: InputDecoration(
                                  labelText: label,
                                  border: const OutlineInputBorder(),
                                  helperText:
                                      required ? 'Required field' : null,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'yes', child: Text('Yes')),
                                  DropdownMenuItem(
                                      value: 'no', child: Text('No')),
                                ],
                                onChanged: (value) {
                                  setState(() => _boolValues[fieldKey] = value);
                                },
                              );
                            }

                            return TextFormField(
                              controller: _textControllers[fieldKey],
                              decoration: InputDecoration(
                                labelText:
                                    unit == null ? label : '$label ($unit)',
                                border: const OutlineInputBorder(),
                                helperText: required ? 'Required field' : null,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSeedingReadOnlyView(
      BuildContext context, String dateText, List<dynamic> existingValues) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _readOnlyRow(context, 'Date', dateText),
          const SizedBox(height: 16),
          _readOnlyRow(context, 'Operator',
              widget.record.operatorName ?? 'Not recorded'),
          const SizedBox(height: 16),
          _readOnlyRow(context, 'Comments',
              widget.record.comments ?? 'None'),
          if (existingValues.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...existingValues.map<Widget>((v) {
              final label = v.fieldLabel as String? ?? v.fieldKey as String;
              final value = v.valueText ?? v.valueNumber?.toString() ??
                  v.valueDate ?? (v.valueBool == true ? 'Yes' : v.valueBool == false ? 'No' : '—');
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _readOnlyRow(context, label, value.toString()),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _readOnlyRow(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16)),
      ],
    );
  }
}

Future<void> _addProtocolField(
    BuildContext context, WidgetRef ref, SeedingRecord record) async {
  final db = ref.read(databaseProvider);

  final labelController = TextEditingController();
  final unitController = TextEditingController();

  String fieldType = 'text';
  bool isRequired = false;

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Add Protocol Field'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Field Label',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(
                  labelText: 'Unit (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: fieldType,
                decoration: const InputDecoration(
                  labelText: 'Field Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'text', child: Text('Text')),
                  DropdownMenuItem(value: 'number', child: Text('Number')),
                  DropdownMenuItem(value: 'date', child: Text('Date')),
                  DropdownMenuItem(value: 'bool', child: Text('Yes/No')),
                ],
                onChanged: (v) {
                  fieldType = v!;
                },
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: isRequired,
                title: const Text('Required field'),
                onChanged: (v) {
                  isRequired = v ?? false;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );

  if (saved != true) return;

  final label = labelController.text.trim();
  final unit = unitController.text.trim();

  if (label.isEmpty) return;

  final key = label.toLowerCase().replaceAll(' ', '_');

  await db.into(db.protocolSeedingFields).insert(
        ProtocolSeedingFieldsCompanion.insert(
          trialId: record.trialId,
          fieldKey: key,
          fieldLabel: label,
          fieldType: fieldType,
          unit: drift.Value(unit.isEmpty ? null : unit),
          isRequired: drift.Value(isRequired),
        ),
      );

  if (context.mounted) {
    Navigator.pop(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _SeedingDetailScreen(record: record),
      ),
    );
  }
}


// ─────────────────────────────────────────────
// TREATMENTS TAB
// ─────────────────────────────────────────────

class _TreatmentsTab extends ConsumerWidget {
  final Trial trial;

  const _TreatmentsTab({required this.trial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treatmentsAsync = ref.watch(treatmentsForTrialProvider(trial.id));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Treatments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Open in full screen',
                icon: const Icon(Icons.fullscreen),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Treatments')),
                        body: _TreatmentsTab(trial: trial),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: treatmentsAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, st) => AppErrorView(error: e, stackTrace: st, onRetry: () => ref.invalidate(treatmentsForTrialProvider(trial.id))),
      data: (treatments) => treatments.isEmpty
          ? _buildEmpty(context, ref)
          : _buildList(context, ref, treatments),
    ),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    final locked = isProtocolLocked(trial.status);
    final button = FilledButton(
      onPressed: locked ? null : () => _showAddTreatmentDialog(context, ref),
      child: const Text('Add Treatment'),
    );
    return AppEmptyState(
      icon: Icons.science_outlined,
      title: 'No Treatments Yet',
      subtitle: locked ? getProtocolLockMessage(trial.status) : 'Add the treatment groups for this trial.',
      action: locked && getProtocolLockMessage(trial.status).isNotEmpty
          ? Tooltip(message: getProtocolLockMessage(trial.status), child: button)
          : button,
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, List<Treatment> treatments) {
    final locked = isProtocolLocked(trial.status);
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
          itemCount: treatments.length + (locked ? 1 : 0),
          itemBuilder: (context, index) {
            if (locked && index == 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ProtocolLockChip(isLocked: true, status: trial.status),
                    const SizedBox(height: 4),
                    Text(
                      getProtocolLockMessage(trial.status),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }
            final i = locked ? index - 1 : index;
            final t = treatments[i];
            return FutureBuilder<List<TreatmentComponent>>(
              future: ref.read(treatmentRepositoryProvider).getComponentsForTreatment(t.id),
              builder: (context, snapshot) {
                final componentCount = snapshot.data?.length ?? 0;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.cardSurface,
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
                    border: Border.all(color: AppDesignTokens.borderCrisp),
                    boxShadow: const [
                      BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDesignTokens.spacing16, vertical: AppDesignTokens.spacing8),
                    leading: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppDesignTokens.spacing8, vertical: AppDesignTokens.spacing4),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.primary,
                        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
                      ),
                      child: Text(t.code,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Colors.white,
                              letterSpacing: 0.2)),
                    ),
                    title: Text(t.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppDesignTokens.primaryText)),
                    subtitle: t.description != null
                        ? Text(t.description!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppDesignTokens.secondaryText))
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (componentCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppDesignTokens.successBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$componentCount ${componentCount == 1 ? "product" : "products"}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppDesignTokens.successFg),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppDesignTokens.emptyBadgeBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'No products',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppDesignTokens.emptyBadgeFg),
                            ),
                          ),
                        const SizedBox(width: AppDesignTokens.spacing8),
                        if (!locked)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20, color: AppDesignTokens.iconSubtle),
                            tooltip: 'Edit or delete treatment',
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showEditTreatmentDialog(context, ref, trial, t);
                              } else if (value == 'delete') {
                                _showDeleteTreatmentDialog(context, ref, trial, t);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          )
                        else
                          const Icon(Icons.chevron_right, size: 18, color: AppDesignTokens.iconSubtle),
                      ],
                    ),
                    onTap: () => _showTreatmentComponents(context, ref, t),
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: locked
              ? GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(getProtocolLockMessage(trial.status))),
                  ),
                  child: Tooltip(
                    message: getProtocolLockMessage(trial.status),
                    child: const FloatingActionButton.extended(
                      heroTag: 'add_treatment',
                      onPressed: null,
                      icon: Icon(Icons.add),
                      label: Text('Add Treatment'),
                    ),
                  ),
                )
              : Tooltip(
                  message: 'Add treatment',
                  child: FloatingActionButton.extended(
                    heroTag: 'add_treatment',
                    onPressed: () => _showAddTreatmentDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Treatment'),
                  ),
                ),
        ),
      ],
    );
  }


  Future<void> _showTreatmentComponents(
      BuildContext context, WidgetRef ref, Treatment treatment) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _TreatmentComponentsSheet(
        trial: trial,
        treatment: treatment,
      ),
    );
  }

  Future<void> _showEditTreatmentDialog(
      BuildContext context, WidgetRef ref, Trial trial, Treatment treatment) async {
    final codeController = TextEditingController(text: treatment.code);
    final nameController = TextEditingController(text: treatment.name);
    final descController = TextEditingController(text: treatment.description ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Edit Treatment',
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Code (e.g. T1, T2)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final useCase = ref.read(updateTreatmentUseCaseProvider);
              final result = await useCase.execute(
                trial: trial,
                treatmentId: treatment.id,
                code: codeController.text,
                name: nameController.text,
                description: descController.text.trim().isEmpty ? null : descController.text.trim(),
              );
              if (!ctx.mounted) return;
              if (result.success) {
                ref.invalidate(treatmentsForTrialProvider(trial.id));
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(result.errorMessage ?? 'Update failed'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteTreatmentDialog(
      BuildContext context, WidgetRef ref, Trial trial, Treatment treatment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Treatment'),
        content: Text(
          'Delete "${treatment.code} — ${treatment.name}"? Plots assigned to this treatment will be unassigned. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final useCase = ref.read(deleteTreatmentUseCaseProvider);
    final result = await useCase.execute(trial: trial, treatmentId: treatment.id);
    if (!context.mounted) return;
    if (result.success) {
      ref.invalidate(treatmentsForTrialProvider(trial.id));
      ref.invalidate(assignmentsForTrialProvider(trial.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treatment deleted')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Delete failed'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showAddTreatmentDialog(
      BuildContext context, WidgetRef ref) async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final descController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Add Treatment',
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Code (e.g. T1, T2)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (codeController.text.trim().isEmpty ||
                  nameController.text.trim().isEmpty) {
                return;
              }
              final repo = ref.read(treatmentRepositoryProvider);
              await repo.insertTreatment(
                trialId: trial.id,
                code: codeController.text.trim(),
                name: nameController.text.trim(),
                description: descController.text.trim().isEmpty
                    ? null
                    : descController.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────
// PHOTOS TAB (by session history)
// ─────────────────────────────────────────────

class _PhotosTab extends ConsumerWidget {
  final Trial trial;

  const _PhotosTab({required this.trial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(photosForTrialProvider(trial.id));
    final sessionsAsync = ref.watch(sessionsForTrialProvider(trial.id));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Photos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Open in full screen',
                icon: const Icon(Icons.fullscreen),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Photos')),
                        body: _PhotosTab(trial: trial),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: photosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load photos: $e', textAlign: TextAlign.center),
        ),
      ),
      data: (photos) {
        if (photos.isEmpty) {
          return const AppEmptyState(
            icon: Icons.photo_library_outlined,
            title: 'No photos yet',
            subtitle: 'Photos taken during sessions will appear here, grouped by session.',
          );
        }
        final sessions = sessionsAsync.valueOrNull ?? <Session>[];
        final sessionById = {for (var s in sessions) s.id: s};
        final bySession = <int, List<Photo>>{};
        for (final p in photos) {
          bySession.putIfAbsent(p.sessionId, () => []).add(p);
        }
        final sessionIds = bySession.keys.toList()..sort();
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: sessionIds.length,
          itemBuilder: (context, i) {
            final sessionId = sessionIds[i];
            final sessionPhotos = bySession[sessionId]!;
            final session = sessionById[sessionId];
            final title = session?.name ?? 'Session $sessionId';
            final subtitle = session?.sessionDateLocal ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppDesignTokens.primaryText,
                      ),
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppDesignTokens.secondaryText,
                        ),
                      ),
                    ),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: sessionPhotos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, j) {
                        final p = sessionPhotos[j];
                        final file = File(p.filePath);
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => PhotoViewerScreen(
                                  photos: sessionPhotos,
                                  initialIndex: j,
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 88,
                              height: 88,
                              color: AppDesignTokens.borderCrisp,
                              child: file.existsSync()
                                  ? Image.file(file, fit: BoxFit.cover)
                                  : const Center(
                                      child: Icon(Icons.broken_image, color: AppDesignTokens.secondaryText),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
        ),
      ],
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
                          content: Text(
                              'Exported ${result.sessionCount} sessions')),
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
                      child: Text('Export all to CSV (ZIP)')),
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
                onRetry: () => ref.invalidate(sessionsForTrialProvider(trial.id)),
              ),
              data: (sessions) {
                final applicationsList = ref.watch(trialApplicationsForTrialProvider(trial.id)).value ?? [];
                final firstApplicationDate = applicationsList.isNotEmpty
                    ? applicationsList.first.applicationDate
                    : null;
                final ratingBeforeFirstApp = firstApplicationDate != null &&
                    sessions.any((s) => s.startedAt.isBefore(firstApplicationDate));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (ratingBeforeFirstApp) _buildSessionDateWarningBanner(context),
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

  Widget _buildSessionDateWarningBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppDesignTokens.warningBg,
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppDesignTokens.warningFg, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Rating recorded before first application — check session dates',
              style: TextStyle(fontSize: 13, color: AppDesignTokens.warningFg),
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
          horizontal: AppDesignTokens.spacing16, vertical: AppDesignTokens.spacing8),
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
    final ratings = ref.watch(sessionRatingsProvider(session.id)).valueOrNull ?? [];
    final flaggedIds = ref.watch(flaggedPlotIdsForSessionProvider(session.id)).valueOrNull ?? <int>{};
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
                    builder: (_) => SessionDetailScreen(
                        trial: trial, session: session)));
          }
        },
        onLongPress: isOpen
            ? () => _confirmCloseSession(context, ref, session)
            : null,
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
            color: isOpen ? AppDesignTokens.openSessionBg : AppDesignTokens.emptyBadgeFg,
            size: 20,
          ),
        ),
        title: Text(
            _shortSessionName(session.name, session.sessionDateLocal),
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
          : (dateStr.contains(' ') ? dateStr.split(' ').first : (dateStr.contains('T') ? dateStr.split('T').first : dateStr));
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
      if (day == null || monthIdx == null || monthIdx < 1 || monthIdx > 12) return dateStr;
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

class _ApplicationsTab extends ConsumerWidget {
  final Trial trial;
  const _ApplicationsTab({required this.trial});

  static const List<String> _rateUnits = ['L/ha', 'kg/ha', 'g/ha', 'mL/ha', 'oz/ac'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(trialApplicationsForTrialProvider(trial.id));
    return applicationsAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, st) => AppErrorView(
        error: e,
        stackTrace: st,
        onRetry: () => ref.invalidate(trialApplicationsForTrialProvider(trial.id)),
      ),
      data: (list) => list.isEmpty
          ? _buildEmpty(context, ref)
          : _buildList(context, ref, list),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return AppEmptyState(
      icon: Icons.science,
      title: 'No Applications Yet',
      subtitle: 'Record spray, granular and other application events for this trial.',
      action: FilledButton.icon(
        onPressed: () => _showApplicationSheet(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add Application'),
      ),
    );
  }

  Widget _buildApplicationTile(
    BuildContext context,
    WidgetRef ref,
    TrialApplicationEvent e,
  ) {
    final dateStr = DateFormat('MMM d, yyyy').format(e.applicationDate);
    final productLabel = e.productName?.trim().isNotEmpty == true
        ? e.productName!
        : null;
    final treatments = ref.watch(treatmentsForTrialProvider(trial.id)).value ?? [];
    final treatment = e.treatmentId != null
        ? treatments.where((t) => t.id == e.treatmentId).firstOrNull
        : null;

    return Card(
      child: ListTile(
        title: Text(
          dateStr,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              productLabel ?? 'No product specified',
              style: TextStyle(
                color: productLabel != null
                    ? null
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            if (e.rate != null && e.rateUnit != null)
              Text(
                '${e.rate} ${e.rateUnit}',
                style: const TextStyle(fontSize: 13),
              ),
            if (treatment != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Chip(
                  label: Text(treatment.code),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => _showApplicationSheet(context, ref, e),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<TrialApplicationEvent> list) {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final e = list[index];
            return Dismissible(
              key: Key(e.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                color: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Application?'),
                    content: const Text(
                      'This application will be permanently deleted.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (_) {
                ref.read(applicationRepositoryProvider).deleteApplication(e.id);
              },
              child: _buildApplicationTile(context, ref, e),
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'add_application',
            onPressed: () => _showApplicationSheet(context, ref, null),
            icon: const Icon(Icons.add),
            label: const Text('Add Application'),
          ),
        ),
      ],
    );
  }

  Future<void> _showApplicationSheet(
    BuildContext context,
    WidgetRef ref,
    TrialApplicationEvent? existing,
  ) async {
    final repo = ref.read(applicationRepositoryProvider);
    final treatments = ref.watch(treatmentsForTrialProvider(trial.id)).value ?? [];

    final dateController = ValueNotifier<DateTime>(
      existing?.applicationDate ?? DateTime.now(),
    );
    final treatmentIdController = ValueNotifier<int?>(existing?.treatmentId);
    final productController = TextEditingController(text: existing?.productName ?? '');
    final rateController = TextEditingController(
      text: existing?.rate != null ? existing!.rate.toString() : '',
    );
    final rateUnitController = ValueNotifier<String?>(
      existing?.rateUnit ?? (existing == null ? _rateUnits.first : null),
    );
    final waterVolumeController = TextEditingController(
      text: existing?.waterVolume != null ? existing!.waterVolume.toString() : '',
    );
    final growthStageController = TextEditingController(text: existing?.growthStageCode ?? '');
    final operatorController = TextEditingController(text: existing?.operatorName ?? '');
    final equipmentController = TextEditingController(text: existing?.equipmentUsed ?? '');
    final windSpeedController = TextEditingController(
      text: existing?.windSpeed != null ? existing!.windSpeed.toString() : '',
    );
    final windDirectionController = TextEditingController(text: existing?.windDirection ?? '');
    final temperatureController = TextEditingController(
      text: existing?.temperature != null ? existing!.temperature.toString() : '',
    );
    final humidityController = TextEditingController(
      text: existing?.humidity != null ? existing!.humidity.toString() : '',
    );
    final notesController = TextEditingController(text: existing?.notes ?? '');

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final selectedDate = dateController.value;
          final selectedTreatmentId = treatmentIdController.value;
          final selectedRateUnit = rateUnitController.value ?? _rateUnits.first;
          final dateLabel = DateFormat('MMM d, yyyy').format(selectedDate);
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null ? 'Add Application' : 'Edit Application',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          dateController.value = picked;
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text('Date: $dateLabel'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      initialValue: selectedTreatmentId,
                      decoration: const InputDecoration(
                        labelText: 'Treatment',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...treatments.map(
                          (t) => DropdownMenuItem<int?>(
                            value: t.id,
                            child: Text(t.code),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        treatmentIdController.value = v;
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: productController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: rateController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Rate',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedRateUnit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(),
                            ),
                            items: _rateUnits
                                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                .toList(),
                            onChanged: (v) {
                              rateUnitController.value = v;
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: waterVolumeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Water Volume (L/ha)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: growthStageController,
                      decoration: const InputDecoration(
                        labelText: 'Growth Stage / BBCH',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: operatorController,
                      decoration: const InputDecoration(
                        labelText: 'Operator',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: equipmentController,
                      decoration: const InputDecoration(
                        labelText: 'Equipment',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Weather',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: windSpeedController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Wind Speed',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: windDirectionController,
                            decoration: const InputDecoration(
                              labelText: 'Wind Direction',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: temperatureController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Temperature (°C)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: humidityController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Humidity (%)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (existing != null) ...[
                          TextButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: ctx,
                                builder: (d) => AlertDialog(
                                  title: const Text('Delete Application?'),
                                  content: const Text(
                                    'This application will be permanently deleted.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(d, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      onPressed: () => Navigator.pop(d, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && ctx.mounted) {
                                await repo.deleteApplication(existing.id);
                                if (ctx.mounted) Navigator.pop(ctx);
                              }
                            },
                            child: const Text('Delete'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            final date = dateController.value;
                            final rate = double.tryParse(rateController.text.trim());
                            final waterVolume = double.tryParse(
                              waterVolumeController.text.trim(),
                            );
                            final windSpeed = double.tryParse(
                              windSpeedController.text.trim(),
                            );
                            final temperature = double.tryParse(
                              temperatureController.text.trim(),
                            );
                            final humidity = double.tryParse(
                              humidityController.text.trim(),
                            );
                            if (existing == null) {
                              await repo.createApplication(
                                TrialApplicationEventsCompanion.insert(
                                  trialId: trial.id,
                                  applicationDate: date,
                                  treatmentId: drift.Value(treatmentIdController.value),
                                  productName: drift.Value(
                                    productController.text.trim().isEmpty
                                        ? null
                                        : productController.text.trim(),
                                  ),
                                  rate: drift.Value(rate),
                                  rateUnit: drift.Value(
                                    rateUnitController.value?.trim().isEmpty == true
                                        ? null
                                        : rateUnitController.value,
                                  ),
                                  waterVolume: drift.Value(waterVolume),
                                  growthStageCode: drift.Value(
                                    growthStageController.text.trim().isEmpty
                                        ? null
                                        : growthStageController.text.trim(),
                                  ),
                                  operatorName: drift.Value(
                                    operatorController.text.trim().isEmpty
                                        ? null
                                        : operatorController.text.trim(),
                                  ),
                                  equipmentUsed: drift.Value(
                                    equipmentController.text.trim().isEmpty
                                        ? null
                                        : equipmentController.text.trim(),
                                  ),
                                  windSpeed: drift.Value(windSpeed),
                                  windDirection: drift.Value(
                                    windDirectionController.text.trim().isEmpty
                                        ? null
                                        : windDirectionController.text.trim(),
                                  ),
                                  temperature: drift.Value(temperature),
                                  humidity: drift.Value(humidity),
                                  notes: drift.Value(
                                    notesController.text.trim().isEmpty
                                        ? null
                                        : notesController.text.trim(),
                                  ),
                                ),
                              );
                            } else {
                              await repo.updateApplication(
                                existing.id,
                                TrialApplicationEventsCompanion(
                                  treatmentId: drift.Value(treatmentIdController.value),
                                  productName: drift.Value(
                                    productController.text.trim().isEmpty
                                        ? null
                                        : productController.text.trim(),
                                  ),
                                  rate: drift.Value(rate),
                                  rateUnit: drift.Value(
                                    rateUnitController.value?.trim().isEmpty == true
                                        ? null
                                        : rateUnitController.value,
                                  ),
                                  waterVolume: drift.Value(waterVolume),
                                  growthStageCode: drift.Value(
                                    growthStageController.text.trim().isEmpty
                                        ? null
                                        : growthStageController.text.trim(),
                                  ),
                                  operatorName: drift.Value(
                                    operatorController.text.trim().isEmpty
                                        ? null
                                        : operatorController.text.trim(),
                                  ),
                                  equipmentUsed: drift.Value(
                                    equipmentController.text.trim().isEmpty
                                        ? null
                                        : equipmentController.text.trim(),
                                  ),
                                  windSpeed: drift.Value(windSpeed),
                                  windDirection: drift.Value(
                                    windDirectionController.text.trim().isEmpty
                                        ? null
                                        : windDirectionController.text.trim(),
                                  ),
                                  temperature: drift.Value(temperature),
                                  humidity: drift.Value(humidity),
                                  notes: drift.Value(
                                    notesController.text.trim().isEmpty
                                        ? null
                                        : notesController.text.trim(),
                                  ),
                                  applicationDate: drift.Value(date),
                                ),
                              );
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


// ─────────────────────────────────────────────
// ADD COMPONENT DIALOG (StatefulWidget owns controllers for safe lifecycle)
// ─────────────────────────────────────────────

class _AddComponentDialog extends StatefulWidget {
  const _AddComponentDialog({
    required this.trial,
    required this.treatment,
    required this.ref,
    required this.onSaved,
  });

  final Trial trial;
  final Treatment treatment;
  final WidgetRef ref;
  final Future<void> Function() onSaved;

  @override
  State<_AddComponentDialog> createState() => _AddComponentDialogState();
}

class _AddComponentDialogState extends State<_AddComponentDialog> {
  late final TextEditingController productController;
  late final TextEditingController rateController;
  late final TextEditingController rateUnitController;
  late final TextEditingController timingController;
  late final TextEditingController notesController;

  @override
  void initState() {
    super.initState();
    productController = TextEditingController();
    rateController = TextEditingController();
    rateUnitController = TextEditingController();
    timingController = TextEditingController();
    notesController = TextEditingController();
  }

  @override
  void dispose() {
    productController.dispose();
    rateController.dispose();
    rateUnitController.dispose();
    timingController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Add Product to ${widget.treatment.code}',
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: productController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Product Name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: rateController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Rate',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: rateUnitController,
                  decoration: const InputDecoration(
                    labelText: 'Unit (e.g. L/ha)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: timingController,
            decoration: const InputDecoration(
              labelText: 'Application Timing (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (productController.text.trim().isEmpty) return;
            final repo = widget.ref.read(treatmentRepositoryProvider);
            await repo.insertComponent(
              treatmentId: widget.treatment.id,
              trialId: widget.trial.id,
              productName: productController.text.trim(),
              rate: rateController.text.trim().isEmpty
                  ? null
                  : rateController.text.trim(),
              rateUnit: rateUnitController.text.trim().isEmpty
                  ? null
                  : rateUnitController.text.trim(),
              applicationTiming: timingController.text.trim().isEmpty
                  ? null
                  : timingController.text.trim(),
              notes: notesController.text.trim().isEmpty
                  ? null
                  : notesController.text.trim(),
            );
            if (!context.mounted) return;
            Navigator.pop(context);
            await widget.onSaved();
          },
          child: const Text('Add Product'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// TREATMENT COMPONENTS BOTTOM SHEET
// ─────────────────────────────────────────────

class _TreatmentComponentsSheet extends ConsumerStatefulWidget {
  final Trial trial;
  final Treatment treatment;

  const _TreatmentComponentsSheet({
    required this.trial,
    required this.treatment,
  });

  @override
  ConsumerState<_TreatmentComponentsSheet> createState() =>
      _TreatmentComponentsSheetState();
}

class _TreatmentComponentsSheetState
    extends ConsumerState<_TreatmentComponentsSheet> {
  List<TreatmentComponent> _components = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadComponents();
  }

  Future<void> _loadComponents() async {
    final repo = ref.read(treatmentRepositoryProvider);
    final result =
        await repo.getComponentsForTreatment(widget.treatment.id);
    if (mounted) setState(() { _components = result; _loading = false; });
    // So the Treatments tab (treatment cards with product counts) rebuilds and shows updated counts.
    ref.invalidate(treatmentsForTrialProvider(widget.trial.id));
  }

  @override
  Widget build(BuildContext context) {
    final locked = isProtocolLocked(widget.trial.status);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppDesignTokens.dragHandle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                  AppDesignTokens.spacing16, AppDesignTokens.spacing8,
                  AppDesignTokens.spacing16, AppDesignTokens.spacing12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppDesignTokens.borderCrisp)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.primary,
                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusXSmall),
                    ),
                    child: Text(widget.treatment.code,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ),
                  const SizedBox(width: AppDesignTokens.spacing8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.treatment.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppDesignTokens.primaryText)),
                        if (_components.isNotEmpty)
                          Text(
                            '${_components.length} ${_components.length == 1 ? "product" : "products"}',
                            style: const TextStyle(
                                fontSize: 11, color: AppDesignTokens.secondaryText),
                          ),
                      ],
                    ),
                  ),
                  if (!locked)
                    ElevatedButton.icon(
                      onPressed: () => _showAddComponentDialog(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Product'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignTokens.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppDesignTokens.spacing16,
                            vertical: AppDesignTokens.spacing8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppDesignTokens.radiusSmall)),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _components.isEmpty
                      ? _buildEmpty(context, locked)
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: _components.length,
                          itemBuilder: (context, i) =>
                              _buildComponentTile(context, i),
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context, bool locked) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppDesignTokens.successBg,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(Icons.science_outlined,
                size: 32, color: AppDesignTokens.primary),
          ),
          const SizedBox(height: AppDesignTokens.spacing16),
          const Text('No products yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppDesignTokens.primaryText)),
          const SizedBox(height: 6),
          const Text('Add products, rates and timing',
              style: TextStyle(
                  fontSize: 13, color: AppDesignTokens.secondaryText)),
          if (!locked) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showAddComponentDialog(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Product'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesignTokens.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        AppDesignTokens.radiusSmall)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComponentTile(BuildContext context, int i) {
    final c = _components[i];
    final locked = isProtocolLocked(widget.trial.status);
    final ratePart = (c.rate != null && c.rateUnit != null)
        ? '${c.rate} ${c.rateUnit}'
        : null;
    final timingPart = c.applicationTiming;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignTokens.spacing16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppDesignTokens.emptyBadgeBg,
                borderRadius: BorderRadius.circular(AppDesignTokens.radiusXSmall),
              ),
              child: Center(
                child: Text('${i + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppDesignTokens.primary)),
              ),
            ),
            const SizedBox(width: AppDesignTokens.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.productName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppDesignTokens.primaryText)),
                  if (ratePart != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.water_drop_outlined,
                            size: 13, color: AppDesignTokens.secondaryText),
                        const SizedBox(width: 4),
                        Text(ratePart,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppDesignTokens.secondaryText)),
                      ],
                    ),
                  ],
                  if (timingPart != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.schedule,
                            size: 13, color: AppDesignTokens.secondaryText),
                        const SizedBox(width: 4),
                        Text(timingPart,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppDesignTokens.secondaryText)),
                      ],
                    ),
                  ],
                  if (c.notes != null && c.notes!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(c.notes!,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppDesignTokens.emptyBadgeFg)),
                  ],
                ],
              ),
            ),
            if (!locked)
              GestureDetector(
                onTap: () => _confirmDelete(context, c),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline,
                      size: 16, color: Color(0xFFDC2626)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, TreatmentComponent component) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDesignTokens.backgroundSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge)),
        title: const Text('Remove Product',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppDesignTokens.primaryText)),
        content: Text(
          'Remove "${component.productName}" from ${widget.treatment.code}?',
          style: const TextStyle(
              fontSize: 14, color: AppDesignTokens.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppDesignTokens.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final repo = ref.read(treatmentRepositoryProvider);
    await repo.deleteComponent(component.id);
    await _loadComponents();
  }

  Future<void> _showAddComponentDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => _AddComponentDialog(
        trial: widget.trial,
        treatment: widget.treatment,
        ref: ref,
        onSaved: _loadComponents,
      ),
    );
  }
}
