import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/widgets/gradient_screen_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/edit_recency_display.dart';
import '../../core/plot_display.dart';
import '../../core/export_guard.dart';
import '../../core/providers.dart';
import '../../core/session_resume_store.dart';
import '../ratings/rating_screen.dart';
import '../ratings/rating_scale_map.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/plot_sort.dart';
import '../../core/session_walk_order_store.dart';
import '../../data/repositories/weather_snapshot_repository.dart';
import '../sessions/arrange_plots_screen.dart';
import '../sessions/session_export_trust_dialog.dart';
import '../weather/weather_capture_form.dart';

typedef _PlotQueueOpenRating = Future<void> Function(
  Plot plot,
  List<Plot> walkPlots,
  List<Assessment> assessments,
  List<int>? filteredPlotIds,
  bool isFilteredMode,
  String? navigationModeLabel,
);

/// Optional one-time seed for plot queue filters (e.g. deep link from Session Summary).
class PlotQueueInitialFilters {
  final bool flaggedOnly;
  final bool issuesOnly;
  final bool editedOnly;
  final bool unratedOnly;
  final int? rep;

  const PlotQueueInitialFilters({
    this.flaggedOnly = false,
    this.issuesOnly = false,
    this.editedOnly = false,
    this.unratedOnly = false,
    this.rep,
  });
}

class PlotQueueScreen extends ConsumerStatefulWidget {
  final Trial trial;
  final Session session;
  final PlotQueueInitialFilters? initialFilters;

  /// After open, scroll list to this plot PK (full queue, default filters only).
  final int? scrollToPlotPkOnOpen;

  const PlotQueueScreen({
    super.key,
    required this.trial,
    required this.session,
    this.initialFilters,
    this.scrollToPlotPkOnOpen,
  });

  @override
  ConsumerState<PlotQueueScreen> createState() => _PlotQueueScreenState();
}

class _PlotQueueScreenState extends ConsumerState<PlotQueueScreen> {
  int? _repFilter;
  bool _showUnratedOnly = false;
  bool _showIssuesOnly = false;
  bool _showEditedOnly = false;
  bool _showFlaggedOnly = false;
  WalkOrderMode _walkOrderMode = WalkOrderMode.serpentine;
  List<int>? _customPlotIds;
  final ScrollController _plotQueueScrollController = ScrollController();
  final Map<int, GlobalKey> _plotRowKeys = {};
  int? _highlightPlotPk;
  bool _consumedScrollToPlotOnOpen = false;

  GlobalKey _keyForPlotRow(int plotPk) =>
      _plotRowKeys.putIfAbsent(plotPk, GlobalKey.new);

  /// Plots in the rating walk; guard rows are excluded (see Plots tab for full list).
  List<Plot> _queuePlotsExcludingGuards(List<Plot> raw) =>
      raw.where((p) => !p.isGuardRow).toList();

  /// Same filter pipeline as [_buildQueue] (full walk order in, filtered out).
  List<Plot> _plotsAfterQueueFilters(
    List<Plot> plotsInWalkOrder,
    Set<int> ratedPks,
    Map<int, List<RatingRecord>> ratingsByPlot,
    Set<int> flaggedIds,
    Set<int> plotPksWithCorrections,
  ) {
    var filtered = plotsInWalkOrder;
    if (_repFilter != null) {
      filtered = filtered.where((p) => p.rep == _repFilter).toList();
    }
    if (_showUnratedOnly) {
      filtered = filtered.where((p) => !ratedPks.contains(p.id)).toList();
    }
    if (_showIssuesOnly) {
      filtered = filtered.where((p) {
        final pr = ratingsByPlot[p.id] ?? [];
        return pr.any((r) => r.resultStatus != 'RECORDED');
      }).toList();
    }
    if (_showEditedOnly) {
      filtered = filtered.where((p) {
        final pr = ratingsByPlot[p.id] ?? [];
        return pr.any((r) => r.amended || (r.previousId != null)) ||
            plotPksWithCorrections.contains(p.id);
      }).toList();
    }
    if (_showFlaggedOnly) {
      filtered = filtered.where((p) => flaggedIds.contains(p.id)).toList();
    }
    return filtered;
  }

  void _scheduleScrollToPlotPkOnOpen(List<Plot> filteredPlots) {
    final pk = widget.scrollToPlotPkOnOpen;
    if (pk == null || _consumedScrollToPlotOnOpen) return;
    if (!filteredPlots.any((p) => p.id == pk)) {
      _consumedScrollToPlotOnOpen = true;
      return;
    }
    _consumedScrollToPlotOnOpen = true;
    final entries = _flattenGroupedQueueItems(filteredPlots);
    const double headerH = 40;
    const double rowH = 88;
    double y = 0;
    var found = false;
    for (final item in entries) {
      if (item.isHeader) {
        y += headerH;
      } else if (item.plot!.id == pk) {
        found = true;
        break;
      } else {
        y += rowH;
      }
    }
    if (!found) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_plotQueueScrollController.hasClients) {
        final max = _plotQueueScrollController.position.maxScrollExtent;
        _plotQueueScrollController.jumpTo(y.clamp(0.0, max));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _plotRowKeys[pk]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            alignment: 0.14,
          );
        }
      });
    });
  }

  /// Maps [Assessment.id] to [AssessmentDefinition] scale via [TrialAssessment.legacyAssessmentId].
  Map<int, ({double? scaleMin, double? scaleMax})> _ratingScaleMap() {
    final trialAssessments = ref
            .read(trialAssessmentsForTrialProvider(widget.trial.id))
            .valueOrNull ??
        <TrialAssessment>[];
    final definitions = ref.read(assessmentDefinitionsProvider).valueOrNull ??
        <AssessmentDefinition>[];
    return buildRatingScaleMap(
      trialAssessments: trialAssessments,
      definitions: definitions,
      trialIdForLog: widget.trial.id,
    );
  }

  Future<void> _openRatingFromQueue(
    BuildContext context,
    Plot plot,
    List<Plot> walkPlots,
    List<Assessment> assessments,
    List<int>? filteredPlotIds,
    bool isFilteredMode,
    String? navigationModeLabel,
  ) async {
    final idx = walkPlots.indexWhere((p) => p.id == plot.id);
    final currentPlotIndex = idx < 0 ? 0 : idx;
    int? initialAssessmentIndex;
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    final pos = SessionResumeStore(prefs).getPosition(widget.session.id);
    if (pos != null && pos.isForPlot(plot.id, currentPlotIndex)) {
      initialAssessmentIndex = pos.clampedAssessmentIndex(assessments.length);
    }
    if (!context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RatingScreen(
          trial: widget.trial,
          session: widget.session,
          plot: plot,
          assessments: assessments,
          allPlots: walkPlots,
          currentPlotIndex: currentPlotIndex,
          initialAssessmentIndex: initialAssessmentIndex,
          filteredPlotIds: filteredPlotIds,
          isFilteredMode: isFilteredMode,
          navigationModeLabel: navigationModeLabel,
          scaleMap: _ratingScaleMap(),
        ),
      ),
    );
    if (!mounted) return;
    _afterReturnFromRating(plot, walkPlots);
  }

  void _afterReturnFromRating(Plot openedPlot, List<Plot> walkPlots) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      // Allow rating stream to emit after save before choosing "next unrated".
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      final rated =
          ref.read(ratedPlotPksProvider(widget.session.id)).valueOrNull ??
              <int>{};
      final raw =
          ref.read(plotsForTrialProvider(widget.trial.id)).valueOrNull ?? [];
      final queuePlots = _queuePlotsExcludingGuards(raw);
      if (raw.isEmpty || queuePlots.isEmpty || walkPlots.isEmpty) return;
      final walk = sortPlotsByWalkOrder(
        queuePlots,
        _walkOrderMode,
        customPlotIds: _customPlotIds,
      );
      final startIdx = walk.indexWhere((p) => p.id == openedPlot.id);
      if (startIdx < 0) return;
      Plot? nextUnrated;
      for (var j = startIdx + 1; j < walk.length; j++) {
        if (!rated.contains(walk[j].id)) {
          nextUnrated = walk[j];
          break;
        }
      }
      final nextUnratedPlot = nextUnrated;
      if (nextUnratedPlot == null) return;

      final ratings =
          ref.read(sessionRatingsProvider(widget.session.id)).valueOrNull ?? [];
      final ratingsByPlot = <int, List<RatingRecord>>{};
      for (final r in ratings) {
        ratingsByPlot.putIfAbsent(r.plotPk, () => []).add(r);
      }
      final flagged = ref
              .read(flaggedPlotIdsForSessionProvider(widget.session.id))
              .valueOrNull ??
          <int>{};
      final plotPksWithCorrections = ref
              .read(plotPksWithCorrectionsForSessionProvider(widget.session.id))
              .valueOrNull ??
          <int>{};
      final filtered = _plotsAfterQueueFilters(
        walk,
        rated,
        ratingsByPlot,
        flagged,
        plotPksWithCorrections,
      );
      if (!filtered.any((p) => p.id == nextUnratedPlot.id)) return;

      final targetPk = nextUnratedPlot.id;
      setState(() => _highlightPlotPk = targetPk);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _plotRowKeys[targetPk]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.12,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOut,
          );
        }
      });
      Future<void>.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          setState(() {
            if (_highlightPlotPk == targetPk) _highlightPlotPk = null;
          });
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    final f = widget.initialFilters;
    if (f != null) {
      _showFlaggedOnly = f.flaggedOnly;
      _showIssuesOnly = f.issuesOnly;
      _showEditedOnly = f.editedOnly;
      _showUnratedOnly = f.unratedOnly;
      _repFilter = f.rep;
    }
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWalkOrder());
  }

  Future<void> _loadWalkOrder() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final store = SessionWalkOrderStore(prefs);
    final mode = store.getMode(widget.session.id);
    final customIds = mode == WalkOrderMode.custom
        ? store.getCustomOrder(widget.session.id)
        : null;
    setState(() {
      _walkOrderMode = mode;
      _customPlotIds = customIds;
    });
  }

  Future<void> _showWalkOrderSheet(BuildContext context) async {
    final mode = await showModalBottomSheet<WalkOrderMode>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Walk order',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              for (final m in WalkOrderMode.values)
                ListTile(
                  title: Text(SessionWalkOrderStore.labelForMode(m)),
                  selected: _walkOrderMode == m,
                  onTap: () => Navigator.pop(ctx, m),
                ),
            ],
          ),
        ),
      ),
    );
    if (mode == null || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await SessionWalkOrderStore(prefs).setMode(widget.session.id, mode);
    if (!mounted) return;
    setState(() => _walkOrderMode = mode);
    if (mode == WalkOrderMode.custom) {
      _loadWalkOrder();
      if (context.mounted) {
        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ArrangePlotsScreen(
              trial: widget.trial,
              session: widget.session,
            ),
          ),
        );
        if (saved == true && mounted) await _loadWalkOrder();
      }
    }
  }

  @override
  void dispose() {
    _plotQueueScrollController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plotsAsync = ref.watch(plotsForTrialProvider(widget.trial.id));
    final sessionAssessmentsAsync =
        ref.watch(sessionAssessmentsProvider(widget.session.id));
    final ratedPlotsAsync = ref.watch(ratedPlotPksProvider(widget.session.id));
    final ratingsAsync = ref.watch(sessionRatingsProvider(widget.session.id));
    final treatments =
        ref.watch(treatmentsForTrialProvider(widget.trial.id)).value ?? [];
    final treatmentById = {for (final t in treatments) t.id: t};
    final assignments =
        ref.watch(assignmentsForTrialProvider(widget.trial.id)).value ?? [];
    final plotIdToTreatmentId = {
      for (var a in assignments) a.plotId: a.treatmentId
    };
    final plotPksWithCorrections = ref
            .watch(plotPksWithCorrectionsForSessionProvider(widget.session.id))
            .valueOrNull ??
        <int>{};
    final weatherRecorded =
        ref.watch(weatherSnapshotForSessionProvider(widget.session.id))
                .valueOrNull !=
            null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EB),
      appBar: GradientScreenHeader(
        title: widget.trial.name,
        subtitle:
            '${widget.session.name} · Walk order: ${SessionWalkOrderStore.labelForMode(_walkOrderMode)}',
        titleFontSize: 17,
        actions: [
          IconButton(
            icon: Icon(
              weatherRecorded ? Icons.wb_cloudy : Icons.wb_cloudy_outlined,
              color: AppDesignTokens.onPrimary,
            ),
            tooltip: 'Weather',
            onPressed: () async {
              final repo = ref.read(weatherSnapshotRepositoryProvider);
              final snap = await repo.getWeatherSnapshotForParent(
                kWeatherParentTypeRatingSession,
                widget.session.id,
              );
              if (!context.mounted) return;
              await showWeatherCaptureBottomSheet(
                context,
                trial: widget.trial,
                session: widget.session,
                initialSnapshot: snap,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.directions_walk),
            tooltip: 'Change walk order',
            onPressed: () => _showWalkOrderSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Jump to plot',
            onPressed: () => _showJumpToPlotDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: plotsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (plots) => sessionAssessmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
          data: (assessments) => ratedPlotsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (ratedPks) => ratingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (ratings) {
                final flaggedIds = ref
                        .watch(
                            flaggedPlotIdsForSessionProvider(widget.session.id))
                        .valueOrNull ??
                    <int>{};
                final seedingEvent = ref
                    .watch(seedingEventForTrialProvider(widget.trial.id))
                    .valueOrNull;
                final int? dasDays =
                    (seedingEvent != null && seedingEvent.status == 'completed')
                        ? widget.session.startedAt
                            .difference(seedingEvent.seedingDate)
                            .inDays
                        : null;
                return _buildQueue(
                    context,
                    plots,
                    assessments,
                    ratedPks,
                    ratings,
                    treatmentById,
                    plotIdToTreatmentId,
                    flaggedIds,
                    plotPksWithCorrections,
                    dasDays: dasDays);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQueue(
    BuildContext context,
    List<Plot> rawPlots,
    List<Assessment> assessments,
    Set<int> ratedPks,
    List<RatingRecord> ratings,
    Map<int, Treatment> treatmentById,
    Map<int, int?> plotIdToTreatmentId,
    Set<int> flaggedIds,
    Set<int> plotPksWithCorrections, {
    int? dasDays,
  }) {
    final ratingsByPlot = <int, List<RatingRecord>>{};
    for (final r in ratings) {
      ratingsByPlot.putIfAbsent(r.plotPk, () => []).add(r);
    }

    final queuePlots = _queuePlotsExcludingGuards(rawPlots);
    // Apply session walk order (numeric, serpentine, or custom) for rating navigation
    final plots = sortPlotsByWalkOrder(
      queuePlots,
      _walkOrderMode,
      customPlotIds: _customPlotIds,
    );
    final filtered = _plotsAfterQueueFilters(
      plots,
      ratedPks,
      ratingsByPlot,
      flaggedIds,
      plotPksWithCorrections,
    );
    _scheduleScrollToPlotPkOnOpen(filtered);
    final filterNavActive = _anyPlotFiltersActive() && filtered.isNotEmpty;
    final filteredPlotIdsForRating =
        filterNavActive ? filtered.map((p) => p.id).toList() : null;
    final navigationModeLabelForRating =
        filterNavActive ? _singleNavigationModeLabel() : null;

    final totalPlots = plots.length;
    final ratedCount = ratedPks.length;
    final scheme = Theme.of(context).colorScheme;
    final hasFieldRow = plots.any((p) => p.fieldRow != null);
    const serpentineGreen = Color(0xFF2D5A40);
    final contextLine = dasDays != null
        ? 'Day $dasDays after seeding · $ratedCount / $totalPlots plots with a rating'
        : '$ratedCount / $totalPlots plots with a rating';

    return Column(
      children: [
        const _PlotQueueDockBar(),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDesignTokens.spacing16,
            0,
            AppDesignTokens.spacing16,
            AppDesignTokens.spacing4,
          ),
          child: Text(
            contextLine,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDesignTokens.spacing16,
            0,
            AppDesignTokens.spacing16,
            AppDesignTokens.spacing8,
          ),
          child: Text(
            'Save & Next Plot keeps you in walk order.',
            style: TextStyle(
              fontSize: 11,
              height: 1.3,
              fontStyle: FontStyle.italic,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
            ),
          ),
        ),
        // Section header (same as Trial Plots tab)
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.spacing16,
            vertical: AppDesignTokens.spacing8,
          ),
          color: scheme.primaryContainer,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.grid_on, color: scheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$ratedCount / $totalPlots with a rating',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.2,
                    color: scheme.primary,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasFieldRow)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: serpentineGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: serpentineGreen.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route, size: 11, color: serpentineGreen),
                          SizedBox(width: 4),
                          Text(
                            'Serpentine',
                            style: TextStyle(
                              color: serpentineGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (hasFieldRow && _anyPlotFiltersActive())
                    const SizedBox(width: 8),
                  if (_anyPlotFiltersActive())
                    Tooltip(
                      message: 'Clear all filters',
                      child: Material(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: _clearAllPlotFilters,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            child: Text(
                              'Filtered',
                              style: TextStyle(
                                color: scheme.onSecondaryContainer,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
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
        ),
        if (assessments.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDesignTokens.spacing16,
              AppDesignTokens.spacing4,
              AppDesignTokens.spacing8,
              AppDesignTokens.spacing8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assessments in this session',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.15,
                      ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 34,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    itemCount: assessments.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Chip(
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          label: Text(
                            assessments[index].name,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurface,
                            ),
                          ),
                          backgroundColor: scheme.surfaceContainerHighest,
                          side: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: 0.9),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_showEditedOnly)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDesignTokens.spacing16,
              AppDesignTokens.spacing4,
              AppDesignTokens.spacing16,
              AppDesignTokens.spacing8,
            ),
            child: Text(
              'Edited = amended, corrected, or re-saved ratings',
              style: TextStyle(
                fontSize: 11,
                height: 1.25,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        // Plot list grouped by rep
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        plots.isEmpty ? Icons.grid_off : Icons.check_circle,
                        size: 64,
                        color: plots.isEmpty
                            ? Theme.of(context).colorScheme.outlineVariant
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                          plots.isEmpty
                              ? (rawPlots.isEmpty
                                  ? 'No plots in this trial'
                                  : 'No plots in rating queue')
                              : (_emptyQueueIsAllRatedUnratedOnly()
                                  ? 'No unrated plots in this view'
                                  : 'No plots match filters'),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        plots.isEmpty
                            ? 'Go to the Plots tab to import plots first.'
                            : (_emptyQueueIsAllRatedUnratedOnly()
                                ? 'Session completeness is separate — review before closing if needed.'
                                : 'Clear filters below to see all plots again.'),
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      if (plots.isNotEmpty && filtered.isEmpty) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _clearAllPlotFilters,
                          child: const Text('Clear filters'),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Export + Share
                      SizedBox(
                        width: 220,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.share),
                          label: const Text('Export & Share Session CSV'),
                          onPressed: () async {
                            final proceed = await confirmSessionExportTrust(
                              context: context,
                              ref: ref,
                              trialId: widget.trial.id,
                              sessionId: widget.session.id,
                            );
                            if (!proceed || !mounted) return;
                            final guard = ref.read(exportGuardProvider);
                            final ran = await guard.runExclusive(() async {
                              try {
                                final usecase =
                                    ref.read(exportSessionCsvUsecaseProvider);
                                final currentUser =
                                    await ref.read(currentUserProvider.future);
                                final result = await usecase.exportSessionToCsv(
                                  sessionId: widget.session.id,
                                  trialId: widget.trial.id,
                                  trialName: widget.trial.name,
                                  sessionName: widget.session.name,
                                  sessionDateLocal:
                                      widget.session.sessionDateLocal,
                                  sessionRaterName: widget.session.raterName,
                                  exportedByDisplayName:
                                      currentUser?.displayName,
                                  isSessionClosed:
                                      widget.session.endedAt != null,
                                );

                                if (!mounted || !context.mounted) return;
                                if (!result.success) {
                                  ref
                                      .read(diagnosticsStoreProvider)
                                      .recordError(
                                        result.errorMessage ?? 'Export failed',
                                        code: 'export_failed',
                                      );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        result.errorMessage ?? 'Export failed',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      result.warningMessage != null
                                          ? result.warningMessage!
                                          : 'Exported ${result.rowCount} rows',
                                    ),
                                  ),
                                );
                                await Share.shareXFiles(
                                  [XFile(result.filePath!)],
                                  text:
                                      'Agnexis export: ${widget.trial.name} / ${widget.session.name}',
                                );
                              } catch (e) {
                                if (!mounted || !context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Export failed: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            });
                            if (!ran && mounted && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(ExportGuard.busyMessage)),
                              );
                            }
                          },
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Back to Sessions
                      SizedBox(
                        width: 220,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back to Sessions'),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                )
              : _buildLazyGroupedQueueList(
                  context,
                  filtered,
                  assessments,
                  ratedPks,
                  ratingsByPlot,
                  treatmentById,
                  plotIdToTreatmentId,
                  flaggedIds,
                  plotPksWithCorrections,
                  allPlotsForTrial: plots,
                  filteredPlotIdsForRating: filteredPlotIdsForRating,
                  isFilteredModeForRating: filterNavActive,
                  navigationModeLabelForRating: navigationModeLabelForRating,
                  onOpenRating:
                      (plot, walkPlots, asmt, fIds, fMode, navLabel) =>
                          _openRatingFromQueue(context, plot, walkPlots, asmt,
                              fIds, fMode, navLabel),
                  highlightPlotPk: _highlightPlotPk,
                  rowKeyForPlot: _keyForPlotRow,
                ),
        ),
      ],
    );
  }

  List<_PlotQueueListItem> _flattenGroupedQueueItems(List<Plot> filteredPlots) {
    final groups = <int?, List<Plot>>{};
    for (final plot in filteredPlots) {
      groups.putIfAbsent(plot.rep, () => []).add(plot);
    }
    final sortedReps = groups.keys.toList()
      ..sort((a, b) => (a ?? 999).compareTo(b ?? 999));
    final items = <_PlotQueueListItem>[];
    for (final rep in sortedReps) {
      items.add(_PlotQueueListItem.header(rep != null ? 'Rep $rep' : 'No Rep'));
      for (final plot in groups[rep]!) {
        items.add(_PlotQueueListItem.plot(plot));
      }
    }
    return items;
  }

  Widget _buildLazyGroupedQueueList(
    BuildContext context,
    List<Plot> filteredPlots,
    List<Assessment> assessments,
    Set<int> ratedPks,
    Map<int, List<RatingRecord>> ratingsByPlot,
    Map<int, Treatment> treatmentById,
    Map<int, int?> plotIdToTreatmentId,
    Set<int> flaggedIds,
    Set<int> plotPksWithCorrections, {
    required List<Plot> allPlotsForTrial,
    required List<int>? filteredPlotIdsForRating,
    required bool isFilteredModeForRating,
    required String? navigationModeLabelForRating,
    required _PlotQueueOpenRating onOpenRating,
    required int? highlightPlotPk,
    required GlobalKey Function(int plotPk) rowKeyForPlot,
  }) {
    final entries = _flattenGroupedQueueItems(filteredPlots);
    return ListView.builder(
      controller: _plotQueueScrollController,
      padding: EdgeInsets.zero,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final item = entries[index];
        if (item.isHeader) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(
              item.headerTitle!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          );
        }
        final plot = item.plot!;
        final plotRatings = ratingsByPlot[plot.id] ?? [];
        final hasEdited =
            plotRatings.any((r) => r.amended || (r.previousId != null)) ||
                plotPksWithCorrections.contains(plot.id);
        final plotHasCorr = plotPksWithCorrections.contains(plot.id);
        String? editRecencyLine;
        if (hasEdited) {
          final ts = latestEditRecencyForPlot(plotRatings, plotHasCorr);
          if (ts != null) {
            editRecencyLine = 'Edited ${formatEditRecencyCompact(ts)}';
          }
        }
        final displayNum = getDisplayPlotLabel(plot, allPlotsForTrial);
        final isRated = ratedPks.contains(plot.id);
        return _PlotQueueTile(
          plot: plot,
          allPlotsForTrial: allPlotsForTrial,
          treatmentLabel: getTreatmentDisplayLabel(plot, treatmentById,
              treatmentIdOverride: plotIdToTreatmentId[plot.id]),
          isRated: isRated,
          plotRatings: plotRatings,
          assessments: assessments,
          trial: widget.trial,
          session: widget.session,
          isFlagged: flaggedIds.contains(plot.id),
          hasIssues: plotRatings.any((r) => r.resultStatus != 'RECORDED'),
          hasEdited: hasEdited,
          editRecencyLine: editRecencyLine,
          onOpenRating: onOpenRating,
          filteredPlotIdsForRating: filteredPlotIdsForRating,
          isFilteredModeForRating: isFilteredModeForRating,
          navigationModeLabelForRating: navigationModeLabelForRating,
          onShowRatedSummary: isRated && plotRatings.isNotEmpty
              ? () => _showRatingSummarySheet(
                    context,
                    plot,
                    plotRatings,
                    assessments,
                    widget.trial,
                    widget.session,
                    displayNum,
                    openRatingFromQueue: () => onOpenRating(
                        plot,
                        allPlotsForTrial,
                        assessments,
                        filteredPlotIdsForRating,
                        isFilteredModeForRating,
                        navigationModeLabelForRating),
                  )
              : null,
          highlightRow: plot.id == highlightPlotPk,
          rowKey: rowKeyForPlot(plot.id),
        );
      },
    );
  }

  Future<void> _showJumpToPlotDialog(BuildContext context) async {
    final rawPlots =
        ref.read(plotsForTrialProvider(widget.trial.id)).value ?? [];
    final assessments =
        ref.read(sessionAssessmentsProvider(widget.session.id)).value ?? [];
    if (rawPlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No plots in this trial')),
      );
      return;
    }
    final queuePlots = _queuePlotsExcludingGuards(rawPlots);
    if (queuePlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No plots in rating queue')),
      );
      return;
    }
    if (assessments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No assessments in this session')),
      );
      return;
    }
    if (!context.mounted) return;
    final plots = sortPlotsByWalkOrder(
      queuePlots,
      _walkOrderMode,
      customPlotIds: _customPlotIds,
    );
    final controller = TextEditingController();
    final plotId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jump to Plot'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Plot number',
            hintText: 'e.g. 47',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          keyboardType: TextInputType.number,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    if (plotId == null || plotId.isEmpty || !context.mounted) return;
    final index = plots.indexWhere(
        (p) => p.plotId == plotId || getDisplayPlotLabel(p, plots) == plotId);
    if (index < 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plot "$plotId" not found')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    await _openRatingFromQueue(
      context,
      plots[index],
      plots,
      assessments,
      null,
      false,
      null,
    );
  }

  bool _anyPlotFiltersActive() {
    return _repFilter != null ||
        _showUnratedOnly ||
        _showIssuesOnly ||
        _showEditedOnly ||
        _showFlaggedOnly;
  }

  /// Single clear filter name for RatingScreen chip; null → generic "Filtered mode".
  String? _singleNavigationModeLabel() {
    final repOnly = _repFilter != null &&
        !_showUnratedOnly &&
        !_showIssuesOnly &&
        !_showEditedOnly &&
        !_showFlaggedOnly;
    if (repOnly) {
      return 'Rep $_repFilter';
    }
    final flags = <String>[];
    if (_showUnratedOnly) flags.add('unrated');
    if (_showIssuesOnly) flags.add('issues');
    if (_showEditedOnly) flags.add('edited');
    if (_showFlaggedOnly) flags.add('flagged');
    if (flags.length != 1) return null;
    switch (flags.single) {
      case 'unrated':
        return 'Unrated';
      case 'issues':
        return 'Issues';
      case 'edited':
        return 'Edited';
      case 'flagged':
        return 'Flagged';
      default:
        return null;
    }
  }

  void _clearAllPlotFilters() {
    setState(() {
      _repFilter = null;
      _showUnratedOnly = false;
      _showIssuesOnly = false;
      _showEditedOnly = false;
      _showFlaggedOnly = false;
    });
  }

  /// Empty list + unrated-only on full trial (no other filters) → no plots lack a current rating in this view.
  bool _emptyQueueIsAllRatedUnratedOnly() {
    return _showUnratedOnly &&
        _repFilter == null &&
        !_showIssuesOnly &&
        !_showEditedOnly &&
        !_showFlaggedOnly;
  }

  void _showFilterSheet(BuildContext context) {
    final plotsAsync = ref.read(plotsForTrialProvider(widget.trial.id));
    final plots = plotsAsync.value ?? [];
    final reps = plots.map((p) => p.rep).whereType<int>().toSet().toList()
      ..sort();

    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter Plots',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Show Unrated Only'),
                value: _showUnratedOnly,
                onChanged: (val) {
                  setState(() => _showUnratedOnly = val);
                  Navigator.pop(context);
                },
              ),
              SwitchListTile(
                title: const Text('Show Issues Only'),
                value: _showIssuesOnly,
                onChanged: (val) {
                  setState(() => _showIssuesOnly = val);
                  Navigator.pop(context);
                },
              ),
              SwitchListTile(
                title: const Text('Show Edited Only'),
                subtitle: const Text(
                  'Edited = amended, corrected, or re-saved ratings',
                  style: TextStyle(fontSize: 12),
                ),
                value: _showEditedOnly,
                onChanged: (val) {
                  setState(() => _showEditedOnly = val);
                  Navigator.pop(context);
                },
              ),
              SwitchListTile(
                title: const Text('Show Flagged Only'),
                value: _showFlaggedOnly,
                onChanged: (val) {
                  setState(() => _showFlaggedOnly = val);
                  Navigator.pop(context);
                },
              ),
              if (reps.isNotEmpty) ...[
                const Text('Filter by Rep',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _repFilter == null,
                      onSelected: (_) {
                        setState(() => _repFilter = null);
                        Navigator.pop(context);
                      },
                    ),
                    ...reps.map((rep) => FilterChip(
                          label: Text('Rep $rep'),
                          selected: _repFilter == rep,
                          onSelected: (_) {
                            setState(() => _repFilter = rep);
                            Navigator.pop(context);
                          },
                        )),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRatingSummarySheet(
    BuildContext context,
    Plot plot,
    List<RatingRecord> plotRatings,
    List<Assessment> assessments,
    Trial trial,
    Session session,
    String displayNum, {
    required Future<void> Function() openRatingFromQueue,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Plot $displayNum',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (plot.rep != null) ...[
                  const SizedBox(width: 12),
                  Text('Rep ${plot.rep}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface)),
                ],
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'Values in this session',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            ...plotRatings.map((r) {
              Assessment? assessment;
              for (final a in assessments) {
                if (a.id == r.assessmentId) {
                  assessment = a;
                  break;
                }
              }
              final name = assessment?.name ?? 'Assessment ${r.assessmentId}';
              final value = r.resultStatus == 'RECORDED'
                  ? (r.numericValue != null
                      ? r.numericValue!.toString()
                      : r.textValue ?? '—')
                  : r.resultStatus;
              final unit = assessment?.unit;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        unit != null && r.resultStatus == 'RECORDED'
                            ? '$value $unit'
                            : value,
                        style: TextStyle(
                          fontSize: 14,
                          color: r.resultStatus == 'RECORDED'
                              ? Colors.green.shade700
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (!context.mounted) return;
                  await openRatingFromQueue();
                },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Rate Again / Edit'),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

/// Flattened row for lazy queue list: rep header or plot tile.
class _PlotQueueListItem {
  const _PlotQueueListItem.header(this.headerTitle) : plot = null;
  const _PlotQueueListItem.plot(this.plot) : headerTitle = null;

  final String? headerTitle;
  final Plot? plot;

  bool get isHeader => plot == null;
}

class _PlotQueueTile extends StatelessWidget {
  final Plot plot;
  final List<Plot> allPlotsForTrial;
  final String treatmentLabel;
  final bool isRated;
  final List<RatingRecord> plotRatings;
  final List<Assessment> assessments;
  final Trial trial;
  final Session session;
  final bool isFlagged;
  final bool hasIssues;
  final bool hasEdited;

  /// Subtle per-plot edit time; null when edited but no safe timestamp.
  final String? editRecencyLine;
  final _PlotQueueOpenRating onOpenRating;
  final List<int>? filteredPlotIdsForRating;
  final bool isFilteredModeForRating;
  final String? navigationModeLabelForRating;

  /// Long-press on row with a current rating: session value summary sheet (optional).
  final VoidCallback? onShowRatedSummary;
  final bool highlightRow;
  final GlobalKey rowKey;

  const _PlotQueueTile({
    required this.plot,
    required this.allPlotsForTrial,
    required this.treatmentLabel,
    required this.isRated,
    required this.plotRatings,
    required this.assessments,
    required this.trial,
    required this.session,
    required this.isFlagged,
    required this.hasIssues,
    required this.hasEdited,
    this.editRecencyLine,
    required this.onOpenRating,
    required this.filteredPlotIdsForRating,
    required this.isFilteredModeForRating,
    required this.navigationModeLabelForRating,
    this.onShowRatedSummary,
    required this.highlightRow,
    required this.rowKey,
  });

  @override
  Widget build(BuildContext context) {
    final displayNum = getDisplayPlotLabel(plot, allPlotsForTrial);
    final titleText = 'Plot $displayNum · $treatmentLabel';
    final hasStatusRow = isFlagged || hasIssues || hasEdited || isRated;
    final rep = plot.rep;

    Widget? statusSubtitle;
    if (hasStatusRow || rep != null) {
      final statusLabels = <String>[
        if (isFlagged) 'Flagged',
        if (hasIssues) 'Issues',
        if (hasEdited) 'Edited',
        if (isRated) 'Has Rating',
      ];
      statusSubtitle = Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasStatusRow)
              Semantics(
                label: statusLabels.join(', '),
                child: Wrap(
                  spacing: 5,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (isFlagged)
                      const Icon(Icons.flag, color: Colors.amber, size: 18),
                    if (hasIssues)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppDesignTokens.warningBg,
                          borderRadius:
                              BorderRadius.circular(AppDesignTokens.radiusChip),
                          border:
                              Border.all(color: AppDesignTokens.warningBorder),
                        ),
                        child: const Text(
                          'Issues',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppDesignTokens.warningFg,
                          ),
                        ),
                      ),
                    if (hasEdited)
                      Tooltip(
                        message:
                            'Edited = amended, corrected, or re-saved ratings',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppDesignTokens.emptyBadgeBg,
                            borderRadius: BorderRadius.circular(
                                AppDesignTokens.radiusChip),
                            border:
                                Border.all(color: AppDesignTokens.borderCrisp),
                          ),
                          child: const Text(
                            'Edited',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppDesignTokens.emptyBadgeFg,
                            ),
                          ),
                        ),
                      ),
                    if (isRated)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppDesignTokens.successBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppDesignTokens.successFg
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          'Has Rating',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppDesignTokens.successFg,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (editRecencyLine != null)
              Padding(
                padding: EdgeInsets.only(top: hasStatusRow ? 4 : 2),
                child: Text(
                  editRecencyLine!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.82),
                  ),
                ),
              ),
            if (rep != null)
              Padding(
                padding: EdgeInsets.only(
                    top: (hasStatusRow || editRecencyLine != null) ? 3 : 0),
                child: Text(
                  'Rep $rep',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.2,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.72),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final card = Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing16,
          vertical: 5,
        ),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF2D5A40),
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusXSmall),
          ),
          child: Text(
            displayNum,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        title: Text(
          titleText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: statusSubtitle,
        trailing: isRated && plotRatings.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit',
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.all(6),
                      minimumSize: Size.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => onOpenRating(
                        plot,
                        allPlotsForTrial,
                        assessments,
                        filteredPlotIdsForRating,
                        isFilteredModeForRating,
                        navigationModeLabelForRating),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              )
            : const Icon(Icons.chevron_right),
        onTap: () => onOpenRating(
            plot,
            allPlotsForTrial,
            assessments,
            filteredPlotIdsForRating,
            isFilteredModeForRating,
            navigationModeLabelForRating),
        onLongPress:
            onShowRatedSummary != null ? () => onShowRatedSummary!() : null,
      ),
    );

    return KeyedSubtree(
      key: rowKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlightRow ? scheme.primary : Colors.transparent,
              width: highlightRow ? 2 : 0,
            ),
            color: highlightRow
                ? scheme.primaryContainer.withValues(alpha: 0.32)
                : Colors.transparent,
          ),
          child: card,
        ),
      ),
    );
  }
}

/// Dock bar matching Trial's _TrialModuleHub / _DockTile: icon, label, scale, underline only.
class _PlotQueueDockBar extends StatelessWidget {
  const _PlotQueueDockBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      width: double.infinity,
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing16,
        ),
        physics: const BouncingScrollPhysics(),
        children: const [
          _PlotQueueDockTile(
              icon: Icons.grid_on, label: 'Plots', selected: true),
        ],
      ),
    );
  }
}

/// Matches Trial's _DockTile: AnimatedScale, InkWell, icon, label, underline (no subtitle).
class _PlotQueueDockTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _PlotQueueDockTile({
    required this.icon,
    required this.label,
    required this.selected,
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
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: selected ? scheme.primaryContainer : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selected ? activeColor : inactiveColor,
                size: selected ? 22 : 19,
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
            ),
          ],
        ),
      ),
    );
  }
}
