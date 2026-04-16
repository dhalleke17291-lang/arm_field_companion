import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/plot_sort.dart';
import '../../core/providers.dart';
import '../../core/session_resume_store.dart';
import '../../core/session_walk_order_store.dart';
import '../../core/last_session_store.dart';
import '../../core/workspace/workspace_config.dart';
import '../derived/trial_attention_provider.dart';
import '../derived/trial_attention_service.dart';
import '../sessions/session_summary_screen.dart';
import '../trials/trial_detail_screen.dart';
import '../sessions/usecases/start_or_continue_rating_usecase.dart';
import '../ratings/rating_screen.dart';

/// Format time (e.g. "8:14 AM").
String _formatTime(DateTime at) {
  final hour = at.hour == 0 ? 12 : (at.hour > 12 ? at.hour - 12 : at.hour);
  final ampm = at.hour < 12 ? 'AM' : 'PM';
  final min = at.minute.toString().padLeft(2, '0');
  return '$hour:$min $ampm';
}

/// Format duration (e.g. "3h 18m").
String _formatDuration(DateTime start, DateTime end) {
  final d = end.difference(start);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0 && m > 0) return '${h}h ${m}m';
  if (h > 0) return '${h}h';
  return '${m}m';
}

enum _StatusFilter { all, open, closed }

enum _TypeFilter { all, standalone, imported }

class WorkLogScreen extends ConsumerStatefulWidget {
  const WorkLogScreen({
    super.key,
    this.onGoToTrials,
  });

  final VoidCallback? onGoToTrials;

  @override
  ConsumerState<WorkLogScreen> createState() => _WorkLogScreenState();
}

class _WorkLogScreenState extends ConsumerState<WorkLogScreen> {
  _StatusFilter _statusFilter = _StatusFilter.all;
  _TypeFilter _typeFilter = _TypeFilter.all;

  List<Session> _applyFilters(List<Session> sessions, Map<int, Trial> trials) {
    var filtered = sessions;

    // Status filter
    if (_statusFilter == _StatusFilter.open) {
      filtered = filtered.where((s) => s.endedAt == null).toList();
    } else if (_statusFilter == _StatusFilter.closed) {
      filtered = filtered.where((s) => s.endedAt != null).toList();
    }

    // Type filter
    if (_typeFilter != _TypeFilter.all) {
      filtered = filtered.where((s) {
        final trial = trials[s.trialId];
        if (trial == null) return true;
        final wt = workspaceTypeFromStringOrNull(trial.workspaceType) ??
            WorkspaceType.efficacy;
        final isStandalone =
            WorkspaceConfig.forType(wt).mode == TrialMode.standalone;
        return _typeFilter == _TypeFilter.standalone
            ? isStandalone
            : !isStandalone;
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(allActiveSessionsProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: AppBar(
        title: Text(
          'Sessions',
          style: AppDesignTokens.headerTitleStyle(
            fontSize: 20,
            color: AppDesignTokens.onPrimary,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: AppDesignTokens.primary,
        foregroundColor: AppDesignTokens.onPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilterChips(),
            Expanded(
              child: sessionsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
                data: (sessions) {
                  // Build trial lookup for type filtering and display
                  final trialIds = sessions.map((s) => s.trialId).toSet();
                  final trialMap = <int, Trial>{};
                  for (final id in trialIds) {
                    final trial =
                        ref.watch(trialProvider(id)).valueOrNull;
                    if (trial != null) trialMap[id] = trial;
                  }

                  final filtered = _applyFilters(sessions, trialMap);

                  if (filtered.isEmpty) {
                    return _buildEmptyState(widget.onGoToTrials);
                  }

                  final openSessions =
                      filtered.where((s) => s.endedAt == null).toList();
                  final closedSessions =
                      filtered.where((s) => s.endedAt != null).toList();

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppDesignTokens.spacing16,
                      AppDesignTokens.spacing12,
                      AppDesignTokens.spacing16,
                      AppDesignTokens.spacing24,
                    ),
                    children: [
                      if (openSessions.isNotEmpty) ...[
                        _sectionHeader('Open Sessions', isFirst: true),
                        ...openSessions.map(
                          (s) => _buildSessionCard(
                            context,
                            s,
                            trial: trialMap[s.trialId],
                            isResumable: true,
                          ),
                        ),
                      ],
                      if (closedSessions.isNotEmpty) ...[
                        _sectionHeader(
                          'Session History',
                          isFirst: openSessions.isEmpty,
                        ),
                        ...closedSessions.map(
                          (s) => _buildSessionCard(
                            context,
                            s,
                            trial: trialMap[s.trialId],
                            isResumable: false,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing16,
        vertical: AppDesignTokens.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status filter row
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _filterChip(
                'All',
                selected: _statusFilter == _StatusFilter.all,
                onTap: () =>
                    setState(() => _statusFilter = _StatusFilter.all),
              ),
              _filterChip(
                'Open',
                selected: _statusFilter == _StatusFilter.open,
                onTap: () =>
                    setState(() => _statusFilter = _StatusFilter.open),
              ),
              _filterChip(
                'Closed',
                selected: _statusFilter == _StatusFilter.closed,
                onTap: () =>
                    setState(() => _statusFilter = _StatusFilter.closed),
              ),
              const SizedBox(width: 8),
              _filterChip(
                'Standalone',
                selected: _typeFilter == _TypeFilter.standalone,
                onTap: () => setState(() {
                  _typeFilter = _typeFilter == _TypeFilter.standalone
                      ? _TypeFilter.all
                      : _TypeFilter.standalone;
                }),
              ),
              _filterChip(
                'Imported',
                selected: _typeFilter == _TypeFilter.imported,
                onTap: () => setState(() {
                  _typeFilter = _typeFilter == _TypeFilter.imported
                      ? _TypeFilter.all
                      : _TypeFilter.imported;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label,
      {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppDesignTokens.primary
              : AppDesignTokens.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? null
              : Border.all(color: AppDesignTokens.borderCrisp),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? AppDesignTokens.onPrimary
                : AppDesignTokens.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(VoidCallback? onGoToTrials) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing24,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.event_note_outlined,
              size: 64,
              color: AppDesignTokens.secondaryText,
            ),
            const SizedBox(height: AppDesignTokens.spacing16),
            Text(
              _statusFilter == _StatusFilter.all && _typeFilter == _TypeFilter.all
                  ? 'No sessions yet'
                  : 'No matching sessions',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppDesignTokens.primaryText,
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing8),
            Text(
              _statusFilter == _StatusFilter.all && _typeFilter == _TypeFilter.all
                  ? 'Start a trial and create your first rating session'
                  : 'Try adjusting your filters',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            if (onGoToTrials != null &&
                _statusFilter == _StatusFilter.all &&
                _typeFilter == _TypeFilter.all) ...[
              const SizedBox(height: AppDesignTokens.spacing24),
              FilledButton.icon(
                onPressed: onGoToTrials,
                icon: const Icon(Icons.folder_outlined, size: 20),
                label: const Text('Go to Trials'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {bool isFirst = false}) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: AppDesignTokens.spacing8,
        top: isFirst ? AppDesignTokens.spacing4 : AppDesignTokens.spacing8,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppDesignTokens.secondaryText,
        ),
      ),
    );
  }

  Future<void> _onSessionCardTap(
    BuildContext context,
    Session session,
    Trial? trial,
    bool isResumable,
  ) async {
    if (trial == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading trial...')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    if (isResumable) {
      await _navigateToRatingForSession(context, trial, session);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SessionSummaryScreen(trial: trial, session: session),
        ),
      );
    }
  }

  Future<void> _navigateToRatingForSession(
    BuildContext context,
    Trial trial,
    Session session,
  ) async {
    final useCase = ref.read(startOrContinueRatingUseCaseProvider);
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
    if (!result.success ||
        result.trial == null ||
        result.session == null ||
        result.allPlotsSerpentine == null ||
        result.assessments == null ||
        result.startPlotIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ??
              'Unable to continue session for this trial.'),
          backgroundColor: Colors.red,
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
    final pos =
        SessionResumeStore(prefs).getPosition(resolvedSession.id);
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

  Widget _buildSessionCard(
    BuildContext context,
    Session session, {
    required Trial? trial,
    required bool isResumable,
  }) {
    final ratingCountAsync =
        ref.watch(ratingCountForSessionProvider(session.id));

    final trialName = trial?.name ?? 'Trial';
    final isOpen = session.endedAt == null;
    final startStr = _formatTime(session.startedAt);
    final endStr =
        session.endedAt != null ? _formatTime(session.endedAt!) : 'Open';
    final durationStr = session.endedAt != null
        ? ' (${_formatDuration(session.startedAt, session.endedAt!)})'
        : '';

    final wt = workspaceTypeFromStringOrNull(trial?.workspaceType) ??
        WorkspaceType.efficacy;
    final isCustom =
        WorkspaceConfig.forType(wt).mode == TrialMode.standalone;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDesignTokens.spacing12),
      padding: const EdgeInsets.all(AppDesignTokens.spacing16),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius:
            BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: AppDesignTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: session name + badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppDesignTokens.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$trialName · ${session.sessionDateLocal}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              _buildWorkspaceBadge(isCustom),
              const SizedBox(width: 6),
              _buildOpenClosedBadge(isOpen),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing8),
          // Time info
          Text(
            '$startStr \u2192 $endStr$durationStr',
            style: const TextStyle(
              fontSize: 13,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing8),
          // Stats + rater
          Row(
            children: [
              _statPill(
                '${ratingCountAsync.valueOrNull ?? 0} rated',
                AppDesignTokens.successBg,
                AppDesignTokens.successFg,
              ),
              if (session.raterName != null &&
                  session.raterName!.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'by ${session.raterName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppDesignTokens.secondaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          // Attention chips for this trial (blockers, setup gaps, etc.)
          if (trial != null) _buildAttentionChips(trial),
          const SizedBox(height: AppDesignTokens.spacing12),
          // Action buttons
          Row(
            children: [
              if (isResumable)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        _onSessionCardTap(context, session, trial, true),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Continue Rating'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppDesignTokens.primary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                )
              else
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _onSessionCardTap(context, session, trial, false),
                    icon: const Icon(Icons.grid_on, size: 18),
                    label: const Text('Review Data'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttentionChips(Trial trial) {
    final attentionAsync = ref.watch(trialAttentionProvider(trial.id));
    return attentionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        // Show only high/medium severity; exclude noise types already covered by
        // the card itself (openSession, noSessionsYet).
        final filtered = items
            .where((i) =>
                i.type != AttentionType.openSession &&
                i.type != AttentionType.noSessionsYet &&
                (i.severity == AttentionSeverity.high ||
                    i.severity == AttentionSeverity.medium))
            .take(2)
            .toList();
        if (filtered.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: AppDesignTokens.spacing8),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: filtered
                .map((item) => _attentionChip(item, trial))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _attentionChip(AttentionItem item, Trial trial) {
    final Color bg;
    final Color fg;
    switch (item.severity) {
      case AttentionSeverity.high:
        bg = AppDesignTokens.warningBg;
        fg = AppDesignTokens.warningFg;
      case AttentionSeverity.medium:
        bg = AppDesignTokens.partialBg;
        fg = AppDesignTokens.partialFg;
      case AttentionSeverity.low:
        bg = AppDesignTokens.emptyBadgeBg;
        fg = AppDesignTokens.emptyBadgeFg;
      case AttentionSeverity.info:
        bg = AppDesignTokens.successBg;
        fg = AppDesignTokens.successFg;
    }
    return GestureDetector(
      onTap: () => _onAttentionChipTap(item, trial),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing8,
          vertical: AppDesignTokens.spacing4,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusChip),
        ),
        child: Text(
          item.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }

  void _onAttentionChipTap(AttentionItem item, Trial trial) {
    final tabIndex = switch (item.type) {
      AttentionType.seedingMissing => 1,
      AttentionType.seedingPending => 1,
      AttentionType.applicationsPending => 2,
      AttentionType.plotsUnassigned => 0,
      AttentionType.setupIncomplete => 0,
      AttentionType.plotsPartiallyRated => 0,
      AttentionType.dataCollectionComplete => 0,
      AttentionType.openSession => null,
      AttentionType.noSessionsYet => null,
      AttentionType.statisticalAnalysisPending => 0,
    };
    if (tabIndex == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TrialDetailScreen(
          trial: trial,
          initialTabIndex: tabIndex,
        ),
      ),
    );
  }

  Widget _buildWorkspaceBadge(bool isCustom) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing8,
        vertical: AppDesignTokens.spacing4,
      ),
      decoration: BoxDecoration(
        color: AppDesignTokens.primaryTint.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isCustom ? 'Standalone' : 'Imported',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppDesignTokens.primary,
        ),
      ),
    );
  }

  Widget _buildOpenClosedBadge(bool isOpen) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing8,
        vertical: AppDesignTokens.spacing4,
      ),
      decoration: BoxDecoration(
        color: isOpen
            ? AppDesignTokens.openSessionBgLight
            : AppDesignTokens.emptyBadgeBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isOpen ? 'Open' : 'Closed',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isOpen
              ? AppDesignTokens.openSessionBg
              : AppDesignTokens.secondaryText,
        ),
      ),
    );
  }

  Widget _statPill(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing8,
        vertical: AppDesignTokens.spacing4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
