import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/plot_display.dart';
import '../../../core/providers.dart';
import '../plot_layout_model.dart';

const double _kRepLabelWidth = 52.0;
const double _kCellSize = 56.0;
const double _kTileSpacing = 6.0;

enum AssistantFilter { all, remaining, done }

/// Returns plots filtered according to [filter].
///
/// [all] returns [allTrialPlots].
/// [remaining] returns current-treatment plots not yet in [tappedPks].
/// [done] returns current-treatment plots already in [tappedPks].
List<Plot> applyAssistantFilter({
  required AssistantFilter filter,
  required List<Plot> allTrialPlots,
  required List<Plot> currentTreatmentPlots,
  required Set<int> tappedPks,
}) {
  switch (filter) {
    case AssistantFilter.all:
      return allTrialPlots;
    case AssistantFilter.remaining:
      return currentTreatmentPlots
          .where((p) => !tappedPks.contains(p.id))
          .toList();
    case AssistantFilter.done:
      return currentTreatmentPlots
          .where((p) => tappedPks.contains(p.id))
          .toList();
  }
}

/// Returns the subset of [allTrialPlots] assigned to [targetTreatmentId].
///
/// Assignment resolution: plotIdToTreatmentId first, then plot.treatmentId.
List<Plot> plotsForTreatment({
  required List<Plot> allTrialPlots,
  required Map<int, int?> plotIdToTreatmentId,
  required int? targetTreatmentId,
}) {
  if (targetTreatmentId == null) return [];
  return allTrialPlots.where((p) {
    final tid = plotIdToTreatmentId[p.id] ?? p.treatmentId;
    return tid == targetTreatmentId;
  }).toList();
}

/// Number of tapped plots that belong to [currentTreatmentPlots].
int assistantProgressCount(Set<int> tappedPks, List<Plot> currentTreatmentPlots) {
  return tappedPks
      .where((pk) => currentTreatmentPlots.any((p) => p.id == pk))
      .length;
}

/// Guided application assistant screen.
///
/// Activated from a pending [TrialApplicationEvent]. The tech taps plots to
/// track which ones have been treated (ephemeral UI state only). When done,
/// [onMarkAsApplied] is called, which triggers the existing apply flow.
class ApplicationAssistantScreen extends ConsumerStatefulWidget {
  const ApplicationAssistantScreen({
    super.key,
    required this.trial,
    required this.applicationEvent,
    required this.onMarkAsApplied,
  });

  final Trial trial;
  final TrialApplicationEvent applicationEvent;

  /// Called after the user taps "Mark as Applied". Triggers the existing
  /// _showApplySheet / mark-applied flow in the calling widget.
  final VoidCallback onMarkAsApplied;

  @override
  ConsumerState<ApplicationAssistantScreen> createState() =>
      _ApplicationAssistantScreenState();
}

class _ApplicationAssistantScreenState
    extends ConsumerState<ApplicationAssistantScreen> {
  final Set<int> _tappedPlotPks = {};
  AssistantFilter _filter = AssistantFilter.all;

  Future<void> _handleBackPress() async {
    if (_tappedPlotPks.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave without saving?'),
        content: const Text(
          'Your tap progress will be lost. The pending application will remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.applicationEvent;
    final plots =
        ref.watch(plotsForTrialProvider(widget.trial.id)).valueOrNull ?? [];
    final assignments =
        ref.watch(assignmentsForTrialProvider(widget.trial.id)).valueOrNull ??
            [];
    final treatments =
        ref.watch(treatmentsForTrialProvider(widget.trial.id)).valueOrNull ??
            [];
    final products =
        ref.watch(trialApplicationProductsForEventProvider(event.id)).valueOrNull ??
            [];

    final treatmentMap = {for (final t in treatments) t.id: t};
    final plotIdToTreatmentId = {
      for (final a in assignments) a.plotId: a.treatmentId,
    };

    final currentTreatmentPlots = plotsForTreatment(
      allTrialPlots: plots,
      plotIdToTreatmentId: plotIdToTreatmentId,
      targetTreatmentId: event.treatmentId,
    );
    final tappedCount =
        assistantProgressCount(_tappedPlotPks, currentTreatmentPlots);

    final treatment =
        event.treatmentId != null ? treatmentMap[event.treatmentId] : null;
    final treatmentLabel = treatment != null
        ? (treatment.name.isNotEmpty
            ? '${treatment.code} — ${treatment.name}'
            : treatment.code)
        : 'No treatment linked';

    final displayPlots = applyAssistantFilter(
      filter: _filter,
      allTrialPlots: plots,
      currentTreatmentPlots: currentTreatmentPlots,
      tappedPks: _tappedPlotPks,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: AppDesignTokens.backgroundSurface,
        appBar: AppBar(
          backgroundColor: const Color(0xFF2D5A40),
          foregroundColor: Colors.white,
          title: const Text('Application Assistant'),
          leading: BackButton(onPressed: _handleBackPress),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TreatmentHeader(
              treatmentLabel: treatmentLabel,
              products: products,
              tappedCount: tappedCount,
              totalTarget: currentTreatmentPlots.length,
            ),
            _FilterChipRow(
              filter: _filter,
              onFilterChanged: (f) => setState(() => _filter = f),
            ),
            Expanded(
              child: displayPlots.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          switch (_filter) {
                            AssistantFilter.remaining =>
                              'All current-treatment plots have been tapped.',
                            AssistantFilter.done => 'No plots tapped yet.',
                            AssistantFilter.all => 'No plots in this trial.',
                          },
                          style: const TextStyle(
                            color: AppDesignTokens.secondaryText,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _AssistantPlotGrid(
                      plots: displayPlots,
                      allTrialPlots: plots,
                      treatments: treatments,
                      treatmentMap: treatmentMap,
                      plotIdToTreatmentId: plotIdToTreatmentId,
                      currentTreatmentId: event.treatmentId,
                      tappedPlotPks: _tappedPlotPks,
                      onTapPlot: (plot) => _onTapPlot(
                        plot,
                        treatment,
                        treatmentMap,
                        plotIdToTreatmentId,
                      ),
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Mark as Applied'),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onMarkAsApplied();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTapPlot(
    Plot plot,
    Treatment? currentTreatment,
    Map<int, Treatment> treatmentMap,
    Map<int, int?> plotIdToTreatmentId,
  ) {
    final effectiveTid =
        plotIdToTreatmentId[plot.id] ?? plot.treatmentId;
    final isCurrentTreatment =
        effectiveTid == widget.applicationEvent.treatmentId;

    if (!isCurrentTreatment) {
      final otherTreatment =
          effectiveTid != null ? treatmentMap[effectiveTid] : null;
      final currentCode =
          currentTreatment?.code ?? 'current treatment';
      final otherCode = otherTreatment?.code ??
          (effectiveTid != null ? '(removed)' : 'unassigned');
      final displayLabel = getDisplayPlotLabel(
          plot,
          ref
                  .read(plotsForTrialProvider(widget.trial.id))
                  .valueOrNull ??
              []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Plot $displayLabel is $otherCode, not $currentCode'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      if (_tappedPlotPks.contains(plot.id)) {
        _tappedPlotPks.remove(plot.id);
      } else {
        _tappedPlotPks.add(plot.id);
      }
    });
  }
}

// ─── Treatment Header ─────────────────────────────────────────────────────────

class _TreatmentHeader extends StatelessWidget {
  const _TreatmentHeader({
    required this.treatmentLabel,
    required this.products,
    required this.tappedCount,
    required this.totalTarget,
  });

  final String treatmentLabel;
  final List<TrialApplicationProduct> products;
  final int tappedCount;
  final int totalTarget;

  @override
  Widget build(BuildContext context) {
    final progressLabel = totalTarget > 0
        ? '$tappedCount of $totalTarget plots tapped'
        : 'No plots assigned to this treatment';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: const BoxDecoration(
        color: AppDesignTokens.sectionHeaderBg,
        border:
            Border(bottom: BorderSide(color: AppDesignTokens.borderCrisp)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.science_outlined,
                  size: 16,
                  color: AppDesignTokens.primary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  treatmentLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppDesignTokens.primaryText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (products.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...products.map(_buildProductLine),
          ],
          const SizedBox(height: 8),
          _ProgressBar(tapped: tappedCount, total: totalTarget),
          const SizedBox(height: 4),
          Text(
            progressLabel,
            style: const TextStyle(
              fontSize: 12,
              color: AppDesignTokens.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductLine(TrialApplicationProduct p) {
    final rate = (p.rate != null && p.rateUnit != null)
        ? '${p.rate} ${p.rateUnit}'
        : (p.rate != null ? '${p.rate}' : null);
    final label = rate != null ? '${p.productName} · $rate' : p.productName;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppDesignTokens.secondaryText,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.tapped, required this.total});

  final int tapped;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction =
        total > 0 ? (tapped / total).clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 6,
        backgroundColor: AppDesignTokens.borderCrisp,
        valueColor: const AlwaysStoppedAnimation<Color>(
            AppDesignTokens.appliedColor),
      ),
    );
  }
}

// ─── Filter Chips ─────────────────────────────────────────────────────────────

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({
    required this.filter,
    required this.onFilterChanged,
  });

  final AssistantFilter filter;
  final void Function(AssistantFilter) onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: AssistantFilter.values.map((f) {
          final selected = filter == f;
          final label = switch (f) {
            AssistantFilter.all => 'All',
            AssistantFilter.remaining => 'Remaining',
            AssistantFilter.done => 'Done',
          };
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => onFilterChanged(f),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Plot Grid ────────────────────────────────────────────────────────────────

class _AssistantPlotGrid extends StatelessWidget {
  const _AssistantPlotGrid({
    required this.plots,
    required this.allTrialPlots,
    required this.treatments,
    required this.treatmentMap,
    required this.plotIdToTreatmentId,
    required this.currentTreatmentId,
    required this.tappedPlotPks,
    required this.onTapPlot,
  });

  final List<Plot> plots;
  final List<Plot> allTrialPlots;
  final List<Treatment> treatments;
  final Map<int, Treatment> treatmentMap;
  final Map<int, int?> plotIdToTreatmentId;
  final int? currentTreatmentId;
  final Set<int> tappedPlotPks;
  final void Function(Plot) onTapPlot;

  @override
  Widget build(BuildContext context) {
    if (plots.isEmpty) return const SizedBox.shrink();
    final blocks = buildRepBasedLayout(plots);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final block in blocks)
            for (final repRow in block.repRows.reversed.toList())
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  height: _kCellSize + 2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: _kRepLabelWidth,
                        height: _kCellSize + 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Rep ${repRow.repNumber}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppDesignTokens.secondaryText,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: _kTileSpacing),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < repRow.plots.length; i++) ...[
                            if (i > 0)
                              const SizedBox(width: _kTileSpacing),
                            SizedBox(
                              width: _kCellSize,
                              height: _kCellSize,
                              child: _AssistantPlotTile(
                                plot: repRow.plots[i],
                                treatmentMap: treatmentMap,
                                treatments: treatments,
                                plotIdToTreatmentId: plotIdToTreatmentId,
                                currentTreatmentId: currentTreatmentId,
                                isTapped: tappedPlotPks
                                    .contains(repRow.plots[i].id),
                                displayLabel: getDisplayPlotLabel(
                                    repRow.plots[i], allTrialPlots),
                                onTap: () => onTapPlot(repRow.plots[i]),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// ─── Plot Tile ────────────────────────────────────────────────────────────────

class _AssistantPlotTile extends StatefulWidget {
  const _AssistantPlotTile({
    required this.plot,
    required this.treatmentMap,
    required this.treatments,
    required this.plotIdToTreatmentId,
    required this.currentTreatmentId,
    required this.isTapped,
    required this.displayLabel,
    required this.onTap,
  });

  final Plot plot;
  final Map<int, Treatment> treatmentMap;
  final List<Treatment> treatments;
  final Map<int, int?> plotIdToTreatmentId;
  final int? currentTreatmentId;
  final bool isTapped;
  final String displayLabel;
  final VoidCallback onTap;

  @override
  State<_AssistantPlotTile> createState() => _AssistantPlotTileState();
}

class _AssistantPlotTileState extends State<_AssistantPlotTile> {
  bool _pressed = false;

  Color _baseTileColor(int? effectiveTid) {
    if (effectiveTid == null) return AppDesignTokens.unassignedColor;
    final idx =
        widget.treatments.indexWhere((t) => t.id == effectiveTid);
    return idx >= 0
        ? AppDesignTokens
            .treatmentPalette[idx % AppDesignTokens.treatmentPalette.length]
        : AppDesignTokens.unassignedColor;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTid =
        widget.plotIdToTreatmentId[widget.plot.id] ?? widget.plot.treatmentId;
    final treatment =
        effectiveTid != null ? widget.treatmentMap[effectiveTid] : null;
    final isCurrentTreatment =
        effectiveTid == widget.currentTreatmentId;
    final isGuardUnused = widget.plot.isGuardRow && effectiveTid == null;
    final baseColor = _baseTileColor(effectiveTid);
    final scheme = Theme.of(context).colorScheme;

    final Color tileColor;
    final Color borderColor;
    final double borderWidth;
    final bool showCheckmark;
    final bool dimmed;

    if (isGuardUnused) {
      tileColor = scheme.surfaceContainerHighest;
      borderColor = AppDesignTokens.borderCrisp;
      borderWidth = 1;
      showCheckmark = false;
      dimmed = true;
    } else if (isCurrentTreatment) {
      if (widget.isTapped) {
        tileColor = AppDesignTokens.appliedColor;
        borderColor = AppDesignTokens.appliedColor;
        borderWidth = 2;
        showCheckmark = true;
        dimmed = false;
      } else {
        tileColor = baseColor;
        borderColor = scheme.primary;
        borderWidth = 2;
        showCheckmark = false;
        dimmed = false;
      }
    } else {
      tileColor = baseColor.withValues(alpha: 0.30);
      borderColor = Colors.white.withValues(alpha: 0.15);
      borderWidth = 1;
      showCheckmark = false;
      dimmed = true;
    }

    final labelColor =
        (dimmed || isGuardUnused) ? AppDesignTokens.secondaryText : Colors.white;
    final subColor = (dimmed || isGuardUnused)
        ? AppDesignTokens.secondaryText.withValues(alpha: 0.8)
        : Colors.white.withValues(alpha: 0.85);

    return Container(
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _pressed && isCurrentTreatment
              ? scheme.primary.withValues(alpha: 0.55)
              : borderColor,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _pressed ? 0.2 : 0.12),
            blurRadius: _pressed ? 8 : 4,
            offset: Offset(0, _pressed ? 3 : 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onHighlightChanged: (v) => setState(() => _pressed = v),
          onTap: widget.onTap,
          splashColor: Colors.white.withValues(alpha: 0.2),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            width: double.infinity,
            alignment: Alignment.center,
            child: showCheckmark
                ? const Icon(Icons.check_circle, color: Colors.white, size: 24)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.displayLabel,
                        style: TextStyle(
                          color: labelColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        treatment != null
                            ? treatment.code
                            : (effectiveTid != null ? '(removed)' : ''),
                        style: TextStyle(
                          color: subColor,
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
