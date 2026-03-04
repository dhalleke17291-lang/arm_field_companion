import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../ratings/rating_screen.dart';

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
  bool _showUnratedOnly = true;

  @override
  Widget build(BuildContext context) {
    final plotsAsync = ref.watch(plotsForTrialProvider(widget.trial.id));
    final sessionAssessmentsAsync =
        ref.watch(sessionAssessmentsProvider(widget.session.id));
    final ratedPlotsAsync =
        ref.watch(ratedPlotPksProvider(widget.session.id));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.trial.name,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            Text(widget.session.name,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
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
            data: (ratedPks) =>
                _buildQueue(context, plots, assessments, ratedPks),
          ),
        ),
      ),
    );
  }

  Widget _buildQueue(
    BuildContext context,
    List<Plot> plots,
    List<Assessment> assessments,
    Set<int> ratedPks,
  ) {
    var filtered = plots;
    if (_repFilter != null) {
      filtered = filtered.where((p) => p.rep == _repFilter).toList();
    }
    if (_showUnratedOnly) {
      filtered = filtered.where((p) => !ratedPks.contains(p.id)).toList();
    }

    final totalPlots = plots.length;
    final ratedCount = ratedPks.length;
    final progress = totalPlots > 0 ? ratedCount / totalPlots : 0.0;

    return Column(
      children: [
        // Progress header
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('$ratedCount / $totalPlots plots rated',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary)),
                  const Spacer(),
                  if (_showUnratedOnly)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Unrated only',
                          style:
                              TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white,
                color: Theme.of(context).colorScheme.primary,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),

        // Assessment chips
        if (assessments.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                      const Icon(Icons.check_circle,
                          size: 64, color: Colors.green),
                      const SizedBox(height: 16),
                      const Text('All plots rated!',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            setState(() => _showUnratedOnly = false),
                        child: const Text('Show all plots'),
                      ),
                    ],
                  ),
                )
              : _buildGroupedList(context, filtered, assessments, ratedPks),
        ),
      ],
    );
  }

  Widget _buildGroupedList(
    BuildContext context,
    List<Plot> plots,
    List<Assessment> assessments,
    Set<int> ratedPks,
  ) {
    final groups = <int?, List<Plot>>{};
    for (final plot in plots) {
      groups.putIfAbsent(plot.rep, () => []).add(plot);
    }
    final sortedReps = groups.keys.toList()
      ..sort((a, b) => (a ?? 999).compareTo(b ?? 999));

    final items = <Widget>[];
    for (final rep in sortedReps) {
      items.add(Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: Colors.grey.shade200,
        child: Text(
          rep != null ? 'Rep $rep' : 'No Rep',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ));
      for (final plot in groups[rep]!) {
        items.add(_PlotQueueTile(
          plot: plot,
          isRated: ratedPks.contains(plot.id),
          assessments: assessments,
          trial: widget.trial,
          session: widget.session,
        ));
      }
    }
    return ListView(children: items);
  }

  void _showFilterSheet(BuildContext context) {
    final plotsAsync = ref.read(plotsForTrialProvider(widget.trial.id));
    final plots = plotsAsync.value ?? [];
    final reps = plots
        .map((p) => p.rep)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();

    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter Plots',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Show unrated only'),
              value: _showUnratedOnly,
              onChanged: (val) {
                setState(() => _showUnratedOnly = val);
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
    );
  }
}

class _PlotQueueTile extends ConsumerWidget {
  final Plot plot;
  final bool isRated;
  final List<Assessment> assessments;
  final Trial trial;
  final Session session;

  const _PlotQueueTile({
    required this.plot,
    required this.isRated,
    required this.assessments,
    required this.trial,
    required this.session,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: isRated
              ? Colors.green.shade100
              : Theme.of(context).colorScheme.primaryContainer,
          child: isRated
              ? const Icon(Icons.check, color: Colors.green)
              : Text(
                  plot.plotId.length >= 2 ? plot.plotId.substring(plot.plotId.length - 2) : plot.plotId,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold),
                ),
        ),
        title: Text('Plot ${plot.plotId}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: plot.rep != null ? Text('Rep ${plot.rep}') : null,
        trailing: isRated
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.chevron_right),
        onTap: () {
          final plots =
              ref.read(plotsForTrialProvider(trial.id)).value ?? [];
          final index = plots.indexWhere((p) => p.id == plot.id);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RatingScreen(
                trial: trial,
                session: session,
                plot: plot,
                assessments: assessments,
                allPlots: plots,
                currentPlotIndex: index < 0 ? 0 : index,
              ),
            ),
          );
        },
      ),
    );
  }
}
