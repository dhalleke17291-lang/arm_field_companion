import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/widgets/gradient_screen_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/plot_display.dart';
import '../../core/plot_sort.dart';
import '../../core/providers.dart';
import '../../core/last_session_store.dart';
import '../../core/session_resume_store.dart';
import '../../core/session_walk_order_store.dart';
import 'package:share_plus/share_plus.dart';
import 'arrange_plots_screen.dart';
import '../plots/plot_queue_screen.dart';
import '../ratings/rating_screen.dart';
import '../derived/derived_snapshot_provider.dart';
import 'usecases/start_or_continue_rating_usecase.dart';
import 'rating_order_sheet.dart';
import 'session_completeness_screen.dart';
import 'session_summary_screen.dart';
import 'session_export_trust_dialog.dart';
import '../../core/widgets/loading_error_widgets.dart';

class SessionDetailScreen extends ConsumerStatefulWidget {
  final Trial trial;
  final Session session;

  const SessionDetailScreen({
    super.key,
    required this.trial,
    required this.session,
  });

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  int _selectedTabIndex = 0;
  WalkOrderMode _walkOrderMode = WalkOrderMode.serpentine;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWalkOrder());
  }

  Future<void> _loadWalkOrder() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _walkOrderMode =
        SessionWalkOrderStore(prefs).getMode(widget.session.id));
  }

  @override
  Widget build(BuildContext context) {
    final trial = widget.trial;
    final session = widget.session;
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final ratingsAsync = ref.watch(sessionRatingsProvider(session.id));
    final assessmentsAsync = ref.watch(sessionAssessmentsProvider(session.id));
    final treatments =
        ref.watch(treatmentsForTrialProvider(trial.id)).value ?? [];
    final assignments =
        ref.watch(assignmentsForTrialProvider(trial.id)).value ?? [];
    final plotIdToTreatmentId = {
      for (var a in assignments) a.plotId: a.treatmentId
    };

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: GradientScreenHeader(
        title: session.name,
        subtitle: session.sessionDateLocal,
        titleFontSize: 17,
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined, color: Colors.white),
            tooltip: 'Session summary',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SessionSummaryScreen(
                    trial: trial,
                    session: session,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.fact_check_outlined, color: Colors.white),
            tooltip: 'Session completeness',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SessionCompletenessScreen(
                    trial: trial,
                    session: session,
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: 'Export',
            onSelected: (value) async {
              final ok = await confirmSessionExportTrust(
                context: context,
                ref: ref,
                trialId: trial.id,
                sessionId: session.id,
              );
              if (!context.mounted) return;
              if (!ok) return;
              if (value == 'csv') {
                await _exportCsv(context, ref);
              } else if (value == 'arm_xml') {
                await _exportArmXml(context, ref);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'csv', child: Text('Export to CSV')),
              const PopupMenuItem(
                  value: 'arm_xml', child: Text('Export as ARM XML')),
            ],
          ),
        ],
      ),
      body: plotsAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, st) => AppErrorView(
            error: e,
            stackTrace: st,
            onRetry: () {
              ref.invalidate(plotsForTrialProvider(widget.trial.id));
              ref.invalidate(sessionRatingsProvider(widget.session.id));
              ref.invalidate(sessionAssessmentsProvider(widget.session.id));
            }),
        data: (plots) => ratingsAsync.when(
          loading: () => const AppLoadingView(),
          error: (e, st) => AppErrorView(
              error: e,
              stackTrace: st,
              onRetry: () {
                ref.invalidate(plotsForTrialProvider(widget.trial.id));
                ref.invalidate(sessionRatingsProvider(widget.session.id));
                ref.invalidate(sessionAssessmentsProvider(widget.session.id));
              }),
          data: (ratings) => assessmentsAsync.when(
            loading: () => const AppLoadingView(),
            error: (e, st) => AppErrorView(
                error: e,
                stackTrace: st,
                onRetry: () {
                  ref.invalidate(plotsForTrialProvider(widget.trial.id));
                  ref.invalidate(sessionRatingsProvider(widget.session.id));
                  ref.invalidate(sessionAssessmentsProvider(widget.session.id));
                }),
            data: (assessments) => Column(
              children: [
                _SessionDockBar(
                  selectedIndex: _selectedTabIndex,
                  onSelected: (index) =>
                      setState(() => _selectedTabIndex = index),
                  ratedCount: ratings.map((r) => r.plotPk).toSet().length,
                  plotCount: plots.length,
                ),
                _SessionWalkOrderBar(
                  sessionId: session.id,
                  mode: _walkOrderMode,
                  onModeChanged: (WalkOrderMode mode) async {
                    setState(() => _walkOrderMode = mode);
                    final prefs = await SharedPreferences.getInstance();
                    await SessionWalkOrderStore(prefs).setMode(session.id, mode);
                    if (mode == WalkOrderMode.custom && context.mounted) {
                      final saved = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ArrangePlotsScreen(
                            trial: widget.trial,
                            session: session,
                          ),
                        ),
                      );
                      if (saved == true && mounted) setState(() {});
                    }
                  },
                ),
                Expanded(
                  child: IndexedStack(
                    index: _selectedTabIndex,
                    children: [
                      _buildContent(context, ref, session, plots, ratings,
                          assessments, treatments, plotIdToTreatmentId),
                      _buildRateTab(
                          context, ref, trial, session, plots, assessments),
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
    final usecase = ref.read(exportSessionCsvUsecaseProvider);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exporting...')),
      );

      final currentUser = await ref.read(currentUserProvider.future);
      final result = await usecase.exportSessionToCsv(
        sessionId: widget.session.id,
        trialId: widget.trial.id,
        trialName: widget.trial.name,
        sessionName: widget.session.name,
        sessionDateLocal: widget.session.sessionDateLocal,
        sessionRaterName: widget.session.raterName,
        exportedByDisplayName: currentUser?.displayName,
        isSessionClosed: widget.session.endedAt != null,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      if (!result.success) {
        ref.read(diagnosticsStoreProvider).recordError(
              result.errorMessage ?? 'Unknown error',
              code: 'export_failed',
            );
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Export Failed'),
            content: SelectableText(result.errorMessage ?? 'Unknown error'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Export Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${result.rowCount} ratings exported'),
              if (result.auditFilePath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Session audit events exported (separate file).',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              if (result.warningMessage != null) ...[
                const SizedBox(height: AppDesignTokens.spacing8),
                Text(
                  result.warningMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text('Saved to:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SelectableText(result.filePath!,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                final files = [XFile(result.filePath!)];
                if (result.auditFilePath != null) {
                  files.add(XFile(result.auditFilePath!));
                }
                final box = context.findRenderObject() as RenderBox?;
                await Share.shareXFiles(
                  files,
                  subject:
                      '${widget.trial.name} - ${widget.session.name} Export',
                  sharePositionOrigin: box == null
                      ? const Rect.fromLTWH(0, 0, 100, 100)
                      : box.localToGlobal(Offset.zero) & box.size,
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ],
        ),
      );
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

  Future<void> _exportArmXml(BuildContext context, WidgetRef ref) async {
    final usecase = ref.read(exportSessionArmXmlUsecaseProvider);
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exporting ARM XML...')),
      );
      final currentUser = await ref.read(currentUserProvider.future);
      final result = await usecase.exportSessionToArmXml(
        sessionId: widget.session.id,
        trialId: widget.trial.id,
        trialName: widget.trial.name,
        sessionName: widget.session.name,
        sessionDateLocal: widget.session.sessionDateLocal,
        sessionRaterName: widget.session.raterName,
        exportedByDisplayName: currentUser?.displayName,
        isSessionClosed: widget.session.endedAt != null,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      if (!result.success) {
        ref.read(diagnosticsStoreProvider).recordError(
              result.errorMessage ?? 'Unknown error',
              code: 'arm_xml_export_failed',
            );
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('ARM XML Export Failed'),
            content: SelectableText(result.errorMessage ?? 'Unknown error'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('ARM XML Export Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Session exported as ARM-style XML.'),
              const SizedBox(height: 8),
              const Text('Saved to:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SelectableText(result.filePath!,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                final box = context.findRenderObject() as RenderBox?;
                await Share.shareXFiles(
                  [XFile(result.filePath!)],
                  subject:
                      '${widget.trial.name} - ${widget.session.name} ARM Export',
                  sharePositionOrigin: box == null
                      ? const Rect.fromLTWH(0, 0, 100, 100)
                      : box.localToGlobal(Offset.zero) & box.size,
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('ARM XML export failed: $e'),
              backgroundColor: Colors.red),
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
        child: Text('No assessments in this session.'),
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
            _SessionProgressFromDerived(sessionId: session.id),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () =>
                  _showRatingOrderSheet(context, ref, session, assessments),
              icon: const Icon(Icons.swap_vert, size: 18),
              label: const Text('Set rating order'),
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
            ElevatedButton.icon(
              onPressed: () =>
                  _startOrContinueRating(context, ref, trial, session),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Rating'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesignTokens.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDesignTokens.spacing24,
                    vertical: AppDesignTokens.spacing16),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDesignTokens.radiusCard)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRatingOrderSheet(
    BuildContext context,
    WidgetRef ref,
    Session session,
    List<Assessment> assessments,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => RatingOrderSheetContent(
        session: session,
        assessments: List.from(assessments),
        ref: ref,
        onSaved: () {
          ref.invalidate(sessionAssessmentsProvider(session.id));
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _startOrContinueRating(
    BuildContext context,
    WidgetRef ref,
    Trial trial,
    Session session,
  ) async {
    final useCase = ref.read(startOrContinueRatingUseCaseProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preparing rating session...'),
        duration: Duration(seconds: 2),
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    final store = SessionWalkOrderStore(prefs);
    final walkOrder = store.getMode(session.id);
    final customIds = walkOrder == WalkOrderMode.custom ? store.getCustomOrder(session.id) : null;
    final result = await useCase.execute(
        StartOrContinueRatingInput(
          sessionId: session.id,
          walkOrderMode: walkOrder,
          customPlotIds: customIds,
        ));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();

    if (!result.success ||
        result.trial == null ||
        result.session == null ||
        result.allPlotsSerpentine == null ||
        result.assessments == null ||
        result.startPlotIndex == null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cannot Start Rating'),
          content: Text(result.errorMessage ??
              'Unable to resolve plots and assessments for this session.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    final resolvedTrial = result.trial!;
    final resolvedSession = result.session!;
    final plots = result.allPlotsSerpentine!;
    final assessments = result.assessments!;
    int startIndex = result.startPlotIndex!;
    int? initialAssessmentIndex;

    final pos = SessionResumeStore(prefs).getPosition(resolvedSession.id);
    if (pos != null && pos.$1 >= 0 && pos.$1 < plots.length) {
      startIndex = pos.$1;
      initialAssessmentIndex = pos.$2.clamp(0, assessments.length - 1);
    }
    LastSessionStore(prefs).save(resolvedTrial.id, resolvedSession.id);

    if (!context.mounted) return;

    if (result.isSessionComplete) {
      // All plots have ratings — let the user choose between review in queue
      // or jumping into the last plot in the rating screen.
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('All Plots Rated'),
          content: const Text(
            'All plots in this session already have ratings. '
            'You can review or edit values from the plot queue, '
            'or open the last plot in the rating screen.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlotQueueScreen(
                      trial: resolvedTrial,
                      session: resolvedSession,
                    ),
                  ),
                );
              },
              child: const Text('Open Plot Queue'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RatingScreen(
                      trial: resolvedTrial,
                      session: resolvedSession,
                      plot: plots[startIndex],
                      assessments: assessments,
                      allPlots: plots,
                      currentPlotIndex: startIndex,
                      initialAssessmentIndex: initialAssessmentIndex,
                    ),
                  ),
                );
              },
              child: const Text('Open Last Plot'),
            ),
          ],
        ),
      );
      return;
    }

    // Normal case: start or resume at the next unrated plot in serpentine order.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RatingScreen(
          trial: resolvedTrial,
          session: resolvedSession,
          plot: plots[startIndex],
          assessments: assessments,
          allPlots: plots,
          currentPlotIndex: startIndex,
          initialAssessmentIndex: initialAssessmentIndex,
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Session session,
    List<Plot> plots,
    List<RatingRecord> ratings,
    List<Assessment> assessments,
    List<Treatment> treatments,
    Map<int, int?> plotIdToTreatmentId,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final ratedCount = ratings.map((r) => r.plotPk).toSet().length;
    final treatmentMap = {for (final t in treatments) t.id: t};
    final flaggedIds =
        ref.watch(flaggedPlotIdsForSessionProvider(session.id)).valueOrNull ??
            <int>{};
    return Column(
      children: [
        // Section header (same as Trial Plots tab)
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDesignTokens.spacing16,
              vertical: AppDesignTokens.spacing8),
          decoration: const BoxDecoration(
            color: AppDesignTokens.sectionHeaderBg,
            border:
                Border(bottom: BorderSide(color: AppDesignTokens.borderCrisp)),
          ),
          child: Row(
            children: [
              const Icon(Icons.grid_on,
                  color: AppDesignTokens.primary, size: 16),
              const SizedBox(width: AppDesignTokens.spacing8),
              Text(
                '${plots.length} plots',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppDesignTokens.primary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDesignTokens.spacing8,
                    vertical: AppDesignTokens.spacing4),
                decoration: BoxDecoration(
                  color: AppDesignTokens.successBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$ratedCount / ${plots.length} rated',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppDesignTokens.successFg),
                ),
              ),
            ],
          ),
        ),
        // Plots with issues (only for closed sessions)
        if (session.endedAt != null) ...[
          _buildSessionIssuesSection(
            context,
            session,
            plots,
            ratings,
            flaggedIds,
          ),
        ],
        // Assessment chips
        if (assessments.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDesignTokens.spacing8,
                  vertical: AppDesignTokens.spacing8),
              itemCount: assessments.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(right: AppDesignTokens.spacing8),
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
              final displayNum = getDisplayPlotLabel(plot, plots);
              final treatmentLabel = getTreatmentDisplayLabel(
                  plot, treatmentMap,
                  treatmentIdOverride: plotIdToTreatmentId[plot.id]);

              final hasIssues =
                  plotRatings.any((r) => r.resultStatus != 'RECORDED');
              final isFlagged = flaggedIds.contains(plot.id);
              return Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: AppDesignTokens.spacing16,
                    vertical: AppDesignTokens.spacing4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(AppDesignTokens.radiusCard),
                  border: Border.all(color: AppDesignTokens.borderCrisp),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 4,
                        offset: Offset(0, 2)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  leading: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppDesignTokens.spacing8,
                        vertical: AppDesignTokens.spacing8),
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
                    'Plot $displayNum · $treatmentLabel',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: plot.rep != null ? Text('Rep ${plot.rep}') : null,
                  trailing: (isFlagged || hasIssues)
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isFlagged)
                              const Padding(
                                padding: EdgeInsets.only(
                                    right: AppDesignTokens.spacing8),
                                child: Icon(Icons.flag,
                                    color: Colors.amber, size: 22),
                              ),
                            if (hasIssues)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppDesignTokens.spacing8,
                                    vertical: AppDesignTokens.spacing4),
                                decoration: BoxDecoration(
                                  color: scheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: scheme.outlineVariant),
                                ),
                                child: Text(
                                  'Missing / issues',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onTertiaryContainer),
                                ),
                              ),
                          ],
                        )
                      : null,
                  children: plotRatings.isEmpty
                      ? [
                          ListTile(
                            title: Text('Not rated',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
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

  /// Read-only summary of plots with issues (flagged or missing/unavailable readings).
  /// Only shown for closed sessions when there are issues.
  Widget _buildSessionIssuesSection(
    BuildContext context,
    Session session,
    List<Plot> plots,
    List<RatingRecord> ratings,
    Set<int> flaggedIds,
  ) {
    final issuePlotIds = ratings
        .where((r) => r.resultStatus != 'RECORDED')
        .map((r) => r.plotPk)
        .toSet();
    if (flaggedIds.isEmpty && issuePlotIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final flaggedPlots = plots.where((p) => flaggedIds.contains(p.id)).toList();
    final issuePlots = plots.where((p) => issuePlotIds.contains(p.id)).toList();
    final flaggedLabels =
        flaggedPlots.map((p) => getDisplayPlotLabel(p, plots)).toList();
    final issueLabels =
        issuePlots.map((p) => getDisplayPlotLabel(p, plots)).toList();
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label:
          'Plots with issues: ${flaggedLabels.length} flagged, ${issueLabels.length} with reading issues',
      child: Container(
        margin: const EdgeInsets.fromLTRB(AppDesignTokens.spacing16,
            AppDesignTokens.spacing8, AppDesignTokens.spacing16, 0),
        padding: const EdgeInsets.all(AppDesignTokens.spacing12),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 18, color: scheme.onTertiaryContainer),
                const SizedBox(width: AppDesignTokens.spacing8),
                Text(
                  'Plots with issues',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
            if (flaggedLabels.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      'Flagged:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onTertiaryContainer),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      flaggedLabels.join(', '),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            if (issueLabels.isNotEmpty) ...[
              const SizedBox(height: AppDesignTokens.spacing8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      'Reading issues:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onTertiaryContainer),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      issueLabels.join(', '),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Walk order selector visible on all session tabs (Plots and Rate).
class _SessionWalkOrderBar extends StatelessWidget {
  const _SessionWalkOrderBar({
    required this.sessionId,
    required this.mode,
    required this.onModeChanged,
  });

  final int sessionId;
  final WalkOrderMode mode;
  final ValueChanged<WalkOrderMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing16,
        vertical: AppDesignTokens.spacing8,
      ),
      decoration: const BoxDecoration(
        color: AppDesignTokens.cardSurface,
        border: Border(bottom: BorderSide(color: AppDesignTokens.borderCrisp)),
      ),
      child: Row(
        children: [
          Text(
            'Walk order:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(width: 8),
          DropdownButton<WalkOrderMode>(
            value: mode,
            items: const [
              DropdownMenuItem(
                  value: WalkOrderMode.numeric, child: Text('Numeric')),
              DropdownMenuItem(
                  value: WalkOrderMode.serpentine, child: Text('Serpentine')),
              DropdownMenuItem(
                  value: WalkOrderMode.custom, child: Text('Custom')),
            ],
            onChanged: (WalkOrderMode? value) {
              if (value != null) onModeChanged(value);
            },
          ),
        ],
      ),
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
      padding: const EdgeInsets.only(
          top: AppDesignTokens.spacing8, bottom: AppDesignTokens.spacing8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing16),
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: AppDesignTokens.spacing12),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = selectedIndex == item.$1;
          return _SessionDockTile(
            key: item.$1 == 1 ? const Key('session_detail_rate_tab') : null,
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

/// Isolate ref.watch(derivedSnapshotForSessionProvider) so it disposes cleanly (avoids _dependents.isEmpty).
class _SessionProgressFromDerived extends ConsumerWidget {
  const _SessionProgressFromDerived({required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync =
        ref.watch(derivedSnapshotForSessionProvider(sessionId));
    return snapshotAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (snapshot) {
        if (snapshot == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '${snapshot.ratedPlotCount} / ${snapshot.totalPlotCount} plots rated (${snapshot.progressPct.toStringAsFixed(0)}%)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
            textAlign: TextAlign.center,
          ),
        );
      },
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
    super.key,
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
          padding: const EdgeInsets.symmetric(
              horizontal: AppDesignTokens.spacing12,
              vertical: AppDesignTokens.spacing8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppDesignTokens.spacing8),
                decoration: BoxDecoration(
                  color:
                      selected ? scheme.primaryContainer : Colors.transparent,
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
