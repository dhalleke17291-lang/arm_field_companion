import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/design/app_design_tokens.dart';
import '../../../../core/providers.dart';
import '../../../../domain/relationships/evidence_anchors_provider.dart';
import '../../../../domain/trial_cognition/environmental_window_evaluator.dart';
import '_overview_card.dart';

class Section8Environmental extends ConsumerWidget {
  const Section8Environmental({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Always watch to satisfy Riverpod's consistent-subscription requirement.
    final summaryAsync = ref.watch(trialEnvironmentalSummaryProvider(trial.id));
    final appsAsync = ref.watch(trialApplicationsForTrialProvider(trial.id));
    final evidenceAsync = ref.watch(evidenceAnchorsProvider(trial.id));

    final hasGps = trial.latitude != null && trial.longitude != null;
    final fieldGpsExists = _hasFieldGps(
      appsAsync.valueOrNull,
      evidenceAsync.valueOrNull,
    );
    final provenanceAsync =
        ref.watch(trialEnvironmentalProvenanceProvider(trial.id));

    return OverviewSectionCard(
      number: 8,
      title: 'Environmental Evidence',
      child: !hasGps
          ? _EnvUnavailable(
              reason: fieldGpsExists
                  ? 'Rating/application GPS exists, but trial site coordinates are not set for environmental weather lookup.'
                  : 'Trial site coordinates are required for environmental evidence. '
                      'Rating/session GPS may exist for provenance, but it is not currently linked as the trial site reference.',
            )
          : summaryAsync.when(
              loading: () => const OverviewSectionLoading(),
              error: (_, __) => const OverviewSectionError(),
              data: (summary) => appsAsync.when(
                loading: () => const OverviewSectionLoading(),
                error: (_, __) => const OverviewSectionError(),
                data: (apps) => _EnvBody(
                  trial: trial,
                  summary: summary,
                  appEvents: apps,
                  provenance: provenanceAsync.valueOrNull,
                ),
              ),
            ),
    );
  }

  bool _hasFieldGps(
    List<TrialApplicationEvent>? apps,
    List<TrialEvidenceSummary>? evidence,
  ) {
    final appGps = apps?.any(
            (a) => a.capturedLatitude != null && a.capturedLongitude != null) ??
        false;
    final evidenceGps = evidence?.any((e) => e.hasGps) ?? false;
    return appGps || evidenceGps;
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _EnvBody extends StatelessWidget {
  const _EnvBody({
    required this.trial,
    required this.summary,
    required this.appEvents,
    this.provenance,
  });

  final Trial trial;
  final EnvironmentalSeasonSummaryDto summary;
  final List<TrialApplicationEvent> appEvents;
  final EnvironmentalProvenanceDto? provenance;

  @override
  Widget build(BuildContext context) {
    final seasonUnavailable =
        summary.overallConfidence == 'unavailable' || summary.daysWithData == 0;
    final factualAppEvents = _dedupeApplicationWindows(
      appEvents.where(_isFactualApplicationEvent).toList(),
    );
    final hiddenPlannedCount =
        appEvents.where((event) => !_isFactualApplicationEvent(event)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (provenance != null) ...[
          _ProvenanceStrip(provenance: provenance!),
          const SizedBox(height: AppDesignTokens.spacing8),
        ],
        if (seasonUnavailable)
          const _EnvUnavailable(
            reason: 'No environmental records have been fetched yet.',
          )
        else
          _SeasonSummarySection(summary: summary),
        const SizedBox(height: AppDesignTokens.spacing8),
        if (appEvents.isEmpty)
          const Text(
            'No application events recorded yet.',
            style: TextStyle(
              fontSize: 12,
              color: AppDesignTokens.secondaryText,
            ),
          )
        else if (factualAppEvents.isEmpty) ...[
          const Text(
            'No confirmed application events recorded yet.',
            style: TextStyle(
              fontSize: 12,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Planned applications are not shown until confirmed.',
            style: TextStyle(
              fontSize: 11,
              color: AppDesignTokens.secondaryText,
            ),
          ),
        ] else ...[
          const _SectionLabel('APPLICATION WINDOWS'),
          const SizedBox(height: AppDesignTokens.spacing4),
          ...factualAppEvents.map(
            (event) => _AppEnvRow(trialId: trial.id, event: event),
          ),
          if (hiddenPlannedCount > 0)
            Text(
              '$hiddenPlannedCount planned application${hiddenPlannedCount == 1 ? '' : 's'} not shown until confirmed.',
              style: const TextStyle(
                fontSize: 11,
                color: AppDesignTokens.secondaryText,
              ),
            ),
        ],
      ],
    );
  }

  bool _isFactualApplicationEvent(TrialApplicationEvent event) {
    return switch (event.status.toLowerCase()) {
      'applied' || 'complete' || 'completed' || 'closed' || 'confirmed' => true,
      _ => false,
    };
  }

  List<TrialApplicationEvent> _dedupeApplicationWindows(
    List<TrialApplicationEvent> events,
  ) {
    final byWindow = <String, TrialApplicationEvent>{};
    for (final event in events) {
      final key = _applicationWindowKey(event);
      final existing = byWindow[key];
      if (existing == null || _applicationWindowScore(event) > _applicationWindowScore(existing)) {
        byWindow[key] = event;
      }
    }
    final deduped = byWindow.values.toList()
      ..sort((a, b) {
        final dateCompare = a.applicationDate.compareTo(b.applicationDate);
        if (dateCompare != 0) return dateCompare;
        return a.id.compareTo(b.id);
      });
    return deduped;
  }

  String _applicationWindowKey(TrialApplicationEvent event) {
    final date = DateTime(
      event.applicationDate.year,
      event.applicationDate.month,
      event.applicationDate.day,
    ).toIso8601String();
    final time = event.applicationTime?.trim().toLowerCase() ?? '';
    final method = event.applicationMethod?.trim().toLowerCase() ?? '';
    final equipment = event.equipmentUsed?.trim().toLowerCase() ?? '';
    return [date, time, method, equipment].join('|');
  }

  int _applicationWindowScore(TrialApplicationEvent event) {
    var score = 0;
    if (event.growthStageBbchAtApplication != null) score += 8;
    if ((event.growthStageCode ?? '').trim().isNotEmpty) score += 4;
    if (event.capturedLatitude != null && event.capturedLongitude != null) {
      score += 2;
    }
    if ((event.notes ?? '').trim().isNotEmpty) score += 1;
    return score;
  }
}

// ── Season summary ────────────────────────────────────────────────────────────

class _SeasonSummarySection extends StatelessWidget {
  const _SeasonSummarySection({required this.summary});

  final EnvironmentalSeasonSummaryDto summary;

  @override
  Widget build(BuildContext context) {
    final (confBg, confFg, confLabel) = switch (summary.overallConfidence) {
      'measured' => (
          AppDesignTokens.successBg,
          AppDesignTokens.successFg,
          'Measured',
        ),
      'estimated' => (
          AppDesignTokens.partialBg,
          AppDesignTokens.partialFg,
          'Estimated',
        ),
      _ => (
          AppDesignTokens.emptyBadgeBg,
          AppDesignTokens.emptyBadgeFg,
          'Unavailable',
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OverviewStatusChip(label: confLabel, bg: confBg, fg: confFg),
        const SizedBox(height: AppDesignTokens.spacing8),
        if (summary.totalPrecipitationMm != null)
          OverviewDataRow(
            'Total precipitation',
            '${summary.totalPrecipitationMm!.toStringAsFixed(1)} mm',
          ),
        if (summary.totalFrostEvents > 0)
          OverviewDataRow('Frost events', '${summary.totalFrostEvents}'),
        if (summary.totalExcessiveRainfallEvents > 0)
          OverviewDataRow(
            'Excessive rainfall events',
            '${summary.totalExcessiveRainfallEvents}',
          ),
        OverviewDataRow(
          'Days with data / expected',
          '${summary.daysWithData} / ${summary.daysExpected}',
        ),
      ],
    );
  }
}

// ── Per-application row ───────────────────────────────────────────────────────

class _AppEnvRow extends ConsumerWidget {
  const _AppEnvRow({required this.trialId, required this.event});

  final int trialId;
  final TrialApplicationEvent event;

  static String? _bbchLabel(TrialApplicationEvent e) {
    if (e.growthStageBbchAtApplication != null) {
      return 'BBCH ${e.growthStageBbchAtApplication}';
    }
    if (e.growthStageCode != null && e.growthStageCode!.isNotEmpty) {
      return e.growthStageCode;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ApplicationEnvironmentalRequest(
      trialId: trialId,
      applicationEventId: event.id,
    );
    final ctxAsync =
        ref.watch(applicationEnvironmentalContextProvider(request));
    final dateStr =
        DateFormat('MMM d, y').format(event.applicationDate.toLocal());
    final bbch = _bbchLabel(event);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Application — $dateStr',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.primaryText,
            ),
          ),
          if (bbch != null) ...[
            const SizedBox(height: 1),
            Text(
              bbch,
              style: const TextStyle(
                fontSize: 11,
                color: AppDesignTokens.secondaryText,
              ),
            ),
          ],
          const SizedBox(height: AppDesignTokens.spacing4),
          ctxAsync.when(
            loading: () => const OverviewSectionLoading(),
            error: (_, __) => const OverviewSectionError(),
            data: (ctx) {
              if (ctx.isUnavailable) {
                return Text(
                  'Application environmental context unavailable — ${ctx.unavailableReason}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppDesignTokens.secondaryText,
                    height: 1.3,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WindowRow(label: '72h before', window: ctx.preWindow),
                  _WindowRow(label: '48h after', window: ctx.postWindow),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Window row ────────────────────────────────────────────────────────────────

class _WindowRow extends StatelessWidget {
  const _WindowRow({required this.label, required this.window});

  final String label;
  final EnvironmentalWindowDto window;

  @override
  Widget build(BuildContext context) {
    final noData = window.recordCount == 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          Text(
            noData
                ? 'No environmental records available for this window.'
                : _summaryLine(window),
            style: TextStyle(
              fontSize: 11,
              color: noData
                  ? AppDesignTokens.secondaryText
                  : AppDesignTokens.primaryText,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  String _summaryLine(EnvironmentalWindowDto w) {
    final parts = <String>[];
    if (w.totalPrecipitationMm != null) {
      parts.add('Rainfall: ${w.totalPrecipitationMm!.toStringAsFixed(1)} mm');
    }
    if (w.minTempC != null) {
      parts.add('Min temp: ${w.minTempC!.toStringAsFixed(1)}°C');
    }
    if (w.frostFlagPresent) parts.add('Frost flagged');
    if (w.excessiveRainfallFlag) parts.add('Excessive rainfall');
    final conf = switch (w.confidence) {
      'measured' => 'Measured',
      'estimated' => 'Estimated',
      _ => 'Unavailable',
    };
    parts.add(conf);
    return parts.join(' · ');
  }
}

// ── Provenance strip ──────────────────────────────────────────────────────────

class _ProvenanceStrip extends StatelessWidget {
  const _ProvenanceStrip({required this.provenance});

  final EnvironmentalProvenanceDto provenance;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];

    final sourceLabel = _sourceLabel(provenance.dataSource);
    if (provenance.isMultiSource) {
      parts.add(
          'Source: $sourceLabel (${provenance.dominantCount} records) · Mixed sources');
    } else {
      parts.add('Source: $sourceLabel');
    }

    parts.add('Trial Site GPS');

    if (provenance.fetchedAtMs != null) {
      parts.add('Fetched ${_relativeTime(provenance.fetchedAtMs!)}');
    }

    parts.add('Confidence: ${_confidenceLabel(provenance.overallConfidence)}');

    return Text(
      parts.join(' · '),
      style: const TextStyle(
        fontSize: 10,
        color: AppDesignTokens.secondaryText,
        height: 1.4,
      ),
    );
  }

  static String _sourceLabel(String? source) => switch (source) {
        'open_meteo' => 'Open-Meteo',
        null || 'unavailable' => 'Not recorded',
        _ => source,
      };

  static String _confidenceLabel(String? confidence) => switch (confidence) {
        'measured' => 'High',
        'estimated' => 'Estimated',
        'unavailable' => 'N/A',
        _ when confidence != null =>
          confidence[0].toUpperCase() + confidence.substring(1),
        _ => 'Unknown',
      };

  static String _relativeTime(int epochMs) {
    final age = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(epochMs));
    if (age.inMinutes < 1) return 'just now';
    if (age.inHours < 1) return '${age.inMinutes}min ago';
    if (age.inDays < 1) return '${age.inHours}h ago';
    if (age.inDays < 7) return '${age.inDays}d ago';
    return DateFormat('MMM d, y')
        .format(DateTime.fromMillisecondsSinceEpoch(epochMs).toLocal());
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _EnvUnavailable extends StatelessWidget {
  const _EnvUnavailable({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Environmental evidence not available yet.',
          style: TextStyle(fontSize: 12, color: AppDesignTokens.primaryText),
        ),
        const SizedBox(height: 2),
        Text(
          reason,
          style: const TextStyle(
            fontSize: 11,
            color: AppDesignTokens.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppDesignTokens.secondaryText,
      ),
    );
  }
}
