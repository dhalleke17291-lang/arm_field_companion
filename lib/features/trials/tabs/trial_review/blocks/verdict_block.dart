import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/design/app_design_tokens.dart';
import '../../../../../core/providers.dart';
import '../../../../../domain/trial_cognition/trial_readiness_statement.dart';
import '../../../trial_data_screen.dart';
import '../../trial_overview/_overview_card.dart';

class VerdictBlock extends ConsumerWidget {
  const VerdictBlock({
    super.key,
    required this.trial,
  });

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statementAsync = ref.watch(trialReadinessStatementProvider((
      trialId: trial.id,
      trialState: trial.status,
    )));
    final amendmentCount =
        ref.watch(amendedRatingCountForTrialProvider(trial.id)).valueOrNull ??
            0;

    return statementAsync.when(
      loading: () => const OverviewSectionLoading(),
      error: (_, __) => const OverviewSectionError(),
      data: (statement) => _VerdictBody(
        statement: statement,
        trial: trial,
        amendmentCount: amendmentCount,
      ),
    );
  }
}

@visibleForTesting
class VerdictBlockBody extends StatelessWidget {
  const VerdictBlockBody({
    super.key,
    required this.statement,
    required this.trial,
    required this.amendmentCount,
  });

  final TrialReadinessStatement statement;
  final Trial trial;
  final int amendmentCount;

  @override
  Widget build(BuildContext context) {
    return _VerdictBody(
      statement: statement,
      trial: trial,
      amendmentCount: amendmentCount,
    );
  }
}

class _VerdictBody extends StatelessWidget {
  const _VerdictBody({
    required this.statement,
    required this.trial,
    required this.amendmentCount,
  });

  final TrialReadinessStatement statement;
  final Trial trial;
  final int amendmentCount;

  String get _headline {
    if (statement.readinessLevel != 'ready_with_cautions') {
      return statement.statusLabel;
    }

    final n = statement.cautions.length;
    if (n <= 0) return statement.statusLabel;
    return 'Export ready · $n caution${n == 1 ? '' : 's'} to review';
  }

  bool get _showSummaryText {
    if (statement.readinessLevel == 'ready') return true;
    if (statement.readinessLevel == 'ready_with_cautions') {
      return statement.cautions.isEmpty;
    }
    return statement.actionItems.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final isReady = statement.readinessLevel != 'not_ready';
    final (chipBg, chipFg) = isReady
        ? (AppDesignTokens.successBg, AppDesignTokens.successFg)
        : (AppDesignTokens.warningBg, AppDesignTokens.warningFg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        OverviewStatusChip(label: _headline, bg: chipBg, fg: chipFg),
        if (_showSummaryText) ...[
          const SizedBox(height: AppDesignTokens.spacing8),
          Text(
            statement.summaryText,
            style: AppDesignTokens.bodyStyle(
              fontSize: 13,
              color: AppDesignTokens.primaryText,
            ).copyWith(height: 1.4),
          ),
        ],
        if (statement.readinessLevel == 'not_ready' &&
            statement.actionItems.isNotEmpty) ...[
          const SizedBox(height: AppDesignTokens.spacing8),
          ...statement.actionItems.map(_ActionBullet.new),
        ],
        if (amendmentCount > 0) ...[
          const SizedBox(height: AppDesignTokens.spacing8),
          _AmendmentLine(trial: trial, count: amendmentCount),
        ],
      ],
    );
  }
}

class _ActionBullet extends StatelessWidget {
  const _ActionBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 8, right: 9),
            decoration: const BoxDecoration(
              color: AppDesignTokens.warningFg,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppDesignTokens.bodyStyle(
                fontSize: 13,
                color: AppDesignTokens.primaryText,
              ).copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmendmentLine extends StatelessWidget {
  const _AmendmentLine({
    required this.trial,
    required this.count,
  });

  final Trial trial;
  final int count;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => TrialDataScreen(trial: trial),
        ),
      ),
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            const Icon(
              Icons.edit_note_outlined,
              size: 14,
              color: AppDesignTokens.warningFg,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$count amendments on record — view in Data',
                style: AppDesignTokens.bodyStyle(
                  fontSize: 13,
                  color: AppDesignTokens.warningFg,
                ).copyWith(height: 1.35),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 14,
              color: AppDesignTokens.warningFg,
            ),
          ],
        ),
      ),
    );
  }
}
