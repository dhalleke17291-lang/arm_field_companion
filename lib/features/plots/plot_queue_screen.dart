import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/widgets/gradient_screen_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/plot_display.dart';
import '../../core/providers.dart';
import '../../core/session_resume_store.dart';
import '../ratings/rating_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/plot_sort.dart';
import '../../core/session_walk_order_store.dart';
import '../sessions/arrange_plots_screen.dart';

/// Shared [RatingScreen] push from Plot Queue (index + [SessionResumeStore] logic).
Future<void> _pushRatingScreenFromPlotQueue({
  required BuildContext context,
  required Plot plot,
  required Trial trial,
  required Session session,
  required List<Assessment> assessments,
  required List<Plot> allPlotsForTrial,
}) async {
  final idx = allPlotsForTrial.indexWhere((p) => p.id == plot.id);
  final currentPlotIndex = idx < 0 ? 0 : idx;
  int? initialAssessmentIndex;
  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return;
  final pos = SessionResumeStore(prefs).getPosition(session.id);
  if (pos != null && pos.$1 == currentPlotIndex) {
    initialAssessmentIndex =
        pos.$2.clamp(0, assessments.length - 1);
  }
  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RatingScreen(
        trial: trial,
        session: session,
        plot: plot,
        assessments: assessments,
        allPlots: allPlotsForTrial,
        currentPlotIndex: currentPlotIndex,
        initialAssessmentIndex: initialAssessmentIndex,
      ),
    ),
  );
}

class PlotQueueScreen extends ConsumerStatefulWidget {
  final Trial trial;
  final Session session;

  const PlotQueueScreen({
    super.key,
    required this.trial,
    required this.session,
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

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWalkOrder());
  }

  Future<void> _loadWalkOrder() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final store = SessionWalkOrderStore(prefs);
    final mode = store.getMode(widget.session.id);
    final customIds = mode == WalkOrderMode.custom ? store.getCustomOrder(widget.session.id) : null;
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

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EB),
      appBar: GradientScreenHeader(
        title: widget.trial.name,
        subtitle: '${widget.session.name} · Walk order: ${SessionWalkOrderStore.labelForMode(_walkOrderMode)}',
        titleFontSize: 17,
        actions: [
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
                return _buildQueue(
                    context,
                    plots,
                    assessments,
                    ratedPks,
                    ratings,
                    treatmentById,
                    plotIdToTreatmentId,
                    flaggedIds,
                    plotPksWithCorrections);
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
    Set<int> plotPksWithCorrections,
  ) {
    final ratingsByPlot = <int, List<RatingRecord>>{};
    for (final r in ratings) {
      ratingsByPlot.putIfAbsent(r.plotPk, () => []).add(r);
    }

    // Apply session walk order (numeric, serpentine, or custom) for rating navigation
    final plots = sortPlotsByWalkOrder(
      rawPlots,
      _walkOrderMode,
      customPlotIds: _customPlotIds,
    );
    var filtered = plots;
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
      filtered =
          filtered.where((p) => flaggedIds.contains(p.id)).toList();
    }

    final totalPlots = plots.length;
    final ratedCount = ratedPks.length;

    return Column(
      children: [
        const _PlotQueueDockBar(),
        // Section header (same as Trial Plots tab)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            children: [
              Icon(Icons.grid_on, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('$ratedCount / $totalPlots rated',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary)),
              const Spacer(),
              if (plots.any((p) => p.fieldRow != null))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D5A40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.route, size: 11, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Serpentine',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              if (_showUnratedOnly)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Unrated Only',
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
              if (_showIssuesOnly ||
                  _showEditedOnly ||
                  _showFlaggedOnly) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Filtered',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSecondaryContainer,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Assessment chips
        if (assessments.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              itemCount: assessments.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Chip(
                    label: Text(assessments[index].name,
                        style: const TextStyle(fontSize: 12)),
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                  ),
                );
              },
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
                              ? 'No plots in this trial'
                              : (_emptyQueueIsAllRatedUnratedOnly()
                                  ? 'All plots rated!'
                                  : 'No plots match filters'),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        plots.isEmpty
                            ? 'Go to the Plots tab to import plots first.'
                            : (_emptyQueueIsAllRatedUnratedOnly()
                                ? 'You can export and share this session now.'
                                : 'Try changing or clearing filters in the filter menu.'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Export + Share
                      SizedBox(
                        width: 220,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.share),
                          label: const Text('Export & Share CSV'),
                          onPressed: () async {
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
                                exportedByDisplayName: currentUser?.displayName,
                                isSessionClosed: widget.session.endedAt != null,
                              );

                              if (!mounted || !context.mounted) return;
                              if (!result.success) {
                                ref.read(diagnosticsStoreProvider).recordError(
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
                                    'Ag-Quest Field Companion export: ${widget.trial.name} / ${widget.session.name}',
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

                      const SizedBox(height: 8),

                      TextButton(
                        onPressed: () =>
                            setState(() => _showUnratedOnly = false),
                        child: const Text('Show all plots'),
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
      items.add(_PlotQueueListItem.header(
          rep != null ? 'Rep $rep' : 'No Rep'));
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
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          );
        }
        final plot = item.plot!;
        final plotRatings = ratingsByPlot[plot.id] ?? [];
        final hasEdited = plotRatings.any(
                (r) => r.amended || (r.previousId != null)) ||
            plotPksWithCorrections.contains(plot.id);
        return _PlotQueueTile(
          plot: plot,
          allPlotsForTrial: allPlotsForTrial,
          treatmentLabel: getTreatmentDisplayLabel(plot, treatmentById,
              treatmentIdOverride: plotIdToTreatmentId[plot.id]),
          isRated: ratedPks.contains(plot.id),
          plotRatings: plotRatings,
          assessments: assessments,
          trial: widget.trial,
          session: widget.session,
          isFlagged: flaggedIds.contains(plot.id),
          hasIssues: plotRatings.any((r) => r.resultStatus != 'RECORDED'),
          hasEdited: hasEdited,
        );
      },
    );
  }

  Future<void> _showJumpToPlotDialog(BuildContext context) async {
    final rawPlots = ref.read(plotsForTrialProvider(widget.trial.id)).value ?? [];
    final assessments =
        ref.read(sessionAssessmentsProvider(widget.session.id)).value ?? [];
    if (rawPlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No plots in this trial')),
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
      rawPlots,
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
    final index = plots.indexWhere((p) =>
        p.plotId == plotId || getDisplayPlotLabel(p, plots) == plotId);
    if (index < 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plot "$plotId" not found')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    await _pushRatingScreenFromPlotQueue(
      context: context,
      plot: plots[index],
      trial: widget.trial,
      session: widget.session,
      assessments: assessments,
      allPlotsForTrial: plots,
    );
  }

  /// Empty list + unrated-only on full trial (no other filters) → "all rated" UX.
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
}

/// Flattened row for lazy queue list: rep header or plot tile.
class _PlotQueueListItem {
  const _PlotQueueListItem.header(this.headerTitle) : plot = null;
  const _PlotQueueListItem.plot(this.plot) : headerTitle = null;

  final String? headerTitle;
  final Plot? plot;

  bool get isHeader => plot == null;
}

class _PlotQueueTile extends ConsumerWidget {
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
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayNum = getDisplayPlotLabel(plot, allPlotsForTrial);
    final titleText = 'Plot $displayNum · $treatmentLabel';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        title: Row(
          children: [
            Expanded(
              child: Text(titleText,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (isFlagged)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.flag, color: Colors.amber, size: 20),
              ),
            if (hasIssues)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusChip),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Text(
                  'Issues',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800),
                ),
              ),
            if (hasEdited)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusChip),
                  border: Border.all(color: Colors.blueGrey.shade200),
                ),
                child: Text(
                  'Edited',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey.shade800,
                  ),
                ),
              ),
            if (isRated)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Text(
                  'Rated',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
          ],
        ),
        subtitle: plot.rep != null ? Text('Rep ${plot.rep}') : null,
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
                    onPressed: () async {
                      await _pushRatingScreenFromPlotQueue(
                        context: context,
                        plot: plot,
                        trial: trial,
                        session: session,
                        assessments: assessments,
                        allPlotsForTrial: allPlotsForTrial,
                      );
                    },
                  ),
                  Icon(
                    Icons.chevron_right,
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              )
            : const Icon(Icons.chevron_right),
        onTap: () async {
          if (isRated && plotRatings.isNotEmpty) {
            _showRatingSummarySheet(
              context,
              ref,
              plot,
              plotRatings,
              assessments,
              trial,
              session,
              displayNum,
            );
          } else {
            await _pushRatingScreenFromPlotQueue(
              context: context,
              plot: plot,
              trial: trial,
              session: session,
              assessments: assessments,
              allPlotsForTrial: allPlotsForTrial,
            );
          }
        },
      ),
    );
  }

  void _showRatingSummarySheet(
    BuildContext context,
    WidgetRef ref,
    Plot plot,
    List<RatingRecord> plotRatings,
    List<Assessment> assessments,
    Trial trial,
    Session session,
    String displayNum,
  ) {
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
                  await _pushRatingScreenFromPlotQueue(
                    context: context,
                    plot: plot,
                    trial: trial,
                    session: session,
                    assessments: assessments,
                    allPlotsForTrial: allPlotsForTrial,
                  );
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

/// Dock bar matching Trial's _TrialModuleHub / _DockTile: icon, label, scale, underline only.
class _PlotQueueDockBar extends StatelessWidget {
  const _PlotQueueDockBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      width: double.infinity,
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected ? scheme.primaryContainer : Colors.transparent,
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
            ),
          ],
        ),
      ),
    );
  }
}
