import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/data/repositories/weather_snapshot_repository.dart';
import 'package:arm_field_companion/domain/ratings/rating_integrity_guard.dart';
import 'package:arm_field_companion/features/export/export_format.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/ratings/usecases/save_rating_usecase.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../support/session_date_test_utils.dart';
import 'stress_import_helpers.dart';

String _stressCsv(String trailingHeaderCols, List<String> dataRows) {
  return 'Plot No.,trt,reps,$trailingHeaderCols\n${dataRows.join('\n')}';
}

/// Mirrors [ExportTrialUseCase] weather filtering for active (non-deleted) sessions.
List<WeatherSnapshot> stressActiveWeatherForExport({
  required List<Session> activeSessions,
  required List<WeatherSnapshot> allWeather,
}) {
  final sessionById = {for (final s in activeSessions) s.id: s};
  return allWeather.where((w) {
    if (w.parentType == kWeatherParentTypeRatingSession) {
      return sessionById[w.parentId] != null;
    }
    return true;
  }).toList();
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.ensureAssessmentDefinitionsSeeded();
  });

  tearDown(() async {
    await db.close();
  });

  group('stress export', () {
    test('10 partial ratings: sparse columns export without crash', () async {
      final u = DateTime.now().microsecondsSinceEpoch;
      final dataRows = List.generate(16, (i) {
        final plot = 101 + i;
        final a1 = i < 8 ? '${10 + i}' : '';
        return '$plot,1,1,$a1,';
      });
      final csv = _stressCsv(
        'AVEFA 1-Jul-26 CONTRO %,AVEFA 2-Jul-26 PHYGEN %',
        dataRows,
      );
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'partial_$u.csv');
      expect(r.success, isTrue);
      final tid = r.trialId!;
      final trial = await (db.select(db.trials)..where((t) => t.id.equals(tid)))
          .getSingle();
      final bundle =
          await exportStressTrialUseCase(db).execute(trial: trial, format: ExportFormat.flatCsv);

      final table = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(bundle.observationsCsv);
      expect(table.length, greaterThan(1));
      final header = table.first.map((c) => c.toString()).toList();
      final nameIdx = header.indexOf('assessment_name');
      final valueIdx = header.indexOf('value');
      expect(nameIdx, greaterThanOrEqualTo(0));
      expect(valueIdx, greaterThanOrEqualTo(0));
      final dataRowsOut = table.skip(1).toList();
      expect(dataRowsOut.length, 8);
      final phygen = dataRowsOut
          .where((row) => row.length > nameIdx && row[nameIdx].toString().contains('PHYGEN'))
          .toList();
      expect(phygen, isEmpty);
      expect(
        dataRowsOut.every((row) => row[valueIdx].toString().trim().isNotEmpty),
        isTrue,
      );
    });

    test('14 voided session excluded from export observations and weather filter',
        () async {
      final u = DateTime.now().microsecondsSinceEpoch;
      const csv = 'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %\n101,1,1,9\n';
      final imp = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'voided_$u.csv');
      expect(imp.success, isTrue);
      final tid = imp.trialId!;
      final s1 = imp.importSessionId!;

      final weatherRepo = WeatherSnapshotRepository(db);
      final now = DateTime.now().millisecondsSinceEpoch;
      await weatherRepo.upsertWeatherSnapshot(
        WeatherSnapshotsCompanion.insert(
          uuid: const Uuid().v4(),
          trialId: tid,
          parentId: s1,
          recordedAt: now,
          createdAt: now,
          modifiedAt: now,
          createdBy: 'stress_test',
        ),
      );

      await SessionRepository(db).softDeleteSession(s1, deletedBy: 'test');

      final taRepo = TrialAssessmentRepository(db);
      final trialTas = await taRepo.getForTrial(tid);
      final assessmentIds = trialTas
          .map((t) => t.legacyAssessmentId)
          .whereType<int>()
          .toList();
      expect(assessmentIds, isNotEmpty);

      final s2 = await SessionRepository(db).createSession(
        trialId: tid,
        name: 'Field A',
        sessionDateLocal: await sessionDateLocalValidForTrial(db, tid),
        assessmentIds: assessmentIds,
      );

      final plot = await (db.select(db.plots)..where((p) => p.trialId.equals(tid)))
          .getSingle();
      final save = SaveRatingUseCase(
        RatingRepository(db),
        RatingIntegrityGuard(
          PlotRepository(db),
          SessionRepository(db),
          TreatmentRepository(db, AssignmentRepository(db)),
        ),
      );
      final res = await save.execute(
        SaveRatingInput(
          trialId: tid,
          plotPk: plot.id,
          assessmentId: assessmentIds.first,
          sessionId: s2.id,
          resultStatus: 'RECORDED',
          numericValue: 42.0,
          textValue: null,
          isSessionClosed: false,
        ),
      );
      expect(res.isSuccess, isTrue);

      final trial = await (db.select(db.trials)..where((t) => t.id.equals(tid)))
          .getSingle();
      final bundle =
          await exportStressTrialUseCase(db).execute(trial: trial, format: ExportFormat.flatCsv);

      final table = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(bundle.observationsCsv);
      final header = table.first.map((c) => c.toString()).toList();
      final valueIdx = header.indexOf('value');
      final values =
          table.skip(1).map((row) => row[valueIdx].toString().trim()).toList();
      expect(values.any((v) => v.startsWith('42')), isTrue);
      expect(values.any((v) => v == '9'), isFalse);

      final activeSessions = await SessionRepository(db).getSessionsForTrial(tid);
      expect(activeSessions.length, 1);
      expect(activeSessions.single.id, s2.id);

      final allW = await weatherRepo.getWeatherSnapshotsForTrial(tid);
      final activeW = stressActiveWeatherForExport(
        activeSessions: activeSessions,
        allWeather: allW,
      );
      expect(activeW, isEmpty);
    });

    test('15 second save shows 55 in export; prior 50 remains in chain', () async {
      final u = DateTime.now().microsecondsSinceEpoch;
      const csv = 'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %\n101,1,1,50\n';
      final imp = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'amend_$u.csv');
      expect(imp.success, isTrue);
      final tid = imp.trialId!;
      final sid = imp.importSessionId!;
      final plot = await (db.select(db.plots)..where((p) => p.trialId.equals(tid)))
          .getSingle();

      final first = await (db.select(db.ratingRecords)
            ..where((rr) =>
                rr.trialId.equals(tid) &
                rr.sessionId.equals(sid) &
                rr.plotPk.equals(plot.id) &
                rr.isCurrent.equals(true)))
          .getSingle();
      final assessmentId = first.assessmentId;

      final save = SaveRatingUseCase(
        RatingRepository(db),
        RatingIntegrityGuard(
          PlotRepository(db),
          SessionRepository(db),
          TreatmentRepository(db, AssignmentRepository(db)),
        ),
      );
      final second = await save.execute(
        SaveRatingInput(
          trialId: tid,
          plotPk: plot.id,
          assessmentId: assessmentId,
          sessionId: sid,
          resultStatus: 'RECORDED',
          numericValue: 55.0,
          textValue: null,
          isSessionClosed: false,
        ),
      );
      expect(second.isSuccess, isTrue);

      final chain = await (db.select(db.ratingRecords)
            ..where((r) => r.sessionId.equals(sid) & r.plotPk.equals(plot.id)))
          .get();
      expect(chain.length, 2);
      expect(chain.where((r) => r.isCurrent).single.numericValue, 55.0);
      expect(chain.where((r) => !r.isCurrent).single.numericValue, 50.0);

      final trial = await (db.select(db.trials)..where((t) => t.id.equals(tid)))
          .getSingle();
      final bundle =
          await exportStressTrialUseCase(db).execute(trial: trial, format: ExportFormat.flatCsv);
      final table = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(bundle.observationsCsv);
      final header = table.first.map((c) => c.toString()).toList();
      final valueIdx = header.indexOf('value');
      final row = table.skip(1).single;
      expect(row[valueIdx].toString().trim(), anyOf('55', '55.0'));
    });
  });
}
