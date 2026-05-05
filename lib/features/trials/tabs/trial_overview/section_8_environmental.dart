import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/design/app_design_tokens.dart';
import '../../../../core/providers.dart';
import '../../../../domain/trial_cognition/environmental_window_evaluator.dart';
import '_overview_card.dart';

class Section8Environmental extends ConsumerWidget {
  const Section8Environmental({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync =
        ref.watch(trialEnvironmentalSummaryProvider(trial.id));

    return OverviewSectionCard(
      number: 8,
      title: 'Environmental Evidence',
      child: summaryAsync.when(
        loading: () => const OverviewSectionLoading(),
        error: (_, __) => const OverviewSectionError(),
        data: (dto) {
          final hasGps =
              trial.latitude != null && trial.longitude != null;
          if (!hasGps) {
            return const Text(
              'Site GPS required for environmental evidence.',
              style: TextStyle(
                fontSize: 12,
                color: AppDesignTokens.secondaryText,
              ),
            );
          }
          return _SeasonSummaryBody(dto: dto);
        },
      ),
    );
  }
}

class _SeasonSummaryBody extends StatelessWidget {
  const _SeasonSummaryBody({required this.dto});

  final EnvironmentalSeasonSummaryDto dto;

  @override
  Widget build(BuildContext context) {
    final (confBg, confFg, confLabel) = switch (dto.overallConfidence) {
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

    final precipLabel = dto.totalPrecipitationMm != null
        ? '${dto.totalPrecipitationMm!.toStringAsFixed(1)} mm'
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OverviewStatusChip(label: confLabel, bg: confBg, fg: confFg),
        const SizedBox(height: AppDesignTokens.spacing8),
        OverviewDataRow('Total precipitation', precipLabel),
        OverviewDataRow('Frost events', '${dto.totalFrostEvents}'),
        OverviewDataRow(
          'Excessive rainfall events',
          '${dto.totalExcessiveRainfallEvents}',
        ),
        OverviewDataRow(
          'Days with data / expected',
          '${dto.daysWithData} / ${dto.daysExpected}',
        ),
        // TODO(A5): per-application environmental windows deferred.
        // Requires a TrialApplicationEvent list provider (UUID IDs) so that
        // applicationEnvironmentalContextProvider can be called per event.
        // The legacy applicationsForTrialProvider uses integer IDs from a
        // different table and cannot be used here.
      ],
    );
  }
}
