import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/core/assessment_result_direction.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/features/trials/full_protocol_details_screen.dart';

List<(TrialAssessment, AssessmentDefinition)> _singleYieldAssessmentPair() {
  final now = DateTime(2026, 1, 1);
  final def = AssessmentDefinition(
    id: 100,
    code: 'YLD',
    name: 'Yield',
    category: 'crop',
    dataType: 'numeric',
    unit: 'kg',
    isSystem: false,
    isActive: true,
    createdAt: now,
    updatedAt: now,
    resultDirection: AssessmentResultDirection.higherBetter,
  );
  final ta = TrialAssessment(
    id: 1,
    trialId: 1,
    assessmentDefinitionId: 100,
    required: false,
    selectedFromProtocol: true,
    selectedManually: false,
    defaultInSessions: true,
    sortOrder: 0,
    isActive: true,
    legacyAssessmentId: 20,
    createdAt: now,
    updatedAt: now,
  );
  return [(ta, def)];
}

void main() {
  late Trial trial;
  late List<Treatment> treatments;
  late List<Assessment> assessments;
  late List<Plot> plots;
  late List<Assignment> assignments;

  setUp(() {
    trial = Trial(
      id: 1,
      name: 'Wheat 2026',
      crop: 'Wheat',
      location: 'North Farm',
      season: '2026',
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      isDeleted: false,
      isArmLinked: false,
    );
    treatments = [
      const Treatment(
          id: 10,
          trialId: 1,
          code: 'T1',
          name: 'Control',
          description: null,
          isDeleted: false),
      const Treatment(
          id: 11,
          trialId: 1,
          code: 'T2',
          name: 'Fertilizer A',
          description: null,
          isDeleted: false),
    ];
    assessments = [
      const Assessment(
        id: 20,
        trialId: 1,
        name: 'Yield',
        dataType: 'numeric',
        minValue: 0,
        maxValue: 100,
        unit: 'kg',
        isActive: true,
      ),
    ];
    plots = [
      const Plot(
        id: 101,
        trialId: 1,
        plotId: '1',
        plotSortIndex: 1,
        rep: 1,
        treatmentId: null,
        row: null,
        column: null,
        fieldRow: null,
        fieldColumn: null,
        assignmentSource: null,
        assignmentUpdatedAt: null,
        plotLengthM: null,
        plotWidthM: null,
        plotAreaM2: null,
        harvestLengthM: null,
        harvestWidthM: null,
        harvestAreaM2: null,
        plotDirection: null,
        soilSeries: null,
        plotNotes: null,
        isGuardRow: false,
        isDeleted: false,
        deletedAt: null,
        deletedBy: null,
        excludeFromAnalysis: false,
        exclusionReason: null,
        damageType: null,
        armPlotNumber: null,
        armImportDataRowIndex: null,
      ),
    ];
    assignments = [
      Assignment(
        id: 1,
        trialId: 1,
        plotId: 101,
        treatmentId: 10,
        replication: null,
        block: null,
        range: null,
        column: null,
        position: null,
        isCheck: null,
        isControl: null,
        assignmentSource: null,
        assignedAt: null,
        assignedBy: null,
        notes: null,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ];
  });

  group('FullProtocolDetailsScreen', () {
    testWidgets('shows Trial Summary title and trial name',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            treatmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value(treatments)),
            assessmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value(assessments)),
            trialAssessmentsWithDefinitionsForTrialProvider(1).overrideWith(
                (ref) => Stream.value(
                    const <(TrialAssessment, AssessmentDefinition)>[])),
            plotsForTrialProvider(1).overrideWith((ref) => Stream.value(plots)),
            assignmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value(assignments)),
          ],
          child: MaterialApp(
            home: FullProtocolDetailsScreen(trial: trial),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Trial Summary'), findsOneWidget);
      expect(find.text('Wheat 2026'), findsOneWidget);
    });

    testWidgets('shows Trial section with status, crop, location, season',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            treatmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value(treatments)),
            assessmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value(assessments)),
            trialAssessmentsWithDefinitionsForTrialProvider(1).overrideWith(
                (ref) => Stream.value(
                    const <(TrialAssessment, AssessmentDefinition)>[])),
            plotsForTrialProvider(1).overrideWith((ref) => Stream.value(plots)),
            assignmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value(assignments)),
          ],
          child: MaterialApp(
            home: FullProtocolDetailsScreen(trial: trial),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Trial'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Wheat'), findsOneWidget);
      expect(find.text('North Farm'), findsOneWidget);
      expect(find.text('2026'), findsWidgets);
    });

    testWidgets('shows Treatments section with count and codes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            treatmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value(treatments)),
            assessmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value(assessments)),
            trialAssessmentsWithDefinitionsForTrialProvider(1).overrideWith(
                (ref) => Stream.value(
                    const <(TrialAssessment, AssessmentDefinition)>[])),
            plotsForTrialProvider(1).overrideWith((ref) => Stream.value(plots)),
            assignmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value(assignments)),
          ],
          child: MaterialApp(
            home: FullProtocolDetailsScreen(trial: trial),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Treatments (2)'), findsOneWidget);
      expect(find.textContaining('T1 — Control'), findsOneWidget);
      expect(find.textContaining('T2 — Fertilizer A'), findsOneWidget);
    });

    testWidgets('shows Assessments section with names',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            treatmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value(treatments)),
            assessmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value(assessments)),
            trialAssessmentsWithDefinitionsForTrialProvider(1).overrideWith(
                (ref) => Stream.value(_singleYieldAssessmentPair())),
            plotsForTrialProvider(1).overrideWith((ref) => Stream.value(plots)),
            assignmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value(assignments)),
          ],
          child: MaterialApp(
            home: FullProtocolDetailsScreen(trial: trial),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Assessments (1)'), findsOneWidget);
      expect(find.text('Yield'), findsOneWidget);
    });

    testWidgets('shows Plots section with count and assigned count',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            treatmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value(treatments)),
            assessmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value(assessments)),
            trialAssessmentsWithDefinitionsForTrialProvider(1).overrideWith(
                (ref) => Stream.value(
                    const <(TrialAssessment, AssessmentDefinition)>[])),
            plotsForTrialProvider(1).overrideWith((ref) => Stream.value(plots)),
            assignmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value(assignments)),
          ],
          child: MaterialApp(
            home: FullProtocolDetailsScreen(trial: trial),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Plots'), findsOneWidget);
      expect(find.text('1 plots'), findsOneWidget);
      expect(find.text('1 assigned'), findsOneWidget);
    });

    testWidgets('shows loading state while providers load',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            treatmentsForTrialProvider(1)
                .overrideWith((ref) => const Stream.empty()),
            assessmentsForTrialProvider(1)
                .overrideWith((ref) => const Stream.empty()),
            trialAssessmentsWithDefinitionsForTrialProvider(1)
                .overrideWith((ref) => const Stream.empty()),
            plotsForTrialProvider(1)
                .overrideWith((ref) => const Stream.empty()),
            assignmentsForTrialProvider(1)
                .overrideWith((ref) => const Stream.empty()),
          ],
          child: MaterialApp(
            home: FullProtocolDetailsScreen(trial: trial),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Trial Summary'), findsOneWidget);
      expect(find.text('Wheat 2026'), findsOneWidget);
      expect(find.byType(FullProtocolDetailsScreen), findsOneWidget);
    });
  });
}
