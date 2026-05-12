import 'dart:convert';
import 'dart:io';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/assessment_guide_repository.dart';
import 'package:arm_field_companion/features/ratings/widgets/assessment_reference_guide_sheet.dart';
import 'package:arm_field_companion/features/reference_guides/lane2a_approved_photo_manifest.dart';
import 'package:arm_field_companion/features/reference_guides/lane2a_reference_photo_seed_service.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Lane2AReferencePhotoSeedService', () {
    late AppDatabase db;
    late Directory tempDir;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      tempDir = await Directory.systemTemp.createTemp('lane2a_manifest_test_');
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('bundled Batch 1 manifest starts empty until files are approved',
        () async {
      await Lane2AReferencePhotoSeedService.fromBundledManifest(db)
          .seedIfNeeded();

      expect(lane2AApprovedPhotoManifestEntries, isEmpty);
      expect(await _lane2Anchors(db), isEmpty);
    });

    test('approved manifest image seeds successfully', () async {
      final file = await _writeApprovedPhotoFile(tempDir, 'wild_oat_01.jpg');
      final reference = Lane2AReferencePhotoSeed.fromManifest(
        _manifestEntry(localAssetPath: file.path),
      );

      await Lane2AReferencePhotoSeedService(
        db,
        approvedReferences: [reference],
      ).seedIfNeeded();

      final lane2 = await _lane2Anchors(db);
      expect(lane2, hasLength(1));

      final anchor = lane2.single;
      final metadata =
          jsonDecode(anchor.generationSpecification!) as Map<String, dynamic>;

      expect(anchor.lane, Lane2AReferencePhotoSeedService.lane);
      expect(anchor.contentType, Lane2AReferencePhotoSeedService.contentType);
      expect(anchor.filePath, file.path);
      expect(anchor.sourceUrl, 'https://doi.org/10.5061/dryad.gtht76hhz');
      expect(anchor.licenseIdentifier, 'CC0-1.0');
      expect(anchor.attributionString, contains('Wild oat'));
      expect(anchor.attributionString, contains('CC0-1.0'));
      expect(anchor.citationFull, contains('10.5061/dryad.gtht76hhz'));
      expect(metadata['sourceDataset'], _dryadDataset);
      expect(metadata['sourceDoi'], '10.5061/dryad.gtht76hhz');
      expect(metadata['authorCreator'], _dryadAuthors);
      expect(metadata['exactLicense'], 'CC0-1.0');
      expect(metadata['licenseAppliesToImageFile'], isTrue);
      expect(metadata['speciesCode'], 'wild_oat');
      expect(metadata['speciesScientificName'], 'Avena fatua');
      expect(metadata['commonName'], 'Wild oat');
      expect(metadata['shortReferenceNote'], contains('weed seedling'));
      expect(metadata['manualReview']['approvedBy'], 'Parminder');
      expect(metadata['manualReview']['approvedForBundling'], isTrue);
    });

    test('missing file in manifest fails test', () async {
      final missingPath = '${tempDir.path}/missing_wild_oat.jpg';
      final reference = Lane2AReferencePhotoSeed.fromManifest(
        _manifestEntry(localAssetPath: missingPath),
      );

      await expectLater(
        Lane2AReferencePhotoSeedService(
          db,
          approvedReferences: [reference],
        ).seedIfNeeded(),
        throwsA(isA<StateError>()),
      );
      expect(await _lane2Anchors(db), isEmpty);
    });

    test('unlisted file in approved folder does not seed', () async {
      await _writeApprovedPhotoFile(tempDir, 'unlisted_canada_thistle.jpg');

      await Lane2AReferencePhotoSeedService(
        db,
        approvedReferences: const [],
      ).seedIfNeeded();

      expect(await _lane2Anchors(db), isEmpty);
    });

    test('Lane 2 beats Lane 1', () async {
      final file = await _writeApprovedPhotoFile(tempDir, 'wild_oat_01.jpg');
      final def = await _definitionByCode(db, 'WEED_COVER');
      final trialAssessmentId = await _makeTrialAssessment(
        db,
        assessmentDefinitionId: def.id,
      );

      await Lane2AReferencePhotoSeedService(
        db,
        approvedReferences: [
          Lane2AReferencePhotoSeed.fromManifest(
            _manifestEntry(localAssetPath: file.path),
          ),
        ],
      ).seedIfNeeded();

      final resolved =
          await AssessmentGuideRepository(db).resolveGuideForDisplay(
        trialAssessmentId: trialAssessmentId,
        assessmentDefinitionId: def.id,
      );

      expect(resolved, isNotNull);
      expect(resolved!.anchors.single.lane, 'identification_photo');
      expect(resolved.anchors.single.filePath, file.path);
    });

    test('Lane 3 beats Lane 2', () async {
      final file = await _writeApprovedPhotoFile(tempDir, 'wild_oat_01.jpg');
      final customerFile =
          await _writeApprovedPhotoFile(tempDir, 'customer_ref.jpg');
      final def = await _definitionByCode(db, 'WEED_COVER');
      final trialAssessmentId = await _makeTrialAssessment(
        db,
        assessmentDefinitionId: def.id,
      );

      await Lane2AReferencePhotoSeedService(
        db,
        approvedReferences: [
          Lane2AReferencePhotoSeed.fromManifest(
            _manifestEntry(localAssetPath: file.path),
          ),
        ],
      ).seedIfNeeded();
      await _insertCustomerAnchor(db, trialAssessmentId, customerFile.path);

      final resolved =
          await AssessmentGuideRepository(db).resolveGuideForDisplay(
        trialAssessmentId: trialAssessmentId,
        assessmentDefinitionId: def.id,
      );

      expect(resolved, isNotNull);
      expect(resolved!.anchors.single.lane, 'customer_upload');
      expect(resolved.anchors.single.filePath, customerFile.path);
    });

    test('CC0 and public-domain metadata displays in comparator', () {
      final cc0Model = ReferenceExampleViewModel.fromAnchor(
        _anchorFor(
          Lane2AReferencePhotoSeed.fromManifest(
            _manifestEntry(localAssetPath: '/tmp/wild_oat.jpg'),
          ),
        ),
      );
      final publicDomainModel = ReferenceExampleViewModel.fromAnchor(
        _anchorFor(
          Lane2AReferencePhotoSeed.fromManifest(
            _manifestEntry(
              localAssetPath: '/tmp/dandelion.jpg',
              speciesCode: 'dandelion',
              commonName: 'Dandelion',
              speciesScientificName: 'Taraxacum officinale',
              exactLicense: 'public_domain',
            ),
          ),
        ),
      );

      expect(cc0Model.label, 'Wild oat - Weed seedling reference');
      expect(cc0Model.description, contains('Wild oat'));
      expect(cc0Model.sourceText, contains('License: CC0-1.0'));
      expect(cc0Model.sourceText, contains('Citation:'));
      expect(publicDomainModel.label, 'Dandelion - Weed seedling reference');
      expect(publicDomainModel.sourceText, contains('License: public_domain'));
    });

    test('no Lane 2 seed happens without manual approval metadata', () async {
      final file = await _writeApprovedPhotoFile(tempDir, 'wild_oat_01.jpg');
      final entry = _manifestEntry(
        localAssetPath: file.path,
        approvedForBundling: false,
      );

      await expectLater(
        Lane2AReferencePhotoSeedService(
          db,
          approvedReferences: [Lane2AReferencePhotoSeed.fromManifest(entry)],
        ).seedIfNeeded(),
        throwsA(isA<ArgumentError>()),
      );
      expect(await _lane2Anchors(db), isEmpty);
    });

    test('manifest without approvedBy fails before seeding', () async {
      final file = await _writeApprovedPhotoFile(tempDir, 'wild_oat_01.jpg');
      final entry = Map<String, Object?>.from(
        _manifestEntry(localAssetPath: file.path),
      )..remove('approvedBy');

      expect(
        () => Lane2AReferencePhotoSeed.fromManifest(entry),
        throwsA(isA<ArgumentError>()),
      );
      expect(await _lane2Anchors(db), isEmpty);
    });

    test('ARM and standalone resolve through the same guide path', () async {
      final file = await _writeApprovedPhotoFile(tempDir, 'wild_oat_01.jpg');
      final def = await _definitionByCode(db, 'WEED_COVER');

      await Lane2AReferencePhotoSeedService(
        db,
        approvedReferences: [
          Lane2AReferencePhotoSeed.fromManifest(
            _manifestEntry(localAssetPath: file.path),
          ),
        ],
      ).seedIfNeeded();

      final standaloneTaId = await _makeTrialAssessment(
        db,
        assessmentDefinitionId: def.id,
      );
      final armTaId = await _makeTrialAssessment(
        db,
        assessmentDefinitionId: def.id,
      );
      await db.into(db.armAssessmentMetadata).insert(
            ArmAssessmentMetadataCompanion.insert(
              trialAssessmentId: armTaId,
              seName: const drift.Value('WEED_COVER'),
              shellCropName: const drift.Value('Wheat'),
            ),
          );

      final repo = AssessmentGuideRepository(db);
      final standalone = await repo.resolveGuideForDisplay(
        trialAssessmentId: standaloneTaId,
        assessmentDefinitionId: def.id,
      );
      final arm = await repo.resolveGuideForDisplay(
        trialAssessmentId: armTaId,
        assessmentDefinitionId: def.id,
      );

      expect(standalone!.anchors.single.lane, 'identification_photo');
      expect(arm!.anchors.single.lane, 'identification_photo');
      expect(standalone.anchors.single.filePath, arm.anchors.single.filePath);
    });
  });
}

const _dryadDataset = 'Dryad Manitoba weed seedling dataset';
const _dryadDoi = '10.5061/dryad.gtht76hhz';
const _dryadAuthors = 'Beck, Liu, Bidinosti, Henry, Godee, Ajmani';
const _dryadCitation = 'Beck, Liu, Bidinosti, Henry, Godee, Ajmani. '
    'Manitoba weed seedling dataset. Dryad. DOI: 10.5061/dryad.gtht76hhz. '
    'CC0-1.0.';

Map<String, Object?> _manifestEntry({
  required String localAssetPath,
  String speciesCode = 'wild_oat',
  String commonName = 'Wild oat',
  String speciesScientificName = 'Avena fatua',
  String exactLicense = 'CC0-1.0',
  bool licenseAppliesToImageFile = true,
  bool approvedForBundling = true,
  String category = 'weed_seedling_reference',
}) {
  return {
    'assessmentDefinitionCode': 'WEED_COVER',
    'localAssetPath': localAssetPath,
    'speciesCode': speciesCode,
    'commonName': commonName,
    'speciesScientificName': speciesScientificName,
    'category': category,
    'sourceDataset': _dryadDataset,
    'sourceUrl': 'https://doi.org/$_dryadDoi',
    'sourceDoi': _dryadDoi,
    'authorCreator': _dryadAuthors,
    'exactLicense': exactLicense,
    'licenseAppliesToImageFile': licenseAppliesToImageFile,
    'approvedBy': 'Parminder',
    'approvedAt': '2026-05-10',
    'approvedForBundling': approvedForBundling,
    'dateObtained': '2026-05-10',
    'dateLastVerified': '2026-05-10',
    'citationFull': _dryadCitation,
    'shortReferenceNote':
        '$commonName weed seedling reference, manually approved for Lane 2A.',
    'subjectLabel': commonName,
    'focalX': 0.5,
    'focalY': 0.45,
    'cropZoom': 1.15,
    'sortOrder': 0,
  };
}

Future<File> _writeApprovedPhotoFile(Directory tempDir, String name) async {
  final file = File('${tempDir.path}/$name');
  await file.writeAsBytes([0, 1, 2, 3, 4]);
  return file;
}

AssessmentGuideAnchor _anchorFor(Lane2AReferencePhotoSeed reference) {
  return AssessmentGuideAnchor(
    id: 1,
    guideId: 1,
    sortOrder: 0,
    filePath: reference.localAssetPath,
    lane: Lane2AReferencePhotoSeedService.lane,
    contentType: Lane2AReferencePhotoSeedService.contentType,
    sourceUrl: reference.sourceUrl,
    licenseIdentifier: reference.exactLicense,
    attributionString: reference.attributionString(),
    generationSpecification: reference.metadataJson(),
    citationFull: reference.citationText,
    dateObtained: reference.dateObtained,
    dateLastVerified: reference.dateLastVerified,
    isDeleted: 0,
    createdAt: 0,
  );
}

Future<List<AssessmentGuideAnchor>> _lane2Anchors(AppDatabase db) {
  return (db.select(db.assessmentGuideAnchors)
        ..where((a) => a.lane.equals(Lane2AReferencePhotoSeedService.lane)))
      .get();
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

Future<int> _makeTrialAssessment(
  AppDatabase db, {
  required int assessmentDefinitionId,
}) async {
  final trialId = await db.into(db.trials).insert(
        TrialsCompanion.insert(name: 'Lane 2A resolver trial'),
      );
  return db.into(db.trialAssessments).insert(
        TrialAssessmentsCompanion.insert(
          trialId: trialId,
          assessmentDefinitionId: assessmentDefinitionId,
        ),
      );
}

Future<void> _insertCustomerAnchor(
  AppDatabase db,
  int trialAssessmentId,
  String filePath,
) async {
  final guideId = await db.into(db.assessmentGuides).insert(
        AssessmentGuidesCompanion.insert(
          trialAssessmentId: drift.Value(trialAssessmentId),
        ),
      );
  await db.into(db.assessmentGuideAnchors).insert(
        AssessmentGuideAnchorsCompanion.insert(
          guideId: guideId,
          sortOrder: const drift.Value(0),
          filePath: drift.Value(filePath),
          lane: 'customer_upload',
          contentType: 'customer_photo',
          licenseIdentifier: const drift.Value('customer_grant_v1'),
          attributionString: 'Customer-uploaded reference image.',
          dateObtained: '2026-05-10',
        ),
      );
}
