import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';

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
  const WorkLogScreen({super.key});

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
                if (sessions.isEmpty) return _buildEmptyState();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDesignTokens.spacing16,
                    AppDesignTokens.spacing12,
                    AppDesignTokens.spacing16,
                    AppDesignTokens.spacing24,
                  ),
                  children: sessions
                      .map((s) => _buildSessionCard(context, s))
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
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
                          ? Colors.white
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

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 64,
            color: AppDesignTokens.secondaryText,
          ),
          SizedBox(height: AppDesignTokens.spacing16),
          Text(
            'No activity on this day',
            style: TextStyle(
              fontSize: 15,
              color: AppDesignTokens.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, Session session) {
    final trialAsync = ref.watch(trialProvider(session.trialId));
    final ratingCountAsync =
        ref.watch(ratingCountForSessionProvider(session.id));
    final flagCountAsync = ref.watch(flagCountForSessionProvider(session.id));
    final photoCountAsync = ref.watch(photoCountForSessionProvider(session.id));

    final trialName = trialAsync.valueOrNull?.name ?? 'Trial';
    final isOpen = session.endedAt == null;
    final startStr = _formatTime(session.startedAt);
    final endStr =
        session.endedAt != null ? _formatTime(session.endedAt!) : 'Open';
    final durationStr = session.endedAt != null
        ? ' (${_formatDuration(session.startedAt, session.endedAt!)})'
        : '';

    return Container(
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
              _buildOpenClosedBadge(isOpen),
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
        ],
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
