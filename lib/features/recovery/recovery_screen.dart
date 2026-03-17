import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../../shared/widgets/app_card.dart';

String _deletedMetadataLine(DateTime? deletedAt, String? deletedBy) {
  final datePart = deletedAt != null
      ? DateFormat('MMM d, yyyy').format(deletedAt.toLocal())
      : 'Unknown date';
  final byPart = (deletedBy != null && deletedBy.trim().isNotEmpty)
      ? deletedBy.trim()
      : 'Unknown';
  return 'Deleted $datePart • $byPart';
}

const _kSectionHeadingStyle = TextStyle(
  fontWeight: FontWeight.w600,
  fontSize: 15,
  color: AppDesignTokens.primaryText,
);

const _kEmptyStateStyle = TextStyle(
  fontSize: 13,
  color: AppDesignTokens.secondaryText,
);

String? _trialCropLocationSubtitle(Trial t) {
  final parts = <String>[];
  if (t.crop != null && t.crop!.trim().isNotEmpty) {
    parts.add(t.crop!.trim());
  }
  if (t.location != null && t.location!.trim().isNotEmpty) {
    parts.add(t.location!.trim());
  }
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

/// Read-only list of soft-deleted trials, sessions, and plots (Recovery).
class RecoveryScreen extends ConsumerWidget {
  const RecoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trialsAsync = ref.watch(deletedTrialsProvider);
    final sessionsAsync = ref.watch(deletedSessionsProvider);
    final plotsAsync = ref.watch(deletedPlotsProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: const GradientScreenHeader(title: 'Recovery'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.spacing16,
            vertical: AppDesignTokens.spacing24,
          ),
          children: [
            _DeletedTrialsSection(async: trialsAsync),
            const SizedBox(height: AppDesignTokens.spacing16),
            _DeletedSessionsSection(async: sessionsAsync),
            const SizedBox(height: AppDesignTokens.spacing16),
            _DeletedPlotsSection(async: plotsAsync),
          ],
        ),
      ),
    );
  }
}

class _DeletedTrialsSection extends StatelessWidget {
  const _DeletedTrialsSection({required this.async});

  final AsyncValue<List<Trial>> async;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDesignTokens.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Deleted Trials', style: _kSectionHeadingStyle),
          const SizedBox(height: AppDesignTokens.spacing12),
          async.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDesignTokens.spacing16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => Text(
              'Error: $e',
              style: const TextStyle(
                fontSize: 13,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            data: (trials) {
              if (trials.isEmpty) {
                return const Text(
                  'No deleted trials',
                  style: _kEmptyStateStyle,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < trials.length; i++) ...[
                    if (i > 0) ...[
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppDesignTokens.borderCrisp,
                      ),
                      const SizedBox(height: AppDesignTokens.spacing12),
                    ],
                    _TrialRecoveryRow(trial: trials[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TrialRecoveryRow extends StatelessWidget {
  const _TrialRecoveryRow({required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context) {
    final sub = _trialCropLocationSubtitle(trial);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          trial.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppDesignTokens.primaryText,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 13,
              color: AppDesignTokens.secondaryText,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          _deletedMetadataLine(trial.deletedAt, trial.deletedBy),
          style: const TextStyle(
            fontSize: 12,
            color: AppDesignTokens.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _DeletedSessionsSection extends StatelessWidget {
  const _DeletedSessionsSection({required this.async});

  final AsyncValue<List<Session>> async;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDesignTokens.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Deleted Sessions', style: _kSectionHeadingStyle),
          const SizedBox(height: AppDesignTokens.spacing12),
          async.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDesignTokens.spacing16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => Text(
              'Error: $e',
              style: const TextStyle(
                fontSize: 13,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            data: (sessions) {
              if (sessions.isEmpty) {
                return const Text(
                  'No deleted sessions',
                  style: _kEmptyStateStyle,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < sessions.length; i++) ...[
                    if (i > 0) ...[
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppDesignTokens.borderCrisp,
                      ),
                      const SizedBox(height: AppDesignTokens.spacing12),
                    ],
                    _SessionRecoveryRow(session: sessions[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SessionRecoveryRow extends StatelessWidget {
  const _SessionRecoveryRow({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          session.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppDesignTokens.primaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${session.sessionDateLocal} · Trial #${session.trialId}',
          style: const TextStyle(
            fontSize: 13,
            color: AppDesignTokens.secondaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _deletedMetadataLine(session.deletedAt, session.deletedBy),
          style: const TextStyle(
            fontSize: 12,
            color: AppDesignTokens.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _DeletedPlotsSection extends StatelessWidget {
  const _DeletedPlotsSection({required this.async});

  final AsyncValue<List<Plot>> async;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDesignTokens.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Deleted Plots', style: _kSectionHeadingStyle),
          const SizedBox(height: AppDesignTokens.spacing12),
          async.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDesignTokens.spacing16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => Text(
              'Error: $e',
              style: const TextStyle(
                fontSize: 13,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            data: (plots) {
              if (plots.isEmpty) {
                return const Text(
                  'No deleted plots',
                  style: _kEmptyStateStyle,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < plots.length; i++) ...[
                    if (i > 0) ...[
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppDesignTokens.borderCrisp,
                      ),
                      const SizedBox(height: AppDesignTokens.spacing12),
                    ],
                    _PlotRecoveryRow(plot: plots[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlotRecoveryRow extends StatelessWidget {
  const _PlotRecoveryRow({required this.plot});

  final Plot plot;

  @override
  Widget build(BuildContext context) {
    final repPart = plot.rep != null ? 'Rep ${plot.rep}' : null;
    final secondary = [
      if (repPart != null) repPart,
      'Trial #${plot.trialId}',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          plot.plotId,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppDesignTokens.primaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          secondary,
          style: const TextStyle(
            fontSize: 13,
            color: AppDesignTokens.secondaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _deletedMetadataLine(plot.deletedAt, plot.deletedBy),
          style: const TextStyle(
            fontSize: 12,
            color: AppDesignTokens.secondaryText,
          ),
        ),
      ],
    );
  }
}
