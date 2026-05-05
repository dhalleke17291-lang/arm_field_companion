import 'package:arm_field_companion/domain/trial_cognition/trial_intent_inferrer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('inferTreatmentRoles', () {
    test('UTC treatment name → untreated_check, high confidence', () {
      final roles = inferTreatmentRoles([
        const TreatmentInferenceData(id: 1, name: 'UTC', code: '1'),
      ]);
      expect(roles.length, 1);
      expect(roles.first.inferredRole, 'untreated_check');
      expect(roles.first.confidence, FieldConfidence.high);
      expect(roles.first.basis, isNotEmpty);
    });

    test('UNTREATED CHECK treatment name → untreated_check, high confidence',
        () {
      final roles = inferTreatmentRoles([
        const TreatmentInferenceData(
            id: 1, name: 'Untreated Check', code: 'CHK'),
      ]);
      expect(roles.first.inferredRole, 'untreated_check');
      expect(roles.first.confidence, FieldConfidence.high);
    });

    test('ARM type code CHK → untreated_check, high confidence', () {
      final roles = inferTreatmentRoles([
        const TreatmentInferenceData(
            id: 1, name: 'Treatment 1', code: '1', treatmentType: 'CHK'),
      ]);
      expect(roles.first.inferredRole, 'untreated_check');
      expect(roles.first.confidence, FieldConfidence.high);
      expect(roles.first.basis, contains('CHK'));
    });

    test('Known reference product name → reference_standard, moderate confidence',
        () {
      final roles = inferTreatmentRoles([
        const TreatmentInferenceData(id: 2, name: 'Proline 480 SC', code: '2'),
      ]);
      expect(roles.first.inferredRole, 'reference_standard');
      expect(roles.first.confidence, FieldConfidence.moderate);
    });

    test('REFERENCE keyword → reference_standard, moderate confidence', () {
      final roles = inferTreatmentRoles([
        const TreatmentInferenceData(
            id: 2, name: 'Industry Reference', code: 'REF'),
      ]);
      expect(roles.first.inferredRole, 'reference_standard');
      expect(roles.first.confidence, FieldConfidence.moderate);
    });

    test('Unknown treatment → test_item, moderate confidence', () {
      final roles = inferTreatmentRoles([
        const TreatmentInferenceData(id: 3, name: 'XYZ-1234 2.5L/ha', code: '3'),
      ]);
      expect(roles.first.inferredRole, 'test_item');
      expect(roles.first.confidence, FieldConfidence.moderate);
    });

    test('Empty treatments → empty list', () {
      final roles = inferTreatmentRoles([]);
      expect(roles, isEmpty);
    });

    test('Mixed treatments inferred correctly', () {
      final roles = inferTreatmentRoles([
        const TreatmentInferenceData(id: 1, name: 'UTC', code: '1'),
        const TreatmentInferenceData(id: 2, name: 'Proline 480 SC', code: '2'),
        const TreatmentInferenceData(id: 3, name: 'XYZ-123', code: '3'),
      ]);
      expect(roles[0].inferredRole, 'untreated_check');
      expect(roles[1].inferredRole, 'reference_standard');
      expect(roles[2].inferredRole, 'test_item');
    });
  });

  group('inferTrialPurpose — trial type', () {
    test('glp workspace → registration_efficacy, high confidence', () {
      final result = inferTrialPurpose(const TrialInferenceInput(
        workspaceType: 'glp',
        treatments: [],
        assessments: [],
        inferenceSource: 'arm_structure',
      ));
      expect(result.trialType, 'registration_efficacy');
      expect(result.trialTypeConfidence, FieldConfidence.high);
    });

    test('efficacy workspace → efficacy, high confidence', () {
      final result = inferTrialPurpose(const TrialInferenceInput(
        workspaceType: 'efficacy',
        treatments: [],
        assessments: [],
        inferenceSource: 'arm_structure',
      ));
      expect(result.trialType, 'efficacy');
      expect(result.trialTypeConfidence, FieldConfidence.high);
    });

    test('variety workspace → variety_evaluation, high confidence', () {
      final result = inferTrialPurpose(const TrialInferenceInput(
        workspaceType: 'variety',
        treatments: [],
        assessments: [],
        inferenceSource: 'standalone_structure',
      ));
      expect(result.trialType, 'variety_evaluation');
      expect(result.trialTypeConfidence, FieldConfidence.high);
    });

    test('standalone workspace → efficacy, moderate confidence', () {
      final result = inferTrialPurpose(const TrialInferenceInput(
        workspaceType: 'standalone',
        treatments: [],
        assessments: [],
        inferenceSource: 'standalone_structure',
      ));
      expect(result.trialType, 'efficacy');
      expect(result.trialTypeConfidence, FieldConfidence.moderate);
    });
  });

  group('inferTrialPurpose — primary endpoint', () {
    test('single assessment → primary endpoint inferred, high confidence', () {
      final result = inferTrialPurpose(const TrialInferenceInput(
        workspaceType: 'efficacy',
        treatments: [],
        assessments: [
          AssessmentInferenceData(name: 'Weed Control'),
        ],
        inferenceSource: 'arm_structure',
      ));
      expect(result.primaryEndpointAssessmentKey, 'Weed Control');
      expect(result.primaryEndpointConfidence, FieldConfidence.high);
    });

    test(
        'multiple assessments — latest timing wins as primary endpoint candidate',
        () {
      final result = inferTrialPurpose(const TrialInferenceInput(
        workspaceType: 'efficacy',
        treatments: [],
        assessments: [
          AssessmentInferenceData(name: 'Early Rating', daysAfterTreatment: 14),
          AssessmentInferenceData(name: 'Final Rating', daysAfterTreatment: 60),
          AssessmentInferenceData(name: 'Mid Rating', daysAfterTreatment: 30),
        ],
        inferenceSource: 'arm_structure',
      ));
      expect(result.primaryEndpointAssessmentKey, 'Final Rating');
      expect(result.primaryEndpointConfidence, FieldConfidence.moderate);
    });

    test('no assessments → cannotInfer', () {
      final result = inferTrialPurpose(const TrialInferenceInput(
        workspaceType: 'efficacy',
        treatments: [],
        assessments: [],
        inferenceSource: 'arm_structure',
      ));
      expect(result.primaryEndpointAssessmentKey, isNull);
      expect(result.primaryEndpointConfidence, FieldConfidence.cannotInfer);
    });
  });

  group('inferTrialPurpose — claim statement', () {
    test('assembles claim from crop, test item, and SE type', () {
      final result = inferTrialPurpose(const TrialInferenceInput(
        workspaceType: 'efficacy',
        crop: 'wheat',
        treatments: [
          TreatmentInferenceData(id: 1, name: 'UTC', code: '1'),
          TreatmentInferenceData(id: 2, name: 'XYZ Fungicide', code: '2'),
        ],
        assessments: [
          AssessmentInferenceData(name: 'Disease Severity', eppoCode: 'SEPTTR'),
        ],
        inferenceSource: 'arm_structure',
      ));
      expect(result.claimStatement, isNotNull);
      expect(result.claimStatement, contains('XYZ Fungicide'));
      expect(result.claimStatement, contains('wheat'));
      expect(result.claimStatement, contains('SEPTTR'));
    });

    test('claim is absent when no data available', () {
      final result = inferTrialPurpose(const TrialInferenceInput(
        workspaceType: 'efficacy',
        treatments: [],
        assessments: [],
        inferenceSource: 'standalone_structure',
      ));
      // No test items + no pest + no crop → cannotInfer
      expect(result.claimConfidence, FieldConfidence.cannotInfer);
    });
  });

  group('inferTrialPurpose — inference notes', () {
    test('inference notes are non-empty for every inferred field', () {
      final result = inferTrialPurpose(const TrialInferenceInput(
        workspaceType: 'glp',
        crop: 'corn',
        treatments: [
          TreatmentInferenceData(id: 1, name: 'UTC', code: '1'),
          TreatmentInferenceData(id: 2, name: 'TestProduct 1L/ha', code: '2'),
        ],
        assessments: [
          AssessmentInferenceData(name: 'Disease Control', pestCode: 'CONTRO'),
        ],
        inferenceSource: 'arm_structure',
      ));
      expect(result.inferenceNotes, isNotEmpty);
      for (final note in result.inferenceNotes) {
        expect(note.trim(), isNotEmpty);
      }
    });

    test('treatment note explains basis for each role', () {
      final result = inferTrialPurpose(const TrialInferenceInput(
        workspaceType: 'efficacy',
        treatments: [
          TreatmentInferenceData(id: 1, name: 'UTC', code: '1'),
        ],
        assessments: [],
        inferenceSource: 'arm_structure',
      ));
      expect(result.inferenceNotes.any((n) => n.contains('UTC')), isTrue);
    });
  });

  group('InferredTrialPurpose serialization', () {
    test('round-trips through JSON', () {
      final original = inferTrialPurpose(const TrialInferenceInput(
        workspaceType: 'glp',
        crop: 'soybean',
        treatments: [
          TreatmentInferenceData(id: 1, name: 'Untreated', code: '1'),
          TreatmentInferenceData(id: 2, name: 'Proline 480 SC', code: '2'),
          TreatmentInferenceData(id: 3, name: 'NewProduct', code: '3'),
        ],
        assessments: [
          AssessmentInferenceData(
              name: 'Disease Control',
              eppoCode: 'SEPTTR',
              daysAfterTreatment: 45),
        ],
        inferenceSource: 'arm_structure',
      ));

      final json = original.toJsonString();
      final decoded = InferredTrialPurpose.fromJsonString(json);

      expect(decoded.trialType, original.trialType);
      expect(decoded.trialTypeConfidence, original.trialTypeConfidence);
      expect(decoded.primaryEndpointAssessmentKey,
          original.primaryEndpointAssessmentKey);
      expect(decoded.inferenceSource, original.inferenceSource);
      expect(decoded.treatmentRoles.length, original.treatmentRoles.length);
      expect(decoded.inferenceNotes.length, original.inferenceNotes.length);
    });
  });
}
