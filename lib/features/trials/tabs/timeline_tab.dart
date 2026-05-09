import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';
import '../../../core/ui/field_note_timestamp_format.dart';
import '../../../domain/application_deviation.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../sessions/session_timing_helper.dart';
import '../../../domain/trial_cognition/environmental_window_evaluator.dart';
import '../../../domain/trial_story/trial_story_event.dart';
import '../../../domain/trial_story/trial_story_provider.dart';

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
    // Session enrichments from trialStoryProvider
    this.activeSignalCount,
    this.hasActiveCriticalSignal = false,
    this.divergenceCount,
    this.sessionEvidenceSummary,
    this.bbchAtSession,
    // Application enrichments from trialStoryProvider
    this.applicationEventId,
    this.isApplied = false,
    this.bbchAtApplication,
    this.hasApplicationGps = false,
    this.applicationTemperatureC,
  });

  final DateTime date;
  final _TimelineEventType type;
  final String title;
  final String? subtitle;
  final String? timingText;
  final bool beforeFirstApplication;
  final bool hasDeviation;
  final int? ratingSessionId;
  final String? noteTimestampCaption;
  final String? noteMetaCaption;
  final int? activeSignalCount;
  final bool hasActiveCriticalSignal;
  final int? divergenceCount;
  final EvidenceSummary? sessionEvidenceSummary;
  final int? bbchAtSession;
  final String? applicationEventId;
  final bool isApplied;
  final int? bbchAtApplication;
  final bool hasApplicationGps;
  final double? applicationTemperatureC;
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
    final storyAsync = ref.watch(trialStoryProvider(trial.id));

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

        // Build story enrichment lookup maps from trialStoryProvider.
        final storyEvents = storyAsync.valueOrNull ?? <TrialStoryEvent>[];
        final storyBySessionId = <int, TrialStoryEvent>{};
        final storyByAppId = <String, TrialStoryEvent>{};
        for (final e in storyEvents) {
          if (e.type == TrialStoryEventType.session) {
            final id = int.tryParse(e.id);
            if (id != null) storyBySessionId[id] = e;
          } else if (e.type == TrialStoryEventType.application) {
            storyByAppId[e.id] = e;
          }
        }

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

          final appProducts =
              ref.watch(trialApplicationProductsForEventProvider(app.id))
                  .valueOrNull ?? [];
          final appDeviations = appProducts.isNotEmpty
              ? computeApplicationDeviations(app, appProducts)
              : <ProductDeviationResult>[];
          final appHasDeviation =
              appDeviations.any((d) => d.exceedsTolerance);

          final appStory = storyByAppId[app.id];
          events.add(_TrialTimelineEvent(
            date: app.applicationDate,
            type: _TimelineEventType.application,
            title: productLabel,
            subtitle: appSubtitleParts.join(' · '),
            timingText: timingText,
            hasDeviation: appHasDeviation,
            applicationEventId: app.id,
            isApplied: app.status == 'applied',
            bbchAtApplication: appStory?.bbchAtApplication,
            hasApplicationGps: appStory?.hasApplicationGps ?? false,
            applicationTemperatureC: appStory?.applicationTemperatureC,
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
          final sessionStory = storyBySessionId[session.id];
          events.add(_TrialTimelineEvent(
            date: session.startedAt,
            type: _TimelineEventType.session,
            title: 'Rating session',
            subtitle: session.name,
            timingText: timingText,
            beforeFirstApplication: beforeFirst,
            ratingSessionId: session.id,
            activeSignalCount: sessionStory?.activeSignalSummary?.count,
            hasActiveCriticalSignal:
                sessionStory?.activeSignalSummary?.hasCritical ?? false,
            divergenceCount: sessionStory?.divergenceSummary?.count,
            sessionEvidenceSummary: sessionStory?.evidenceSummary,
            bbchAtSession: sessionStory?.bbchAtSession,
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
              _TimelineDateGroupSection(group: groups[i], trialId: trial.id),
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
  const _TimelineDateGroupSection({required this.group, required this.trialId});

  final _TimelineDateGroup group;
  final int trialId;

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
                  trialId: trialId,
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
    required this.trialId,
  });

  final _TrialTimelineEvent event;
  final bool isFirst;
  final bool isLast;
  final Color railColor;
  final int trialId;

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
                            const Text(
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
                          // ── Session enrichments ──────────────────────────
                          if (event.type == _TimelineEventType.session) ...[
                            if (event.activeSignalCount != null &&
                                event.activeSignalCount! > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${event.activeSignalCount} active signal${event.activeSignalCount == 1 ? '' : 's'}${event.hasActiveCriticalSignal ? ' · Critical' : ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppDesignTokens.warningFg,
                                ),
                              ),
                            ],
                            if (event.divergenceCount != null &&
                                event.divergenceCount! > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${event.divergenceCount} protocol deviation${event.divergenceCount == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (event.sessionEvidenceSummary != null) ...[
                              const SizedBox(height: 2),
                              _TimelineEvidenceText(
                                summary: event.sessionEvidenceSummary!,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                            if (event.bbchAtSession != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'BBCH ${event.bbchAtSession}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                          // ── Application enrichments ──────────────────────
                          if (event.type == _TimelineEventType.application) ...[
                            if (event.bbchAtApplication != null ||
                                event.hasApplicationGps ||
                                event.applicationTemperatureC != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (event.bbchAtApplication != null)
                                    'BBCH ${event.bbchAtApplication}',
                                  if (event.hasApplicationGps) 'GPS confirmed',
                                  if (event.applicationTemperatureC != null)
                                    '${event.applicationTemperatureC!.round()}°C at application',
                                ].join(' · '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (event.isApplied &&
                                event.applicationEventId != null) ...[
                              const SizedBox(height: 2),
                              _TimelineAppWindowsRow(
                                trialId: trialId,
                                applicationEventId: event.applicationEventId!,
                              ),
                            ],
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

/// Evidence summary line for a session tile: "GPS · Weather · 3 photos" or "No evidence captured".
class _TimelineEvidenceText extends StatelessWidget {
  const _TimelineEvidenceText({required this.summary, required this.color});

  final EvidenceSummary summary;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (summary.hasGps) 'GPS',
      if (summary.hasWeather) 'Weather',
      if (summary.photoCount > 0)
        '${summary.photoCount} photo${summary.photoCount == 1 ? '' : 's'}',
    ];
    return Text(
      parts.isEmpty ? 'No evidence captured' : parts.join(' · '),
      style: TextStyle(fontSize: 12, color: color),
    );
  }
}

/// Pre- and post-application environmental windows for an applied application tile.
class _TimelineAppWindowsRow extends ConsumerWidget {
  const _TimelineAppWindowsRow({
    required this.trialId,
    required this.applicationEventId,
  });

  final int trialId;
  final String applicationEventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ctxAsync = ref.watch(
      applicationEnvironmentalContextProvider(
        ApplicationEnvironmentalRequest(
          trialId: trialId,
          applicationEventId: applicationEventId,
        ),
      ),
    );
    return ctxAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (ctx) {
        if (ctx.isUnavailable) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _windowLine('72h before', ctx.preWindow, scheme),
            _windowLine('48h after', ctx.postWindow, scheme),
          ],
        );
      },
    );
  }

  Widget _windowLine(String label, EnvironmentalWindowDto w, ColorScheme scheme) {
    final String detail;
    if (w.recordCount == 0) {
      detail = 'no records';
    } else {
      final parts = <String>[
        if (w.totalPrecipitationMm != null)
          '${w.totalPrecipitationMm!.toStringAsFixed(1)} mm',
        if (w.minTempC != null) 'min ${w.minTempC!.toStringAsFixed(1)}°C',
        if (w.frostFlagPresent) 'frost',
      ];
      detail = parts.isEmpty ? 'no records' : parts.join(' · ');
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '$label: $detail',
        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
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
