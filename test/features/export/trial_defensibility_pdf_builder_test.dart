import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/assessment_result_direction.dart';
import 'package:arm_field_companion/domain/trial_cognition/environmental_window_evaluator.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_coherence_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_ctq_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_decision_summary_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_evidence_arc_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_interpretation_risk_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_purpose_dto.dart';
import 'package:arm_field_companion/features/derived/domain/trial_statistics.dart';
import 'package:arm_field_companion/features/export/trial_defensibility_pdf_builder.dart';
import 'package:flutter_test/flutter_test.dart';

Trial _trial() => Trial(
      id: 1,
      name: 'Canola 2026',
      crop: 'Canola',
      season: '2026',
      status: 'active',
      sponsor: 'Sponsor',
      protocolNumber: 'P-17',
      investigatorName: 'Researcher',
      location: 'PEI',
      experimentalDesign: 'RCBD',
      workspaceType: 'efficacy',
      region: 'pmra_canada',
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      isDeleted: false,
    );

const _purpose = TrialPurposeDto(
  trialId: 1,
  purposeStatus: 'confirmed',
  claimBeingTested: 'Treatment improves weed control.',
  trialPurpose: 'Efficacy',
  regulatoryContext: 'Research',
  primaryEndpoint: '% weed control',
  missingIntentFields: [],
  provenanceSummary: 'Confirmed by researcher',
  canDriveReadinessClaims: true,
);

const _evidenceArc = TrialEvidenceArcDto(
  trialId: 1,
  evidenceState: 'sufficient_for_review',
  plannedEvidenceSummary: '16 layout plot(s).',
  actualEvidenceSummary: 'Rating evidence recorded.',
  missingEvidenceItems: [],
  evidenceAnchors: ['Ratings'],
  riskFlags: [],
);

const _ctq = TrialCtqDto(
  trialId: 1,
  ctqItems: [],
  blockerCount: 0,
  warningCount: 0,
  reviewCount: 0,
  satisfiedCount: 1,
  overallStatus: 'ready_for_review',
);

final _coherence = TrialCoherenceDto(
  coherenceState: 'aligned',
  checks: const [
    TrialCoherenceCheckDto(
      checkKey: 'primary_endpoint',
      label: 'Primary endpoint assessment present',
      status: 'aligned',
      reason: 'Assessment present.',
      sourceFields: [],
    ),
  ],
  computedAt: DateTime.utc(2026, 5, 8),
);

final _risk = TrialInterpretationRiskDto(
  riskLevel: 'low',
  factors: const [],
  computedAt: DateTime.utc(2026, 5, 8),
);

const _decisionSummary = TrialDecisionSummaryDto(
  trialId: 1,
  signalDecisions: [],
  ctqAcknowledgments: [],
  hasAnyResearcherReasoning: false,
);

const _environmentalSummary = EnvironmentalSeasonSummaryDto(
  totalPrecipitationMm: 42.5,
  totalFrostEvents: 1,
  totalExcessiveRainfallEvents: 2,
  daysWithData: 8,
  daysExpected: 8,
  overallConfidence: 'measured',
);

AssessmentStatistics _assessmentStat() => const AssessmentStatistics(
      progress: AssessmentProgress(
        assessmentId: 1,
        assessmentName: '% weed control',
        ratedPlots: 4,
        totalPlots: 4,
        completeness: AssessmentCompleteness.complete,
        missingReps: [],
      ),
      unit: '%',
      resultDirection: ResultDirection.neutral,
      treatmentMeans: [
        TreatmentMean(
          treatmentCode: 'CHK',
          mean: 10,
          standardDeviation: 1.2,
          standardError: 0.6,
          n: 4,
          min: 8,
          max: 12,
          isPreliminary: false,
        ),
        TreatmentMean(
          treatmentCode: 'T2',
          mean: 80,
          standardDeviation: 4,
          standardError: 2,
          n: 4,
          min: 75,
          max: 85,
          isPreliminary: false,
        ),
      ],
      trialCV: 20,
      cvInterpretation: null,
      outliers: null,
      repConsistencyIssues: [],
      totalReps: 4,
    );

Signal _signal() => const Signal(
      id: 1,
      trialId: 1,
      sessionId: null,
      plotId: null,
      signalType: 'replication_warning',
      moment: 2,
      severity: 'review',
      raisedAt: 1000,
      raisedBy: null,
      referenceContext: '{}',
      magnitudeContext: null,
      consequenceText: 'Replication pattern may affect interpretation.',
      status: 'open',
      createdAt: 1000,
    );

TrialDefensibilityPdfBuilder _builder({
  EnvironmentalSeasonSummaryDto? environmentalSummary = _environmentalSummary,
  List<Signal> openSignals = const [],
  List<AssessmentStatistics>? assessmentStats,
  int amendmentCount = 0,
}) {
  return TrialDefensibilityPdfBuilder(
    trial: _trial(),
    purpose: _purpose,
    evidenceArc: _evidenceArc,
    ctq: _ctq,
    coherence: _coherence,
    interpretationRisk: _risk,
    decisionSummary: _decisionSummary,
    openSignals: openSignals,
    environmentalSummary: environmentalSummary,
    assessmentStats: assessmentStats ?? [_assessmentStat()],
    amendmentCount: amendmentCount,
    generatedAt: DateTime(2026, 5, 8),
    logo: null,
  );
}

void main() {
  group('TrialDefensibilityPdfBuilder', () {
    test('builds without throwing with full data', () async {
      final bytes = await _builder().build();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('builds without throwing when environmental summary is null',
        () async {
      final bytes = await _builder(environmentalSummary: null).build();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('builds without throwing with open signals', () async {
      final bytes = await _builder(openSignals: [_signal()]).build();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('builds without throwing with amendments', () async {
      final bytes = await _builder(amendmentCount: 3).build();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('builds without throwing with empty assessment stats', () async {
      final bytes = await _builder(assessmentStats: []).build();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('cvTierLabel returns correct tiers', () {
      expect(TrialDefensibilityPdfBuilder.cvTierLabel(null), '-');
      expect(TrialDefensibilityPdfBuilder.cvTierLabel(10), 'Excellent');
      expect(TrialDefensibilityPdfBuilder.cvTierLabel(20), 'Acceptable');
      expect(TrialDefensibilityPdfBuilder.cvTierLabel(30), 'Caution');
      expect(TrialDefensibilityPdfBuilder.cvTierLabel(50), 'High');
    });

    test('isCheckTreatment identifies CHK UTC CONTROL', () {
      expect(TrialDefensibilityPdfBuilder.isCheckTreatment('CHK'), isTrue);
      expect(TrialDefensibilityPdfBuilder.isCheckTreatment('UTC'), isTrue);
      expect(
        TrialDefensibilityPdfBuilder.isCheckTreatment('CONTROL'),
        isTrue,
      );
      expect(TrialDefensibilityPdfBuilder.isCheckTreatment('T2'), isFalse);
    });
  });
}
