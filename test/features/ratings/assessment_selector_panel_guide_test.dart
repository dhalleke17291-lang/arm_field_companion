import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/ratings/widgets/assessment_selector_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Wheat standalone disease severity title row renders guide icon and opens comparator',
      (tester) async {
    var opened = false;

    await tester.pumpWidget(
      _harness(
        hasGuide: true,
        onGuideIconTap: () {
          opened = true;
          showDialog<void>(
            context: tester.element(find.byType(AssessmentSelectorPanel)),
            builder: (_) => const AlertDialog(
              content: Text('Reference comparator'),
            ),
          );
        },
      ),
    );

    expect(find.text('% disease severity'), findsOneWidget);
    expect(find.text('· %'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(opened, isTrue);
    expect(find.text('Reference comparator'), findsOneWidget);
  });

  testWidgets('custom unmapped assessment title row does not render guide icon',
      (tester) async {
    await tester.pumpWidget(_harness(hasGuide: false));

    expect(find.text('% disease severity'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsNothing);
  });
}

Widget _harness({
  required bool hasGuide,
  VoidCallback? onGuideIconTap,
}) {
  final now = DateTime(2026, 1, 1);
  const assessment = Assessment(
    id: 10,
    trialId: 1,
    name: '% disease severity',
    dataType: 'numeric',
    minValue: 0,
    maxValue: 100,
    unit: '%',
    isActive: true,
  );
  final definition = AssessmentDefinition(
    id: 2,
    code: 'DISEASE_SEV',
    name: 'Disease severity',
    category: 'disease',
    dataType: 'numeric',
    unit: '%',
    scaleMin: 0,
    scaleMax: 100,
    isSystem: true,
    isActive: true,
    createdAt: now,
    updatedAt: now,
    resultDirection: 'neutral',
  );
  final trialAssessment = TrialAssessment(
    id: 20,
    trialId: 1,
    assessmentDefinitionId: 2,
    displayNameOverride: '% disease severity',
    required: false,
    selectedFromProtocol: false,
    selectedManually: true,
    defaultInSessions: true,
    sortOrder: 0,
    isActive: true,
    legacyAssessmentId: assessment.id,
    createdAt: now,
    updatedAt: now,
  );

  return MaterialApp(
    home: Scaffold(
      body: AssessmentSelectorPanel(
        assessments: const [assessment],
        currentAssessment: assessment,
        taByLegacy: {assessment.id: trialAssessment},
        taById: {trialAssessment.id: trialAssessment},
        nonRecordedAssessmentIds: const {},
        definitions: [definition],
        aamMap: const {},
        assessmentScrollController: ScrollController(),
        sessionTrialAssessmentIdsByAssessmentId: {
          assessment.id: trialAssessment.id,
        },
        shellDescription: null,
        assessmentDisplayLabel: (assessment, _, __) => assessment.name,
        assessmentChipLabel: (assessment, _, __) => assessment.name,
        onAssessmentSelected: (_, __) {},
        hasGuide: hasGuide,
        onGuideIconTap: onGuideIconTap,
      ),
    ),
  );
}
