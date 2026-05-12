import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/assessment_guide_repository.dart';
import 'package:arm_field_companion/features/ratings/widgets/assessment_reference_guide_sheet.dart';
import 'package:arm_field_companion/features/photos/photo_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reference = ReferenceExampleViewModel(
    displayPath: 'assets/reference_guides/lane1/wheat_disease_severity.svg',
    label: '0% / 5% / 10%',
    selectedBadgeLabel: 'Calibration reference',
    description: 'Focused reference view for visual comparison.',
    sourceText: 'Original Agnexis reference. License: original_work_agnexis',
    isPendingValidation: true,
  );

  Widget harness({
    required Size size,
    String? currentPhotoPath,
    List<ReferenceExampleViewModel> references = const [reference],
    Future<void> Function()? onCapturePhoto,
    Future<void> Function()? onRemovePhoto,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(
          body: SizedBox(
            width: size.width,
            height: size.height,
            child: ReferenceGuideComparator(
              data: ReferenceComparatorData(
                currentPhotoPath: currentPhotoPath,
                showCalibrationFallbackNotice: false,
                references: references,
              ),
              onCapturePhoto: onCapturePhoto,
              onRemovePhoto: onRemovePhoto,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('uses split top-bottom layout on narrow screens', (tester) async {
    await tester.pumpWidget(harness(size: const Size(390, 760)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('referenceComparatorNarrowLayout')),
        findsOneWidget);
    expect(
        find.byKey(const Key('referenceComparatorWideLayout')), findsNothing);
    expect(find.text('Current field photo'), findsOneWidget);
  });

  testWidgets('uses side-by-side layout on wide screens', (tester) async {
    await tester.pumpWidget(harness(size: const Size(920, 760)));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('referenceComparatorWideLayout')), findsOneWidget);
    expect(
        find.byKey(const Key('referenceComparatorNarrowLayout')), findsNothing);
  });

  testWidgets('shows fallback when no current plot photo exists',
      (tester) async {
    await tester.pumpWidget(harness(size: const Size(390, 760)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('currentPhotoFallback')), findsOneWidget);
    expect(find.text('Capture field photo'), findsOneWidget);
    expect(
      find.text(
          'Take a photo of this plot to compare it with reference examples.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('referenceCard_0')), findsOneWidget);
  });

  testWidgets('empty current photo panel wires capture action', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      harness(
        size: const Size(390, 760),
        onCapturePhoto: () async {
          tapped = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    final buttonFinder = find.byKey(const Key('captureFieldPhotoButton'));
    expect(buttonFinder, findsOneWidget);

    tester.widget<FilledButton>(buttonFinder).onPressed!();
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('current photo panel shows retake and remove actions',
      (tester) async {
    await tester.pumpWidget(
      harness(
        size: const Size(390, 760),
        currentPhotoPath: '/tmp/current-comparison-photo.jpg',
        onCapturePhoto: () async {},
        onRemovePhoto: () async {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('currentPhotoFallback')), findsNothing);
    expect(find.byKey(const Key('retakeCurrentPhotoButton')), findsOneWidget);
    expect(find.byKey(const Key('removeCurrentPhotoButton')), findsOneWidget);
    expect(find.text('Retake photo'), findsOneWidget);
    expect(find.text('Remove photo'), findsOneWidget);
  });

  testWidgets('retake callback is wired when current photo exists',
      (tester) async {
    var retakeTapped = false;

    await tester.pumpWidget(
      harness(
        size: const Size(390, 760),
        currentPhotoPath: '/tmp/current-comparison-photo.jpg',
        onCapturePhoto: () async {
          retakeTapped = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    final buttonFinder = find.byKey(const Key('retakeCurrentPhotoButton'));
    expect(buttonFinder, findsOneWidget);

    tester.widget<OutlinedButton>(buttonFinder).onPressed!();
    await tester.pumpAndSettle();

    expect(retakeTapped, isTrue);
  });

  testWidgets('remove callback is wired and returns panel to capture state',
      (tester) async {
    var removed = false;
    String? currentPath = '/tmp/current-comparison-photo.jpg';

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              width: 390,
              height: 760,
              child: ReferenceGuideComparator(
                data: ReferenceComparatorData(
                  currentPhotoPath: currentPath,
                  showCalibrationFallbackNotice: false,
                  references: const [reference],
                ),
                onRemovePhoto: () async {
                  removed = true;
                  setState(() => currentPath = null);
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('removeCurrentPhotoButton')));
    await tester.pumpAndSettle();
    expect(find.text('Remove this comparison photo?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirmRemoveCurrentPhotoButton')));
    await tester.pumpAndSettle();

    expect(removed, isTrue);
    expect(find.byKey(const Key('currentPhotoFallback')), findsOneWidget);
    expect(find.text('Capture field photo'), findsOneWidget);
  });

  testWidgets('current photo remains tappable for zoom', (tester) async {
    await tester.pumpWidget(
      harness(
        size: const Size(390, 760),
        currentPhotoPath: '/tmp/current-comparison-photo.jpg',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FocusedReferenceImage).first);
    await tester.pumpAndSettle();

    expect(find.byType(FullImageView), findsOneWidget);
    expect(find.text('Current field photo'), findsWidgets);
  });

  testWidgets('tap marks Lane 1 calibration reference and shows use action',
      (tester) async {
    await tester.pumpWidget(harness(size: const Size(390, 760)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('selectionActionBar')), findsNothing);

    await tester.tap(find.text('0% / 5% / 10%'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('closestVisualMatchBadge')), findsOneWidget);
    expect(find.text('Calibration reference'), findsOneWidget);
    expect(find.byKey(const Key('selectionActionBar')), findsOneWidget);
    expect(find.byKey(const Key('useThisValueButton')), findsOneWidget);
  });

  testWidgets('Lane 2 selected card says closest visual match', (tester) async {
    const lane2Reference = ReferenceExampleViewModel(
      displayPath: 'assets/reference_guides/lane2a/approved/wild_oat/a.jpg',
      label: 'Wild oat - Weed seedling reference',
      selectedBadgeLabel: 'Closest visual match',
      description: 'Focused reference view: weed seedling reference.',
      sourceText: 'License: CC0',
      isPendingValidation: false,
    );

    await tester.pumpWidget(
      harness(
        size: const Size(390, 760),
        references: const [lane2Reference],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wild oat - Weed seedling reference'));
    await tester.pumpAndSettle();

    expect(find.text('Closest visual match'), findsOneWidget);
    expect(find.text('Calibration reference'), findsNothing);
  });

  testWidgets('reference photo cards support tap-to-zoom', (tester) async {
    await tester.pumpWidget(harness(size: const Size(390, 760)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FocusedReferenceImage).last);
    await tester.pumpAndSettle();

    expect(find.byType(FullImageView), findsOneWidget);
    expect(find.text('0% / 5% / 10%'), findsWidgets);
  });

  test('weed cover view text avoids control and dot-density language', () {
    final model = ReferenceExampleViewModel.fromAnchor(
      const AssessmentGuideAnchor(
        id: 1,
        guideId: 1,
        sortOrder: 0,
        lane: 'calibration_diagram',
        contentType: 'ai_generated_svg',
        sourceUrl: 'assets/reference_guides/lane1/weed_cover_percent.svg',
        licenseIdentifier: 'original_work_agnexis',
        attributionString: 'Weed cover reference diagram (c) Agnexis.',
        generationSpecification:
            '{"assessment_type":"weed_cover","scale_values":[0,10,25,50,75,90,100],"visual":"overhead_quadrat_irregular_canopy_occupancy"}',
        citationFull: 'EPPO PP 1/152',
        dateObtained: '2026-05-10',
        isDeleted: 0,
        createdAt: 0,
      ),
    );

    final visibleText = [
      model.label,
      model.description,
      model.sourceText,
    ].join('\n').toLowerCase();

    expect(visibleText, contains('weed cover'));
    expect(visibleText, contains('overhead quadrat'));
    expect(visibleText, contains('absolute canopy/ground occupancy'));
    expect(visibleText, isNot(contains('weed control')));
    expect(visibleText, isNot(contains('dot density')));
  });

  testWidgets('pending validation remains visible for Lane 1 references',
      (tester) async {
    await tester.pumpWidget(harness(size: const Size(390, 760)));
    await tester.pumpAndSettle();

    expect(find.text('Pending validation'), findsOneWidget);
  });

  test('retake and remove refresh loads do not duplicate guide-view audit',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final def = await _definitionByCode(db, 'WEED_COVER');
    final trialId = await db.into(db.trials).insert(
          TrialsCompanion.insert(name: 'Comparator audit trial'),
        );
    final plotPk = await db.into(db.plots).insert(
          PlotsCompanion.insert(trialId: trialId, plotId: '101'),
        );
    final sessionId = await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            trialId: trialId,
            name: 'Rating session',
            sessionDateLocal: '2026-05-10',
          ),
        );
    final assessmentId = await db.into(db.assessments).insert(
          AssessmentsCompanion.insert(
            trialId: trialId,
            name: 'Weed cover',
          ),
        );
    final trialAssessmentId = await db.into(db.trialAssessments).insert(
          TrialAssessmentsCompanion.insert(
            trialId: trialId,
            assessmentDefinitionId: def.id,
          ),
        );

    final repo = AssessmentGuideRepository(db);
    final photoRepository = PhotoRepository(db);

    await loadReferenceComparatorData(
      trialId: trialId,
      plotPk: plotPk,
      assessmentId: assessmentId,
      trialAssessmentId: trialAssessmentId,
      assessmentDefinitionId: def.id,
      sessionId: sessionId,
      raterUserId: null,
      repo: repo,
      photoRepository: photoRepository,
      recordViewEvent: true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(await _guideViewEventCount(db), 1);

    await loadReferenceComparatorData(
      trialId: trialId,
      plotPk: plotPk,
      assessmentId: assessmentId,
      trialAssessmentId: trialAssessmentId,
      assessmentDefinitionId: def.id,
      sessionId: sessionId,
      raterUserId: null,
      repo: repo,
      photoRepository: photoRepository,
      recordViewEvent: false,
    );
    await loadReferenceComparatorData(
      trialId: trialId,
      plotPk: plotPk,
      assessmentId: assessmentId,
      trialAssessmentId: trialAssessmentId,
      assessmentDefinitionId: def.id,
      sessionId: sessionId,
      raterUserId: null,
      repo: repo,
      photoRepository: photoRepository,
      recordViewEvent: false,
      showEmptyPhotoPanel: true,
    );

    expect(await _guideViewEventCount(db), 1);
  });
}

Future<AssessmentDefinition> _definitionByCode(
  AppDatabase db,
  String code,
) async {
  final def = await (db.select(db.assessmentDefinitions)
        ..where((d) => d.code.equals(code)))
      .getSingleOrNull();
  expect(def, isNotNull);
  return def!;
}

Future<int> _guideViewEventCount(AppDatabase db) async {
  final events = await db.select(db.ratingGuideViewEvents).get();
  return events.length;
}
