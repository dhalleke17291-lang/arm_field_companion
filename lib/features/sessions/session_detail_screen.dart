import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/widgets/gradient_screen_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/ui/assessment_display_helper.dart';
import '../../core/plot_display.dart';
import '../../core/plot_sort.dart';
import '../../core/export_guard.dart';
import '../../core/providers.dart';
import '../../core/last_session_store.dart';
import '../../core/session_resume_store.dart';
import '../../core/session_walk_order_store.dart';
import 'package:share_plus/share_plus.dart';
import 'arrange_plots_screen.dart';
import '../plots/plot_queue_screen.dart';
import '../../data/repositories/weather_snapshot_repository.dart';
import '../ratings/rating_screen.dart';
import '../weather/weather_capture_form.dart';
import '../ratings/rating_scale_map.dart';
import '../derived/derived_snapshot_provider.dart'
    show derivedSnapshotForSessionProvider;
import 'usecases/start_or_continue_rating_usecase.dart';
import 'rating_order_sheet.dart';
import 'session_summary_screen.dart';
import 'session_export_trust_dialog.dart';
import 'session_export_trust_messaging.dart';
import '../../core/ui/field_note_timestamp_format.dart';
import '../../core/widgets/loading_error_widgets.dart';
import 'crop_stage_bbch_editor_dialog.dart';
import '../notes/field_note_editor_sheet.dart';

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

  Future<void> _confirmAndSoftDeleteSession(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session'),
        content: const Text(
          'This session moves to Recovery. Ratings in this session move to Recovery too. '
          'The trial and its plots are unchanged. You can restore this session later from Recovery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete session'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final user = await ref.read(currentUserProvider.future);
      final userId = await ref.read(currentUserIdProvider.future);
      await ref.read(sessionRepositoryProvider).softDeleteSession(
            widget.session.id,
            deletedBy: user?.displayName,
            deletedByUserId: userId,
          );
      if (!context.mounted) return;
      final trialId = widget.trial.id;
      final sessionId = widget.session.id;
      ref.invalidate(sessionsForTrialProvider(trialId));
      ref.invalidate(deletedSessionsProvider);
      ref.invalidate(deletedSessionsForTrialRecoveryProvider(trialId));
      ref.invalidate(openSessionProvider(trialId));
      ref.invalidate(sessionRatingsProvider(sessionId));
      ref.invalidate(sessionAssessmentsProvider(sessionId));
      ref.invalidate(ratedPlotPksProvider(sessionId));
      ref.invalidate(derivedSnapshotForSessionProvider(sessionId));
      ref.invalidate(lastSessionContextProvider);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Session moved to Recovery')),
      );
    } catch (e) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Could not delete session'),
          content: SelectableText('$e'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// Compact BBCH, weather, checklist, and completeness row (below Plots/Rate dock).
  Widget _buildSessionToolsRow(
    BuildContext context,
    Trial trial,
    Session session,
  ) {
    final live =
        ref.watch(sessionByIdProvider(session.id)).valueOrNull ?? session;
    final weatherRecorded =
        ref.watch(weatherSnapshotForSessionProvider(session.id)).valueOrNull !=
            null;

    Future<void> openWeather() async {
      final repo = ref.read(weatherSnapshotRepositoryProvider);
      final snap = await repo.getWeatherSnapshotForParent(
        kWeatherParentTypeRatingSession,
        session.id,
      );
      if (!context.mounted) return;
      await showWeatherCaptureBottomSheet(
        context,
        trial: trial,
        session: session,
        initialSnapshot: snap,
      );
    }

    Widget toolSlot({
      required String tooltip,
      required Widget icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    const SizedBox(height: 4),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final bbchIcon = Icon(
      live.cropStageBbch != null ? Icons.eco : Icons.eco_outlined,
      size: 22,
      color: AppDesignTokens.primary,
    );
    final weatherIcon = Icon(
      weatherRecorded ? Icons.wb_cloudy : Icons.wb_cloudy_outlined,
      size: 22,
      color: AppDesignTokens.primary,
    );
    const checklistIcon = Icon(
      Icons.insights_outlined,
      size: 22,
      color: AppDesignTokens.primary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          toolSlot(
            tooltip: 'Crop Growth Stage (BBCH)',
            icon: bbchIcon,
            label: 'Growth Stage (BBCH)',
            onTap: () => showCropStageBbchEditorDialog(
                  context: context,
                  ref: ref,
                  session: live,
                  trialId: widget.trial.id,
                ),
          ),
          toolSlot(
            tooltip: 'Weather',
            icon: weatherIcon,
            label: 'Weather',
            onTap: openWeather,
          ),
          toolSlot(
            tooltip: 'Session data grid',
            icon: checklistIcon,
            label: 'Data Grid',
            onTap: () {
              Navigator.push<void>(
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trial = widget.trial;
    final sessionSnap = ref.watch(sessionByIdProvider(widget.session.id));
    final session = sessionSnap.valueOrNull ?? widget.session;
    final timingForHeader =
        ref.watch(sessionTimingContextProvider(session.id)).maybeWhen(
              data: (t) => t.displayLineDatDasOnly,
              orElse: () => '',
            );
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final ratingsAsync = ref.watch(sessionRatingsProvider(session.id));
    final assessmentsAsync = ref.watch(sessionAssessmentsProvider(session.id));
    // Must watch at top level: nested watch inside .when(data:) caused the notes
    // StreamProvider.autoDispose to drop to zero listeners when plots/ratings/
    // assessments briefly went loading, triggering debug InheritedElement asserts.
    final notesAsync = ref.watch(notesForTrialProvider(trial.id));
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
        subtitleLine2:
            timingForHeader.isEmpty ? null : timingForHeader,
        titleFontSize: 17,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download, color: AppDesignTokens.onPrimary),
            iconSize: 24,
            tooltip: 'Export session',
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
              const PopupMenuItem(
                  value: 'csv', child: Text('Session Data (CSV)')),
              const PopupMenuItem(
                  value: 'arm_xml', child: Text('Session (XML)')),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppDesignTokens.onPrimary),
            iconSize: 24,
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'delete_session') {
                _confirmAndSoftDeleteSession(context);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'delete_session',
                child: Text('Move to Recovery'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(top: false, child: plotsAsync.when(
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
                _buildSessionToolsRow(context, trial, session),
                _SessionWalkOrderBar(
                  sessionId: session.id,
                  mode: _walkOrderMode,
                  onModeChanged: (WalkOrderMode mode) async {
                    setState(() => _walkOrderMode = mode);
                    final prefs = await SharedPreferences.getInstance();
                    await SessionWalkOrderStore(prefs)
                        .setMode(session.id, mode);
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                  child: Column(
                    children: [
                      _SessionExportTrustCaption(
                        trialId: widget.trial.id,
                        sessionId: session.id,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'See full history in Diagnostics → Audit log',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.48),
                            ),
                      ),
                    ],
                  ),
                ),
                _sessionLinkedFieldNotesSection(
                  context,
                  ref,
                  trial: trial,
                  session: session,
                  notesAsync: notesAsync,
                  plots: plots,
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Move to Recovery'),
                    onPressed: () => _confirmAndSoftDeleteSession(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      )),
    );
  }

  /// Uses [notesAsync] from [build] so [notesForTrialProvider] stays subscribed
  /// for the whole screen — avoids autoDispose dropping to zero listeners when
  /// nested plots/ratings/assessments `.when` branches swap.
  Widget _sessionLinkedFieldNotesSection(
    BuildContext context,
    WidgetRef ref, {
    required Trial trial,
    required Session session,
    required AsyncValue<List<Note>> notesAsync,
    required List<Plot> plots,
  }) {
    return notesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, __) => AppErrorHint(error: e),
      data: (trialNotes) {
        final sessionNotes =
            trialNotes.where((n) => n.sessionId == session.id).toList();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Card(
            elevation: 0,
            color: AppDesignTokens.sectionHeaderBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppDesignTokens.borderCrisp),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Linked Field Notes',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => showFieldNoteEditorSheet(
                          context,
                          ref,
                          trial: trial,
                          initialSessionId: session.id,
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  if (sessionNotes.isEmpty)
                    Text(
                      'No field notes linked to this session.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppDesignTokens.secondaryText,
                          ),
                    )
                  else
                    for (final n in sessionNotes)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          n.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Builder(
                          builder: (_) {
                            const subStyle = TextStyle(
                              fontSize: 11,
                              color: AppDesignTokens.secondaryText,
                            );
                            final meta =
                                formatFieldNoteContextLineWithPlots(
                              n,
                              plots,
                              includeSession: false,
                            );
                            if (meta.isEmpty) {
                              return Text(
                                formatFieldNoteTimestampLine(n),
                                style: subStyle,
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formatFieldNoteTimestampLine(n),
                                  style: subStyle,
                                ),
                                Text(meta, style: subStyle),
                              ],
                            );
                          },
                        ),
                        onTap: () => showFieldNoteEditorSheet(
                          context,
                          ref,
                          trial: trial,
                          existing: n,
                        ),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final guard = ref.read(exportGuardProvider);
    final ran = await guard.runExclusive(() async {
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
                    child: Text(
                        'Session audit events exported (separate file).',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ),
                if (result.warningMessage != null) ...[
                  const SizedBox(height: AppDesignTokens.spacing8),
                  Text(
                    result.warningMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade700,
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
          final scheme = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Export failed — please try again. If the problem persists, check trial data for missing or incomplete records.',
                style: TextStyle(color: scheme.onError),
              ),
              backgroundColor: scheme.error,
            ),
          );
        }
      }
    });
    if (!ran && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(ExportGuard.busyMessage)),
      );
    }
  }

  Future<void> _exportArmXml(BuildContext context, WidgetRef ref) async {
    final guard = ref.read(exportGuardProvider);
    final ran = await guard.runExclusive(() async {
      final usecase = ref.read(exportSessionArmXmlUsecaseProvider);
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exporting XML...')),
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
              title: const Text('XML Export Failed'),
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
            title: const Text('XML Export Complete'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Session exported as structured XML.'),
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
                        '${widget.trial.name} - ${widget.session.name} XML Export',
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
          final scheme = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'XML export failed — please try again. If the problem persists, check session data for missing or incomplete records.',
                style: TextStyle(color: scheme.onError),
              ),
              backgroundColor: scheme.error,
            ),
          );
        }
      }
    });
    if (!ran && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(ExportGuard.busyMessage)),
      );
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
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              _SessionProgressFromDerived(
                sessionId: session.id,
                sessionStartedAt: session.startedAt,
                isOpen: session.endedAt == null,
              ),
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
    final customIds = walkOrder == WalkOrderMode.custom
        ? store.getCustomOrder(session.id)
        : null;
    final result = await useCase.execute(StartOrContinueRatingInput(
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
    if (pos != null) {
      final resolved = pos.resolveResumeStart(
        plots: plots,
        fallbackStartIndex: startIndex,
        assessmentCount: assessments.length,
      );
      startIndex = resolved.$1;
      initialAssessmentIndex = resolved.$2;
    }
    LastSessionStore(prefs).save(resolvedTrial.id, resolvedSession.id);

    if (!context.mounted) return;

    final scaleMap = buildRatingScaleMap(
      trialAssessments: ref
              .read(trialAssessmentsForTrialProvider(resolvedTrial.id))
              .valueOrNull ??
          <TrialAssessment>[],
      definitions:
          ref.read(assessmentDefinitionsProvider).valueOrNull ??
              <AssessmentDefinition>[],
      trialIdForLog: resolvedTrial.id,
    );

    if (result.isWalkEndReachedWithAnyRating) {
      // Walk end has at least one rating — choose plot queue or last plot.
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('End of Plot Walk'),
          content: const Text(
            'The last plot in the current walk order already has at least one '
            'rating. That reflects navigation progress, not full completeness '
            'for every assessment. Open the plot queue to review, or open the '
            'last plot in the rating screen.',
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
                      scaleMap: scaleMap,
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

    // Normal case: start or resume at the next plot without any current rating (navigation / walk order).
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
          scaleMap: scaleMap,
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
    final tas =
        ref.watch(trialAssessmentsForTrialProvider(widget.trial.id)).valueOrNull ??
            <TrialAssessment>[];
    final taByLegacy = <int, TrialAssessment>{};
    for (final ta in tas) {
      final lid = ta.legacyAssessmentId;
      if (lid != null) taByLegacy[lid] = ta;
    }
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
              itemBuilder: (context, index) {
                final a = assessments[index];
                final ta = taByLegacy[a.id];
                final chipLabel = ta != null
                    ? AssessmentDisplayHelper.compactName(ta)
                    : AssessmentDisplayHelper.legacyAssessmentDisplayName(a.name);
                return Padding(
                  padding:
                      const EdgeInsets.only(right: AppDesignTokens.spacing8),
                  child: Chip(
                    label: Text(chipLabel,
                        style: const TextStyle(fontSize: 12)),
                  ),
                );
              },
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
                      borderRadius:
                          BorderRadius.circular(AppDesignTokens.radiusXSmall),
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
                              Padding(
                                padding: const EdgeInsets.only(
                                    right: AppDesignTokens.spacing8),
                                child: Icon(Icons.flag,
                                    color: Colors.amber.shade700, size: 22),
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
                                  'Warnings',
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
                            title: Text('No Current Rating',
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
                          final ta = assessment != null
                              ? taByLegacy[assessment.id]
                              : null;
                          final ratingTitle = ta != null
                              ? AssessmentDisplayHelper.compactName(ta)
                              : (assessment != null
                                  ? AssessmentDisplayHelper
                                      .legacyAssessmentDisplayName(
                                          assessment.name)
                                  : 'Assessment');
                          return ListTile(
                            dense: true,
                            title: Text(ratingTitle),
                            trailing: Text(
                              rating.resultStatus == 'RECORDED'
                                  ? '${rating.numericValue ?? "-"} ${assessment?.unit ?? ""}'
                                  : rating.resultStatus,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: rating.resultStatus == 'RECORDED'
                                    ? AppDesignTokens.successFg
                                    : Colors.amber.shade700,
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
          'Warnings — plots: ${flaggedLabels.length} flagged, ${issueLabels.length} with non-recorded readings',
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
                Icon(Icons.warning_amber_outlined,
                    size: 18, color: Colors.amber.shade700),
                const SizedBox(width: AppDesignTokens.spacing8),
                Text(
                  'Warnings — plots',
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
                      'Warnings — readings:',
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

/// Read-only pre-export trust line (same signals as [confirmSessionExportTrust], no blocking).
class _SessionExportTrustCaption extends ConsumerWidget {
  const _SessionExportTrustCaption({
    required this.trialId,
    required this.sessionId,
  });

  final int trialId;
  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plotsAsync = ref.watch(plotsForTrialProvider(trialId));
    final ratedAsync = ref.watch(ratedPlotPksProvider(sessionId));
    final ratingsAsync = ref.watch(sessionRatingsProvider(sessionId));
    final correctionsAsync =
        ref.watch(plotPksWithCorrectionsForSessionProvider(sessionId));
    final reportAsync = ref.watch(sessionCompletenessReportProvider(sessionId));

    return plotsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, __) => AppErrorHint(error: e),
      data: (plots) => ratedAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (e, __) => AppErrorHint(error: e),
        data: (ratedPks) => ratingsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, __) => AppErrorHint(error: e),
          data: (ratings) => correctionsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, __) => AppErrorHint(error: e),
            data: (corrections) => reportAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, __) => AppErrorHint(error: e),
              data: (report) {
                final unratedPlots =
                    plots.where((p) => !ratedPks.contains(p.id)).length;
                final noRatings = ratings.isEmpty;
                final ratingsByPlot = <int, List<RatingRecord>>{};
                for (final r in ratings) {
                  ratingsByPlot.putIfAbsent(r.plotPk, () => []).add(r);
                }
                var issuesPlotCount = 0;
                var editedPlotCount = 0;
                for (final plot in plots) {
                  final pr = ratingsByPlot[plot.id] ?? [];
                  if (pr.any((r) => r.resultStatus != 'RECORDED')) {
                    issuesPlotCount++;
                  }
                  if (pr.any((r) => r.amended || (r.previousId != null)) ||
                      corrections.contains(plot.id)) {
                    editedPlotCount++;
                  }
                }

                final captionLines = sessionExportTrustCaptionLines(
                  sessionExpectedPlots: report.expectedPlots,
                  sessionCompletedPlots: report.completedPlots,
                  sessionIncompletePlots: report.incompletePlots,
                  sessionCanClose: report.canClose,
                  noRatings: noRatings,
                  unratedPlots: unratedPlots,
                  issuesPlotCount: issuesPlotCount,
                  editedPlotCount: editedPlotCount,
                );
                final baseStyle =
                    Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55),
                        );
                final footStyle =
                    Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          height: 1.25,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.45),
                        );

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      captionLines[0],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: baseStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      captionLines[1],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: baseStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      kSessionExportTrustEditedClarification,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: footStyle,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Isolate ref.watch(derivedSnapshotForSessionProvider) so it disposes cleanly (avoids _dependents.isEmpty).
class _SessionProgressFromDerived extends ConsumerWidget {
  const _SessionProgressFromDerived({
    required this.sessionId,
    this.sessionStartedAt,
    this.isOpen = false,
  });

  final int sessionId;
  final DateTime? sessionStartedAt;
  final bool isOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync =
        ref.watch(derivedSnapshotForSessionProvider(sessionId));
    return snapshotAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, __) => AppErrorHint(error: e),
      data: (snapshot) {
        if (snapshot == null) return const SizedBox.shrink();
        final paceText = _estimatePace(
          ratedCount: snapshot.ratedPlotCount,
          totalCount: snapshot.totalPlotCount,
          startedAt: sessionStartedAt,
          isOpen: isOpen,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${snapshot.ratedPlotCount} / ${snapshot.totalPlotCount} plots with a rating (${snapshot.progressPct.toStringAsFixed(0)}%) — navigation',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                textAlign: TextAlign.center,
              ),
              if (paceText != null) ...[
                const SizedBox(height: 4),
                Text(
                  paceText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Pace estimate for open sessions with at least 2 rated plots.
  /// Returns null when not enough data or session is closed.
  static String? _estimatePace({
    required int ratedCount,
    required int totalCount,
    required DateTime? startedAt,
    required bool isOpen,
  }) {
    if (!isOpen || startedAt == null || ratedCount < 2) return null;
    final remaining = totalCount - ratedCount;
    if (remaining <= 0) return null;
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed.inSeconds < 10) return null;
    final secsPerPlot = elapsed.inSeconds / ratedCount;
    final remainingSecs = (secsPerPlot * remaining).round();
    if (remainingSecs < 60) {
      return '~$remainingSecs sec remaining at current pace';
    }
    final mins = (remainingSecs / 60).round();
    return '~$mins min remaining at current pace';
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
