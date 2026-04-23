// Phase 2d — Treatments-sheet round-trip trust anchor.
//
// Locks in cross-cutting invariants that neither the parser test
// (`arm_shell_parser_treatments_sheet_test.dart`) nor the write-through
// test (`import_arm_rating_shell_treatments_sheet_test.dart`) covers:
//
//   1. Dual-write consistency — for every ARM-tagged treatment,
//      `Treatments.treatmentType` equals `ArmTreatmentMetadata.armTypeCode`
//      byte-for-byte. This is the invariant that keeps control-treatment
//      detection (reads core) and round-trip export (reads AAM) in sync.
//
//   2. Deterministic re-import — running the full importer twice on the
//      same fixture produces two trials whose ARM-scoped data is
//      byte-for-byte identical (modulo primary keys + createdAt
//      timestamps). Catches any latent non-determinism from iteration
//      order, string-trimming drift, or stale in-memory state.
//
//   3. Full-table survey — the only AAM / component / treatment rows
//      that exist after import are the ones the fixture describes.
//      Catches regressions where a later phase accidentally writes
//      extra rows into ARM-scoped tables.
//
// When Phase 3 (Applications) lands, the same invariants will want to
// hold for `arm_applications`; that test can be modelled on this one.

import 'dart:io';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/arm/arm_column_mapping_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/features/arm_import/usecases/import_arm_rating_shell_usecase.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

const _fixturePath = 'test/fixtures/arm_shells/AgQuest_RatingShell.xlsx';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getTemporaryPath() async => path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getLibraryPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => path;
}

/// Normalised snapshot of one treatment across core + ARM-extension
/// tables, stripped of anything that legitimately changes between
/// imports (primary keys, audit timestamps, foreign-key references).
/// Two snapshots that compare equal mean the import was deterministic.
class _TreatmentSnapshot {
  const _TreatmentSnapshot({
    required this.code,
    required this.name,
    required this.treatmentType,
    required this.armTypeCode,
    required this.formConc,
    required this.formConcUnit,
    required this.formType,
    required this.armRowSortOrder,
    required this.components,
  });

  final String code;
  final String name;
  final String? treatmentType;
  final String? armTypeCode;
  final double? formConc;
  final String? formConcUnit;
  final String? formType;
  final int? armRowSortOrder;
  final List<_ComponentSnapshot> components;

  @override
  bool operator ==(Object other) =>
      other is _TreatmentSnapshot &&
      other.code == code &&
      other.name == name &&
      other.treatmentType == treatmentType &&
      other.armTypeCode == armTypeCode &&
      other.formConc == formConc &&
      other.formConcUnit == formConcUnit &&
      other.formType == formType &&
      other.armRowSortOrder == armRowSortOrder &&
      _listEquals(other.components, components);

  @override
  int get hashCode => Object.hash(code, name, treatmentType, armTypeCode,
      formConc, formConcUnit, formType, armRowSortOrder, components.length);

  @override
  String toString() => 'TreatmentSnapshot(code=$code, name=$name, '
      'treatmentType=$treatmentType, armTypeCode=$armTypeCode, '
      'formConc=$formConc, formConcUnit=$formConcUnit, '
      'formType=$formType, armRowSortOrder=$armRowSortOrder, '
      'components=$components)';
}

class _ComponentSnapshot {
  const _ComponentSnapshot({
    required this.productName,
    required this.rate,
    required this.rateUnit,
    required this.sortOrder,
  });

  final String productName;
  final double? rate;
  final String? rateUnit;
  final int sortOrder;

  @override
  bool operator ==(Object other) =>
      other is _ComponentSnapshot &&
      other.productName == productName &&
      other.rate == rate &&
      other.rateUnit == rateUnit &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode =>
      Object.hash(productName, rate, rateUnit, sortOrder);

  @override
  String toString() =>
      'ComponentSnapshot(name=$productName, rate=$rate $rateUnit, '
      'sortOrder=$sortOrder)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Loads a sorted, code-keyed snapshot of all treatments for a trial,
/// joined with their `arm_treatment_metadata` + `treatment_components`
/// rows. Output order: ascending treatment code.
Future<List<_TreatmentSnapshot>> _snapshotTrial(
  AppDatabase db,
  int trialId,
) async {
  final treatments = await (db.select(db.treatments)
        ..where((t) => t.trialId.equals(trialId))
        ..orderBy([(t) => OrderingTerm.asc(t.code)]))
      .get();

  final treatmentIds = treatments.map((t) => t.id).toSet();

  final aamRows = await db.select(db.armTreatmentMetadata).get();
  final aamByTreatmentId = {
    for (final a in aamRows)
      if (treatmentIds.contains(a.treatmentId)) a.treatmentId: a,
  };

  final components = await (db.select(db.treatmentComponents)
        ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
      .get();
  final componentsByTreatmentId = <int, List<_ComponentSnapshot>>{};
  for (final c in components) {
    if (!treatmentIds.contains(c.treatmentId)) continue;
    (componentsByTreatmentId[c.treatmentId] ??= <_ComponentSnapshot>[])
        .add(_ComponentSnapshot(
      productName: c.productName,
      rate: c.rate,
      rateUnit: c.rateUnit,
      sortOrder: c.sortOrder,
    ));
  }

  return [
    for (final t in treatments)
      _TreatmentSnapshot(
        code: t.code,
        name: t.name,
        treatmentType: t.treatmentType,
        armTypeCode: aamByTreatmentId[t.id]?.armTypeCode,
        formConc: aamByTreatmentId[t.id]?.formConc,
        formConcUnit: aamByTreatmentId[t.id]?.formConcUnit,
        formType: aamByTreatmentId[t.id]?.formType,
        armRowSortOrder: aamByTreatmentId[t.id]?.armRowSortOrder,
        components:
            componentsByTreatmentId[t.id] ?? const <_ComponentSnapshot>[],
      ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tempDir;
  late PathProviderPlatform savedProvider;
  late ImportArmRatingShellUseCase useCase;

  setUp(() async {
    savedProvider = PathProviderPlatform.instance;
    tempDir = await Directory.systemTemp.createTemp('import_shell_rt_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    db = AppDatabase.forTesting(NativeDatabase.memory());

    final assignmentRepo = AssignmentRepository(db);
    useCase = ImportArmRatingShellUseCase(
      db: db,
      trialRepository: TrialRepository(db),
      plotRepository: PlotRepository(db),
      treatmentRepository: TreatmentRepository(db, assignmentRepo),
      trialAssessmentRepository: TrialAssessmentRepository(db),
      assignmentRepository: assignmentRepo,
      armColumnMappingRepository: ArmColumnMappingRepository(db),
    );
  });

  tearDown(() async {
    PathProviderPlatform.instance = savedProvider;
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Treatments sheet round-trip trust anchor', () {
    test('dual-write invariant: core treatmentType equals AAM armTypeCode',
        () async {
      final result = await useCase.execute(_fixturePath);
      final trialId = result.trialId!;

      final treatments = await (db.select(db.treatments)
            ..where((t) => t.trialId.equals(trialId)))
          .get();
      final aamRows = await db.select(db.armTreatmentMetadata).get();
      final aamByTreatmentId = {for (final a in aamRows) a.treatmentId: a};

      // Every treatment in this trial must have an AAM row AND the
      // type codes on both sides must match byte-for-byte. The whole
      // point of Phase 2b's dual-write is that these stay in lockstep;
      // a later phase that starts stripping whitespace on one side but
      // not the other would silently break round-trip export.
      for (final t in treatments) {
        final aam = aamByTreatmentId[t.id];
        expect(aam, isNotNull,
            reason: 'Every treatment must have a matching AAM row '
                '(treatment code ${t.code})');
        expect(aam!.armTypeCode, t.treatmentType,
            reason:
                'Dual-write invariant broken for treatment ${t.code}: '
                'core treatmentType=${t.treatmentType} vs '
                'AAM armTypeCode=${aam.armTypeCode}');
      }
    });

    test('re-importing the same shell produces identical ARM-scoped data',
        () async {
      final first = await useCase.execute(_fixturePath);
      expect(first.success, isTrue, reason: first.errorMessage);

      // The importer rejects a second import when the shell's trial
      // name collides with an existing trial (prevents accidental
      // double-import in the field). Rename the first trial out of
      // the way so the second import can take the canonical name.
      await (db.update(db.trials)
            ..where((t) => t.id.equals(first.trialId!)))
          .write(const TrialsCompanion(
        name: Value('__round_trip_first_import__'),
      ));

      final second = await useCase.execute(_fixturePath);
      expect(second.success, isTrue, reason: second.errorMessage);
      expect(second.trialId, isNot(first.trialId),
          reason: 'Re-import must create a new trial, not mutate the old one');

      final snapA = await _snapshotTrial(db, first.trialId!);
      final snapB = await _snapshotTrial(db, second.trialId!);

      expect(snapA, hasLength(4));
      expect(snapB, equals(snapA),
          reason:
              'Two imports of the same fixture must produce identical '
              'ARM-scoped data (codes, names, type codes, formulation, '
              'sort order, components). Any diff implies hidden state '
              'or non-deterministic iteration.');
    });

    test('re-import does not mutate the first trial', () async {
      final first = await useCase.execute(_fixturePath);
      final beforeSecondImport = await _snapshotTrial(db, first.trialId!);

      await (db.update(db.trials)
            ..where((t) => t.id.equals(first.trialId!)))
          .write(const TrialsCompanion(
        name: Value('__round_trip_first_import__'),
      ));
      await useCase.execute(_fixturePath);

      final afterSecondImport = await _snapshotTrial(db, first.trialId!);
      expect(afterSecondImport, equals(beforeSecondImport),
          reason:
              'Importing a second trial must not touch the first trial\'s '
              'treatments / AAM rows / components');
    });

    test('no unexpected rows written to ARM-scoped tables', () async {
      final result = await useCase.execute(_fixturePath);
      final trialId = result.trialId!;

      final treatments = await (db.select(db.treatments)
            ..where((t) => t.trialId.equals(trialId)))
          .get();
      final treatmentIds = treatments.map((t) => t.id).toSet();

      // AAM rows: exactly one per treatment.
      final aamRows = await db.select(db.armTreatmentMetadata).get();
      expect(aamRows, hasLength(4),
          reason: 'Exactly one AAM row per parsed Treatments-sheet row');
      expect(
        aamRows.every((a) => treatmentIds.contains(a.treatmentId)),
        isTrue,
        reason: 'Every AAM row must FK to a treatment in this trial',
      );

      // Component rows: exactly three (CHK has no product).
      final components = await (db.select(db.treatmentComponents)
            ..where((c) => c.trialId.equals(trialId)))
          .get();
      expect(components, hasLength(3),
          reason:
              'Exactly three components (one per non-blank product row); '
              'CHK contributes zero');
      expect(
        components.every((c) => treatmentIds.contains(c.treatmentId)),
        isTrue,
        reason: 'Every component must FK to a treatment in this trial',
      );
    });
  });
}
