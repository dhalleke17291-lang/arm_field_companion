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
            _buildFilterRow(),
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

                  // Group closed sessions by sessionDateLocal
                  final closedByDate = <String, List<Session>>{};
                  for (final s in closedSessions) {
                    closedByDate
                        .putIfAbsent(s.sessionDateLocal, () => [])
                        .add(s);
                  }
                  final sortedDates = closedByDate.keys.toList()
                    ..sort((a, b) => b.compareTo(a));

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppDesignTokens.spacing16,
                      AppDesignTokens.spacing12,
                      AppDesignTokens.spacing16,
                      AppDesignTokens.spacing24,
                    ),
                    children: [
                      if (openSessions.isNotEmpty) ...[
                        _sectionHeader('Open', isFirst: true),
                        ...openSessions.map(
                          (s) => _buildSessionCard(
                            context,
                            s,
                            trial: trialMap[s.trialId],
                            isResumable: true,
                          ),
                        ),
                      ],
                      for (var i = 0; i < sortedDates.length; i++) ...[
                        _sectionHeader(
                          _formatDateHeader(sortedDates[i]),
                          isFirst: openSessions.isEmpty && i == 0,
                        ),
                        ...closedByDate[sortedDates[i]]!.map(
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

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing12,
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing12,
      ),
      decoration: const BoxDecoration(
        color: AppDesignTokens.cardSurface,
        border: Border(
          bottom: BorderSide(color: AppDesignTokens.borderCrisp, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _filterDropdown<_StatusFilter>(
              label: 'Status',
              value: _statusFilter,
              items: const [
                (_StatusFilter.all, 'All'),
                (_StatusFilter.open, 'Open'),
                (_StatusFilter.closed, 'Closed'),
              ],
              onChanged: (v) => setState(() => _statusFilter = v),
            ),
          ),
          const SizedBox(width: AppDesignTokens.spacing8),
          Expanded(
            child: _filterDropdown<_TypeFilter>(
              label: 'Type',
              value: _typeFilter,
              items: const [
                (_TypeFilter.all, 'All'),
                (_TypeFilter.standalone, 'Custom'),
                (_TypeFilter.imported, 'Protocol'),
              ],
              onChanged: (v) => setState(() => _typeFilter = v),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact outlined dropdown — "Label: Value ▾".
  /// Follows visual calm rule: no fill, subtle border, secondary text weight.
  Widget _filterDropdown<T>({
    required String label,
    required T value,
    required List<(T, String)> items,
    required ValueChanged<T> onChanged,
  }) {
    final selectedLabel =
        items.firstWhere((e) => e.$1 == value, orElse: () => items.first).$2;
    return Container(
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppDesignTokens.borderCrisp),
      ),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            iconSize: 18,
            icon: Icon(
              Icons.arrow_drop_down,
              color: AppDesignTokens.secondaryText.withValues(alpha: 0.7),
            ),
            borderRadius: BorderRadius.circular(8),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppDesignTokens.primaryText,
            ),
            selectedItemBuilder: (_) => items
                .map((e) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$label: ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppDesignTokens.secondaryText
                                    .withValues(alpha: 0.75),
                              ),
                            ),
                            TextSpan(
                              text: selectedLabel,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppDesignTokens.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ))
                .toList(),
            items: items
                .map((e) => DropdownMenuItem<T>(
                      value: e.$1,
                      child: Text(e.$2),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }

  String _formatDateHeader(String sessionDateLocal) {
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (sessionDateLocal == today) return 'Today';

    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr =
        '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    if (sessionDateLocal == yesterdayStr) return 'Yesterday';

    final d = DateTime.tryParse('$sessionDateLocal 12:00:00');
    if (d == null) return sessionDateLocal;
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final month = months[d.month - 1];
    return '$month ${d.day}, ${d.year}';
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
        top: isFirst
            ? AppDesignTokens.spacing4
            : AppDesignTokens.spacing16,
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppDesignTokens.secondaryText.withValues(alpha: 0.7),
          letterSpacing: 0.8,
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

    // Soft accent color for trial type distinction — left bar only, no pill.
    final accentColor = isCustom
        ? AppDesignTokens.primary.withValues(alpha: 0.45)
        : const Color(0xFFB8860B).withValues(alpha: 0.45); // muted amber

    return Container(
      margin: const EdgeInsets.only(bottom: AppDesignTokens.spacing12),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: AppDesignTokens.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDesignTokens.spacing12,
          AppDesignTokens.spacing12,
          AppDesignTokens.spacing16,
          AppDesignTokens.spacing12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trial type accent line (soft green = Custom, soft amber = Protocol).
            Container(
              width: 3,
              height: 44,
              margin: const EdgeInsets.only(
                  right: AppDesignTokens.spacing12, top: 2),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // Header: session name + status
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
            ),
          ],
        ),
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
