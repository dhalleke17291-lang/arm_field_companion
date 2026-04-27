import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/features/export/export_trial_ratings_share_usecase.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../stress/stress_import_helpers.dart';

/// Unit tests for the trial-wide ratings share (CSV + TSV).
///
/// Covers:
/// - Pure TSV writer: tab join, newline/tab sanitization in values
/// - Integration with real repositories against an in-memory Drift DB
/// - Schema stability (header row matches the spec)
/// - Safety under values that would break naive CSV writers
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.ensureAssessmentDefinitionsSeeded();
  });

  tearDown(() async {
    await db.close();
  });

  ExportTrialRatingsShareUsecase makeUsecase() => ExportTrialRatingsShareUsecase(
        sessionRepository: SessionRepository(db),
        ratingRepository: RatingRepository(db),
        plotRepository: PlotRepository(db),
        treatmentRepository: TreatmentRepository(db, AssignmentRepository(db)),
        assignmentRepository: AssignmentRepository(db),
      );

  group('buildTsvString (pure)', () {
    test('joins cells with tabs and terminates rows with newline', () {
      final out = ExportTrialRatingsShareUsecase.buildTsvString(
        ['a', 'b', 'c'],
        [
          ['1', '2', '3'],
          ['4', '5', '6'],
        ],
      );
      expect(out, 'a\tb\tc\n1\t2\t3\n4\t5\t6\n');
    });

    test('replaces tabs and newlines inside cells with spaces', () {
      final out = ExportTrialRatingsShareUsecase.buildTsvString(
        ['note'],
        [
          ['has\ttab and\nnewline here'],
        ],
      );
      expect(out, 'note\nhas tab and newline here\n');
    });

    test('preserves commas and quotes (TSV does not need to escape those)',
        () {
      final out = ExportTrialRatingsShareUsecase.buildTsvString(
        ['raw'],
        [
          ['value, with "quote"'],
        ],
      );
      expect(out, contains('value, with "quote"'));
    });
  });

  group('buildCsv (integration with in-memory DB)', () {
    test('emits expected header row and at least one data row', () async {
      const csv =
          'Plot No.,trt,reps,WEED1 1-Jul-26 CONTRO %\n101,1,1,40\n102,2,1,70\n';
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'ratings_share_test.csv');
      expect(r.success, isTrue);

      final trial = await (db.select(db.trials)
            ..where((t) => t.id.equals(r.trialId!)))
          .getSingle();

      final out = await makeUsecase().buildCsv(trial);

      // UTF-8 BOM so Excel opens it correctly
      expect(out.codeUnitAt(0), 0xFEFF);

      // Header row matches the declared schema
      final headerLine = out
          .replaceFirst('\uFEFF', '')
          .split('\n')
          .first;
      expect(headerLine, ExportTrialRatingsShareUsecase.headers.join(','));

      // At least one data row with the trial name and a numeric value
      expect(out, contains(trial.name));
      expect(out.split('\n').where((l) => l.contains(trial.name)).length,
          greaterThanOrEqualTo(1));
    });

    test('emits one row per rating across sessions', () async {
      const csv =
          'Plot No.,trt,reps,WEED1 1-Jul-26 CONTRO %\n101,1,1,40\n102,2,1,70\n103,1,2,45\n104,2,2,75\n';
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'ratings_rowcount.csv');
      final trial = await (db.select(db.trials)
            ..where((t) => t.id.equals(r.trialId!)))
          .getSingle();

      final out = await makeUsecase().buildCsv(trial);
      // Header + BOM line + 4 data rows + trailing newline -> 5 non-empty lines
      final lines = out
          .replaceFirst('\uFEFF', '')
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines.length, 5);
    });
  });

  group('buildTsv (integration with in-memory DB)', () {
    test('emits tab-delimited output with no BOM', () async {
      const csv =
          'Plot No.,trt,reps,WEED1 1-Jul-26 CONTRO %\n101,1,1,40\n102,2,1,70\n';
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'ratings_tsv.csv');
      final trial = await (db.select(db.trials)
            ..where((t) => t.id.equals(r.trialId!)))
          .getSingle();

      final out = await makeUsecase().buildTsv(trial);

      // No BOM on clipboard text
      expect(out.codeUnitAt(0), isNot(0xFEFF));

      // Header is tab-joined
      final headerLine = out.split('\n').first;
      expect(headerLine,
          ExportTrialRatingsShareUsecase.headers.join('\t'));

      // Tabs appear on every data line
      final dataLines = out
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .skip(1)
          .toList();
      expect(dataLines.length, greaterThanOrEqualTo(1));
      for (final line in dataLines) {
        expect(line.split('\t').length,
            ExportTrialRatingsShareUsecase.headers.length);
      }
    });
  });
}
