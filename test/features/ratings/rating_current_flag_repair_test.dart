// Tests for RatingRepository.repairCurrentFlagsForExport and the export-gate
// repair that runs inside ExportRepository before every export read.
//
// Two tests insert duplicate is_current=true rows for the same logical key to
// simulate flag drift that could exist on databases upgraded from pre-v77
// schemas. The v77 COALESCE unique index prevents this via normal INSERT, so
// the setup temporarily replaces it with the old null-hole form to allow the
// corrupt state to be constructed.

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/diagnostics/diagnostic_finding.dart';
import 'package:arm_field_companion/features/export/data/export_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Inserts a minimal trial + session + plot + assessment and returns their IDs.
Future<({int trialId, int sessionId, int plotPk, int assessmentId})>
    _insertFixture(AppDatabase db) async {
  final trialId = await db
      .into(db.trials)
      .insert(TrialsCompanion.insert(name: 'FlagRepairTrial'));
  final sessionId = await db.into(db.sessions).insert(
        SessionsCompanion.insert(
          trialId: trialId,
          name: 'S1',
          sessionDateLocal: '2026-05-01',
        ),
      );
  final plotPk = await db
      .into(db.plots)
      .insert(PlotsCompanion.insert(trialId: trialId, plotId: 'P1'));
  final assessmentId = await db.into(db.assessments).insert(
        AssessmentsCompanion.insert(trialId: trialId, name: 'CONTRO'),
      );
  return (
    trialId: trialId,
    sessionId: sessionId,
    plotPk: plotPk,
    assessmentId: assessmentId,
  );
}

/// Inserts a rating record with isCurrent forced to the given value.
Future<int> _insertRating(
  AppDatabase db, {
  required int trialId,
  required int plotPk,
  required int assessmentId,
  required int sessionId,
  required bool isCurrent,
  double numericValue = 10.0,
}) async {
  return db.into(db.ratingRecords).insert(
        RatingRecordsCompanion.insert(
          trialId: trialId,
          plotPk: plotPk,
          assessmentId: assessmentId,
          sessionId: sessionId,
          resultStatus: const Value('RECORDED'),
          numericValue: Value(numericValue),
          isCurrent: Value(isCurrent),
        ),
      );
}

/// Replaces the v77 COALESCE unique index with the legacy null-hole form so
/// that duplicate is_current=true rows can be inserted for the same key.
/// Used only in tests that need to simulate pre-v77 flag drift.
Future<void> _useNullHoleIndex(AppDatabase db) async {
  await db.customStatement('DROP INDEX IF EXISTS idx_rating_current');
  await db.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_rating_current ON rating_records'
      '(trial_id, plot_pk, assessment_id, session_id, sub_unit_id)'
      ' WHERE is_current = 1');
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('repairCurrentFlagsForExport', () {
    test(
      'returns a DiagnosticFinding when duplicate is_current flags are corrected',
      () async {
        final fix = await _insertFixture(db);
        await _useNullHoleIndex(db);

        // Two is_current=true rows for the same logical key — simulates drift.
        await _insertRating(db,
            trialId: fix.trialId,
            plotPk: fix.plotPk,
            assessmentId: fix.assessmentId,
            sessionId: fix.sessionId,
            isCurrent: true,
            numericValue: 5.0);
        await _insertRating(db,
            trialId: fix.trialId,
            plotPk: fix.plotPk,
            assessmentId: fix.assessmentId,
            sessionId: fix.sessionId,
            isCurrent: true,
            numericValue: 10.0);

        final ratingRepo = RatingRepository(db);
        final findings = await ratingRepo.repairCurrentFlagsForExport(
          sessionId: fix.sessionId,
        );

        expect(findings, hasLength(1));
        expect(findings.single.code, 'rating_current_flag_drift_corrected');
        expect(findings.single.severity, DiagnosticSeverity.warning);
        expect(findings.single.blocksExport, false);
        expect(findings.single.trialId, fix.trialId);
        expect(findings.single.sessionId, fix.sessionId);

        // Only one row must remain current after repair.
        final allRows = await db.select(db.ratingRecords).get();
        final currentRows = allRows
            .where((r) =>
                r.sessionId == fix.sessionId && r.isCurrent && !r.isDeleted)
            .toList();
        expect(currentRows, hasLength(1),
            reason: 'exactly one row must be current after repair');
      },
    );

    test(
      'export contains exactly one row per group after is_current flag repair',
      () async {
        final fix = await _insertFixture(db);
        await _useNullHoleIndex(db);

        // Two is_current=true rows for the same logical key.
        await _insertRating(db,
            trialId: fix.trialId,
            plotPk: fix.plotPk,
            assessmentId: fix.assessmentId,
            sessionId: fix.sessionId,
            isCurrent: true,
            numericValue: 5.0);
        await _insertRating(db,
            trialId: fix.trialId,
            plotPk: fix.plotPk,
            assessmentId: fix.assessmentId,
            sessionId: fix.sessionId,
            isCurrent: true,
            numericValue: 10.0);

        final ratingRepo = RatingRepository(db);
        final exportRepo =
            ExportRepository(db, ratingRepository: ratingRepo);

        final rows = await exportRepo.buildSessionExportRows(
          sessionId: fix.sessionId,
        );

        // Only one export row must be produced despite two is_current=true rows.
        expect(rows, hasLength(1),
            reason:
                'duplicate is_current flags must not produce duplicate export rows');
      },
    );

    test(
      'returns empty findings when no duplicate flags exist',
      () async {
        final fix = await _insertFixture(db);

        await _insertRating(db,
            trialId: fix.trialId,
            plotPk: fix.plotPk,
            assessmentId: fix.assessmentId,
            sessionId: fix.sessionId,
            isCurrent: true);

        final ratingRepo = RatingRepository(db);
        final findings = await ratingRepo.repairCurrentFlagsForExport(
          sessionId: fix.sessionId,
        );

        expect(findings, isEmpty);
      },
    );
  });
}
