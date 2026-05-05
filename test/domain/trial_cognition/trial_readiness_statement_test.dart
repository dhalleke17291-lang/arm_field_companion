import 'package:arm_field_companion/domain/trial_cognition/trial_coherence_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_ctq_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_interpretation_risk_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_readiness_statement.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

TrialCoherenceDto _coherenceAligned() => TrialCoherenceDto(
      coherenceState: 'aligned',
      checks: const [
        TrialCoherenceCheckDto(
          checkKey: 'arc',
          label: 'Evidence arc',
          status: 'aligned',
          reason: 'All evidence arcs complete.',
          sourceFields: [],
        ),
      ],
      computedAt: DateTime(2026, 1, 1),
    );

TrialCoherenceDto _coherenceWithReviewNeeded({
  String label = 'Application timing deviation',
  String reason = 'Application T2 recorded 4 days after planned window.',
}) =>
    TrialCoherenceDto(
      coherenceState: 'review_needed',
      checks: [
        TrialCoherenceCheckDto(
          checkKey: 'app_timing',
          label: label,
          status: 'review_needed',
          reason: reason,
          sourceFields: const [],
        ),
      ],
      computedAt: DateTime(2026, 1, 1),
    );

TrialCoherenceDto _coherenceWithCannotEvaluate({
  String label = 'Primary endpoint completeness',
  String reason = 'Missing primary endpoint definition.',
}) =>
    TrialCoherenceDto(
      coherenceState: 'cannot_evaluate',
      checks: [
        TrialCoherenceCheckDto(
          checkKey: 'primary_endpoint',
          label: label,
          status: 'cannot_evaluate',
          reason: reason,
          sourceFields: const [],
        ),
      ],
      computedAt: DateTime(2026, 1, 1),
    );

TrialInterpretationRiskDto _riskLow() => TrialInterpretationRiskDto(
      riskLevel: 'low',
      factors: const [],
      computedAt: DateTime(2026, 1, 1),
    );

TrialInterpretationRiskDto _riskModerate({
  String reason = 'CV on primary endpoint assessment is 28%.',
}) =>
    TrialInterpretationRiskDto(
      riskLevel: 'moderate',
      factors: [
        TrialRiskFactorDto(
          factorKey: 'cv',
          label: 'Data variability',
          severity: 'moderate',
          reason: reason,
          sourceFields: const [],
        ),
      ],
      computedAt: DateTime(2026, 1, 1),
    );

TrialCtqDto _ctqReady() => const TrialCtqDto(
      trialId: 1,
      ctqItems: [],
      blockerCount: 0,
      warningCount: 0,
      reviewCount: 0,
      satisfiedCount: 3,
      overallStatus: 'ready_for_review',
    );

TrialCtqDto _ctqWithBlocker({
  String label = 'Primary endpoint data',
  String reason = 'Rep 2 rating for T3 is missing.',
}) =>
    TrialCtqDto(
      trialId: 1,
      ctqItems: [
        TrialCtqItemDto(
          factorKey: 'primary_endpoint_completeness',
          label: label,
          importance: 'critical',
          status: 'blocked',
          evidenceSummary: '3 of 4 treatments complete.',
          reason: reason,
          source: 'system',
        ),
      ],
      blockerCount: 1,
      warningCount: 0,
      reviewCount: 0,
      satisfiedCount: 0,
      overallStatus: 'incomplete',
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('computeTrialReadinessStatement', () {
    test('RS-1: clean inputs return ready statement', () {
      final result = computeTrialReadinessStatement(
        coherenceDto: _coherenceAligned(),
        riskDto: _riskLow(),
        ctqDto: _ctqReady(),
        trialState: 'active',
      );

      expect(result.isReadyForExport, isTrue);
      expect(result.actionItems, isEmpty);
      expect(
        result.narrative,
        contains('Trial is ready for export and analysis.'),
      );
      expect(result.narrative, contains('No coherence concerns identified.'));
      expect(result.narrative, contains('Interpretation risk is low.'));
    });

    test('RS-2: missing final assessment returns named action item', () {
      final result = computeTrialReadinessStatement(
        coherenceDto: _coherenceAligned(),
        riskDto: _riskLow(),
        ctqDto: _ctqWithBlocker(
          label: 'Primary endpoint data',
          reason: 'Rep 2 rating for T3 is missing.',
        ),
        trialState: 'active',
      );

      expect(result.isReadyForExport, isFalse);
      expect(result.actionItems, isNotEmpty);
      expect(
        result.actionItems.any((a) => a.contains('Primary endpoint data')),
        isTrue,
        reason: 'action item must name the specific factor label',
      );
      expect(
        result.narrative,
        contains('Trial is not currently export-ready.'),
      );
    });

    test('RS-3: moderate interpretation risk includes CV value from DTO', () {
      final result = computeTrialReadinessStatement(
        coherenceDto: _coherenceAligned(),
        riskDto: _riskModerate(
          reason: 'CV on primary endpoint assessment is 28%.',
        ),
        ctqDto: _ctqReady(),
        trialState: 'active',
      );

      expect(result.narrative, contains('moderate'));
      expect(result.narrative, contains('28%'));
    });

    test('RS-4: review-needed coherence check names the specific deviation',
        () {
      final result = computeTrialReadinessStatement(
        coherenceDto: _coherenceWithReviewNeeded(
          label: 'Application timing deviation',
          reason: 'Application T2 recorded 4 days after planned window.',
        ),
        riskDto: _riskLow(),
        ctqDto: _ctqReady(),
        trialState: 'active',
      );

      expect(
        result.actionItems
            .any((a) => a.contains('Application timing deviation')),
        isTrue,
        reason: 'action item must include the coherence check label',
      );
      expect(result.narrative, contains('Application timing deviation'));
    });

    test(
        'RS-5: cannot-evaluate coherence check returns missing input description',
        () {
      final result = computeTrialReadinessStatement(
        coherenceDto: _coherenceWithCannotEvaluate(
          label: 'Primary endpoint completeness',
          reason: 'Missing primary endpoint definition.',
        ),
        riskDto: _riskLow(),
        ctqDto: _ctqReady(),
        trialState: 'active',
      );

      expect(
        result.actionItems
            .any((a) => a.contains('Primary endpoint completeness')),
        isTrue,
        reason: 'must name the cannot_evaluate check',
      );
    });

    test('RS-6: draft trial state does not produce isReadyForExport=true', () {
      final result = computeTrialReadinessStatement(
        coherenceDto: _coherenceAligned(),
        riskDto: _riskLow(),
        ctqDto: _ctqReady(),
        trialState: 'draft',
      );

      expect(result.isReadyForExport, isFalse);
    });

    group('RS-7: forbidden language never produced', () {
      const forbiddenWords = [
        'passed',
        'failed',
        'statistically significant',
        'superior',
        'best treatment',
        'winner',
      ];

      for (final word in forbiddenWords) {
        test('never outputs "$word"', () {
          final clean = computeTrialReadinessStatement(
            coherenceDto: _coherenceAligned(),
            riskDto: _riskLow(),
            ctqDto: _ctqReady(),
            trialState: 'active',
          );
          final problem = computeTrialReadinessStatement(
            coherenceDto: _coherenceWithReviewNeeded(),
            riskDto: _riskModerate(),
            ctqDto: _ctqWithBlocker(),
            trialState: 'active',
          );

          final allText = [
            clean.narrative,
            ...clean.actionItems,
            problem.narrative,
            ...problem.actionItems,
          ].join(' ').toLowerCase();

          expect(
            allText.contains(word.toLowerCase()),
            isFalse,
            reason: '"$word" must never appear in readiness statement output',
          );
        });
      }
    });
  });
}
