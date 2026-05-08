import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../../domain/signals/signal_providers.dart';
import '../../domain/signals/signal_review_projection_mapper.dart';
import '../../domain/trial_cognition/environmental_window_evaluator.dart';
import '../../domain/trial_cognition/trial_decision_summary_dto.dart';
import '../../domain/trial_story/trial_story_event.dart';
import '../../domain/trial_story/trial_story_provider.dart';
import '../../shared/layout/responsive_layout.dart';
import 'widgets/signal_action_sheet.dart';

class TrialStoryScreen extends ConsumerWidget {
  const TrialStoryScreen({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trialStoryProvider(trial.id));

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: GradientScreenHeader(
        title: 'Trial Story',
        subtitle: trial.name,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text(
            'Unable to load trial story',
            style: TextStyle(color: AppDesignTokens.secondaryText),
          ),
        ),
        data: (events) => _TrialStoryBody(trial: trial, events: events),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _TrialStoryBody extends StatelessWidget {
  const _TrialStoryBody({required this.trial, required this.events});

  final Trial trial;
  final List<TrialStoryEvent> events;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      child: ListView(
        padding: const EdgeInsets.all(AppDesignTokens.spacing16),
        children: [
          // ── Status ───────────────────────────────────────────────────────────
          _StoryStatusBanner(trialId: trial.id),
          const SizedBox(height: 4),

          // ── Open signals ─────────────────────────────────────────────────────
          _OpenSignalsSection(trialId: trial.id),

          // ── Decisions and reasoning ──────────────────────────────────────────
          _DecisionsSection(trialId: trial.id),

          // ── Timeline section ────────────────────────────────────────────────
          const SizedBox(height: AppDesignTokens.spacing12),
          const Text(
            'TIMELINE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing8),

          if (events.isEmpty) ...[
            const SizedBox(height: AppDesignTokens.spacing8),
            const Text(
              'No trial story yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.primaryText,
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing8),
            const Text(
              'Seeding, applications, and sessions will appear here '
              'as the trial is executed.',
              style: TextStyle(
                fontSize: 13,
                color: AppDesignTokens.secondaryText,
                height: 1.5,
              ),
            ),
          ] else ...[
            const Text(
              'Events are shown with current unresolved signal context '
              'where available.',
              style: TextStyle(
                fontSize: 12,
                color: AppDesignTokens.secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing12),
            ...events.map(
              (e) => Padding(
                padding:
                    const EdgeInsets.only(bottom: AppDesignTokens.spacing12),
                child: _TrialStoryEventTile(event: e, trialId: trial.id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Open signals ──────────────────────────────────────────────────────────────

class _OpenSignalsSection extends ConsumerWidget {
  const _OpenSignalsSection({required this.trialId});
  final int trialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(openSignalsForTrialProvider(trialId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (signals) {
        if (signals.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OPEN SIGNALS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing8),
            ...signals.map(
              (signal) {
                final projection = projectSignalForReview(signal);
                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
                  child: GestureDetector(
                    onTap: () => showSignalActionSheet(
                      context,
                      signal: signal,
                      trialId: trialId,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(AppDesignTokens.spacing12),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.cardSurface,
                        borderRadius:
                            BorderRadius.circular(AppDesignTokens.radiusCard),
                        border: Border.all(color: AppDesignTokens.borderCrisp),
                        boxShadow: AppDesignTokens.cardShadowRating,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  projection.statusLabel,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                    color: AppDesignTokens.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  projection.displayTitle,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppDesignTokens.primaryText,
                                    height: 1.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  projection.shortSummary,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppDesignTokens.secondaryText,
                                    height: 1.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppDesignTokens.spacing8),
                          const Text(
                            'Decide →',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppDesignTokens.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppDesignTokens.spacing4),
          ],
        );
      },
    );
  }
}

// ── Decisions and reasoning ───────────────────────────────────────────────────

class _DecisionsSection extends ConsumerWidget {
  const _DecisionsSection({required this.trialId});
  final int trialId;

  static final _dateFmt = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trialDecisionSummaryProvider(trialId));
    final rawSignalsById = {
      for (final signal
          in ref.watch(openSignalsForTrialProvider(trialId)).valueOrNull ??
              const <Signal>[])
        signal.id: signal,
    };
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (dto) {
        if (!dto.hasAnyResearcherReasoning) return const SizedBox.shrink();

        final entries = _mergedEntries(dto);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DECISIONS AND REASONING',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing8),
            ...entries.map((e) {
              final rawSignal =
                  e.signalId != null ? rawSignalsById[e.signalId] : null;
              final inner = Container(
                padding: const EdgeInsets.all(AppDesignTokens.spacing12),
                decoration: BoxDecoration(
                  color: AppDesignTokens.cardSurface,
                  borderRadius:
                      BorderRadius.circular(AppDesignTokens.radiusCard),
                  border: Border.all(color: AppDesignTokens.borderCrisp),
                  boxShadow: AppDesignTokens.cardShadowRating,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.sourceLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppDesignTokens.primaryText,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        e.decisionLabel,
                        _dateFmt.format(
                            DateTime.fromMillisecondsSinceEpoch(e.timestampMs)
                                .toLocal()),
                        if (e.actorName != null) e.actorName!,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppDesignTokens.secondaryText,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: AppDesignTokens.spacing4),
                    Text(
                      e.reasoning,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppDesignTokens.primaryText,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
              return Padding(
                padding:
                    const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
                child: rawSignal != null
                    ? InkWell(
                        onTap: () => showSignalActionSheet(
                          context,
                          signal: rawSignal,
                          trialId: trialId,
                        ),
                        borderRadius:
                            BorderRadius.circular(AppDesignTokens.radiusCard),
                        child: inner,
                      )
                    : inner,
              );
            }),
          ],
        );
      },
    );
  }

  static List<_LedgerEntry> _mergedEntries(TrialDecisionSummaryDto dto) {
    final entries = <_LedgerEntry>[
      for (final d in dto.signalDecisions)
        if (d.note != null && d.note!.isNotEmpty)
          _LedgerEntry(
            sourceLabel:
                d.note!.length > 80 ? '${d.note!.substring(0, 80)}…' : d.note!,
            decisionLabel: _decisionLabel(d.eventType),
            timestampMs: d.occurredAt,
            actorName: d.actorName,
            reasoning: d.note!,
            signalId: d.signalId,
          ),
      for (final a in dto.ctqAcknowledgments)
        _LedgerEntry(
          sourceLabel: a.factorKey.replaceAll('_', ' '),
          decisionLabel: 'Acknowledged',
          timestampMs: a.acknowledgedAt.millisecondsSinceEpoch,
          actorName: a.actorName,
          reasoning: a.reason,
        ),
    ]..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    return entries;
  }

  static String _decisionLabel(String eventType) => switch (eventType) {
        'confirm' => 'Confirmed',
        'investigate' => 'Investigating',
        'defer' => 'Deferred',
        'suppress' => 'Suppressed',
        're_rate' => 'Re-rated',
        'expire' => 'Expired',
        _ => eventType,
      };
}

class _LedgerEntry {
  const _LedgerEntry({
    required this.sourceLabel,
    required this.decisionLabel,
    required this.timestampMs,
    required this.actorName,
    required this.reasoning,
    this.signalId,
  });

  final String sourceLabel;
  final String decisionLabel;
  final int timestampMs;
  final String? actorName;
  final String reasoning;
  final int? signalId;
}

// ---------------------------------------------------------------------------
// Status banner
// ---------------------------------------------------------------------------

class _StoryStatusBanner extends ConsumerWidget {
  final int trialId;
  const _StoryStatusBanner({required this.trialId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readinessAsync = ref.watch(trialReadinessProvider(trialId));
    return readinessAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (report) {
        final ready = report.canExport;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: ready
                ? AppDesignTokens.successBg
                : AppDesignTokens.warningBg,
            border: Border.all(
              color: ready
                  ? AppDesignTokens.successBg
                  : AppDesignTokens.warningBorder,
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                ready
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                size: 14,
                color: ready
                    ? AppDesignTokens.successFg
                    : AppDesignTokens.warningFg,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ready
                      ? 'Trial is export-ready.'
                      : 'Trial is not export-ready — see Trial Review for details.',
                  style: TextStyle(
                    fontSize: 12,
                    color: ready
                        ? AppDesignTokens.successFg
                        : AppDesignTokens.warningFg,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

class _TrialStoryEventTile extends StatelessWidget {
  const _TrialStoryEventTile({required this.event, required this.trialId});

  final TrialStoryEvent event;
  final int trialId;

  static final _dateFmt = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDesignTokens.spacing16),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: AppDesignTokens.cardShadowRating,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TypeDot(type: event.type),
          const SizedBox(width: AppDesignTokens.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dateFmt.format(event.occurredAt.toLocal()),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppDesignTokens.secondaryText,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppDesignTokens.primaryText,
                    letterSpacing: 0.1,
                  ),
                ),
                if (event.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    event.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ],
                if (event.type == TrialStoryEventType.session) ...[
                  const SizedBox(height: AppDesignTokens.spacing8),
                  _SessionDetails(event: event),
                ],
                if (event.type == TrialStoryEventType.application) ...[
                  const SizedBox(height: AppDesignTokens.spacing8),
                  _ApplicationDetails(event: event, trialId: trialId),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session detail rows
// ---------------------------------------------------------------------------

class _SessionDetails extends StatelessWidget {
  const _SessionDetails({required this.event});

  final TrialStoryEvent event;

  @override
  Widget build(BuildContext context) {
    final signals = event.activeSignalSummary;
    final divs = event.divergenceSummary;
    final ev = event.evidenceSummary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (signals != null && signals.count > 0) ...[
          _DetailRow(
            label:
                '${signals.count} active signal${signals.count == 1 ? '' : 's'}',
          ),
          if (signals.hasCritical)
            const _DetailRow(
              label: 'Critical signal present',
              muted: true,
            ),
        ],
        if (divs != null && divs.count > 0)
          _DetailRow(
            label:
                '${divs.count} protocol difference${divs.count == 1 ? '' : 's'}',
          ),
        if (ev != null) _EvidenceRow(summary: ev),
        if (event.bbchAtSession != null)
          _DetailRow(
            label: 'BBCH ${event.bbchAtSession}',
            muted: true,
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: muted
              ? AppDesignTokens.secondaryText
              : AppDesignTokens.primaryText,
          height: 1.4,
        ),
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.summary});

  final EvidenceSummary summary;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (summary.hasGps) 'GPS confirmed',
      if (summary.hasWeather) 'Weather captured',
      if (summary.photoCount > 0)
        '${summary.photoCount} photo${summary.photoCount == 1 ? '' : 's'}',
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        parts.isEmpty ? 'No evidence captured' : parts.join(' · '),
        style: const TextStyle(
          fontSize: 12,
          color: AppDesignTokens.secondaryText,
          height: 1.4,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Application detail block
// ---------------------------------------------------------------------------

class _ApplicationDetails extends ConsumerWidget {
  const _ApplicationDetails({required this.event, required this.trialId});

  final TrialStoryEvent event;
  final int trialId;

  static bool _isFactual(String status) => switch (status.toLowerCase()) {
        'applied' ||
        'complete' ||
        'completed' ||
        'closed' ||
        'confirmed' =>
          true,
        _ => false,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appSummary = event.applicationSummary;
    if (appSummary == null) return const SizedBox.shrink();

    final contextParts = <String>[
      if (event.bbchAtApplication != null) 'BBCH ${event.bbchAtApplication}',
      if (event.hasApplicationGps) 'GPS confirmed',
    ];

    final isFactual = _isFactual(appSummary.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (contextParts.isNotEmpty)
          _DetailRow(label: contextParts.join(' · '), muted: true),
        if (event.applicationTemperatureC != null)
          _DetailRow(
            label: '${event.applicationTemperatureC!.round()}°C at application',
            muted: true,
          ),
        if (isFactual)
          _AppWindowsRow(trialId: trialId, eventId: event.id)
        else
          const _DetailRow(
            label:
                'Environmental window available after application is confirmed.',
            muted: true,
          ),
      ],
    );
  }
}

class _AppWindowsRow extends ConsumerWidget {
  const _AppWindowsRow({required this.trialId, required this.eventId});

  final int trialId;
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ApplicationEnvironmentalRequest(
      trialId: trialId,
      applicationEventId: eventId,
    );
    final ctxAsync =
        ref.watch(applicationEnvironmentalContextProvider(request));

    return ctxAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (ctx) {
        if (ctx.isUnavailable) {
          return const _DetailRow(
            label: 'Environmental window unavailable.',
            muted: true,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WindowCompactRow(label: '72h before', window: ctx.preWindow),
            _WindowCompactRow(label: '48h after', window: ctx.postWindow),
          ],
        );
      },
    );
  }
}

class _WindowCompactRow extends StatelessWidget {
  const _WindowCompactRow({required this.label, required this.window});

  final String label;
  final EnvironmentalWindowDto window;

  @override
  Widget build(BuildContext context) {
    final noData = window.recordCount == 0;
    final detail = noData ? 'no records' : _summary(window);
    return _DetailRow(label: '$label: $detail', muted: true);
  }

  String _summary(EnvironmentalWindowDto w) {
    final parts = <String>[];
    if (w.totalPrecipitationMm != null) {
      parts.add('${w.totalPrecipitationMm!.toStringAsFixed(1)} mm');
    }
    if (w.minTempC != null) {
      parts.add('min ${w.minTempC!.toStringAsFixed(1)}°C');
    }
    if (w.frostFlagPresent) parts.add('frost');
    return parts.isEmpty ? 'no records' : parts.join(' · ');
  }
}

// ---------------------------------------------------------------------------
// Leading dot
// ---------------------------------------------------------------------------

class _TypeDot extends StatelessWidget {
  const _TypeDot({required this.type});

  final TrialStoryEventType type;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppDesignTokens.secondaryText,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
