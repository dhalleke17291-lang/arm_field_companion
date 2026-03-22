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
import '../derived/derived_snapshot_provider.dart'
    show derivedSnapshotForSessionProvider;
import '../derived/trial_attention_provider.dart';
import '../derived/trial_attention_service.dart';
import '../sessions/session_detail_screen.dart';
import '../trials/trial_detail_screen.dart';
import '../sessions/usecases/start_or_continue_rating_usecase.dart';
import '../ratings/rating_screen.dart';

/// Wall-clock date string for "today" in local time (yyyy-MM-dd).
String workLogTodayDateLocal() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// Format date for AppBar subtitle (e.g. "Wednesday, March 12").
String formatWorkLogSubtitle(String dateLocal) {
  final d = DateTime.tryParse('$dateLocal 12:00:00');
  if (d == null) return dateLocal;
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
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
  final w = d.weekday - 1;
  final weekday = w >= 0 && w < 7 ? weekdays[w] : '';
  final month = d.month >= 1 && d.month <= 12 ? months[d.month - 1] : '';
  return '$weekday, $month ${d.day}';
}

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

class WorkLogScreen extends ConsumerStatefulWidget {
  const WorkLogScreen({
    super.key,
    this.onGoToTrials,
  });

  /// Called when user taps "Go to Trials" in the empty state. Switches shell to Home tab.
  final VoidCallback? onGoToTrials;

  @override
  ConsumerState<WorkLogScreen> createState() => _WorkLogScreenState();
}

class _WorkLogScreenState extends ConsumerState<WorkLogScreen> {
  late String _selectedDateLocal;

  @override
  void initState() {
    super.initState();
    _selectedDateLocal = workLogTodayDateLocal();
  }

  List<String> _dateChipDates() {
    final today = DateTime.now();
    return List.generate(5, (i) {
      final d = today.subtract(Duration(days: i));
      return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    });
  }

  String _chipLabel(String dateLocal) {
    if (dateLocal == workLogTodayDateLocal()) return 'Today';
    final d = DateTime.tryParse('$dateLocal 12:00:00');
    if (d == null) return dateLocal;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = d.month >= 1 && d.month <= 12 ? months[d.month - 1] : '';
    return '$month ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync =
        ref.watch(workLogSessionsProvider(_selectedDateLocal));
    final subtitle = formatWorkLogSubtitle(_selectedDateLocal);

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Work Log',
              style: AppDesignTokens.headerTitleStyle(
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        backgroundColor: AppDesignTokens.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDateChips(),
          Expanded(
            child: sessionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (sessions) {
                if (sessions.isEmpty) {
                  return _buildEmptyState(widget.onGoToTrials);
                }
                final openSessions =
                    sessions.where((s) => s.endedAt == null).toList();
                final closedSessions =
                    sessions.where((s) => s.endedAt != null).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopAttentionStrip(
                      trialIds: _orderedUniqueTrialIds(
                        openSessions,
                        closedSessions,
                      ),
                      onAttentionTap: (item, trial) =>
                          _onAttentionChipTap(context, item, trial),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppDesignTokens.spacing16,
                          AppDesignTokens.spacing12,
                          AppDesignTokens.spacing16,
                          AppDesignTokens.spacing24,
                        ),
                        children: [
                          if (openSessions.isNotEmpty) ...[
                            _sectionHeader('Continue Working', isFirst: true),
                            ...openSessions.map(
                              (s) => _buildSessionCard(
                                context,
                                s,
                                isResumable: true,
                              ),
                            ),
                          ],
                          if (closedSessions.isNotEmpty) ...[
                            _sectionHeader(
                              'Recent Activity',
                              isFirst: openSessions.isEmpty,
                            ),
                            ...closedSessions.map(
                              (s) => _buildSessionCard(
                                context,
                                s,
                                isResumable: false,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Ordered unique trial IDs: open sessions first, then closed. Preserves display order.
  List<int> _orderedUniqueTrialIds(
    List<Session> openSessions,
    List<Session> closedSessions,
  ) {
    final ordered = [...openSessions, ...closedSessions];
    final seen = <int>{};
    final result = <int>[];
    for (final s in ordered) {
      if (seen.add(s.trialId)) result.add(s.trialId);
    }
    return result;
  }

  Widget _buildDateChips() {
    final dates = _dateChipDates();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing16,
        vertical: AppDesignTokens.spacing12,
      ),
      child: Row(
        children: dates.map((dateLocal) {
          final selected = _selectedDateLocal == dateLocal;
          return Padding(
            padding: const EdgeInsets.only(right: AppDesignTokens.spacing8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedDateLocal = dateLocal),
                borderRadius:
                    BorderRadius.circular(AppDesignTokens.radiusSmall),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDesignTokens.spacing16,
                    vertical: AppDesignTokens.spacing8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppDesignTokens.primary
                        : AppDesignTokens.cardSurface,
                    borderRadius:
                        BorderRadius.circular(AppDesignTokens.radiusSmall),
                    border: selected
                        ? null
                        : Border.all(color: AppDesignTokens.borderCrisp),
                  ),
                  child: Text(
                    _chipLabel(dateLocal),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppDesignTokens.onPrimary
                          : AppDesignTokens.secondaryText,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
            Icon(
              Icons.event_note_outlined,
              size: 64,
              color: AppDesignTokens.secondaryText,
            ),
            const SizedBox(height: AppDesignTokens.spacing16),
            Text(
              'No activity yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppDesignTokens.primaryText,
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing8),
            Text(
              'Start a trial or record your first session to see activity here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            if (onGoToTrials != null) ...[
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
            ? AppDesignTokens.spacing12
            : AppDesignTokens.spacing8,
      ),
      child: Text(
        title,
        style: TextStyle(
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
    bool isResumable,
  ) async {
    final trial = ref.read(trialProvider(session.trialId)).valueOrNull;
    if (trial == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading trial…')),
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
          builder: (_) => SessionDetailScreen(trial: trial, session: session),
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
    final customIds =
        walkOrder == WalkOrderMode.custom ? store.getCustomOrder(session.id) : null;
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
    if (pos != null && pos.$1 >= 0 && pos.$1 < plots.length) {
      startIndex = pos.$1;
      initialAssessmentIndex = pos.$2.clamp(0, assessments.length - 1);
    }
    LastSessionStore(prefs).save(resolvedTrial.id, resolvedSession.id);
    if (!context.mounted) return;
    // Use push (not pushAndRemoveUntil) to avoid disposing MainShell/Work Log
    // while ref.watch dependents are still active; pop returns to Work Log.
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
    required bool isResumable,
  }) {
    final trialAsync = ref.watch(trialProvider(session.trialId));
    final ratingCountAsync =
        ref.watch(ratingCountForSessionProvider(session.id));
    final flagCountAsync = ref.watch(flagCountForSessionProvider(session.id));
    final photoCountAsync = ref.watch(photoCountForSessionProvider(session.id));
    final attentionAsync = ref.watch(trialAttentionProvider(session.trialId));

    final trial = trialAsync.valueOrNull;
    final trialName = trial?.name ?? 'Trial';
    final isOpen = session.endedAt == null;
    final startStr = _formatTime(session.startedAt);
    final endStr =
        session.endedAt != null ? _formatTime(session.endedAt!) : 'Open';
    final durationStr = session.endedAt != null
        ? ' (${_formatDuration(session.startedAt, session.endedAt!)})'
        : '';

    final isCustom =
        trial?.workspaceType.toLowerCase() == 'standalone';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onSessionCardTap(context, session, isResumable),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppDesignTokens.spacing12),
          padding: const EdgeInsets.all(AppDesignTokens.spacing16),
          decoration: BoxDecoration(
            color: AppDesignTokens.cardSurface,
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
            border: Border.all(color: AppDesignTokens.borderCrisp),
            boxShadow: AppDesignTokens.cardShadow,
          ),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      trialName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (trial != null) _buildWorkspaceBadge(isCustom),
                  const SizedBox(width: AppDesignTokens.spacing8),
                  _buildOpenClosedBadge(isOpen),
                  const SizedBox(width: AppDesignTokens.spacing4),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: AppDesignTokens.secondaryText,
                    ),
                    tooltip: 'More actions',
                    onSelected: (value) {
                      if (value == 'delete_session') {
                        _confirmAndSoftDeleteSession(context, session);
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
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing12),
          Text(
            '$startStr → $endStr$durationStr',
            style: const TextStyle(
              fontSize: 13,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing12),
          _buildStatsRow(
            ratingCount: ratingCountAsync.valueOrNull ?? 0,
            flagCount: flagCountAsync.valueOrNull ?? 0,
            photoCount: photoCountAsync.valueOrNull ?? 0,
          ),
          _buildAttentionChips(
            attentionAsync: attentionAsync,
            trial: trial,
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildAttentionChips({
    required AsyncValue<List<AttentionItem>> attentionAsync,
    required Trial? trial,
  }) {
    if (trial == null) return const SizedBox.shrink();
    return attentionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
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
          padding: const EdgeInsets.only(
            top: AppDesignTokens.spacing8,
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: AppDesignTokens.spacing4,
            children: filtered
                .map((item) => _WorkLogAttentionChip(
                      item: item,
                      trial: trial,
                      onTap: () => _onAttentionChipTap(context, item, trial),
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  void _onAttentionChipTap(
    BuildContext context,
    AttentionItem item,
    Trial trial,
  ) {
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

  Future<void> _confirmAndSoftDeleteSession(
    BuildContext context,
    Session session,
  ) async {
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
            session.id,
            deletedBy: user?.displayName,
            deletedByUserId: userId,
          );
      if (!context.mounted) return;
      final trialId = session.trialId;
      ref.invalidate(workLogSessionsProvider(_selectedDateLocal));
      ref.invalidate(sessionsForTrialProvider(trialId));
      ref.invalidate(deletedSessionsProvider);
      ref.invalidate(deletedSessionsForTrialRecoveryProvider(trialId));
      ref.invalidate(openSessionProvider(trialId));
      ref.invalidate(sessionRatingsProvider(session.id));
      ref.invalidate(sessionAssessmentsProvider(session.id));
      ref.invalidate(ratedPlotPksProvider(session.id));
      ref.invalidate(derivedSnapshotForSessionProvider(session.id));
      ref.invalidate(lastSessionContextProvider);
      ScaffoldMessenger.of(context).showSnackBar(
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
        isCustom ? 'Custom' : 'Protocol',
        style: TextStyle(
          fontSize: 11,
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
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isOpen
              ? AppDesignTokens.openSessionBg
              : AppDesignTokens.secondaryText,
        ),
      ),
    );
  }

  Widget _buildStatsRow({
    required int ratingCount,
    required int flagCount,
    required int photoCount,
  }) {
    if (ratingCount == 0 && flagCount == 0 && photoCount == 0) {
      return const Text(
        'No activity recorded',
        style: TextStyle(
          fontSize: 13,
          color: AppDesignTokens.secondaryText,
        ),
      );
    }
    return Wrap(
      spacing: AppDesignTokens.spacing8,
      runSpacing: AppDesignTokens.spacing8,
      children: [
        _statPill(
          '$ratingCount plots rated',
          AppDesignTokens.successBg,
          AppDesignTokens.successFg,
        ),
        _statPill(
          '$flagCount flagged',
          AppDesignTokens.warningBg,
          AppDesignTokens.warningFg,
        ),
        _statPill(
          '$photoCount photos',
          AppDesignTokens.primaryTint,
          AppDesignTokens.primary,
        ),
      ],
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

/// Compact top strip: cross-trial summary of highest-priority attention items.
/// Shows at most 3 items, one per trial, ranked by severity then trial order.
class _TopAttentionStrip extends ConsumerWidget {
  const _TopAttentionStrip({
    required this.trialIds,
    required this.onAttentionTap,
  });

  final List<int> trialIds;
  final void Function(AttentionItem item, Trial trial) onAttentionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stripItems = <({AttentionItem item, int trialId})>[];

    for (final trialId in trialIds) {
      final async = ref.watch(trialAttentionProvider(trialId));
      final items = async.valueOrNull;
      if (items == null) continue;
      final filtered = items.where((i) =>
          i.type != AttentionType.openSession &&
          i.type != AttentionType.noSessionsYet &&
          (i.severity == AttentionSeverity.high ||
              i.severity == AttentionSeverity.medium));
      if (filtered.isNotEmpty) {
        stripItems.add((item: filtered.first, trialId: trialId));
      }
    }

    stripItems.sort((a, b) {
      final severityCompare =
          a.item.severity.index.compareTo(b.item.severity.index);
      if (severityCompare != 0) return severityCompare;
      final indexA = trialIds.indexOf(a.trialId);
      final indexB = trialIds.indexOf(b.trialId);
      return indexA.compareTo(indexB);
    });

    final displayItems = stripItems.take(3).toList();
    if (displayItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing8,
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing8,
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: AppDesignTokens.spacing4,
        children: displayItems
            .map((e) => _TopAttentionStripChip(
                  item: e.item,
                  trialId: e.trialId,
                  onAttentionTap: onAttentionTap,
                ))
            .toList(),
      ),
    );
  }
}

class _TopAttentionStripChip extends ConsumerWidget {
  const _TopAttentionStripChip({
    required this.item,
    required this.trialId,
    required this.onAttentionTap,
  });

  final AttentionItem item;
  final int trialId;
  final void Function(AttentionItem item, Trial trial) onAttentionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trial = ref.watch(trialProvider(trialId)).valueOrNull;
    if (trial == null) return const SizedBox.shrink();
    return _WorkLogAttentionChip(
      item: item,
      trial: trial,
      onTap: () => onAttentionTap(item, trial),
    );
  }
}

class _WorkLogAttentionChip extends StatelessWidget {
  const _WorkLogAttentionChip({
    required this.item,
    required this.trial,
    required this.onTap,
  });

  final AttentionItem item;
  final Trial trial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color dot;

    switch (item.severity) {
      case AttentionSeverity.high:
        bg = AppDesignTokens.warningBg;
        fg = AppDesignTokens.warningFg;
        dot = AppDesignTokens.flagColor;
        break;
      case AttentionSeverity.medium:
        bg = AppDesignTokens.partialBg;
        fg = AppDesignTokens.partialFg;
        dot = AppDesignTokens.flagColor;
        break;
      case AttentionSeverity.low:
        bg = AppDesignTokens.emptyBadgeBg;
        fg = AppDesignTokens.emptyBadgeFg;
        dot = AppDesignTokens.secondaryText;
        break;
      case AttentionSeverity.info:
        bg = AppDesignTokens.successBg;
        fg = AppDesignTokens.successFg;
        dot = AppDesignTokens.appliedColor;
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusChip),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.spacing8,
            vertical: AppDesignTokens.spacing4,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusChip),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                item.label,
                style: AppDesignTokens.headingStyle(
                  fontSize: 11,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
