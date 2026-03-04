import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import 'package:drift/drift.dart' as drift;
import '../sessions/create_session_screen.dart';
import '../sessions/session_detail_screen.dart';
import '../plots/plot_queue_screen.dart';
import '../plots/import_plots_screen.dart';
import '../plots/plot_detail_screen.dart';
import '../../core/providers.dart';

class TrialDetailScreen extends ConsumerStatefulWidget {
  final Trial trial;

  const TrialDetailScreen({super.key, required this.trial});

  @override
  ConsumerState<TrialDetailScreen> createState() => _TrialDetailScreenState();
}

class _TrialDetailScreenState extends ConsumerState<TrialDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.trial.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (widget.trial.crop != null)
              Text(widget.trial.crop!,
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.grid_on), text: 'Plots'),
            Tab(icon: Icon(Icons.assessment), text: 'Assessments'),
            Tab(icon: Icon(Icons.folder_open), text: 'Sessions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PlotsTab(trial: widget.trial),
          _AssessmentsTab(trial: widget.trial),
          _SessionsTab(trial: widget.trial),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PLOTS TAB
// ─────────────────────────────────────────────

class _PlotsTab extends ConsumerWidget {
  final Trial trial;

  const _PlotsTab({required this.trial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    return plotsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (plots) => plots.isEmpty
          ? _buildEmptyPlots(context, ref)
          : _buildPlotsList(context, plots),
    );
  }

  Widget _buildEmptyPlots(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.grid_on, size: 64,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          const Text('No plots yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Import plots via CSV to get started',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ImportPlotsScreen(trial: trial))),
            icon: const Icon(Icons.upload_file),
            label: const Text('Import Plots from CSV'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _seedTestPlots(context, ref),
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
          trialId: trial.id,
          plotId: i.toString().padLeft(3, '0'),
          plotSortIndex: drift.Value(i),
          rep: drift.Value((i / 3).ceil()),
        ),
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('10 test plots added'),
            backgroundColor: Colors.green));
    }
  }

  Widget _buildPlotsList(BuildContext context, List<Plot> plots) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
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
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: plots.length,
            itemBuilder: (context, index) {
              final plot = plots[index];
              return ListTile(
                dense: true,
            leading: CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    plot.rep?.toString() ?? '-',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                title: Text('Plot ${plot.plotId}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: plot.rep != null
                    ? Text('Rep ${plot.rep}')
                    : null,
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PlotDetailScreen(trial: trial, plot: plot))),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AssessmentsTab extends ConsumerWidget {
  final Trial trial;

  const _AssessmentsTab({required this.trial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessmentsAsync =
        ref.watch(assessmentsForTrialProvider(trial.id));

    return assessmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (assessments) => assessments.isEmpty
          ? _buildEmptyAssessments(context, ref)
          : _buildAssessmentsList(context, ref, assessments),
    );
  }

  Widget _buildEmptyAssessments(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assessment, size: 64,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          const Text('No assessments yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Add assessments to define what to measure',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddAssessmentDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add Assessment'),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentsList(
      BuildContext context, WidgetRef ref, List<Assessment> assessments) {
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
                onPressed: () => _showAddAssessmentDialog(context, ref),
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
                      color: Theme.of(context).colorScheme.primary,
                      size: 20),
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
                      minValue: drift.Value(double.tryParse(minController.text)),
                      maxValue: drift.Value(double.tryParse(maxController.text)),
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
// SESSIONS TAB
// ─────────────────────────────────────────────

class _SessionsTab extends ConsumerWidget {
  final Trial trial;

  const _SessionsTab({required this.trial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsForTrialProvider(trial.id));

    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (sessions) => sessions.isEmpty
          ? _buildEmptySessions(context)
          : _buildSessionsList(context, ref, sessions),
    );
  }

  Widget _buildEmptySessions(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          const Text('No sessions yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Start a session to begin field data collection',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => CreateSessionScreen(trial: trial))),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Session'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList(BuildContext context, WidgetRef ref, List<Session> sessions) {
    final groups = <String, List<Session>>{};
    for (final session in sessions) {
      groups.putIfAbsent(session.sessionDateLocal, () => []).add(session);
    }
    final sortedDates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final items = <Widget>[];
    for (final date in sortedDates) {
      items.add(Container(
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
      ));
      for (final session in groups[date]!) {
        final isOpen = session.endedAt == null;
        items.add(Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: ListTile(
            onTap: () {
              if (isOpen) {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PlotQueueScreen(trial: trial, session: session)));
              } else {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => SessionDetailScreen(trial: trial, session: session)));
              }
            },
            onLongPress: isOpen ? () => _confirmCloseSession(context, ref, session) : null,
            leading: CircleAvatar(
              backgroundColor: isOpen ? Colors.green.shade100 : Colors.grey.shade100,
              child: Icon(
                isOpen ? Icons.play_circle : Icons.check_circle,
                color: isOpen ? Colors.green : Colors.grey,
              ),
            ),
            title: Text(session.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(_formatSessionTimes(session)),
            trailing: isOpen
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('OPEN',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  )
                : const Text('Closed',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ));
      }
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: items,
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => CreateSessionScreen(trial: trial))),
            icon: const Icon(Icons.add),
            label: const Text('New Session'),
          ),
        ),
      ],
    );
  }

  String _formatSessionTimes(Session session) {
    String _fmtTime(DateTime dt) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    final start = _fmtTime(session.startedAt);
    final rater = session.raterName != null ? ' · ${session.raterName}' : '';
    if (session.endedAt != null) {
      final end = _fmtTime(session.endedAt!);
      return '$start – $end$rater';
    }
    return 'Started $start$rater';
  }

  String _formatDateHeader(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return dateStr;
      final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final day = int.parse(parts[2]);
      final month = months[int.parse(parts[1])];
      final year = parts[0];
      return '$day $month $year';
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _confirmCloseSession(BuildContext context, WidgetRef ref, Session session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Close Session"),
        content: Text("Close session \"${session.name}\"? You can still view ratings but cannot add new ones."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel")),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Close Session")),
        ],
      ),
    );
    if (confirm != true) return;
    final useCase = ref.read(closeSessionUseCaseProvider);
    final result = await useCase.execute(
      sessionId: session.id,
      trialId: trial.id,
      raterName: session.raterName,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.success ? "Session closed" : result.errorMessage ?? "Error"),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ));
    }
  }
}
