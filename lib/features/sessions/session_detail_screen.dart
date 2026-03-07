import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../export/data/export_repository.dart';
import '../export/domain/export_session_csv_usecase.dart';
import 'package:share_plus/share_plus.dart';
import '../plots/plot_queue_screen.dart';

class SessionDetailScreen extends ConsumerStatefulWidget {
  final Trial trial;
  final Session session;

  const SessionDetailScreen({
    super.key,
    required this.trial,
    required this.session,
  });

  @override
  ConsumerState<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final trial = widget.trial;
    final session = widget.session;
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final ratingsAsync = ref.watch(sessionRatingsProvider(session.id));
    final assessmentsAsync = ref.watch(sessionAssessmentsProvider(session.id));
    final treatments = ref.watch(treatmentsForTrialProvider(trial.id)).value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.name,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(session.sessionDateLocal,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to CSV',
            onPressed: () => _exportCsv(context, ref),
          ),
        ],
      ),
      body: plotsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (plots) => ratingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
          data: (ratings) => assessmentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (assessments) => Column(
              children: [
                _SessionDockBar(
                  selectedIndex: _selectedTabIndex,
                  onSelected: (index) =>
                      setState(() => _selectedTabIndex = index),
                  ratedCount: ratings.map((r) => r.plotPk).toSet().length,
                  plotCount: plots.length,
                ),
                Expanded(
                  child: IndexedStack(
                    index: _selectedTabIndex,
                    children: [
                      _buildContent(context, ref, plots, ratings, assessments,
                          treatments),
                      _buildRateTab(context, ref, trial, session, plots,
                          assessments),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final repo = ExportRepository(db);
    final usecase = ExportSessionCsvUsecase(repo);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exporting...')),
      );

      final result = await usecase.exportSessionToCsv(
        sessionId: widget.session.id,
        trialName: widget.trial.name,
        sessionName: widget.session.name,
        sessionDateLocal: widget.session.sessionDateLocal,
        sessionRaterName: widget.session.raterName,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Export Complete'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${result.rowCount} ratings exported'),
                const SizedBox(height: 8),
                const Text('Saved to:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                SelectableText(result.filePath,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await Share.shareXFiles(
                    [XFile(result.filePath)],
                    subject: '${widget.trial.name} - ${widget.session.name} Export',
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildRateTab(
    BuildContext context,
    WidgetRef ref,
    Trial trial,
    Session session,
    List<Plot> plots,
    List<Assessment> assessments,
  ) {
    if (assessments.isEmpty) {
      return const Center(
        child: Text('No assessments in this session'),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_note,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Rate plots in this session',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Open the plot queue to enter or edit ratings.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlotQueueScreen(
                      trial: trial,
                      session: session,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start rating'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<Plot> plots,
    List<RatingRecord> ratings,
    List<Assessment> assessments,
    List<Treatment> treatments,
  ) {
    final ratedCount = ratings.map((r) => r.plotPk).toSet().length;
    return Column(
      children: [
        // Section header (same as Trial Plots tab)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            children: [
              Icon(Icons.grid_on,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('${plots.length} plots',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary)),
              const Spacer(),
              Text('$ratedCount / ${plots.length} rated',
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary)),
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
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Chip(
                  label: Text(assessments[index].name,
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
            ),
          ),

        // Plot ratings list
        Expanded(
          child: ListView.builder(
            itemCount: plots.length,
            itemBuilder: (context, index) {
              final plot = plots[index];
              final plotRatings =
                  ratings.where((r) => r.plotPk == plot.id).toList();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: ExpansionTile(
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D5A40),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      plot.plotId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  title: Text('Plot ${plot.plotId}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: plot.rep != null ? Text('Rep ${plot.rep}') : null,
                  children: plotRatings.isEmpty
                      ? [
                          const ListTile(
                            title: Text('Not rated',
                                style: TextStyle(color: Colors.grey)),
                          )
                        ]
                      : plotRatings.map((rating) {
                          final assessment = assessments
                              .where((a) => a.id == rating.assessmentId)
                              .firstOrNull;
                          return ListTile(
                            dense: true,
                            title: Text(assessment?.name ?? 'Assessment'),
                            trailing: Text(
                              rating.resultStatus == 'RECORDED'
                                  ? '${rating.numericValue ?? "-"} ${assessment?.unit ?? ""}'
                                  : rating.resultStatus,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: rating.resultStatus == 'RECORDED'
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          );
                        }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Dock-style tab bar for session detail (same look as trial's Plots / Sessions dock).
class _SessionDockBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int ratedCount;
  final int plotCount;

  const _SessionDockBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.ratedCount,
    required this.plotCount,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      (0, Icons.grid_on, 'Plots'),
      (1, Icons.edit_note_rounded, 'Rate'),
    ];
    return Container(
      height: 110,
      width: double.infinity,
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = selectedIndex == item.$1;
          return _SessionDockTile(
            icon: item.$2,
            label: item.$3,
            selected: isSelected,
            onTap: () => onSelected(item.$1),
          );
        },
      ),
    );
  }
}

/// Matches Trial's _DockTile: icon, label, scale, underline (no subtitle).
class _SessionDockTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SessionDockTile({
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
