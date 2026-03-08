import 'dart:async';

import 'package:flutter/material.dart';
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
import '../plots/import_plots_screen.dart';
import '../plots/plot_detail_screen.dart';
import '../protocol_import/protocol_import_screen.dart';
import 'plot_layout_model.dart';
import '../../core/providers.dart';
import '../../data/repositories/treatment_repository.dart';

/// Key for persisting that the trial module hub one-time scroll hint was seen or dismissed.
const String _kTrialHubHintDismissedKey = 'trial_module_hub_hint_dismissed';

enum _LayoutLayer { treatments, applications, ratings }

class TrialDetailScreen extends ConsumerStatefulWidget {
  final Trial trial;

  const TrialDetailScreen({super.key, required this.trial});

  @override
  ConsumerState<TrialDetailScreen> createState() => _TrialDetailScreenState();
}

class _TrialDetailScreenState extends ConsumerState<TrialDetailScreen> {
  int _selectedTabIndex = 0;
  int _previousTabIndex = 0;
  static const int _sessionsIndex = 5;

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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(currentTrial.name,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (currentTrial.crop != null)
              Text(currentTrial.crop!,
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildTrialStatusBar(context, ref, currentTrial),
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
          if (_selectedTabIndex != _sessionsIndex)
            _buildSessionsBar(context, ref.watch(sessionsForTrialProvider(widget.trial.id))),
          Expanded(
            child: IndexedStack(
              index: _selectedTabIndex,
              children: [
                _PlotsTab(trial: currentTrial),
                _SeedingTab(trial: currentTrial),
                _ApplicationsTab(trial: currentTrial),
                _AssessmentsTab(trial: currentTrial),
                _TreatmentsTab(trial: currentTrial),
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

  Widget _buildTrialStatusBar(BuildContext context, WidgetRef ref, Trial trial) {
    final nextStatuses = allowedNextTrialStatuses(trial.status);
    final label = labelForTrialStatus(trial.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Text('Status:',
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(width: 8),
          Chip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 12),
          ...nextStatuses.map((next) {
            final nextLabel = labelForTrialStatus(next);
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilledButton.tonal(
                onPressed: () => _transitionTrialStatus(context, ref, next),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(
                  next == kTrialStatusReady
                      ? 'Mark Ready'
                      : next == kTrialStatusActive
                          ? 'Activate'
                          : next == kTrialStatusClosed
                              ? 'Close'
                              : next == kTrialStatusArchived
                                  ? 'Archive'
                                  : nextLabel,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _transitionTrialStatus(
      BuildContext context, WidgetRef ref, String newStatus) async {
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

  Widget _buildSessionsBar(
      BuildContext context, AsyncValue<List<Session>> sessionsAsync) {
    final scheme = Theme.of(context).colorScheme;
    final surfaceTint = scheme.primary.withValues(alpha: 0.08);
    final subtitle = sessionsAsync.when(
      loading: () => 'Start or continue a session',
      error: (_, __) => 'Start or continue a session',
      data: (sessions) => _sessionsBarSubtitle(sessions),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: surfaceTint,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: () => setState(() {
            _previousTabIndex = _selectedTabIndex;
            _selectedTabIndex = _sessionsIndex;
          }),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sessions',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSurfaceVariant,
                  size: 22,
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
    ];

    final listView = ListView.separated(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 14, right: 48),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
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
      padding: const EdgeInsets.only(top: 8, bottom: 6),
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
    final scheme = Theme.of(context).colorScheme;
    final activeColor = scheme.primary;
    final inactiveColor = scheme.primary.withValues(alpha: 0.55);

    return AnimatedScale(
      scale: selected ? 1.18 : 0.92,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primaryContainer
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: selected ? activeColor : inactiveColor,
                  size: selected ? 24 : 20,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? activeColor : inactiveColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: selected ? 13 : 12,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 2,
                width: selected ? 22 : 0,
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(2),
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
  bool _showLayoutView = false;
  _LayoutLayer _layoutLayer = _LayoutLayer.treatments;
  ApplicationEvent? _selectedAppEvent;
  List<ApplicationPlotRecord> _appPlotRecords = [];
  bool _loadingAppRecords = false;

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
    return plotsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (plots) => plots.isEmpty
          ? _buildEmptyPlots(context, ref)
          : _buildPlotsContent(context, ref, plots),
    );
  }

  Widget _buildPlotsContent(
      BuildContext context, WidgetRef ref, List<Plot> plots) {
    final treatments = ref.watch(treatmentsForTrialProvider(widget.trial.id)).value ?? [];
    final layoutDiag = computePlotLayoutDiagnostics(
      plots,
      (p) => getDisplayPlotNumber(p, plots),
      (p) => getDisplayPlotLabel(p, plots),
    );
    return Column(
      children: [
        _buildPlotsHeader(context, ref, plots),
        if (layoutDiag.hasIssues) _buildLayoutDiagnosticsBanner(context, layoutDiag),
        _buildListLayoutToggle(context),
        if (_showLayoutView) ...[
          _buildLayerSwitcher(context),
          if (_layoutLayer == _LayoutLayer.applications)
            _buildAppEventSelector(context, ref),
          Expanded(
            child: _layoutLayer == _LayoutLayer.ratings
                ? const Center(child: Text('Ratings overlay coming soon', style: TextStyle(color: Colors.grey)))
                : SingleChildScrollView(
                    child: _PlotLayoutGrid(
                      plots: plots,
                      treatments: treatments,
                      trial: widget.trial,
                      layer: _layoutLayer,
                      appPlotRecords: _appPlotRecords,
                      onLongPressPlot: isProtocolLocked(widget.trial.status)
                          ? null
                          : (plot) => _showAssignTreatmentDialog(context, ref, plot, plots),
                    ),
                  ),
          ),
        ] else
          Expanded(child: _buildPlotsListBody(context, ref, plots)),
      ],
    );
  }

  Widget _buildLayerSwitcher(BuildContext context) {
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

  Widget _buildAppEventSelector(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(applicationsForTrialProvider(widget.trial.id));
    return eventsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (events) {
        if (events.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('No application events recorded yet', style: TextStyle(color: Colors.grey, fontSize: 13)),
          );
        }
        final completed = events.where((e) => e.status == 'completed').toList();
        if (completed.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('No completed application events yet', style: TextStyle(color: Colors.grey, fontSize: 13)),
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
            initialValue: _selectedAppEvent,
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
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListLayoutToggle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    );
  }

  Widget _buildEmptyPlots(BuildContext context, WidgetRef ref) {
    final locked = isProtocolLocked(widget.trial.status);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.grid_on,
              size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          const Text('No Plots Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            locked
                ? 'Protocol is locked. Change trial status to edit structure.'
                : 'Import plots via CSV to get started',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: locked
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ImportPlotsScreen(trial: widget.trial))),
            icon: const Icon(Icons.upload_file),
            label: const Text('Import Plots from CSV'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: locked
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ProtocolImportScreen(trial: widget.trial))),
            icon: const Icon(Icons.folder_special),
            label: const Text('Import Protocol (Treatments + Plots)'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: locked ? null : () => _seedTestPlots(context, ref),
            icon: const Icon(Icons.science),
            label: const Text('Add 10 Test Plots'),
          ),
        ],
      ),
    );
  }

  Future<void> _seedTestPlots(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    for (int i = 1; i <= 10; i++) {
      await db.into(db.plots).insert(
            PlotsCompanion.insert(
              trialId: widget.trial.id,
              plotId: i.toString().padLeft(3, '0'),
              plotSortIndex: drift.Value(i),
              rep: drift.Value((i / 3).ceil()),
            ),
          );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('10 test plots added'), backgroundColor: Colors.green));
    }
  }



  Future<void> _showBulkAssignDialog(
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

    // Map of plotPk -> selected treatmentId
    final Map<int, int?> assignments = {
      for (final p in plots) p.id: p.treatmentId,
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
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
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

  Future<void> _showAssignTreatmentDialog(
      BuildContext context, WidgetRef ref, Plot plot, List<Plot> plots) async {
    final treatments =
        ref.read(treatmentsForTrialProvider(widget.trial.id)).value ?? [];

    if (treatments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No treatments defined yet. Add treatments first.')),
      );
      return;
    }

    int? selectedId = plot.treatmentId;
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
                  trial: widget.trial,
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

  Widget _buildLayoutDiagnosticsBanner(
      BuildContext context, PlotLayoutDiagnostics diag) {
    final messages = <String>[];
    if (diag.noRep.isNotEmpty) {
      messages.add('${diag.noRep.length} plot(s) without rep');
    }
    if (diag.duplicatePositionInRep.isNotEmpty) {
      messages.add('Duplicate position in rep');
    }
    if (diag.unassignedPlotLabels.isNotEmpty) {
      messages.add('${diag.unassignedPlotLabels.length} unassigned');
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              messages.join(' · '),
              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlotsHeader(
      BuildContext context, WidgetRef ref, List<Plot> plots) {
    final locked = isProtocolLocked(widget.trial.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Icon(Icons.grid_on, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text('${plots.length} plots',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary)),
          const Spacer(),
          if (!locked)
            TextButton.icon(
              onPressed: () => _showBulkAssignDialog(context, ref, plots),
              icon: Icon(Icons.assignment,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary),
              label: Text('Bulk Assign',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 13)),
            )
          else
            Tooltip(
              message: 'Protocol is locked. Assignments cannot be changed.',
              child: Text('Locked',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }

  Widget _buildPlotsListBody(
      BuildContext context, WidgetRef ref, List<Plot> plots) {
    final treatments = ref.watch(treatmentsForTrialProvider(widget.trial.id)).value ?? [];
    final treatmentMap = {for (final t in treatments) t.id: t};
    return ListView.builder(
      itemCount: plots.length,
      itemBuilder: (context, index) {
        final plot = plots[index];
        final displayNum = getDisplayPlotLabel(plot, plots);
        final treatmentLabel = getTreatmentDisplayLabel(plot, treatmentMap);
        final sourceLabel = getAssignmentSourceLabel(
            treatmentId: plot.treatmentId, assignmentSource: plot.assignmentSource);
        return ListTile(
          dense: true,
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              displayNum,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white),
            ),
          ),
          title: Text('Plot $displayNum',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Row(
            children: [
              Expanded(
                child: Text(
                  treatmentLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: plot.treatmentId != null
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade700,
                    fontWeight: plot.treatmentId != null ? FontWeight.w600 : null,
                  ),
                ),
              ),
              if (sourceLabel != 'Unknown' && sourceLabel != 'Unassigned')
                Text(
                  sourceLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      PlotDetailScreen(trial: widget.trial, plot: plot))),
          onLongPress: () {
            if (isProtocolLocked(widget.trial.status)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Protocol is locked. Assignments cannot be changed.')),
              );
              return;
            }
            _showAssignTreatmentDialog(context, ref, plot, plots);
          },
        );
      },
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
  final void Function(Plot plot)? onLongPressPlot;

  const _PlotLayoutGrid({
    required this.plots,
    required this.treatments,
    required this.trial,
    required this.layer,
    required this.appPlotRecords,
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
      final record = appPlotRecords.where((r) => r.plotPk == plot.id).firstOrNull;
      if (record == null) {
        return Colors.grey.shade300;
      }
      if (record.status == 'applied') {
        return Colors.green.shade600;
      }
      if (record.status == 'skipped') {
        return Colors.orange.shade600;
      }
      if (record.status == 'missed') {
        return Colors.red.shade600;
      }
      return Colors.grey.shade300;
    }
    if (plot.treatmentId == null) {
      return Colors.grey.shade400;
    }
    final treatmentIndex = treatments.indexWhere((t) => t.id == plot.treatmentId);
    final colors = [
      const Color(0xFF2D5A40),
      Colors.blue.shade700,
      Colors.orange.shade700,
      Colors.purple.shade700,
      Colors.red.shade700,
      Colors.teal.shade700,
    ];
    return treatmentIndex >= 0
        ? colors[treatmentIndex % colors.length]
        : Colors.grey.shade400;
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
                  children: [
                    _legendChip(Colors.green.shade600, 'Applied'),
                    _legendChip(Colors.orange.shade600, 'Skipped'),
                    _legendChip(Colors.red.shade600, 'Missed'),
                    _legendChip(Colors.grey.shade300, 'No record'),
                  ],
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    ...treatments.asMap().entries.map((entry) {
                      final colors = [
                        const Color(0xFF2D5A40),
                        Colors.blue.shade700,
                        Colors.orange.shade700,
                        Colors.purple.shade700,
                        Colors.red.shade700,
                        Colors.teal.shade700,
                      ];
                      final color = colors[entry.key % colors.length];
                      return _legendChip(color, '${entry.value.code} ${entry.value.name}');
                    }),
                    _legendChip(Colors.grey.shade400, 'Unassigned'),
                  ],
                ),
        ),
      ],
    );
  }

  static const double _repLabelWidth = 52.0;
  static const double _tileSpacing = 6.0;
  static const double _minTileSize = 40.0;
  static const double _tileHeight = 48.0;

  Widget _buildRepBasedGrid(BuildContext context, Map<int, Treatment> treatmentMap) {
    final blocks = buildRepBasedLayout(plots);
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth - 24; // horizontal padding
        final plotRowWidth = contentWidth - _repLabelWidth - _tileSpacing;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (blocks.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Field Layout — Rep-based',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
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
                  final n = repRow.plots.length;
                  final tileWidth = n > 0
                      ? (plotRowWidth - (n - 1) * _tileSpacing) / n
                      : 0.0;
                  final size = tileWidth.clamp(_minTileSize, double.infinity);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: _tileSpacing),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: _repLabelWidth,
                          child: Text(
                            'Rep ${repRow.repNumber}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: _tileSpacing),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (var i = 0; i < repRow.plots.length; i++) ...[
                                  if (i > 0) const SizedBox(width: _tileSpacing),
                                  SizedBox(
                                    width: size,
                                    height: _tileHeight,
                                  child: _PlotGridTile(
                                    plot: repRow.plots[i],
                                    treatmentMap: treatmentMap,
                                    treatments: treatments,
                                    trial: trial,
                                    tileColor: _tileColorFor(repRow.plots[i]),
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
                      ],
                    ),
                  );
                });
                return [...blockHeader, ...repRows];
              }),
            ],
          ),
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
  final String? displayLabel;
  final VoidCallback? onLongPress;

  const _PlotGridTile({
    required this.plot,
    required this.treatmentMap,
    required this.treatments,
    required this.trial,
    required this.tileColor,
    this.displayLabel,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final treatment = plot.treatmentId != null ? treatmentMap[plot.treatmentId] : null;
    final label = displayLabel ?? plot.plotId;
    return Material(
      color: tileColor,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onLongPress: onLongPress,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlotDetailScreen(trial: trial, plot: plot),
          ),
        ),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
              Text(
                treatment != null ? treatment.code : 'Unassigned',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 10,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssessmentsTab extends ConsumerWidget {
  final Trial trial;

  const _AssessmentsTab({required this.trial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessmentsAsync = ref.watch(assessmentsForTrialProvider(trial.id));

    return assessmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (assessments) => assessments.isEmpty
          ? _buildEmptyAssessments(context, ref)
          : _buildAssessmentsList(context, ref, assessments),
    );
  }

  Widget _buildEmptyAssessments(BuildContext context, WidgetRef ref) {
    final locked = isProtocolLocked(trial.status);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assessment,
              size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          const Text('No Assessments Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            locked
                ? 'Protocol is locked. Change trial status to edit structure.'
                : 'Add assessments to define what to measure.',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: locked ? null : () => _showAddAssessmentDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add Assessment'),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentsList(
      BuildContext context, WidgetRef ref, List<Assessment> assessments) {
    final locked = isProtocolLocked(trial.status);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            children: [
              Icon(Icons.assessment,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('${assessments.length} assessments',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary)),
              const Spacer(),
              TextButton.icon(
                onPressed: locked ? null : () => _showAddAssessmentDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: assessments.length,
            itemBuilder: (context, index) {
              final assessment = assessments[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(Icons.analytics,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                ),
                title: Text(assessment.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '${assessment.dataType}${assessment.unit != null ? " (${assessment.unit})" : ""}'),
                trailing: assessment.isActive
                    ? const Icon(Icons.check_circle,
                        color: Colors.green, size: 20)
                    : const Icon(Icons.pause_circle,
                        color: Colors.grey, size: 20),
              );
            },
          ),
        ),
      ],
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
      builder: (context) => AlertDialog(
        title: const Text('Add Assessment'),
        content: SingleChildScrollView(
          child: Column(
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
              const SizedBox(height: 12),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(
                  labelText: 'Unit (e.g. %, cm, score)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
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
// SEEDING TAB (placeholder)
// ─────────────────────────────────────────────

class _SeedingTab extends ConsumerWidget {
  final Trial trial;

  const _SeedingTab({required this.trial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return FutureBuilder(
      future: (db.select(db.seedingRecords)
            ..where((t) => t.trialId.equals(trial.id))
            ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
          .get(),
      builder: (context, AsyncSnapshot<List> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data!;

        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.agriculture,
                    size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                const Text(
                  'No Seeding Records Yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Record the seeding operation for this trial',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Seeding Event'),
                  onPressed: () => _addSeeding(context, ref),
                )
              ],
            ),
          );
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  Icon(Icons.agriculture,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '${records.length} seeding events',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addSeeding(context, ref),
                  )
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: records.length,
                itemBuilder: (context, i) {
                  final r = records[i];
                  final dateText =
                      r.seedingDate.toLocal().toString().split(' ')[0];
                  final operatorText = (r.operatorName != null &&
                          r.operatorName!.trim().isNotEmpty)
                      ? 'Operator: ${r.operatorName}'
                      : 'Operator not entered';
                  final commentsText =
                      (r.comments != null && r.comments!.trim().isNotEmpty)
                          ? r.comments!.trim()
                          : null;

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                    child: ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _SeedingDetailScreen(record: r),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.agriculture,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        'Seeding $dateText',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 4),
                          Text(operatorText),
                          if (commentsText != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              commentsText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addSeeding(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final operatorController = TextEditingController();
    final commentsController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final dateLabel =
                '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

            return AlertDialog(
              title: const Text('Add Seeding Event'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Core fields',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text('Seeding Date: $dateLabel'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: operatorController,
                      decoration: const InputDecoration(
                        labelText: 'Operator Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: commentsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Comments',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Protocol-driven fields will appear here next.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
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
                  onPressed: () async {
                    await db.into(db.seedingRecords).insert(
                          SeedingRecordsCompanion.insert(
                            trialId: trial.id,
                            seedingDate: selectedDate,
                            operatorName: drift.Value(
                              operatorController.text.trim().isEmpty
                                  ? null
                                  : operatorController.text.trim(),
                            ),
                            comments: drift.Value(
                              commentsController.text.trim().isEmpty
                                  ? null
                                  : commentsController.text.trim(),
                            ),
                          ),
                        );

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seeding record added')),
      );
    }
  }
}

// ─────────────────────────────────────────────
// APPLICATIONS TAB (placeholder)
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

    return treatmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (treatments) => treatments.isEmpty
          ? _buildEmpty(context, ref)
          : _buildList(context, ref, treatments),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science_outlined,
              size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          const Text('No Treatments Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Add the treatment groups for this trial.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddTreatmentDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add Treatment'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, List<Treatment> treatments) {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
          itemCount: treatments.length,
          itemBuilder: (context, index) {
            final t = treatments[index];
            return Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(t.code,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white)),
                ),
                title: Text(t.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: t.description != null ? Text(t.description!) : null,
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => _showTreatmentComponents(context, ref, t),
              ),
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'add_treatment',
            onPressed: () => _showAddTreatmentDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add Treatment'),
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

  Future<void> _showAddTreatmentDialog(
      BuildContext context, WidgetRef ref) async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final descController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Treatment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Code (e.g. T1, T2)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
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
// SESSIONS VIEW (navigated from bottom bar)
// ─────────────────────────────────────────────

class _SessionListEntry {
  final bool isHeader;
  final String? date;
  final Session? session;
  const _SessionListEntry({required this.isHeader, this.date, this.session});
}

class SessionsView extends ConsumerWidget {
  final Trial trial;
  final VoidCallback? onBack;

  const SessionsView({super.key, required this.trial, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsForTrialProvider(trial.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F2),
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
              IconButton(
                icon: const Icon(Icons.download_for_offline),
                tooltip: 'Export all closed sessions',
                onPressed: () async {
                  final useCase =
                      ref.read(exportTrialClosedSessionsUsecaseProvider);
                  final user = await ref.read(currentUserProvider.future);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Exporting...')));
                  final result = await useCase.execute(
                    trialId: trial.id,
                    trialName: trial.name,
                    exportedByDisplayName: user?.displayName,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).clearSnackBars();
                  if (result.success) {
                    await Share.shareXFiles(
                      [XFile(result.filePath!)],
                      text:
                          '${trial.name} – ${result.sessionCount} closed sessions',
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
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: sessionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (sessions) => sessions.isEmpty
                  ? _buildEmptySessions(context)
                  : _buildSessionsList(context, ref, sessions),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySessions(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open,
              size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          const Text('No Sessions Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Start a session to begin collecting field data.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CreateSessionScreen(trial: trial))),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Session'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList(
      BuildContext context, WidgetRef ref, List<Session> sessions) {
    final groups = <String, List<Session>>{};
    for (final session in sessions) {
      groups.putIfAbsent(session.sessionDateLocal, () => []).add(session);
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            _formatDateHeader(date),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionListTile(
      BuildContext context, WidgetRef ref, Session session) {
    final isOpen = session.endedAt == null;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
        leading: CircleAvatar(
          backgroundColor:
              isOpen ? Colors.green.shade100 : Colors.grey.shade100,
          child: Icon(
            isOpen ? Icons.play_circle : Icons.check_circle,
            color: isOpen ? Colors.green : Colors.grey,
          ),
        ),
        title: Text(
            _shortSessionName(session.name, session.sessionDateLocal),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        subtitle: Text(_formatSessionTimes(session)),
        trailing: isOpen
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Open',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              )
            : const Text('Closed',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
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
      final parts = dateStr.split('-');
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
      final day = int.parse(parts[2]);
      final month = months[int.parse(parts[1])];
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(applicationsForTrialProvider(trial.id));
    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (events) => events.isEmpty
          ? _buildEmpty(context, ref)
          : _buildList(context, ref, events),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          const Text('No Application Events Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Record spray, granular and other application events',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddEventDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add Application Event'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<ApplicationEvent> events) {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final e = events[index];
            final dateStr =
                '${e.applicationDate.year}-${e.applicationDate.month.toString().padLeft(2, '0')}-${e.applicationDate.day.toString().padLeft(2, '0')}';
            final isCompleted = e.status == 'completed';
            return Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    border: isCompleted
                        ? null
                        : Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('A${e.applicationNumber}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isCompleted
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary)),
                ),
                title: Row(children: [
                  Expanded(
                    child: Text(
                      e.timingLabel ?? '${_methodLabel(e.method)} — $dateStr',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Builder(builder: (ctx2) {
                    final isPartial = e.partialFlag;
                    final bgColor = isCompleted
                        ? (isPartial ? Colors.amber.shade100 : Colors.green.shade100)
                        : Colors.orange.shade50;
                    final fgColor = isCompleted
                        ? (isPartial ? Colors.amber.shade800 : Colors.green.shade700)
                        : Colors.orange.shade700;
                    final icn = isCompleted
                        ? (isPartial ? Icons.warning_amber_rounded : Icons.check_circle)
                        : Icons.schedule;
                    final lbl = isCompleted
                        ? (isPartial ? 'Partial' : 'Completed')
                        : 'Planned';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icn, size: 11, color: fgColor),
                          const SizedBox(width: 3),
                          Text(
                            lbl,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: fgColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ]),
                subtitle: Text([
                  _methodLabel(e.method),
                  if (e.growthStage != null) e.growthStage!,
                  if (e.operatorName != null) e.operatorName!,
                  if (e.partialFlag) 'Partial',
                ].whereType<String>().join('  ·  ')),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => _showEventDetail(context, e),
              ),
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'add_application',
            onPressed: () => _showAddEventDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add Event'),
          ),
        ),
      ],
    );
  }

  /// Completion (and future "Mark as Planned" reversal) must produce audit
  /// records when the audit layer is built. See docs/AUDIT_APPLICATION_EVENTS.md.
  Future<void> _showMarkCompletedDialog(
      BuildContext context, ApplicationEvent e) async {
    final repo = ProviderScope.containerOf(context)
        .read(applicationRepositoryProvider);
    final operatorController = TextEditingController(
        text: e.operatorName ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Completed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              e.timingLabel ?? 'Application ${e.applicationNumber}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: operatorController,
              decoration: const InputDecoration(
                labelText: 'Completed by (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Did this application cover the entire trial?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'If only some plots were sprayed, choose No and create a second event for the remaining plots.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () async {
              await repo.markCompleted(
                eventId: e.id,
                trialId: e.trialId,
                completedBy: operatorController.text.trim(),
                coversEntireTrial: false,
                specificPlotPks: [],
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('No — Partial'),
          ),
          FilledButton(
            onPressed: () async {
              await repo.markCompleted(
                eventId: e.id,
                trialId: e.trialId,
                completedBy: operatorController.text.trim(),
                coversEntireTrial: true,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Yes — Full Trial'),
          ),
        ],
      ),
    );
  }

  /// Every edit save must produce an audit record (event_edited) when the
  /// audit layer is built. See docs/AUDIT_APPLICATION_EVENTS.md.
  Future<void> _showEditEventDialog(
      BuildContext context, ApplicationEvent e) async {
    final repo = ProviderScope.containerOf(context)
        .read(applicationRepositoryProvider);
    final timingController =
        TextEditingController(text: e.timingLabel ?? '');
    final growthController =
        TextEditingController(text: e.growthStage ?? '');
    final operatorController =
        TextEditingController(text: e.operatorName ?? '');
    final equipmentController =
        TextEditingController(text: e.equipment ?? '');
    final weatherController =
        TextEditingController(text: e.weather ?? '');
    final notesController = TextEditingController(text: e.notes ?? '');
    DateTime selectedDate = e.applicationDate;
    String selectedMethod = e.method;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final d = selectedDate;
          final dateLabel =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          return AlertDialog(
            title: Text('Edit Application #${e.applicationNumber}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: timingController,
                    decoration: const InputDecoration(
                        labelText: 'Timing Label',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMethod,
                    decoration: const InputDecoration(
                        labelText: 'Application Method',
                        border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'spray', child: Text('Spray')),
                      DropdownMenuItem(value: 'granular', child: Text('Granular')),
                      DropdownMenuItem(value: 'seed_treatment', child: Text('Seed Treatment')),
                      DropdownMenuItem(value: 'soil_drench', child: Text('Soil Drench')),
                      DropdownMenuItem(value: 'fertigation', child: Text('Fertigation')),
                      DropdownMenuItem(value: 'in_furrow', child: Text('In-Furrow')),
                      DropdownMenuItem(value: 'broadcast', child: Text('Broadcast')),
                      DropdownMenuItem(value: 'banded', child: Text('Banded')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => selectedMethod = v!),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text('Date: $dateLabel'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: growthController,
                    decoration: const InputDecoration(
                        labelText: 'Growth Stage',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: operatorController,
                    decoration: const InputDecoration(
                        labelText: 'Operator',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: equipmentController,
                    decoration: const InputDecoration(
                        labelText: 'Equipment',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: weatherController,
                    decoration: const InputDecoration(
                        labelText: 'Weather Conditions',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final updated = e.copyWith(
                    timingLabel: drift.Value(timingController.text.trim().isEmpty
                        ? null
                        : timingController.text.trim()),
                    method: selectedMethod,
                    applicationDate: selectedDate,
                    growthStage: drift.Value(growthController.text.trim().isEmpty
                        ? null
                        : growthController.text.trim()),
                    operatorName: drift.Value(operatorController.text.trim().isEmpty
                        ? null
                        : operatorController.text.trim()),
                    equipment: drift.Value(equipmentController.text.trim().isEmpty
                        ? null
                        : equipmentController.text.trim()),
                    weather: drift.Value(weatherController.text.trim().isEmpty
                        ? null
                        : weatherController.text.trim()),
                    notes: drift.Value(notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim()),
                  );
                  await repo.updateEvent(updated);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEventDetail(BuildContext context, ApplicationEvent e) {
    final dateStr =
        '${e.applicationDate.year}-${e.applicationDate.month.toString().padLeft(2, '0')}-${e.applicationDate.day.toString().padLeft(2, '0')}';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('A${e.applicationNumber}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(e.timingLabel ?? 'Application ${e.applicationNumber}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ]),
            const Divider(height: 24),
            _detailRow(context, Icons.science, 'Method', _methodLabel(e.method)),
            _detailRow(context, Icons.calendar_today, 'Date', dateStr),
            if (e.growthStage != null)
              _detailRow(context, Icons.grass, 'Growth Stage', e.growthStage!),
            if (e.operatorName != null)
              _detailRow(context, Icons.person, 'Operator', e.operatorName!),
            if (e.equipment != null)
              _detailRow(context, Icons.precision_manufacturing, 'Equipment', e.equipment!),
            if (e.weather != null)
              _detailRow(context, Icons.cloud, 'Weather', e.weather!),
            if (e.notes != null)
              _detailRow(context, Icons.notes, 'Notes', e.notes!),
            const SizedBox(height: 16),
            if (e.status != 'completed' || e.partialFlag)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    _showMarkCompletedDialog(ctx, e);
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Mark Completed'),
                ),
              ),
            if (e.status != 'completed' || e.partialFlag) const SizedBox(height: 8),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showEditEventDialog(context, e);
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red)),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (d) => AlertDialog(
                          title: const Text('Delete Application Event?'),
                          content: const Text(
                              'This will permanently delete this event and all its plot records.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(d, false),
                                child: const Text('Cancel')),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(d, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && ctx.mounted) {
                        final repo = ProviderScope.containerOf(ctx)
                            .read(applicationRepositoryProvider);
                        await repo.deleteEvent(e.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _methodLabel(String method) {
    const labels = {
      'spray': 'Spray',
      'granular': 'Granular',
      'seed_treatment': 'Seed Treatment',
      'soil_drench': 'Soil Drench',
      'fertigation': 'Fertigation',
      'in_furrow': 'In-Furrow',
      'broadcast': 'Broadcast',
      'banded': 'Banded',
    };
    return labels[method] ?? method;
  }

  Future<void> _showAddEventDialog(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(applicationRepositoryProvider);
    final timingController = TextEditingController();
    final growthController = TextEditingController();
    final operatorController = TextEditingController();
    final equipmentController = TextEditingController();
    final weatherController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedMethod = 'spray';

    final nextNumber = await repo.getNextApplicationNumber(trial.id);
    timingController.text = 'Application $nextNumber';

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final d = selectedDate;
          final dateLabel = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          return AlertDialog(
            title: Text('Add Application Event #$nextNumber'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: timingController,
                    decoration: const InputDecoration(
                        labelText: 'Timing Label', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMethod,
                    decoration: const InputDecoration(
                        labelText: 'Application Method', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'spray', child: Text('Spray')),
                      DropdownMenuItem(value: 'granular', child: Text('Granular')),
                      DropdownMenuItem(value: 'seed_treatment', child: Text('Seed Treatment')),
                      DropdownMenuItem(value: 'soil_drench', child: Text('Soil Drench')),
                      DropdownMenuItem(value: 'fertigation', child: Text('Fertigation')),
                      DropdownMenuItem(value: 'in_furrow', child: Text('In-Furrow')),
                      DropdownMenuItem(value: 'broadcast', child: Text('Broadcast')),
                      DropdownMenuItem(value: 'banded', child: Text('Banded')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedMethod = v!),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setDialogState(() => selectedDate = picked);
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text('Date: $dateLabel'),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: growthController,
                      decoration: const InputDecoration(
                          labelText: 'Growth Stage (e.g. GS31)', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: operatorController,
                      decoration: const InputDecoration(
                          labelText: 'Operator', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: equipmentController,
                      decoration: const InputDecoration(
                          labelText: 'Equipment', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: weatherController,
                      decoration: const InputDecoration(
                          labelText: 'Weather Conditions', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Notes (optional)', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  await repo.insertEvent(
                    trialId: trial.id,
                    applicationNumber: nextNumber,
                    timingLabel: timingController.text.trim().isEmpty
                        ? null : timingController.text.trim(),
                    method: selectedMethod,
                    applicationDate: selectedDate,
                    growthStage: growthController.text.trim().isEmpty
                        ? null : growthController.text.trim(),
                    operatorName: operatorController.text.trim().isEmpty
                        ? null : operatorController.text.trim(),
                    equipment: equipmentController.text.trim().isEmpty
                        ? null : equipmentController.text.trim(),
                    weather: weatherController.text.trim().isEmpty
                        ? null : weatherController.text.trim(),
                    notes: notesController.text.trim().isEmpty
                        ? null : notesController.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TREATMENT COMPONENTS BOTTOM SHEET
// ─────────────────────────────────────────────

class _TreatmentComponentsSheet extends ConsumerWidget {
  final Trial trial;
  final Treatment treatment;

  const _TreatmentComponentsSheet({
    required this.trial,
    required this.treatment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(treatmentRepositoryProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(treatment.code,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(treatment.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  FilledButton.icon(
                    onPressed: () =>
                        _showAddComponentDialog(context, ref, repo),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Components list
            Expanded(
              child: FutureBuilder<List<TreatmentComponent>>(
                future: repo.getComponentsForTreatment(treatment.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final components = snapshot.data!;
                  if (components.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.science_outlined,
                              size: 48,
                              color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text('No components yet',
                              style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 8),
                          const Text(
                              'Add products, rates and timing',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: components.length,
                    itemBuilder: (context, i) {
                      final c = components[i];
                      final ratePart = (c.rate != null && c.rateUnit != null)
                          ? '${c.rate} ${c.rateUnit}'
                          : null;
                      final timingPart = c.applicationTiming;
                      final subtitle = [
                        if (ratePart != null) ratePart,
                        if (timingPart != null) timingPart,
                      ].join('  ·  ');
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary)),
                          ),
                          title: Text(c.productName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle:
                              subtitle.isNotEmpty ? Text(subtitle) : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddComponentDialog(
      BuildContext context, WidgetRef ref, TreatmentRepository repo) async {
    final productController = TextEditingController();
    final rateController = TextEditingController();
    final rateUnitController = TextEditingController();
    final timingController = TextEditingController();
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Component to ${treatment.code}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: productController,
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (productController.text.trim().isEmpty) return;
              await repo.insertComponent(
                treatmentId: treatment.id,
                trialId: trial.id,
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
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
