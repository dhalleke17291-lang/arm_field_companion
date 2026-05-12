import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_intent_inferrer.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_purpose_dto.dart';
import 'package:arm_field_companion/features/trials/trial_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Trial _trial({
  String studyType = 'Efficacy',
  String? experimentalDesign = 'RCBD',
}) =>
    Trial(
      id: 1,
      name: 'Wheat 2026',
      status: 'active',
      workspaceType: 'efficacy',
      crop: 'Wheat',
      sponsor: 'Prairie Research',
      studyType: studyType,
      experimentalDesign: experimentalDesign,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      region: 'eppo_eu',
      isDeleted: false,
    );

TrialPurposeDto _confirmedPurpose() => const TrialPurposeDto(
      trialId: 1,
      purposeStatus: 'confirmed',
      claimBeingTested: 'Treatment improves disease control.',
      trialPurpose: 'Registration efficacy',
      regulatoryContext: 'registration',
      primaryEndpoint: 'Disease Severity',
      missingIntentFields: [],
      provenanceSummary: 'Manual entry',
      canDriveReadinessClaims: true,
      requiresConfirmation: false,
      inferenceSource: 'manual_revelation',
    );

TrialPurposeDto _inferredPurpose() => const TrialPurposeDto(
      trialId: 1,
      purposeStatus: 'draft',
      regulatoryContext: 'internalResearch',
      primaryEndpoint: 'Yield',
      missingIntentFields: [],
      provenanceSummary: 'Inferred from setup',
      canDriveReadinessClaims: false,
      requiresConfirmation: true,
      inferenceSource: 'standalone_structure',
      inferredPurpose: InferredTrialPurpose(
        trialType: 'Efficacy',
        trialTypeConfidence: FieldConfidence.moderate,
        primaryEndpointAssessmentKey: 'Yield',
        primaryEndpointConfidence: FieldConfidence.low,
        treatmentRoles: [
          InferredTreatmentRole(
            treatmentId: 1,
            treatmentName: 'UTC',
            inferredRole: 'untreated_check',
            confidence: FieldConfidence.high,
            basis: 'Name contains UTC.',
          ),
        ],
        claimStatement: 'Treatment improves yield.',
        claimConfidence: FieldConfidence.moderate,
        regulatoryContext: 'internalResearch',
        regulatoryContextConfidence: FieldConfidence.low,
        inferenceSource: 'standalone_structure',
        inferenceNotes: ['Inferred from setup.'],
      ),
    );

Treatment _treatment(int id, {bool isDeleted = false}) => Treatment(
      id: id,
      trialId: 1,
      code: 'T$id',
      name: 'Treatment $id',
      isDeleted: isDeleted,
    );

Plot _plot(
  int id, {
  int? rep,
  bool isGuardRow = false,
  bool isDeleted = false,
}) =>
    Plot(
      id: id,
      trialId: 1,
      plotId: 'P$id',
      treatmentId: 1,
      rep: rep,
      isGuardRow: isGuardRow,
      isDeleted: isDeleted,
      excludeFromAnalysis: false,
    );

Widget _wrapIdentity({
  Trial? trial,
  TrialPurposeDto? purpose,
}) {
  final resolvedTrial = trial ?? _trial();
  return ProviderScope(
    overrides: [
      trialProvider(resolvedTrial.id).overrideWith(
        (_) => Stream.value(resolvedTrial),
      ),
      trialPurposeProvider(resolvedTrial.id).overrideWith(
        (_) => Stream.value(purpose ?? _confirmedPurpose()),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TrialIdentitySummaryCard(trial: resolvedTrial),
        ),
      ),
    ),
  );
}

Widget _wrapDesign({
  Trial? trial,
  List<Treatment> treatments = const [],
  List<Plot> plots = const [],
  ArmTrialMetadataData? armMetadata,
}) {
  final resolvedTrial = trial ?? _trial();
  return ProviderScope(
    overrides: [
      treatmentsForTrialProvider(resolvedTrial.id).overrideWith(
        (_) => Stream.value(treatments),
      ),
      plotsForTrialProvider(resolvedTrial.id).overrideWith(
        (_) => Stream.value(plots),
      ),
      armTrialMetadataStreamProvider(resolvedTrial.id).overrideWith(
        (_) => Stream.value(armMetadata),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TrialDesignSummaryCard(trial: resolvedTrial),
        ),
      ),
    ),
  );
}

void main() {
  group('Overview identity and design cards', () {
    testWidgets('OID-1: identity renders trial fields', (tester) async {
      await tester.pumpWidget(_wrapIdentity());
      await tester.pumpAndSettle();

      expect(find.text('Trial Identity'), findsOneWidget);
      expect(find.text('Wheat 2026'), findsOneWidget);
      expect(find.text('Wheat'), findsOneWidget);
      expect(find.text('Prairie Research'), findsOneWidget);
      expect(find.text('Efficacy'), findsWidgets);
      expect(find.text('efficacy'), findsOneWidget);
    });

    testWidgets('OID-2: design summary renders counts and ARM chip',
        (tester) async {
      await tester.pumpWidget(_wrapDesign(
        treatments: [
          _treatment(1),
          _treatment(2),
          _treatment(3, isDeleted: true),
        ],
        plots: [
          _plot(1, rep: 1),
          _plot(2, rep: 1),
          _plot(3, rep: 2),
          _plot(4, rep: 2, isGuardRow: true),
          _plot(5, rep: 3, isDeleted: true),
        ],
        armMetadata: const ArmTrialMetadataData(
          trialId: 1,
          isArmLinked: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Design Summary'), findsOneWidget);
      expect(find.text('Treatments'), findsOneWidget);
      expect(find.text('2'), findsNWidgets(2));
      expect(find.text('Replications'), findsOneWidget);
      expect(find.text('Total plots'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Design type'), findsOneWidget);
      expect(find.text('RCBD'), findsOneWidget);
      expect(find.text('ARM-linked'), findsOneWidget);
    });

    testWidgets('OID-3: inferred intent omits confidence labels',
        (tester) async {
      await tester.pumpWidget(_wrapIdentity(purpose: _inferredPurpose()));
      await tester.pumpAndSettle();

      expect(find.text('Intent inferred'), findsOneWidget);
      expect(find.text('Yield'), findsOneWidget);
      expect(find.text('Internal research'), findsOneWidget);
      expect(find.textContaining('moderate confidence'), findsNothing);
      expect(find.textContaining('low confidence'), findsNothing);
      expect(find.textContaining('high confidence'), findsNothing);
    });

    testWidgets('OID-4: inferred intent uses compact confirmation preview',
        (tester) async {
      await tester.pumpWidget(_wrapIdentity(purpose: _inferredPurpose()));
      await tester.pumpAndSettle();

      expect(find.text('Intent inferred'), findsOneWidget);
      expect(
        find.text(
            'Intent inferred from standalone setup. Confirm before export.'),
        findsOneWidget,
      );
      expect(find.text('UTC=untreated check'), findsOneWidget);
      expect(find.text('Confirm intent'), findsOneWidget);
      expect(find.textContaining('Review the inferred fields below'),
          findsNothing);
    });

    testWidgets('OID-5: design summary hides deleted and guard rows',
        (tester) async {
      await tester.pumpWidget(_wrapDesign(
        treatments: [_treatment(1), _treatment(2, isDeleted: true)],
        plots: [
          _plot(1, rep: 1),
          _plot(2, rep: 2, isGuardRow: true),
          _plot(3, rep: 3, isDeleted: true),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Treatments'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(3));
      expect(find.text('Total plots'), findsOneWidget);
      expect(find.text('ARM-linked'), findsNothing);
    });

    testWidgets('OID-6: confirmed intent renders fields and edit CTA',
        (tester) async {
      await tester.pumpWidget(_wrapIdentity(purpose: _confirmedPurpose()));
      await tester.pumpAndSettle();

      expect(find.text('Intent confirmed'), findsOneWidget);
      expect(find.text('Disease Severity'), findsOneWidget);
      expect(find.text('Registration efficacy'), findsOneWidget);
      expect(find.text('Registration / regulatory submission'), findsOneWidget);
      expect(find.text('Edit intent'), findsOneWidget);
      expect(find.text('Confirm intent'), findsNothing);
    });
  });
}
