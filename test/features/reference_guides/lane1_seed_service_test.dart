/// Tests for [Lane1SeedService].
///
/// AppDatabase.forTesting(NativeDatabase.memory()) runs onCreate, which
/// calls _seedAssessmentDefinitions() and Lane1SeedService.seedIfNeeded().
/// Tests build on that foundation — no separate definition seeding needed.
///
/// Covers:
///   S-1  seedIfNeeded() is idempotent — calling twice does not duplicate rows.
///   S-2  watchHasAnyGuide returns true when Lane 1 content exists.
///   S-3  watchHasAnyGuide returns false when assessmentDefinitionId is unknown.
///   S-4  Seed skips gracefully when assessment definition is missing — no
///        exception, other already-seeded diagrams are unchanged.
library;

import 'dart:io';
import 'dart:convert';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/assessment_guide_repository.dart';
import 'package:arm_field_companion/features/reference_guides/lane1_seed_service.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Lane1SeedService', () {
    late AppDatabase db;

    setUp(() async {
      // onCreate runs automatically: seeds assessment definitions (including
      // STAND_COVER) and calls Lane1SeedService.seedIfNeeded() once.
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    // S-1 ─────────────────────────────────────────────────────────────────
    test(
        'S-1: seedIfNeeded() is idempotent — calling a second time does not '
        'add rows', () async {
      final afterOnCreate = await db.select(db.assessmentGuideAnchors).get();
      expect(afterOnCreate.length, greaterThanOrEqualTo(5),
          reason: 'onCreate should have seeded at least 5 anchors');

      // Second call — should be a no-op.
      await Lane1SeedService(db).seedIfNeeded();

      final afterSecond = await db.select(db.assessmentGuideAnchors).get();
      expect(afterSecond.length, equals(afterOnCreate.length),
          reason: 'row count must not change on second call');
    });

    // S-2 ─────────────────────────────────────────────────────────────────
    test(
        'S-2: watchHasAnyGuide returns true for DISEASE_SEV only when '
        'crop context matches a calibrated Lane 1 disease guide', () async {
      final defRow = await _definitionByCode(db, 'DISEASE_SEV');
      final trialId = await db.into(db.trials).insert(
            TrialsCompanion.insert(
              name: 'Wheat guide context',
              crop: const drift.Value('Spring wheat'),
            ),
          );
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defRow.id,
            ),
          );

      final repo = AssessmentGuideRepository(db);
      final result = await repo
          .watchHasAnyGuide(
            trialAssessmentId: taId,
            assessmentDefinitionId: defRow.id,
          )
          .first;

      expect(result, isTrue);
    });

    test('S-2a: ARM DISEASE_SEV guide availability uses the shared resolver',
        () async {
      final defRow = await _definitionByCode(db, 'DISEASE_SEV');
      final trialId = await db.into(db.trials).insert(
            TrialsCompanion.insert(
              name: 'ARM wheat guide context',
              crop: const drift.Value('Wheat'),
              workspaceType: const drift.Value('arm'),
            ),
          );
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defRow.id,
            ),
          );
      await db.into(db.armAssessmentMetadata).insert(
            ArmAssessmentMetadataCompanion.insert(
              trialAssessmentId: taId,
              shellCropName: const drift.Value('Wheat'),
              seDescription: const drift.Value('Percent disease severity'),
            ),
          );

      final repo = AssessmentGuideRepository(db);
      final result = await repo
          .watchHasAnyGuide(
            trialAssessmentId: taId,
            assessmentDefinitionId: defRow.id,
          )
          .first;

      expect(result, isTrue);
    });

    test(
        'S-2b: standalone wheat disease severity can use trial name as crop context',
        () async {
      final defRow = await _definitionByCode(db, 'DISEASE_SEV');
      final trialId = await db.into(db.trials).insert(
            TrialsCompanion.insert(
              name: 'Wheat',
              workspaceType: const drift.Value('standalone'),
            ),
          );
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defRow.id,
              displayNameOverride: const drift.Value('% disease severity'),
            ),
          );

      final repo = AssessmentGuideRepository(db);
      final result = await repo
          .watchHasAnyGuide(
            trialAssessmentId: taId,
            assessmentDefinitionId: defRow.id,
          )
          .first;
      final diagnostics = await repo.diagnoseGuideAvailability(
        trialAssessmentId: taId,
        assessmentDefinitionId: defRow.id,
      );

      expect(result, isTrue);
      expect(
          diagnostics.reason, 'guide exists and is safe: calibration_diagram');
      expect(diagnostics.cropContext, contains('wheat'));
    });

    // S-3 ─────────────────────────────────────────────────────────────────
    test(
        'S-3: watchHasAnyGuide returns false when assessmentDefinitionId '
        'has no guide content', () async {
      final repo = AssessmentGuideRepository(db);

      final result = await repo
          .watchHasAnyGuide(
            trialAssessmentId: 0,
            assessmentDefinitionId: 999999, // non-existent
          )
          .first;

      expect(result, isFalse);
    });

    // S-4 ─────────────────────────────────────────────────────────────────
    test(
        'S-4: seed skips gracefully when an assessment definition is missing '
        '— no exception, other anchors are unchanged', () async {
      // Remove the stand_coverage anchor that was seeded in onCreate, then
      // delete the STAND_COVER definition. A subsequent seedIfNeeded() must
      // not throw and must not re-insert the missing-def anchor.
      await db.customStatement(
        "DELETE FROM assessment_guide_anchors "
        "WHERE source_url = 'assets/reference_guides/lane1/stand_coverage_percent.svg'",
      );
      await db.customStatement(
        "DELETE FROM assessment_definitions WHERE code = 'STAND_COVER'",
      );

      // Should complete without throwing.
      await expectLater(
        Lane1SeedService(db).seedIfNeeded(),
        completes,
      );

      // stand_coverage anchor must not be present (def was missing, seed skipped).
      final anchors = await db.select(db.assessmentGuideAnchors).get();
      final sourceUrls = anchors.map((a) => a.sourceUrl).toSet();

      expect(
        sourceUrls,
        isNot(contains(
            'assets/reference_guides/lane1/stand_coverage_percent.svg')),
        reason:
            'stand_coverage anchor must not be created when STAND_COVER def is absent',
      );

      // The other diagrams that were already seeded must still be present
      // (their _anyAnchorExists check returns true, so they were skipped
      // without touching their anchors).
      expect(sourceUrls,
          contains('assets/reference_guides/lane1/wheat_disease_severity.svg'));
      expect(
          sourceUrls,
          contains(
              'assets/reference_guides/lane1/canola_disease_severity.svg'));
      expect(sourceUrls,
          contains('assets/reference_guides/lane1/weed_cover_percent.svg'));
      expect(
          sourceUrls,
          contains(
              'assets/reference_guides/lane1/crop_injury_categorical.svg'));
    });

    test('S-5: Lane 1 seed paths exist and remain pending validation',
        () async {
      final anchors = await db.select(db.assessmentGuideAnchors).get();
      final lane1 = anchors
          .where((a) => a.lane == 'calibration_diagram')
          .toList(growable: false);

      expect(lane1, hasLength(greaterThanOrEqualTo(5)));
      for (final anchor in lane1) {
        expect(anchor.validatedBy, isNull);
        expect(anchor.validationDate, isNull);
        final sourceUrl = anchor.sourceUrl;
        expect(sourceUrl, isNotNull);
        expect(File(sourceUrl!).existsSync(), isTrue,
            reason: 'Lane 1 source_url must point to a bundled asset file');
      }
    });

    test('S-6: seeded captions and metadata match guide concepts', () async {
      final anchors = await db.select(db.assessmentGuideAnchors).get();
      final bySource = {
        for (final anchor in anchors)
          if (anchor.sourceUrl != null) anchor.sourceUrl!: anchor
      };

      expect(
        bySource['assets/reference_guides/lane1/weed_cover_percent.svg']!
            .attributionString
            .trim(),
        'Weed cover reference diagram © Agnexis.',
      );
      expect(
        bySource['assets/reference_guides/lane1/weed_cover_percent.svg']!
            .generationSpecification!
            .toLowerCase(),
        isNot(contains('dot density')),
      );
      expect(
        bySource['assets/reference_guides/lane1/weed_cover_percent.svg']!
            .generationSpecification!,
        contains('weed cover overhead quadrat reference'),
      );
      expect(
        bySource['assets/reference_guides/lane1/canola_disease_severity.svg']!
            .attributionString
            .toLowerCase(),
        contains('sclerotinia'),
      );
      expect(
        bySource['assets/reference_guides/lane1/crop_injury_categorical.svg']!
            .generationSpecification!,
        contains('"scale_values":[0,1,2,3,4]'),
      );
    });

    test('S-6a: old weed cover Lane 1 anchor path and metadata are repaired',
        () async {
      final oldAnchor = await _makeWeedAnchorLegacy(db);

      await Lane1SeedService(db).seedIfNeeded();

      final repaired = await (db.select(db.assessmentGuideAnchors)
            ..where((a) => a.id.equals(oldAnchor.id)))
          .getSingle();
      final visibleMetadata = [
        repaired.sourceUrl,
        repaired.attributionString,
        repaired.generationSpecification,
        repaired.citationFull,
      ].join('\n').toLowerCase();

      expect(
        repaired.sourceUrl,
        'assets/reference_guides/lane1/weed_cover_percent.svg',
      );
      expect(File(repaired.sourceUrl!).existsSync(), isTrue);
      expect(repaired.attributionString,
          'Weed cover reference diagram © Agnexis.');
      expect(repaired.generationSpecification,
          contains('weed cover overhead quadrat reference'));
      expect(repaired.generationSpecification,
          contains('Absolute canopy/ground occupancy'));
      expect(visibleMetadata, isNot(contains('weed control')));
      expect(visibleMetadata, isNot(contains('dot density')));
      expect(repaired.validatedBy, isNull);
      expect(repaired.validationDate, isNull);
    });

    test('S-6b: repair preserves existing validation fields exactly', () async {
      final oldAnchor = await _makeWeedAnchorLegacy(
        db,
        validatedBy: 'field-pathologist',
        validationDate: '2026-05-10',
      );

      await Lane1SeedService(db).seedIfNeeded();

      final repaired = await (db.select(db.assessmentGuideAnchors)
            ..where((a) => a.id.equals(oldAnchor.id)))
          .getSingle();

      expect(repaired.sourceUrl,
          'assets/reference_guides/lane1/weed_cover_percent.svg');
      expect(repaired.validatedBy, 'field-pathologist');
      expect(repaired.validationDate, '2026-05-10');
    });

    test('S-7: DISEASE_SEV without crop context shows no Lane 1 guide',
        () async {
      final defRow = await _definitionByCode(db, 'DISEASE_SEV');
      final repo = AssessmentGuideRepository(db);

      final resolved = await repo.resolveGuideForDisplay(
        trialAssessmentId: 0,
        assessmentDefinitionId: defRow.id,
      );

      expect(resolved, isNull);
    });

    test('S-8: wheat DISEASE_SEV resolves only the wheat foliar guide',
        () async {
      final defRow = await _definitionByCode(db, 'DISEASE_SEV');
      final trialId = await db.into(db.trials).insert(
            TrialsCompanion.insert(
              name: 'Wheat foliar disease',
              crop: const drift.Value('Wheat'),
            ),
          );
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defRow.id,
            ),
          );

      final resolved =
          await AssessmentGuideRepository(db).resolveGuideForDisplay(
        trialAssessmentId: taId,
        assessmentDefinitionId: defRow.id,
      );

      expect(resolved, isNotNull);
      expect(resolved!.anchors.map((a) => a.sourceUrl), [
        'assets/reference_guides/lane1/wheat_disease_severity.svg',
      ]);
    });

    test(
        'S-9: canola DISEASE_SEV without sclerotinia target shows no disease '
        'Lane 1 guide', () async {
      final defRow = await _definitionByCode(db, 'DISEASE_SEV');
      final trialId = await db.into(db.trials).insert(
            TrialsCompanion.insert(
              name: 'Canola generic disease',
              crop: const drift.Value('Canola'),
            ),
          );
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defRow.id,
              displayNameOverride:
                  const drift.Value('Generic disease severity'),
            ),
          );

      final resolved =
          await AssessmentGuideRepository(db).resolveGuideForDisplay(
        trialAssessmentId: taId,
        assessmentDefinitionId: defRow.id,
      );

      expect(resolved, isNull);
    });

    test('S-10: canola sclerotinia resolves only the sclerotinia guide',
        () async {
      final defRow = await _definitionByCode(db, 'DISEASE_SEV');
      final trialId = await db.into(db.trials).insert(
            TrialsCompanion.insert(
              name: 'Canola sclerotinia',
              crop: const drift.Value('Canola'),
            ),
          );
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defRow.id,
            ),
          );
      await db.into(db.armAssessmentMetadata).insert(
            ArmAssessmentMetadataCompanion.insert(
              trialAssessmentId: taId,
              seDescription: const drift.Value('Sclerotinia stem rot severity'),
              pestCode: const drift.Value('SCLESC'),
              shellCropName: const drift.Value('Canola'),
            ),
          );

      final resolved =
          await AssessmentGuideRepository(db).resolveGuideForDisplay(
        trialAssessmentId: taId,
        assessmentDefinitionId: defRow.id,
      );

      expect(resolved, isNotNull);
      expect(resolved!.anchors.map((a) => a.sourceUrl), [
        'assets/reference_guides/lane1/canola_disease_severity.svg',
      ]);
    });
  });
}

Future<AssessmentDefinition> _definitionByCode(
  AppDatabase db,
  String code,
) async {
  final def = await (db.select(db.assessmentDefinitions)
        ..where((d) => d.code.equals(code)))
      .getSingleOrNull();
  expect(def, isNotNull, reason: '$code definition must exist after onCreate');
  return def!;
}

Future<AssessmentGuideAnchor> _makeWeedAnchorLegacy(
  AppDatabase db, {
  String? validatedBy,
  String? validationDate,
}) async {
  final current = await (db.select(db.assessmentGuideAnchors)
        ..where((a) => a.sourceUrl.equals(
              'assets/reference_guides/lane1/weed_cover_percent.svg',
            )))
      .getSingle();

  await (db.update(db.assessmentGuideAnchors)
        ..where((a) => a.id.equals(current.id)))
      .write(
    AssessmentGuideAnchorsCompanion(
      sourceUrl: const drift.Value(
        'assets/reference_guides/lane1/weed_control_percent.svg',
      ),
      attributionString:
          const drift.Value('Weed control scale diagram © Agnexis.'),
      generationSpecification: drift.Value(jsonEncode({
        'assessment_type': 'weed_control',
        'scale_values': [0, 10, 25, 50, 75, 90, 100],
        'visual': 'dot_density_plot',
        'description': 'Focused reference view: weed control dot density plot.',
      })),
      validatedBy: drift.Value(validatedBy),
      validationDate: drift.Value(validationDate),
    ),
  );

  return (db.select(db.assessmentGuideAnchors)
        ..where((a) => a.id.equals(current.id)))
      .getSingle();
}
