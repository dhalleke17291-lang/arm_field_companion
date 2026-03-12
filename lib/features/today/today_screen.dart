import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';
import 'domain/activity_event.dart';

/// Wall-clock date string for "today" in local time.
String todayDateLocal() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// Format [dateLocal] for display (e.g. "Wed, Mar 11" or "Today").
String formatDateLabel(String dateLocal) {
  final today = todayDateLocal();
  if (dateLocal == today) return 'Today';
  final d = DateTime.tryParse('$dateLocal 12:00:00');
  if (d == null) return dateLocal;
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final w = d.weekday - 1; // 1=Mon -> 0
  final weekday = w >= 0 && w < 7 ? weekdays[w] : '';
  final month = d.month >= 1 && d.month <= 12 ? months[d.month - 1] : '';
  return '$weekday, $month ${d.day}';
}

/// Format time for list (e.g. "2:34 PM").
String formatTime(DateTime at) {
  final hour = at.hour == 0 ? 12 : (at.hour > 12 ? at.hour - 12 : at.hour);
  final ampm = at.hour < 12 ? 'AM' : 'PM';
  final min = at.minute.toString().padLeft(2, '0');
  return '$hour:$min $ampm';
}

/// Date and time on one line (e.g. "11 Mar 2026, 10:18 PM").
String formatDateAndTime(DateTime at) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final month = at.month >= 1 && at.month <= 12 ? months[at.month - 1] : '';
  final hour = at.hour == 0 ? 12 : (at.hour > 12 ? at.hour - 12 : at.hour);
  final ampm = at.hour < 12 ? 'AM' : 'PM';
  final min = at.minute.toString().padLeft(2, '0');
  return '${at.day} $month ${at.year}, $hour:$min $ampm';
}

enum WorkLogSort { dateNewest, dateOldest, trial, session, eventType }

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late String _dateLocal;
  WorkLogSort _sort = WorkLogSort.dateNewest;

  @override
  void initState() {
    super.initState();
    _dateLocal = todayDateLocal();
  }

  List<ActivityEvent> _applySort(List<ActivityEvent> events) {
    final copy = List<ActivityEvent>.from(events);
    String trialName(ActivityEvent e) => switch (e) {
          SessionStartedEvent x => x.trialName,
          SessionClosedEvent x => x.trialName,
          RatingsBatchEvent x => x.trialName,
          FlagsBatchEvent x => x.trialName,
          PhotosBatchEvent x => x.trialName,
          PlotsAssignedEvent x => x.trialName,
          ExportDoneEvent x => x.trialName,
        };
    String sessionName(ActivityEvent e) => switch (e) {
          SessionStartedEvent x => x.sessionName,
          SessionClosedEvent x => x.sessionName,
          RatingsBatchEvent x => x.sessionName,
          FlagsBatchEvent x => x.sessionName,
          PhotosBatchEvent x => x.sessionName,
          PlotsAssignedEvent _ => '',
          ExportDoneEvent _ => '',
        };
    String eventTypeKey(ActivityEvent e) => switch (e) {
          SessionStartedEvent _ => 'Started',
          SessionClosedEvent _ => 'Closed',
          RatingsBatchEvent _ => 'Rated',
          FlagsBatchEvent _ => 'Flagged',
          PhotosBatchEvent _ => 'Photos',
          PlotsAssignedEvent _ => 'Assigned',
          ExportDoneEvent _ => 'Export',
        };
    switch (_sort) {
      case WorkLogSort.dateNewest:
        copy.sort((a, b) => b.at.compareTo(a.at));
        break;
      case WorkLogSort.dateOldest:
        copy.sort((a, b) => a.at.compareTo(b.at));
        break;
      case WorkLogSort.trial:
        copy.sort((a, b) {
          final c = trialName(a).compareTo(trialName(b));
          return c != 0 ? c : b.at.compareTo(a.at);
        });
        break;
      case WorkLogSort.session:
        copy.sort((a, b) {
          final c = sessionName(a).compareTo(sessionName(b));
          return c != 0 ? c : b.at.compareTo(a.at);
        });
        break;
      case WorkLogSort.eventType:
        copy.sort((a, b) {
          final c = eventTypeKey(a).compareTo(eventTypeKey(b));
          return c != 0 ? c : b.at.compareTo(a.at);
        });
        break;
    }
    return copy;
  }

  Future<void> _showDatePickerSheet() async {
    final today = todayDateLocal();
    final dates = await ref.read(workLogDatesProvider.future);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Today'),
              trailing: _dateLocal == today ? const Icon(Icons.check, color: AppDesignTokens.primary) : null,
              onTap: () {
                setState(() => _dateLocal = today);
                Navigator.pop(ctx);
              },
            ),
            if (dates.isNotEmpty) ...[
              const Divider(height: 1),
              ...dates.map((d) {
                final isSelected = _dateLocal == d.dateLocal;
                return ListTile(
                  title: Text(formatDateLabel(d.dateLocal)),
                  subtitle: Text('${d.eventCount} ${d.eventCount == 1 ? 'event' : 'events'}'),
                  trailing: isSelected ? const Icon(Icons.check, color: AppDesignTokens.primary) : null,
                  onTap: () {
                    setState(() => _dateLocal = d.dateLocal);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Pick another date'),
              onTap: () async {
                Navigator.pop(ctx);
                final d = DateTime.tryParse('$_dateLocal 12:00:00');
                final initial = d ?? DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null && mounted) {
                  setState(() {
                    _dateLocal = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(todayActivityProvider(_dateLocal));
    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: GradientScreenHeader(
        title: 'Work log',
        actions: [
          PopupMenuButton<WorkLogSort>(
            icon: const Icon(Icons.sort, color: Colors.white),
            tooltip: 'Sort by',
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: WorkLogSort.dateNewest, child: Text('Date (newest)')),
              const PopupMenuItem(value: WorkLogSort.dateOldest, child: Text('Date (oldest)')),
              const PopupMenuItem(value: WorkLogSort.trial, child: Text('Trial')),
              const PopupMenuItem(value: WorkLogSort.session, child: Text('Session')),
              const PopupMenuItem(value: WorkLogSort.eventType, child: Text('Event type')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppDesignTokens.spacing16, AppDesignTokens.spacing12, AppDesignTokens.spacing16, 0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showDatePickerSheet,
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDesignTokens.spacing16,
                      vertical: AppDesignTokens.spacing12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, size: 18, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: AppDesignTokens.spacing8),
                        Text(
                          formatDateLabel(_dateLocal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppDesignTokens.primaryText,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 20, color: AppDesignTokens.iconSubtle),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing8),
            Expanded(
              child: activityAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDesignTokens.spacing24),
                    child: Text(
                      'Unable to load activity: $e',
                      style: const TextStyle(color: AppDesignTokens.secondaryText),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (events) {
                  final sorted = _applySort(events);
                  if (sorted.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(todayActivityProvider(_dateLocal));
                        await ref.read(todayActivityProvider(_dateLocal).future);
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppDesignTokens.spacing24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.today_outlined,
                                    size: 56,
                                    color: AppDesignTokens.emptyBadgeFg,
                                  ),
                                  const SizedBox(height: AppDesignTokens.spacing16),
                                  Text(
                                    _dateLocal == todayDateLocal()
                                        ? 'Nothing recorded today yet'
                                        : 'Nothing recorded on ${formatDateLabel(_dateLocal)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppDesignTokens.primaryText,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(todayActivityProvider(_dateLocal));
                      await ref.read(todayActivityProvider(_dateLocal).future);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(AppDesignTokens.spacing16, 0, AppDesignTokens.spacing16, AppDesignTokens.spacing24),
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        return _ActivityTile(event: sorted[index]);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.event});

  final ActivityEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (String title, IconData icon, Color? iconColor) = switch (event) {
      SessionStartedEvent e => (
          '${e.trialName} · ${e.sessionName} · Started',
          Icons.play_circle_outline,
          AppDesignTokens.primary,
        ),
      SessionClosedEvent e => (
          '${e.trialName} · ${e.sessionName} · Closed',
          Icons.check_circle_outline,
          AppDesignTokens.successFg,
        ),
      RatingsBatchEvent e => (
          '${e.trialName} · ${e.sessionName} · Rated ${e.count} ${e.count == 1 ? 'plot' : 'plots'}',
          Icons.rate_review_outlined,
          null,
        ),
      FlagsBatchEvent e => (
          '${e.trialName} · ${e.sessionName} · Flagged ${e.count} ${e.count == 1 ? 'plot' : 'plots'}',
          Icons.flag_outlined,
          AppDesignTokens.flagColor,
        ),
      PhotosBatchEvent e => (
          '${e.trialName} · ${e.sessionName} · ${e.count} ${e.count == 1 ? 'photo' : 'photos'}',
          Icons.photo_library_outlined,
          null,
        ),
      PlotsAssignedEvent e => (
          '${e.trialName} · Assigned ${e.count} ${e.count == 1 ? 'plot' : 'plots'}',
          Icons.assignment_outlined,
          null,
        ),
      ExportDoneEvent e => (
          '${e.trialName} · Exported ${e.format}',
          Icons.upload_file,
          AppDesignTokens.secondaryText,
        ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing12),
      child: Container(
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (iconColor ?? theme.colorScheme.primary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDesignTokens.radiusXSmall),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppDesignTokens.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppDesignTokens.primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDateAndTime(event.at),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
