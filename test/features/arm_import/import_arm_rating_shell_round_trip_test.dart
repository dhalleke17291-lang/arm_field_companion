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
// Phase 3e — Applications-sheet round-trip trust anchor (same goals as
// Treatments above, for `trial_application_events` + `arm_applications`).

import 'dart:io';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/arm/arm_applications_repository.dart';
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

import '../export/export_arm_rating_shell_usecase_test.dart'
    show writeArmShellFixture;

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

List<String?> _verbatimArmRows(ArmApplication a) {
  return [
    a.row01,
    a.row02,
    a.row03,
    a.row04,
    a.row05,
    a.row06,
    a.row07,
    a.row08,
    a.row09,
    a.row10,
    a.row11,
    a.row12,
    a.row13,
    a.row14,
    a.row15,
    a.row16,
    a.row17,
    a.row18,
    a.row19,
    a.row20,
    a.row21,
    a.row22,
    a.row23,
    a.row24,
    a.row25,
    a.row26,
    a.row27,
    a.row28,
    a.row29,
    a.row30,
    a.row31,
    a.row32,
    a.row33,
    a.row34,
    a.row35,
    a.row36,
    a.row37,
    a.row38,
    a.row39,
    a.row40,
    a.row41,
    a.row42,
    a.row43,
    a.row44,
    a.row45,
    a.row46,
    a.row47,
    a.row48,
    a.row49,
    a.row50,
    a.row51,
    a.row52,
    a.row53,
    a.row54,
    a.row55,
    a.row56,
    a.row57,
    a.row58,
    a.row59,
    a.row60,
    a.row61,
    a.row62,
    a.row63,
    a.row64,
    a.row65,
    a.row66,
    a.row67,
    a.row68,
    a.row69,
    a.row70,
    a.row71,
    a.row72,
    a.row73,
    a.row74,
    a.row75,
    a.row76,
    a.row77,
    a.row78,
    a.row79,
  ];
}

bool _strEq(String? a, String? b) => (a ?? '') == (b ?? '');

bool _dblEq(double? a, double? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return (a - b).abs() < 1e-9;
}

bool _rowListEq(List<String?> a, List<String?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _ymdUtc(DateTime d) {
  final u = d.toUtc();
  return '${u.year.toString().padLeft(4, '0')}-'
      '${u.month.toString().padLeft(2, '0')}-'
      '${u.day.toString().padLeft(2, '0')}';
}

/// Normalised Applications import snapshot (ignores event UUID, `id`,
/// `createdAt`, `lastEditedAt`).
class _ApplicationSnapshot {
  const _ApplicationSnapshot({
    required this.armSheetColumnIndex,
    required this.applicationDateYyyyMmDdUtc,
    required this.applicationTime,
    required this.applicationMethod,
    required this.operatorName,
    required this.equipmentUsed,
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.cloudCoverPct,
    required this.soilMoisture,
    required this.soilTemperature,
    required this.nozzleType,
    required this.operatingPressure,
    required this.pressureUnit,
    required this.groundSpeed,
    required this.speedUnit,
    required this.waterVolume,
    required this.waterVolumeUnit,
    required this.spraySolutionPh,
    required this.verbatimRows,
  });

  final int? armSheetColumnIndex;
  final String applicationDateYyyyMmDdUtc;
  final String? applicationTime;
  final String? applicationMethod;
  final String? operatorName;
  final String? equipmentUsed;
  final double? temperature;
  final double? humidity;
  final double? windSpeed;
  final String? windDirection;
  final double? cloudCoverPct;
  final String? soilMoisture;
  final double? soilTemperature;
  final String? nozzleType;
  final double? operatingPressure;
  final String? pressureUnit;
  final double? groundSpeed;
  final String? speedUnit;
  final double? waterVolume;
  final String? waterVolumeUnit;
  final double? spraySolutionPh;
  final List<String?> verbatimRows;

  factory _ApplicationSnapshot.fromJoined(ArmSheetApplicationRow row) {
    final e = row.event;
    final a = row.arm;
    return _ApplicationSnapshot(
      armSheetColumnIndex: a.armSheetColumnIndex,
      applicationDateYyyyMmDdUtc: _ymdUtc(e.applicationDate),
      applicationTime: e.applicationTime,
      applicationMethod: e.applicationMethod,
      operatorName: e.operatorName,
      equipmentUsed: e.equipmentUsed,
      temperature: e.temperature,
      humidity: e.humidity,
      windSpeed: e.windSpeed,
      windDirection: e.windDirection,
      cloudCoverPct: e.cloudCoverPct,
      soilMoisture: e.soilMoisture,
      soilTemperature: e.soilTemperature,
      nozzleType: e.nozzleType,
      operatingPressure: e.operatingPressure,
      pressureUnit: e.pressureUnit,
      groundSpeed: e.groundSpeed,
      speedUnit: e.speedUnit,
      waterVolume: e.waterVolume,
      waterVolumeUnit: e.waterVolumeUnit,
      spraySolutionPh: e.spraySolutionPh,
      verbatimRows: _verbatimArmRows(a),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _ApplicationSnapshot &&
      other.armSheetColumnIndex == armSheetColumnIndex &&
      other.applicationDateYyyyMmDdUtc == applicationDateYyyyMmDdUtc &&
      _strEq(other.applicationTime, applicationTime) &&
      _strEq(other.applicationMethod, applicationMethod) &&
      _strEq(other.operatorName, operatorName) &&
      _strEq(other.equipmentUsed, equipmentUsed) &&
      _dblEq(other.temperature, temperature) &&
      _dblEq(other.humidity, humidity) &&
      _dblEq(other.windSpeed, windSpeed) &&
      _strEq(other.windDirection, windDirection) &&
      _dblEq(other.cloudCoverPct, cloudCoverPct) &&
      _strEq(other.soilMoisture, soilMoisture) &&
      _dblEq(other.soilTemperature, soilTemperature) &&
      _strEq(other.nozzleType, nozzleType) &&
      _dblEq(other.operatingPressure, operatingPressure) &&
      _strEq(other.pressureUnit, pressureUnit) &&
      _dblEq(other.groundSpeed, groundSpeed) &&
      _strEq(other.speedUnit, speedUnit) &&
      _dblEq(other.waterVolume, waterVolume) &&
      _strEq(other.waterVolumeUnit, waterVolumeUnit) &&
      _dblEq(other.spraySolutionPh, spraySolutionPh) &&
      _rowListEq(other.verbatimRows, verbatimRows);

  @override
  int get hashCode => Object.hash(
        armSheetColumnIndex,
        applicationDateYyyyMmDdUtc,
        applicationTime,
        applicationMethod,
        verbatimRows.length,
      );

  @override
  String toString() => 'ApplicationSnapshot(col=$armSheetColumnIndex, '
      'date=$applicationDateYyyyMmDdUtc)';
}

Future<List<_ApplicationSnapshot>> _snapshotApplications(
  ArmApplicationsRepository repo,
  int trialId,
) async {
  final joined = await repo.getArmSheetApplicationsForTrial(trialId);
  return [
    for (final row in joined) _ApplicationSnapshot.fromJoined(row),
  ];
}

/// Two application columns with overlapping dual-write fields populated.
List<List<String?>> _applicationsSheetFixture() {
  List<String?> full({
    required String date,
    String? timing,
  }) {
    final r = List<String?>.filled(79, null);
    r[0] = date;
    r[1] = '08:30';
    r[5] = 'BROADCAST';
    r[6] = timing;
    r[8] = 'J.D.';
    r[9] = '22.5';
    r[12] = '55';
    r[14] = '12';
    r[17] = 'NW';
    r[22] = '18';
    r[24] = 'MOIST';
    r[26] = '40';
    r[35] = 'Tractor';
    r[36] = 'Boom';
    r[37] = '3.2';
    r[38] = 'bar';
    r[39] = 'TTI8003';
    r[62] = '8';
    r[63] = 'km/h';
    r[70] = '200';
    r[71] = 'L/ha';
    r[76] = '6.8';
    return r;
  }

  return [
    full(date: '15-Jun-26', timing: 'A1'),
    full(date: '20-Jun-26', timing: 'AA'),
  ];
}

Future<String> _writeShellWithApplications(String tempDir) {
  return writeArmShellFixture(
    tempDir,
    plotNumbers: const [101],
    armColumnIds: const ['3'],
    seNames: const ['W003'],
    ratingDates: const ['1-Jul-26'],
    ratingTypes: const ['CONTRO'],
    applicationSheetColumns: _applicationsSheetFixture(),
  );
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
      armApplicationsRepository: ArmApplicationsRepository(db),
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

  group('Applications sheet round-trip trust anchor', () {
    test('dual-write invariant: core fields match Applications-sheet slots',
        () async {
      final path = await _writeShellWithApplications(tempDir.path);
      final result = await useCase.execute(path);
      expect(result.success, isTrue, reason: result.errorMessage);

      final repo = ArmApplicationsRepository(db);
      final rows = await repo.getArmSheetApplicationsForTrial(result.trialId!);

      for (final row in rows) {
        final e = row.event;
        final a = row.arm;
        expect(e.applicationMethod, a.row06);
        expect(e.applicationTime, a.row02);
        expect(e.operatorName, a.row09);
        expect(e.windDirection, a.row18);
        expect(e.soilMoisture, a.row25);
        expect(e.nozzleType, a.row40);
        expect(e.pressureUnit, a.row39);
        expect(e.speedUnit, a.row64);
        expect(e.waterVolumeUnit, a.row72);
        expect(e.temperature, double.tryParse(a.row10 ?? ''));
        expect(e.humidity, double.tryParse(a.row13 ?? ''));
        expect(e.windSpeed, double.tryParse(a.row15 ?? ''));
        expect(e.soilTemperature, double.tryParse(a.row23 ?? ''));
        expect(e.cloudCoverPct, double.tryParse(a.row27 ?? ''));
        expect(e.operatingPressure, double.tryParse(a.row38 ?? ''));
        expect(e.groundSpeed, double.tryParse(a.row63 ?? ''));
        expect(e.waterVolume, double.tryParse(a.row71 ?? ''));
        expect(e.spraySolutionPh, double.tryParse(a.row77 ?? ''));
        // R36–R37 (Excel rows 36–37) → `row36` / `row37`; importer joins these
        // for [TrialApplicationEvents.equipmentUsed].
        final equip = [a.row36, a.row37]
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .join(' / ');
        expect(e.equipmentUsed, equip.isEmpty ? null : equip);
      }
    });

    test('re-importing the same shell produces identical application snapshots',
        () async {
      final path = await _writeShellWithApplications(tempDir.path);
      final first = await useCase.execute(path);
      expect(first.success, isTrue, reason: first.errorMessage);

      await (db.update(db.trials)..where((t) => t.id.equals(first.trialId!)))
          .write(const TrialsCompanion(
        name: Value('__round_trip_app_first__'),
      ));

      final second = await useCase.execute(path);
      expect(second.success, isTrue, reason: second.errorMessage);
      expect(second.trialId, isNot(first.trialId));

      final repo = ArmApplicationsRepository(db);
      final snapA = await _snapshotApplications(repo, first.trialId!);
      final snapB = await _snapshotApplications(repo, second.trialId!);
      expect(snapA, hasLength(2));
      expect(snapB, equals(snapA),
          reason:
              'Two imports of the same Applications fixture must produce '
              'identical dual-write + verbatim row data.');
    });

    test('re-import does not mutate the first trial application data',
        () async {
      final path = await _writeShellWithApplications(tempDir.path);
      final first = await useCase.execute(path);
      final repo = ArmApplicationsRepository(db);
      final before = await _snapshotApplications(repo, first.trialId!);

      await (db.update(db.trials)..where((t) => t.id.equals(first.trialId!)))
          .write(const TrialsCompanion(name: Value('__round_trip_app_first__')));
      await useCase.execute(path);

      final after = await _snapshotApplications(repo, first.trialId!);
      expect(after, equals(before),
          reason:
              'Second import must not change the first trial\'s application '
              'events / arm_applications');
    });

    test('only expected application + arm_applications rows for trial',
        () async {
      final path = await _writeShellWithApplications(tempDir.path);
      final result = await useCase.execute(path);
      final trialId = result.trialId!;

      final events = await (db.select(db.trialApplicationEvents)
            ..where((e) => e.trialId.equals(trialId)))
          .get();
      expect(events, hasLength(2));

      final repo = ArmApplicationsRepository(db);
      final joined = await repo.getArmSheetApplicationsForTrial(trialId);
      expect(joined, hasLength(2));

      final eventIds = events.map((e) => e.id).toSet();
      for (final row in joined) {
        expect(eventIds.contains(row.arm.trialApplicationEventId), isTrue);
      }
    });
  });
}
