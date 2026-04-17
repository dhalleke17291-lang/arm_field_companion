import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';
import '../../../core/ui/field_note_timestamp_format.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../sessions/session_timing_helper.dart';

enum _TimelineEventType { seeding, application, session, note }

class _TrialTimelineEvent {
  const _TrialTimelineEvent({
    required this.date,
    required this.type,
    required this.title,
    this.subtitle,
    this.timingText,
    this.beforeFirstApplication = false,
    this.hasDeviation = false,
    this.ratingSessionId,
    this.noteTimestampCaption,
    this.noteMetaCaption,
  });

  final DateTime date;
  final _TimelineEventType type;
  final String title;
  final String? subtitle;
  final String? timingText;
  final bool beforeFirstApplication;
  /// True when this application has deviation-flagged products.
  final bool hasDeviation;
  /// Set for rating sessions only (weather badge).
  final int? ratingSessionId;
  /// Field note: full date · time line (matches list/detail surfaces).
  final String? noteTimestampCaption;
  /// Field note: plot / session name / author (matches list/detail surfaces).
  final String? noteMetaCaption;
}

/// Date group: header + events on a continuous vertical rail.
class _TimelineDateGroup {
  const _TimelineDateGroup({required this.date, required this.events});

  final DateTime date;
  final List<_TrialTimelineEvent> events;
}

/// Read-only trial timeline: date-grouped seeding, applications, sessions.
/// Weather cloud badge on session rows uses [weatherSnapshotForSessionProvider].
class TimelineTab extends ConsumerWidget {
  const TimelineTab({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seedingAsync = ref.watch(seedingEventForTrialProvider(trial.id));
    final applicationsAsync =
        ref.watch(trialApplicationsForTrialProvider(trial.id));
    final sessionsAsync = ref.watch(sessionsForTrialProvider(trial.id));
    final notesAsync = ref.watch(notesForTrialProvider(trial.id));
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));

    return seedingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDesignTokens.spacing16),
          child: Text(
            'Failed to load timeline: $e',
            style: const TextStyle(color: AppDesignTokens.secondaryText),
          ),
        ),
      ),
      data: (seedingEvent) {
        final applications = applicationsAsync.valueOrNull ?? [];
        final sessions = sessionsAsync.valueOrNull ?? [];
        final fieldNotes = notesAsync.valueOrNull ?? [];
        final plots = plotsAsync.valueOrNull ?? [];
        final plotIdByPk = {for (final p in plots) p.id: p.plotId};
        final sessionIdToName = {for (final s in sessions) s.id: s.name};
        final seedingDate = seedingEvent?.seedingDate;

        // "Before first application" warning uses first APPLIED date only.
        // A session before a pending (planned) application is not a problem.
        final appliedApplications =
            applications.where((a) => a.status == 'applied').toList();
        final DateTime? firstApplicationDate = appliedApplications.isEmpty
            ? null
            : appliedApplications
                .map((a) => a.applicationDate)
                .reduce((a, b) => a.isBefore(b) ? a : b);

        final events = <_TrialTimelineEvent>[];

        if (seedingEvent != null) {
          final statusLabel =
              seedingEvent.status == 'completed' ? 'Completed' : 'Pending';
          final op = seedingEvent.operatorName?.trim();
          final String? seedingSubtitle;
          if (op != null && op.isNotEmpty) {
            seedingSubtitle = '$op · $statusLabel';
          } else {
            seedingSubtitle = statusLabel;
          }
          events.add(_TrialTimelineEvent(
            date: seedingEvent.seedingDate,
            type: _TimelineEventType.seeding,
            title: 'Seeding',
            subtitle: seedingSubtitle,
            timingText: 'Day 0',
          ));
        }

        for (final app in applications) {
          final days = seedingDate != null
              ? app.applicationDate.difference(seedingDate).inDays
              : null;
          final timingText = days != null ? '$days days after seeding' : null;
          final productLabel = app.productName?.trim().isNotEmpty == true
              ? app.productName!
              : 'Application';
          final ratePart = (app.rate != null && app.rateUnit != null)
              ? '${app.rate} ${app.rateUnit}'
              : null;
          final statusLabel = app.status == 'applied' ? 'Applied' : 'Pending';
          final appSubtitleParts = <String>[];
          if (ratePart != null && ratePart.isNotEmpty) {
            appSubtitleParts.add(ratePart);
          }
          appSubtitleParts.add(statusLabel);

          events.add(_TrialTimelineEvent(
            date: app.applicationDate,
            type: _TimelineEventType.application,
            title: productLabel,
            subtitle: appSubtitleParts.join(' · '),
            timingText: timingText,
          ));
        }

        for (final session in sessions) {
          final timingCtx = buildSessionTimingContext(
            sessionStartedAt: session.startedAt,
            cropStageBbch: session.cropStageBbch,
            seeding: seedingEvent,
            applications: applications,
          );
          final days = seedingDate != null
              ? session.startedAt.difference(seedingDate).inDays
              : null;
          final String? timingText;
          if (timingCtx.displayLine.isNotEmpty) {
            timingText = timingCtx.displayLine;
          } else if (days != null) {
            timingText = '$days days after seeding';
          } else {
            timingText = null;
          }
          final beforeFirst = firstApplicationDate != null &&
              !session.startedAt.isAfter(firstApplicationDate) &&
              session.startedAt.isBefore(firstApplicationDate);
          events.add(_TrialTimelineEvent(
            date: session.startedAt,
            type: _TimelineEventType.session,
            title: 'Rating session',
            subtitle: session.name,
            timingText: timingText,
            beforeFirstApplication: beforeFirst,
            ratingSessionId: session.id,
          ));
        }

        for (final note in fieldNotes) {
          final days = seedingDate != null
              ? note.createdAt.difference(seedingDate).inDays
              : null;
          final timingText = days != null ? '$days days after seeding' : null;
          final preview = note.content.trim();
          final noteMeta = formatFieldNoteContextLine(
            note,
            plotIdByPk: plotIdByPk,
            sessionIdToName: sessionIdToName,
            includeSession: true,
          );
          events.add(_TrialTimelineEvent(
            date: note.createdAt,
            type: _TimelineEventType.note,
            title: 'Field note',
            subtitle: preview.length > 80
                ? '${preview.substring(0, 80)}…'
                : preview,
            timingText: timingText,
            noteTimestampCaption: formatFieldNoteTimestampLine(note),
            noteMetaCaption:
                noteMeta.trim().isEmpty ? null : noteMeta.trim(),
          ));
        }

        events.sort((a, b) => a.date.compareTo(b.date));

        if (events.isEmpty) {
          return const AppEmptyState(
            icon: Icons.timeline,
            title: 'No events recorded yet',
            subtitle:
                'Seeding, applications, rating sessions, and field notes will appear here.',
          );
        }

        // Group by local calendar date — key is (year, month, day), never raw timestamp equality
        final groups = <_TimelineDateGroup>[];
        List<_TrialTimelineEvent>? currentList;
        DateTime? currentDay;

        for (final e in events) {
          final day = DateTime(e.date.year, e.date.month, e.date.day);
          if (currentDay == null || day != currentDay) {
            currentDay = day;
            currentList = [];
            groups.add(_TimelineDateGroup(date: day, events: currentList));
          }
          currentList!.add(e);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDesignTokens.spacing16,
            AppDesignTokens.spacing12,
            AppDesignTokens.spacing16,
            AppDesignTokens.spacing24,
          ),
          children: [
            for (var i = 0; i < groups.length; i++) ...[
              _TimelineDateGroupSection(group: groups[i]),
              if (i < groups.length - 1)
                _IntervalLabel(
                  from: groups[i].date,
                  to: groups[i + 1].date,
                ),
            ],
          ],
        );
      },
    );
  }
}

/// One date group: bold date header + vertical rail with event rows.
class _TimelineDateGroupSection extends StatelessWidget {
  const _TimelineDateGroupSection({required this.group});

  final _TimelineDateGroup group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateHeader = DateFormat('MMM d, yyyy').format(group.date);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dateHeader,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < group.events.length; i++)
                _TimelineEventRow(
                  event: group.events[i],
                  isFirst: i == 0,
                  isLast: i == group.events.length - 1,
                  railColor: scheme.outlineVariant,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One event row: 2px rail segment + filled circle (color by type) + content (title, subtitle, timing, warning).
class _TimelineEventRow extends ConsumerWidget {
  const _TimelineEventRow({
    required this.event,
    required this.isFirst,
    required this.isLast,
    required this.railColor,
  });

  final _TrialTimelineEvent event;
  final bool isFirst;
  final bool isLast;
  final Color railColor;

  static const double _railWidth = 2.0;
  static const double _circleSize = 12.0;
  static const double _segmentHeight = 16.0;

  IconData get _icon {
    switch (event.type) {
      case _TimelineEventType.seeding:
        return Icons.grass;
      case _TimelineEventType.application:
        return Icons.water_drop_outlined;
      case _TimelineEventType.session:
        return Icons.assignment_outlined;
      case _TimelineEventType.note:
        return Icons.sticky_note_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final circleColor = switch (event.type) {
      _TimelineEventType.seeding => scheme.primary,
      _TimelineEventType.application => scheme.secondary,
      _TimelineEventType.session => scheme.tertiary,
      _TimelineEventType.note => scheme.primaryContainer,
    };
    final hasWeather = event.type == _TimelineEventType.session &&
            event.ratingSessionId != null
        ? ref
            .watch(
              weatherSnapshotForSessionProvider(event.ratingSessionId!),
            )
            .maybeWhen(
              data: (w) => w != null,
              orElse: () => false,
            )
        : false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isFirst)
                Container(
                  width: _railWidth,
                  height: _segmentHeight,
                  margin: const EdgeInsets.only(left: 14),
                  color: railColor,
                ),
              Center(
                child: Container(
                  width: _circleSize,
                  height: _circleSize,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: _railWidth,
                  height: _segmentHeight,
                  margin: const EdgeInsets.only(left: 14),
                  color: railColor,
                ),
            ],
          ),
        ),
        const SizedBox(width: AppDesignTokens.spacing12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Icon(_icon, size: 18, color: scheme.onSurface),
                    ),
                    const SizedBox(width: AppDesignTokens.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              if (hasWeather)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.cloud,
                                    size: 16,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          if (event.noteTimestampCaption != null &&
                              event.noteTimestampCaption!.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              event.noteTimestampCaption!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (event.noteMetaCaption != null &&
                              event.noteMetaCaption!.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              event.noteMetaCaption!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (event.subtitle != null &&
                              event.subtitle!.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              event.subtitle!,
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (event.timingText != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              event.timingText!,
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (event.hasDeviation) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Rate deviation flagged',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppDesignTokens.warningFg,
                              ),
                            ),
                          ],
                          if (event.beforeFirstApplication) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Before first application',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows the number of days between two date groups on the timeline.
class _IntervalLabel extends StatelessWidget {
  const _IntervalLabel({required this.from, required this.to});
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    final days = to.difference(from).inDays.abs();
    if (days <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(
        left: 40,
        bottom: AppDesignTokens.spacing8,
      ),
      child: Text(
        '$days days',
        style: TextStyle(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: AppDesignTokens.secondaryText.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
