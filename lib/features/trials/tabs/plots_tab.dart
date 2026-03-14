import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/plot_display.dart';
import '../../../core/providers.dart';
import '../../../core/trial_state.dart';
import '../../../core/widgets/loading_error_widgets.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../plot_layout_model.dart';
import '../../plots/plot_detail_screen.dart';

enum _LayoutLayer { treatments, applications, ratings }

const double _kGridMinScale = 0.15;
const double _kGridMaxScale = 5.0;
const double _kGridZoomFactor = 1.25;

void _plotGridZoom(TransformationController controller,
    {required bool zoomIn}) {
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

  final assignmentsList =
      ref.read(assignmentsForTrialProvider(trial.id)).value ?? [];
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
  int get _plotsPerRep =>
      (int.tryParse(_plotsPerRepController.text) ?? 8).clamp(1, 99);

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
              style:
                  TextStyle(fontSize: 13, color: AppDesignTokens.secondaryText),
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
          onPressed: () =>
              Navigator.pop(context, (reps: _reps, plotsPerRep: _plotsPerRep)),
          child: const Text('Add Plots'),
        ),
      ],
    );
  }
}

/// Pinned bar for navigating to plot details. Used as Scaffold.bottomNavigationBar when Plots tab uses unified scroll.
class PlotDetailsBar extends StatelessWidget {
  const PlotDetailsBar({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        color: AppDesignTokens.primary,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => _PlotDetailsScreen(trial: trial),
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
    );
  }
}

class PlotsTab extends ConsumerStatefulWidget {
  const PlotsTab({super.key, required this.trial, this.embeddedInScroll = false});

  final Trial trial;
  final bool embeddedInScroll;

  @override
  ConsumerState<PlotsTab> createState() => _PlotsTabState();
}

class _PlotsTabState extends ConsumerState<PlotsTab> {
  bool _showMatrix = false;

  @override
  Widget build(BuildContext context) {
    final trial = widget.trial;
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final treatmentsAsync = ref.watch(treatmentsForTrialProvider(trial.id));
    final assignmentsAsync = ref.watch(assignmentsForTrialProvider(trial.id));
    final sessionsAsync = ref.watch(sessionsForTrialProvider(trial.id));
    final sessionCount = sessionsAsync.value?.length ?? 0;
    final applicationsList =
        ref.watch(trialApplicationsForTrialProvider(trial.id)).value ?? [];
    final applicationCount = applicationsList.length;
    final lastApplication = applicationsList.isEmpty
        ? null
        : applicationsList.last;
    final treatmentComponentCount = ref
            .watch(treatmentComponentsCountForTrialProvider(trial.id))
            .valueOrNull ??
        0;
    final ratedPlotsCount =
        ref.watch(ratedPlotsCountForTrialProvider(trial.id)).valueOrNull ?? 0;
    final seedingEvent =
        ref.watch(seedingEventForTrialProvider(trial.id)).valueOrNull;
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
          if (widget.embeddedInScroll) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildListMatrixToggle(context),
                _buildPlotsSummaryRowsOnly(
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
                  lastApplication,
                  seedingDate,
                ),
              ],
            );
          }
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
            lastApplication,
            seedingDate,
          );
        }
        final treatments = treatmentsAsync.value ?? [];
        final assignmentsList = assignmentsAsync.value ?? [];
        final assignmentByPlotId = {for (var a in assignmentsList) a.plotId: a};
        final assignedCount = plots
            .where((p) =>
                (assignmentByPlotId[p.id]?.treatmentId ?? p.treatmentId) !=
                null)
            .length;
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
        if (widget.embeddedInScroll) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildListMatrixToggle(context),
              _showMatrix
                  ? _AssignmentMatrix(
                      trial: trial,
                      plots: plots,
                      shrinkWrap: true,
                    )
                  : _buildPlotsSummaryRowsOnly(
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
                      lastApplication,
                      seedingDate,
                    ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildListMatrixToggle(context),
            Expanded(
              child: _showMatrix
                  ? _AssignmentMatrix(trial: trial, plots: plots)
                  : _buildPlotsSummaryWithBar(
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
                      lastApplication,
                      seedingDate,
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListMatrixToggle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing8,
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing4,
      ),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
              value: false, label: Text('List'), icon: Icon(Icons.list)),
          ButtonSegment(
              value: true, label: Text('Matrix'), icon: Icon(Icons.grid_on)),
        ],
        selected: {_showMatrix},
        onSelectionChanged: (Set<bool> selected) {
          setState(() => _showMatrix = selected.first);
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.spacing12,
            vertical: AppDesignTokens.spacing8,
          )),
        ),
      ),
    );
  }

  /// Summary rows only (no scroll wrapper, no bottom bar). For use inside a parent scroll.
  Widget _buildPlotsSummaryRowsOnly(
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
    TrialApplicationEvent? lastApplication,
    DateTime? seedingDate,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
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
          if (trial.sponsor != null ||
              trial.protocolNumber != null ||
              trial.investigatorName != null) ...[
            const SizedBox(height: 8),
            _buildProtocolHeader(context, trial),
            const SizedBox(height: 8),
          ],
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
          _lastApplicationSummaryRow(context, lastApplication),
          _seedingDateSummaryRow(seedingDate),
        ],
      ),
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
    TrialApplicationEvent? lastApplication,
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
                if (trial.sponsor != null ||
                    trial.protocolNumber != null ||
                    trial.investigatorName != null) ...[
                  const SizedBox(height: 8),
                  _buildProtocolHeader(context, trial),
                  const SizedBox(height: 8),
                ],
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
                _lastApplicationSummaryRow(context, lastApplication),
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
                    builder: (_) => _PlotDetailsScreen(trial: trial),
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
                    Icon(Icons.arrow_forward_ios,
                        size: 14, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProtocolHeader(BuildContext context, Trial trial) {
    final lines = <String>[];
    if (trial.sponsor != null && trial.sponsor!.trim().isNotEmpty) {
      lines.add('Sponsor: ${trial.sponsor!.trim()}');
    }
    if (trial.protocolNumber != null &&
        trial.protocolNumber!.trim().isNotEmpty) {
      lines.add('Protocol: ${trial.protocolNumber!.trim()}');
    }
    if (trial.investigatorName != null &&
        trial.investigatorName!.trim().isNotEmpty) {
      lines.add('Investigator: ${trial.investigatorName!.trim()}');
    }
    if (lines.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing12,
          vertical: AppDesignTokens.spacing8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: lines
            .map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ))
            .toList(),
      ),
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

  Widget _applicationsSummaryRow(
      BuildContext context, Trial trial, int applicationCount) {
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

  Widget _lastApplicationSummaryRow(
      BuildContext context, TrialApplicationEvent? lastApplication) {
    String value = 'None';
    if (lastApplication != null) {
      value = DateFormat('MMM d, yyyy').format(lastApplication.applicationDate);
      if (lastApplication.applicationMethod != null &&
          lastApplication.applicationMethod!.trim().isNotEmpty) {
        value = '$value · ${lastApplication.applicationMethod!.trim()}';
      }
    }
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
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: lastApplication != null
                    ? AppDesignTokens.primaryText
                    : AppDesignTokens.secondaryText,
              ),
              textAlign: TextAlign.end,
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

/// Assignment matrix: plots grouped by rep, each cell shows plot label + treatment code; tap to assign.
/// When [shrinkWrap] is true, the matrix is used inside an unbounded scroll (e.g. trial detail Plots tab);
/// it must not use [Expanded] and instead uses [ListView] with [shrinkWrap: true].
class _AssignmentMatrix extends ConsumerWidget {
  const _AssignmentMatrix({
    required this.trial,
    required this.plots,
    this.shrinkWrap = false,
  });

  final Trial trial;
  final List<Plot> plots;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsList =
        ref.watch(assignmentsForTrialProvider(trial.id)).value ?? [];
    final treatments =
        ref.watch(treatmentsForTrialProvider(trial.id)).value ?? [];
    final assignmentByPlotId = {for (var a in assignmentsList) a.plotId: a};
    final treatmentById = {for (var t in treatments) t.id: t};

    if (plots.isEmpty) {
      return Center(
        child: Text(
          'No plots',
          style: TextStyle(
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final blocks = buildRepBasedLayout(plots);
    final listContent = ListView(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing4,
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing12,
      ),
      children: [
        for (final block in blocks)
          for (final repRow in block.repRows) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: AppDesignTokens.spacing12,
                bottom: AppDesignTokens.spacing8,
              ),
              child: Text(
                'Rep ${repRow.repNumber}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Wrap(
              spacing: AppDesignTokens.spacing8,
              runSpacing: AppDesignTokens.spacing8,
              children: repRow.plots.map((plot) {
                final a = assignmentByPlotId[plot.id];
                final tid = a?.treatmentId ?? plot.treatmentId;
                final treatment = tid != null ? treatmentById[tid] : null;
                final code = treatment?.code ?? '—';
                final treatmentIndex = tid != null
                    ? treatments.indexWhere((t) => t.id == tid)
                    : null;
                return _AssignmentMatrixCell(
                  plot: plot,
                  treatmentCode: code,
                  treatmentIndex: treatmentIndex,
                  trial: trial,
                  plots: plots,
                );
              }).toList(),
            ),
          ],
      ],
    );

    if (shrinkWrap) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          listContent,
          _AssignmentMatrixLegend(treatments: treatments),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: listContent),
        _AssignmentMatrixLegend(treatments: treatments),
      ],
    );
  }
}

/// One shared legend below the matrix: treatment code (chip) + name. Keeps cells compact.
class _AssignmentMatrixLegend extends StatelessWidget {
  const _AssignmentMatrixLegend({required this.treatments});

  final List<Treatment> treatments;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing12,
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing16,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Treatment legend',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing8),
          if (treatments.isEmpty)
            Text(
              'No treatments defined',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            ...treatments
                .map((t) => _TreatmentLegendRow(code: t.code, name: t.name)),
        ],
      ),
    );
  }
}

/// One row in the legend: [code] name.
class _TreatmentLegendRow extends StatelessWidget {
  const _TreatmentLegendRow({required this.code, required this.name});

  final String code;
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDesignTokens.spacing8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusXSmall),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              code,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: AppDesignTokens.spacing8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single plot cell in the assignment matrix: label + treatment code; tap opens assign dialog.
class _AssignmentMatrixCell extends ConsumerWidget {
  const _AssignmentMatrixCell({
    required this.plot,
    required this.treatmentCode,
    required this.trial,
    required this.plots,
    this.treatmentIndex,
  });

  final Plot plot;
  final String treatmentCode;
  final Trial trial;
  final List<Plot> plots;
  final int? treatmentIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = getDisplayPlotLabel(plot, plots);
    Color bg = scheme.surface;
    if (treatmentIndex != null && treatmentIndex! >= 0) {
      bg = scheme.primaryContainer.withValues(
        alpha: 0.12 + (treatmentIndex! % 3) * 0.04,
      );
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
      child: InkWell(
        onTap: () async {
          await showAssignTreatmentDialogForTrial(
            trial: trial,
            context: context,
            ref: ref,
            plot: plot,
            plots: plots,
          );
          ref.invalidate(assignmentsForTrialProvider(trial.id));
        },
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.spacing12,
            vertical: AppDesignTokens.spacing8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                treatmentCode,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plot Details sub-screen: List/Layout toggle, layer switcher, and full plot list or grid.
class _PlotDetailsScreen extends ConsumerStatefulWidget {
  final Trial trial;

  const _PlotDetailsScreen({required this.trial});

  @override
  ConsumerState<_PlotDetailsScreen> createState() => _PlotDetailsScreenState();
}

class _PlotDetailsScreenState extends ConsumerState<_PlotDetailsScreen> {
  bool _showLayoutView = false;
  _LayoutLayer _layoutLayer = _LayoutLayer.treatments;
  ApplicationEvent? _selectedAppEvent;
  List<ApplicationPlotRecord> _appPlotRecords = [];
  bool _loadingAppRecords = false;
  final TransformationController _gridTransformController =
      TransformationController();
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
    final viewportBox =
        _plotViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize) return;
    final viewportWidth = viewportBox.size.width;
    final viewportHeight = viewportBox.size.height;
    final gridBox =
        _gridContentKey.currentContext?.findRenderObject() as RenderBox?;
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
    final treatments =
        ref.watch(treatmentsForTrialProvider(widget.trial.id)).value ?? [];
    final sessions =
        ref.watch(sessionsForTrialProvider(widget.trial.id)).value ?? [];
    final assignmentsLocked =
        isAssignmentsLocked(widget.trial.status, sessions.isNotEmpty);
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
                ? const Center(
                    child: Text('Ratings overlay coming soon',
                        style: TextStyle(color: AppDesignTokens.secondaryText)))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (!_gridCenterScheduled) {
                        _gridCenterScheduled = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _centerGridOnFirstFrame(context, plots);
                        });
                      }
                      final size = MediaQuery.sizeOf(context);
                      final viewportWidth = constraints.maxWidth.isFinite &&
                              constraints.maxWidth > 0
                          ? constraints.maxWidth
                          : size.width;
                      final viewportHeight = constraints.maxHeight.isFinite &&
                              constraints.maxHeight > 0
                          ? constraints.maxHeight
                          : size.height;
                      final blocks = buildRepBasedLayout(plots);
                      int columnCount = 0;
                      for (final block in blocks) {
                        for (final row in block.repRows) {
                          if (row.plots.length > columnCount) {
                            columnCount = row.plots.length;
                          }
                        }
                      }
                      const double repLabelW = 52.0;
                      const double tileSpace = 6.0;
                      const double cellW = 56.0;
                      const double gridHorizontalPadding = 24.0;
                      const double gridWidthBuffer = 8.0;
                      final double rowContentWidth = columnCount > 0
                          ? repLabelW +
                              tileSpace +
                              columnCount * cellW +
                              (columnCount - 1) * tileSpace
                          : viewportWidth;
                      final double totalGridWidth = rowContentWidth +
                          gridHorizontalPadding +
                          gridWidthBuffer;
                      final double gridContentWidth =
                          totalGridWidth > viewportWidth
                              ? totalGridWidth
                              : viewportWidth;
                      final assignmentsList = ref
                              .watch(
                                  assignmentsForTrialProvider(widget.trial.id))
                              .value ??
                          [];
                      final plotIdToTreatmentIdMap = {
                        for (var a in assignmentsList) a.plotId: a.treatmentId
                      };
                      final applicationsList = ref
                              .watch(trialApplicationsForTrialProvider(
                                  widget.trial.id))
                              .value ??
                          [];
                      final treatmentIdsWithApp = applicationsList
                          .map((e) => e.treatmentId)
                          .whereType<int>()
                          .toSet();
                      final plotPksWithTrialApplication = <int>{};
                      for (final p in plots) {
                        final tid =
                            plotIdToTreatmentIdMap[p.id] ?? p.treatmentId;
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
                                transformationController:
                                    _gridTransformController,
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
                                    plotPksWithTrialApplication:
                                        plotPksWithTrialApplication,
                                    plotIdToTreatmentId: plotIdToTreatmentIdMap,
                                    onLongPressPlot: assignmentsLocked
                                        ? null
                                        : (plot) =>
                                            _showAssignTreatmentDialogForDetails(
                                                context, ref, plot, plots),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: AppDesignTokens.spacing12,
                              bottom: AppDesignTokens.spacing12,
                              child: Material(
                                elevation: 2,
                                borderRadius: BorderRadius.circular(
                                    AppDesignTokens.radiusSmall),
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
          Expanded(
              child: _buildPlotsListBodyForDetails(
                  context, ref, plots, assignmentsLocked)),
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
          ButtonSegment(
              value: _LayoutLayer.treatments,
              label: Text('Treats'),
              icon: Icon(Icons.science, size: 14)),
          ButtonSegment(
              value: _LayoutLayer.applications,
              label: Text('Apps'),
              icon: Icon(Icons.water_drop, size: 14)),
          ButtonSegment(
              value: _LayoutLayer.ratings,
              label: Text('Ratings'),
              icon: Icon(Icons.bar_chart, size: 14)),
        ],
        selected: {_layoutLayer},
        onSelectionChanged: (val) => setState(() => _layoutLayer = val.first),
      ),
    );
  }

  Widget _buildAppEventSelectorForDetails(BuildContext context, WidgetRef ref) {
    final eventsAsync =
        ref.watch(applicationsForTrialProvider(widget.trial.id));
    return eventsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (events) {
        if (events.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('No application events recorded yet',
                style: TextStyle(
                    color: AppDesignTokens.secondaryText, fontSize: 13)),
          );
        }
        final completed = events.where((e) => e.status == 'completed').toList();
        if (completed.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('No completed application events yet',
                style: TextStyle(
                    color: AppDesignTokens.secondaryText, fontSize: 13)),
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
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  initialValue: _selectedAppEvent == null
                      ? null
                      : completed
                              .where((e) => e.id == _selectedAppEvent!.id)
                              .firstOrNull ??
                          completed.first,
                  items: completed
                      .map((e) => DropdownMenuItem<ApplicationEvent>(
                            value: e,
                            child: Text(
                                'A${e.applicationNumber} — ${e.timingLabel ?? e.method}'),
                          ))
                      .toList(),
                  onChanged: (e) {
                    if (e != null) _loadAppRecords(e);
                  },
                ),
              ),
              if (_loadingAppRecords)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListLayoutToggleForDetails(
      BuildContext context, WidgetRef ref, List<Plot> plots) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing16,
          vertical: AppDesignTokens.spacing8),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false, label: Text('List'), icon: Icon(Icons.list)),
                ButtonSegment(
                    value: true,
                    label: Text('Layout'),
                    icon: Icon(Icons.grid_on)),
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

  Widget _buildPlotsHeaderForDetails(BuildContext context, WidgetRef ref,
      List<Plot> plots, bool assignmentsLocked) {
    final sessions =
        ref.watch(sessionsForTrialProvider(widget.trial.id)).value ?? [];
    final message =
        getAssignmentsLockMessage(widget.trial.status, sessions.isNotEmpty);
    final assignmentsList =
        ref.watch(assignmentsForTrialProvider(widget.trial.id)).value ?? [];
    final assignmentByPlotId = {for (var a in assignmentsList) a.plotId: a};
    final assignedCount = plots
        .where((p) =>
            (assignmentByPlotId[p.id]?.treatmentId ?? p.treatmentId) != null)
        .length;
    final unassignedCount = plots.length - assignedCount;
    final summaryLine = plots.isEmpty
        ? 'No plots'
        : unassignedCount == 0
            ? 'All $assignedCount assigned'
            : '$assignedCount assigned · $unassignedCount unassigned';
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing16,
          vertical: AppDesignTokens.spacing8),
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
                      borderRadius:
                          BorderRadius.circular(AppDesignTokens.radiusXSmall),
                    ),
                    child: const Icon(Icons.grid_on,
                        size: 20, color: AppDesignTokens.primary),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: assignmentsLocked
                            ? AppDesignTokens.secondaryText
                            : AppDesignTokens.primary,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          assignmentsLocked
                              ? Icons.lock_outlined
                              : Icons.lock_open_outlined,
                          size: 14,
                          color: assignmentsLocked
                              ? AppDesignTokens.secondaryText
                              : AppDesignTokens.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          assignmentsLocked ? 'Locked' : 'Editable',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: assignmentsLocked
                                ? AppDesignTokens.secondaryText
                                : AppDesignTokens.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: assignmentsLocked
                        ? message
                        : 'Assign treatments to multiple plots',
                    child: OutlinedButton.icon(
                      onPressed: assignmentsLocked
                          ? null
                          : () => _showBulkAssignSheet(
                              context, ref, widget.trial, plots),
                      icon: Icon(
                        Icons.grid_view,
                        size: 18,
                        color: assignmentsLocked
                            ? AppDesignTokens.iconSubtle
                            : AppDesignTokens.primary,
                      ),
                      label: const Text('Bulk Assign'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: assignmentsLocked
                            ? AppDesignTokens.secondaryText
                            : AppDesignTokens.primary,
                        side: BorderSide(
                          color: assignmentsLocked
                              ? AppDesignTokens.iconSubtle
                              : AppDesignTokens.primary,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
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

  Widget _buildPlotsListBodyForDetails(BuildContext context, WidgetRef ref,
      List<Plot> plots, bool assignmentsLocked) {
    final sessions =
        ref.watch(sessionsForTrialProvider(widget.trial.id)).value ?? [];
    final assignmentsLockMessage =
        getAssignmentsLockMessage(widget.trial.status, sessions.isNotEmpty);
    final treatments =
        ref.watch(treatmentsForTrialProvider(widget.trial.id)).value ?? [];
    final treatmentMap = {for (final t in treatments) t.id: t};
    final assignmentsList =
        ref.watch(assignmentsForTrialProvider(widget.trial.id)).value ?? [];
    final assignmentByPlotId = {for (var a in assignmentsList) a.plotId: a};
    return ListView.builder(
      itemCount: plots.length,
      itemBuilder: (context, index) {
        final plot = plots[index];
        final assignment = assignmentByPlotId[plot.id];
        final effectiveTreatmentId =
            assignment?.treatmentId ?? plot.treatmentId;
        final effectiveSource =
            assignment?.assignmentSource ?? plot.assignmentSource;
        final displayNum = getDisplayPlotLabel(plot, plots);
        final treatmentLabel = getTreatmentDisplayLabel(plot, treatmentMap,
            treatmentIdOverride: effectiveTreatmentId);
        final sourceLabel = getAssignmentSourceLabel(
            treatmentId: effectiveTreatmentId,
            assignmentSource: effectiveSource);
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
                  horizontal: AppDesignTokens.spacing8,
                  vertical: AppDesignTokens.spacing4),
              decoration: BoxDecoration(
                color: AppDesignTokens.primary,
                borderRadius:
                    BorderRadius.circular(AppDesignTokens.radiusXSmall),
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
                        fontWeight: effectiveTreatmentId != null
                            ? FontWeight.w600
                            : FontWeight.w400,
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

  void _showBulkAssignSheet(
      BuildContext context, WidgetRef ref, Trial trial, List<Plot> plots) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BulkAssignSheet(trial: trial, plots: plots),
    );
  }
}

/// Bottom sheet: Mode 1 — RCBD randomisation; Mode 2 — Manual multi-select.
class _BulkAssignSheet extends ConsumerStatefulWidget {
  const _BulkAssignSheet({required this.trial, required this.plots});

  final Trial trial;
  final List<Plot> plots;

  @override
  ConsumerState<_BulkAssignSheet> createState() => _BulkAssignSheetState();
}

class _BulkAssignSheetState extends ConsumerState<_BulkAssignSheet> {
  bool _showManualSelect = false;
  String? _rcbdError;
  final Set<int> _selectedPlotIds = {};
  int? _selectedTreatmentId;

  @override
  Widget build(BuildContext context) {
    if (_showManualSelect) {
      return _buildManualSelectContent(context);
    }
    return _buildModeChoiceContent(context);
  }

  Widget _buildModeChoiceContent(BuildContext context) {
    final treatments =
        ref.read(treatmentsForTrialProvider(widget.trial.id)).value ?? [];
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.25,
      maxChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(AppDesignTokens.spacing16),
          child: ListView(
            controller: scrollController,
            shrinkWrap: true,
            children: [
              Text(
                'Bulk Assign',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (_rcbdError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Theme.of(context).colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _rcbdError!,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _runRcbdRandomisation(context, treatments),
                icon: const Icon(Icons.shuffle, size: 20),
                label: const Text('Randomise assignments'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showManualSelect = true;
                    _rcbdError = null;
                  });
                },
                icon: const Icon(Icons.checklist_rtl, size: 20),
                label: const Text('Select plots manually'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runRcbdRandomisation(
      BuildContext context, List<Treatment> treatments) async {
    if (treatments.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No treatments defined yet. Add treatments first.')),
      );
      return;
    }
    final blocks = buildRepBasedLayout(widget.plots);
    if (blocks.isEmpty) return;
    int? plotsPerRep;
    for (final block in blocks) {
      for (final repRow in block.repRows) {
        final n = repRow.plots.length;
        if (plotsPerRep != null && n != plotsPerRep) {
          setState(() {
            _rcbdError =
                'Plot count per rep must be equal across all reps for RCBD randomisation.';
          });
          return;
        }
        plotsPerRep = n;
      }
    }
    if (plotsPerRep == null || plotsPerRep != treatments.length) {
      setState(() {
        _rcbdError =
            'Plot count per rep must equal treatment count for RCBD randomisation. Currently $plotsPerRep plots per rep, ${treatments.length} treatments.';
      });
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Overwrite assignments?'),
        content: const Text(
          'This will overwrite all existing assignments. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final treatmentIds = treatments.map((t) => t.id).toList();
    final plotPkToTreatmentId = <int, int?>{};
    for (final block in blocks) {
      for (final repRow in block.repRows) {
        final shuffled = List<int>.from(treatmentIds)
          ..shuffle(Random(repRow.repNumber + widget.trial.id));
        for (var i = 0; i < repRow.plots.length; i++) {
          plotPkToTreatmentId[repRow.plots[i].id] = shuffled[i];
        }
      }
    }
    final useCase = ref.read(updatePlotAssignmentUseCaseProvider);
    final result = await useCase.updateBulk(
      trial: widget.trial,
      plotPkToTreatmentId: plotPkToTreatmentId,
    );
    if (!context.mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Update failed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    ref.invalidate(trialReadinessProvider(widget.trial.id));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Assignments randomised (RCBD)')),
    );
  }

  Widget _buildManualSelectContent(BuildContext context) {
    final treatments =
        ref.read(treatmentsForTrialProvider(widget.trial.id)).value ?? [];
    final assignmentsList =
        ref.read(assignmentsForTrialProvider(widget.trial.id)).value ?? [];
    final assignmentByPlotId = {for (var a in assignmentsList) a.plotId: a};
    final treatmentMap = {for (final t in treatments) t.id: t};
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(AppDesignTokens.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() {
                        _showManualSelect = false;
                        _selectedPlotIds.clear();
                        _selectedTreatmentId = null;
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      'Select plots manually',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: widget.plots.length,
                  itemBuilder: (context, index) {
                    final plot = widget.plots[index];
                    final assignment = assignmentByPlotId[plot.id];
                    final currentId =
                        assignment?.treatmentId ?? plot.treatmentId;
                    final currentCode = currentId != null
                        ? (treatmentMap[currentId]?.code ?? '—')
                        : '—';
                    final selected = _selectedPlotIds.contains(plot.id);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedPlotIds.add(plot.id);
                          } else {
                            _selectedPlotIds.remove(plot.id);
                          }
                        });
                      },
                      title: Text(
                        getDisplayPlotLabel(plot, widget.plots),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        currentCode,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey<int?>(_selectedTreatmentId),
                      initialValue: _selectedTreatmentId,
                      decoration: const InputDecoration(
                        labelText: 'Assign to selected',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('—')),
                        ...treatments.map((t) => DropdownMenuItem<int?>(
                              value: t.id,
                              child: Text('${t.code} — ${t.name}',
                                  overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedTreatmentId = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => _applyManualSelection(
                        context, treatments, treatmentMap),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _applyManualSelection(
    BuildContext context,
    List<Treatment> treatments,
    Map<int, Treatment> treatmentMap,
  ) async {
    if (_selectedPlotIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one plot')),
      );
      return;
    }
    if (_selectedTreatmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a treatment')),
      );
      return;
    }
    final plotPkToTreatmentId = {
      for (final id in _selectedPlotIds) id: _selectedTreatmentId
    };
    final useCase = ref.read(updatePlotAssignmentUseCaseProvider);
    final result = await useCase.updateBulk(
      trial: widget.trial,
      plotPkToTreatmentId: plotPkToTreatmentId,
    );
    if (!context.mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Update failed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final code = treatmentMap[_selectedTreatmentId]?.code ?? '?';
    ref.invalidate(trialReadinessProvider(widget.trial.id));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('${_selectedPlotIds.length} plots assigned to $code')),
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
        if (plotPksWithTrialApplication!.contains(plot.id)) {
          return AppDesignTokens.appliedColor;
        }
        final treatmentIndex =
            treatments.indexWhere((t) => t.id == effectiveTid);
        return treatmentIndex >= 0
            ? AppDesignTokens.treatmentPalette[
                treatmentIndex % AppDesignTokens.treatmentPalette.length]
            : AppDesignTokens.unassignedColor;
      }
      final record =
          appPlotRecords.where((r) => r.plotPk == plot.id).firstOrNull;
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
                          _legendChip(
                              AppDesignTokens.unassignedColor, 'Unassigned'),
                        ]
                      : [
                          _legendChip(AppDesignTokens.appliedColor, 'Applied'),
                          _legendChip(AppDesignTokens.skippedColor, 'Skipped'),
                          _legendChip(AppDesignTokens.missedColor, 'Missed'),
                          _legendChip(
                              AppDesignTokens.noRecordColor, 'No record'),
                        ],
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    ...treatments.asMap().entries.map((entry) {
                      final color = AppDesignTokens.treatmentPalette[
                          entry.key % AppDesignTokens.treatmentPalette.length];
                      return _legendChip(
                          color, '${entry.value.code} ${entry.value.name}');
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

  Widget _buildRepBasedGrid(
      BuildContext context, Map<int, Treatment> treatmentMap) {
    final blocks = buildRepBasedLayout(plots);
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0;
        final contentHeight =
            hasBoundedHeight ? constraints.maxHeight - 16 : null;
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
                                  for (var i = 0;
                                      i < repRow.plots.length;
                                      i++) ...[
                                    if (i > 0)
                                      const SizedBox(width: _tileSpacing),
                                    SizedBox(
                                      width: cellSize,
                                      height: cellSize,
                                      child: _PlotGridTile(
                                        plot: repRow.plots[i],
                                        treatmentMap: treatmentMap,
                                        treatments: treatments,
                                        trial: trial,
                                        tileColor:
                                            _tileColorFor(repRow.plots[i]),
                                        treatmentIdOverride:
                                            plotIdToTreatmentId?[
                                                    repRow.plots[i].id] ??
                                                repRow.plots[i].treatmentId,
                                        displayLabel: getDisplayPlotLabel(
                                            repRow.plots[i], plots),
                                        onLongPress: onLongPressPlot != null
                                            ? () => onLongPressPlot!(
                                                repRow.plots[i])
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
  ConsumerState<_PlotsFullScreenPage> createState() =>
      _PlotsFullScreenPageState();
}

class _PlotsFullScreenPageState extends ConsumerState<_PlotsFullScreenPage> {
  late _LayoutLayer _layoutLayer;
  ApplicationEvent? _selectedAppEvent;
  List<ApplicationPlotRecord> _appPlotRecords = [];
  bool _loadingAppRecords = false;
  final TransformationController _gridTransformController =
      TransformationController();
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
    final viewportBox =
        _plotViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize) return;
    final viewportWidth = viewportBox.size.width;
    final viewportHeight = viewportBox.size.height;
    final gridBox =
        _gridContentKey.currentContext?.findRenderObject() as RenderBox?;
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
          final sessions =
              ref.watch(sessionsForTrialProvider(widget.trial.id)).value ?? [];
          final assignmentsLocked =
              isAssignmentsLocked(widget.trial.status, sessions.isNotEmpty);
          if (!widget.isLayoutView) {
            return _buildListBody(context, ref, plots, assignmentsLocked);
          }
          final treatments =
              ref.watch(treatmentsForTrialProvider(widget.trial.id)).value ??
                  [];
          final assignments =
              ref.watch(assignmentsForTrialProvider(widget.trial.id)).value ??
                  [];
          final Map<int, int?> plotIdToTreatmentId = {
            for (final a in assignments) a.plotId: a.treatmentId
          };
          const double maxTopHeight = 200;
          final topSection = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SegmentedButton<_LayoutLayer>(
                  style: const ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(
                        value: _LayoutLayer.treatments,
                        label: Text('Treats'),
                        icon: Icon(Icons.science, size: 14)),
                    ButtonSegment(
                        value: _LayoutLayer.applications,
                        label: Text('Apps'),
                        icon: Icon(Icons.water_drop, size: 14)),
                    ButtonSegment(
                        value: _LayoutLayer.ratings,
                        label: Text('Ratings'),
                        icon: Icon(Icons.bar_chart, size: 14)),
                  ],
                  selected: {_layoutLayer},
                  onSelectionChanged: (val) =>
                      setState(() => _layoutLayer = val.first),
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
                    ? const Center(
                        child: Text('Ratings overlay coming soon',
                            style: TextStyle(
                                color: AppDesignTokens.secondaryText)))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (!_gridCenterScheduled) {
                            _gridCenterScheduled = true;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _centerGridOnFirstFrame(context, plots);
                            });
                          }
                          final size = MediaQuery.sizeOf(context);
                          final viewportWidth = constraints.maxWidth.isFinite &&
                                  constraints.maxWidth > 0
                              ? constraints.maxWidth
                              : size.width;
                          final viewportHeight =
                              constraints.maxHeight.isFinite &&
                                      constraints.maxHeight > 0
                                  ? constraints.maxHeight
                                  : size.height;
                          final blocks = buildRepBasedLayout(plots);
                          int columnCount = 0;
                          for (final block in blocks) {
                            for (final row in block.repRows) {
                              if (row.plots.length > columnCount) {
                                columnCount = row.plots.length;
                              }
                            }
                          }
                          const double repLabelW = 52.0;
                          const double tileSpace = 6.0;
                          const double cellW = 56.0;
                          const double gridHorizontalPadding =
                              24.0; // 12 + 12 from Padding in _buildRepBasedGrid
                          const double gridWidthBuffer =
                              8.0; // avoid last column clipping from rounding
                          final double rowContentWidth = columnCount > 0
                              ? repLabelW +
                                  tileSpace +
                                  columnCount * cellW +
                                  (columnCount - 1) * tileSpace
                              : viewportWidth;
                          final double totalGridWidth = rowContentWidth +
                              gridHorizontalPadding +
                              gridWidthBuffer;
                          final double gridContentWidth =
                              totalGridWidth > viewportWidth
                                  ? totalGridWidth
                                  : viewportWidth;
                          final applicationsList = ref
                                  .watch(trialApplicationsForTrialProvider(
                                      widget.trial.id))
                                  .value ??
                              [];
                          final treatmentIdsWithApp = applicationsList
                              .map((e) => e.treatmentId)
                              .whereType<int>()
                              .toSet();
                          final plotPksWithTrialApplication = <int>{};
                          for (final p in plots) {
                            final tid =
                                plotIdToTreatmentId[p.id] ?? p.treatmentId;
                            if (tid != null &&
                                treatmentIdsWithApp.contains(tid)) {
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
                                    transformationController:
                                        _gridTransformController,
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
                                        plotPksWithTrialApplication:
                                            plotPksWithTrialApplication,
                                        plotIdToTreatmentId:
                                            plotIdToTreatmentId,
                                        onLongPressPlot: assignmentsLocked
                                            ? null
                                            : (plot) => _showAssignDialog(
                                                context, ref, plot, plots),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: AppDesignTokens.spacing12,
                                  bottom: AppDesignTokens.spacing12,
                                  child: Material(
                                    elevation: 2,
                                    borderRadius: BorderRadius.circular(
                                        AppDesignTokens.radiusSmall),
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
    final eventsAsync =
        ref.watch(applicationsForTrialProvider(widget.trial.id));
    return eventsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (events) {
        final completed = events.where((e) => e.status == 'completed').toList();
        if (completed.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('No completed application events yet',
                style: TextStyle(
                    color: AppDesignTokens.secondaryText, fontSize: 13)),
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
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  initialValue: _selectedAppEvent == null
                      ? null
                      : completed
                              .where((e) => e.id == _selectedAppEvent!.id)
                              .firstOrNull ??
                          completed.first,
                  items: completed
                      .map((e) => DropdownMenuItem<ApplicationEvent>(
                            value: e,
                            child: Text(
                                'A${e.applicationNumber} — ${e.timingLabel ?? e.method}'),
                          ))
                      .toList(),
                  onChanged: (e) {
                    if (e != null) _loadAppRecords(e);
                  },
                ),
              ),
              if (_loadingAppRecords)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListBody(BuildContext context, WidgetRef ref, List<Plot> plots,
      bool assignmentsLocked) {
    final sessions =
        ref.watch(sessionsForTrialProvider(widget.trial.id)).value ?? [];
    final assignmentsLockMessage =
        getAssignmentsLockMessage(widget.trial.status, sessions.isNotEmpty);
    final treatments =
        ref.watch(treatmentsForTrialProvider(widget.trial.id)).value ?? [];
    final treatmentMap = {for (final t in treatments) t.id: t};
    final assignmentsList =
        ref.watch(assignmentsForTrialProvider(widget.trial.id)).value ?? [];
    final assignmentByPlotId = {for (var a in assignmentsList) a.plotId: a};
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: plots.length,
      itemBuilder: (context, index) {
        final plot = plots[index];
        final assignment = assignmentByPlotId[plot.id];
        final effectiveTreatmentId =
            assignment?.treatmentId ?? plot.treatmentId;
        final effectiveSource =
            assignment?.assignmentSource ?? plot.assignmentSource;
        final displayNum = getDisplayPlotLabel(plot, plots);
        final treatmentLabel = getTreatmentDisplayLabel(plot, treatmentMap,
            treatmentIdOverride: effectiveTreatmentId);
        final sourceLabel = getAssignmentSourceLabel(
            treatmentId: effectiveTreatmentId,
            assignmentSource: effectiveSource);
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
                      color: effectiveTreatmentId != null
                          ? Theme.of(context).colorScheme.primary
                          : AppDesignTokens.secondaryText,
                      fontWeight:
                          effectiveTreatmentId != null ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                if (sourceLabel != 'Unknown' && sourceLabel != 'Unassigned')
                  Text(sourceLabel,
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppDesignTokens.secondaryText,
                          fontStyle: FontStyle.italic)),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      PlotDetailScreen(trial: widget.trial, plot: plot)),
            ),
            onLongPress: () {
              if (assignmentsLocked) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(assignmentsLockMessage)));
                return;
              }
              _showAssignDialog(context, ref, plot, plots);
            },
          ),
        );
      },
    );
  }

  Future<void> _showAssignDialog(
      BuildContext context, WidgetRef ref, Plot plot, List<Plot> plots) async {
    return showAssignTreatmentDialogForTrial(
      trial: widget.trial,
      context: context,
      ref: ref,
      plot: plot,
      plots: plots,
    );
  }
}
