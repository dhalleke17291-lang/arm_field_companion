import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/relationships/trial_data_integrity_provider.dart';
import 'package:arm_field_companion/features/diagnostics/integrity_check_result.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer(AppDatabase db) => ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

Future<int> _createTrial(AppDatabase db) =>
    db.into(db.trials).insert(TrialsCompanion.insert(name: 'T'));

Future<int> _createTreatment(AppDatabase db, int trialId) =>
    db.into(db.treatments).insert(
          TreatmentsCompanion.insert(trialId: trialId, code: 'TRT', name: 'Trt'),
        );

Future<int> _createPlot(AppDatabase db, int trialId, {int? treatmentId}) =>
    db.into(db.plots).insert(
          PlotsCompanion.insert(
            trialId: trialId,
            plotId: 'P${DateTime.now().microsecondsSinceEpoch}',
            treatmentId: Value(treatmentId),
          ),
        );

Future<int> _createAssignment(
  AppDatabase db,
  int trialId,
  int plotId, {
  int? treatmentId,
}) =>
    db.into(db.assignments).insert(
          AssignmentsCompanion.insert(
            trialId: trialId,
            plotId: plotId,
            treatmentId: Value(treatmentId),
          ),
        );

Future<int> _createSession(
  AppDatabase db,
  int trialId, {
  DateTime? endedAt,
  int? createdByUserId,
}) =>
    db.into(db.sessions).insert(
          SessionsCompanion.insert(
            trialId: trialId,
            name: 'S',
            sessionDateLocal: '2026-06-01',
            endedAt: Value(endedAt),
            createdByUserId: Value(createdByUserId),
          ),
        );

Future<int> _createAssessment(AppDatabase db, int trialId) =>
    db.into(db.assessments).insert(
          AssessmentsCompanion.insert(trialId: trialId, name: 'A'),
        );

Future<int> _createRating(
  AppDatabase db,
  int trialId,
  int plotPk,
  int assessmentId,
  int sessionId, {
  bool isCurrent = true,
  bool isDeleted = false,
  String? createdAppVersion,
  int? subUnitId,
}) =>
    db.into(db.ratingRecords).insert(
          RatingRecordsCompanion.insert(
            trialId: trialId,
            plotPk: plotPk,
            assessmentId: assessmentId,
            sessionId: sessionId,
            isCurrent: Value(isCurrent),
            isDeleted: Value(isDeleted),
            createdAppVersion: Value(createdAppVersion),
            subUnitId: Value(subUnitId),
          ),
        );

Future<void> _createCorrection(
  AppDatabase db,
  int ratingId, {
  String reason = 'typo',
  int? correctedByUserId,
}) =>
    db.into(db.ratingCorrections).insert(
          RatingCorrectionsCompanion.insert(
            ratingId: ratingId,
            oldResultStatus: 'RECORDED',
            newResultStatus: 'RECORDED',
            reason: reason,
            correctedByUserId: Value(correctedByUserId),
          ),
        );

// Drops the partial unique index that prevents duplicate is_current=1 rows.
// Use in duplicate_current_ratings tests to simulate historical corruption.
Future<void> _allowDuplicateCurrentRatings(AppDatabase db) =>
    db.customStatement('DROP INDEX IF EXISTS idx_rating_current');

Future<void> _createSessionAssessment(
  AppDatabase db,
  int sessionId,
  int assessmentId,
) =>
    db.into(db.sessionAssessments).insert(
          SessionAssessmentsCompanion.insert(
            sessionId: sessionId,
            assessmentId: assessmentId,
          ),
        );

Future<TrialIntegrityState> _run(ProviderContainer c, int trialId) =>
    c.read(trialDataIntegrityProvider(trialId).future);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = _makeContainer(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // ── TrialIntegrityState helpers ───────────────────────────────────────────

  group('TrialIntegrityState.summaryText', () {
    test('returns "clean" when issues is empty', () {
      const state = TrialIntegrityState(issues: []);
      expect(state.summaryText, 'clean');
    });

    test('returns named format for single issue type', () {
      const state = TrialIntegrityState(issues: [
        IntegrityIssue(
          code: 'duplicate_current_ratings',
          summary: 'Duplicate current rating rows',
          count: 3,
        ),
      ]);
      expect(state.summaryText, '3 duplicate ratings');
    });

    test('uses singular label when count is 1', () {
      const state = TrialIntegrityState(issues: [
        IntegrityIssue(
          code: 'duplicate_current_ratings',
          summary: 'Duplicate current rating rows',
          count: 1,
        ),
      ]);
      expect(state.summaryText, '1 duplicate rating');
    });

    test('returns "N issues found" for multiple issue types', () {
      const state = TrialIntegrityState(issues: [
        IntegrityIssue(
          code: 'duplicate_current_ratings',
          summary: 'Duplicates',
          count: 2,
        ),
        IntegrityIssue(
          code: 'trials_with_no_plots',
          summary: 'No plots',
          count: 1,
        ),
      ]);
      expect(state.summaryText, '2 issues found');
    });

    test('isClean true when empty', () {
      expect(const TrialIntegrityState(issues: []).isClean, true);
    });

    test('hasRepairableIssues true when any issue is repairable', () {
      const state = TrialIntegrityState(issues: [
        IntegrityIssue(
          code: 'duplicate_current_ratings',
          summary: 'x',
          count: 1,
          isRepairable: true,
        ),
      ]);
      expect(state.hasRepairableIssues, true);
    });

    test('hasRepairableIssues false when no issue is repairable', () {
      const state = TrialIntegrityState(issues: [
        IntegrityIssue(
          code: 'trials_with_no_plots',
          summary: 'x',
          count: 1,
        ),
      ]);
      expect(state.hasRepairableIssues, false);
    });
  });

  // ── sessions_without_creator ──────────────────────────────────────────────

  group('sessions_without_creator', () {
    test('clean when all ended sessions have a creator', () async {
      final trialId = await _createTrial(db);
      await _createSession(db, trialId,
          endedAt: DateTime.now(), createdByUserId: null);
      // Give it a user — but wait, createdByUserId references Users table.
      // Insert a user first so we can reference it.
      final userId = await db
          .into(db.users)
          .insert(UsersCompanion.insert(displayName: 'U'));
      await _createSession(db, trialId,
          endedAt: DateTime.now(), createdByUserId: userId);

      // Only the second session (with user) should be clean; the first has no user.
      // Reset and use only sessions with users.
      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      final c2 = _makeContainer(db2);
      addTearDown(() async {
        c2.dispose();
        await db2.close();
      });
      final tid = await _createTrial(db2);
      final uid = await db2
          .into(db2.users)
          .insert(UsersCompanion.insert(displayName: 'U'));
      await _createSession(db2, tid,
          endedAt: DateTime.now(), createdByUserId: uid);

      final result = await _run(c2, tid);
      expect(
        result.issues.where((i) => i.code == 'sessions_without_creator'),
        isEmpty,
      );
    });

    test('issue detected when ended session has no creator', () async {
      final trialId = await _createTrial(db);
      await _createSession(db, trialId, endedAt: DateTime.now());

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'sessions_without_creator'),
        isTrue,
      );
    });

    test('isRepairable is false for sessions_without_creator', () async {
      final trialId = await _createTrial(db);
      await _createSession(db, trialId, endedAt: DateTime.now());

      final result = await _run(container, trialId);
      final issue =
          result.issues.firstWhere((i) => i.code == 'sessions_without_creator');
      expect(issue.isRepairable, false);
    });

    test('open sessions without creator do not trigger issue', () async {
      final trialId = await _createTrial(db);
      // endedAt is null — open session, should not be counted
      await _createSession(db, trialId);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'sessions_without_creator'),
        isFalse,
      );
    });

    test('sessions in other trials are not counted', () async {
      final trialId = await _createTrial(db);
      final otherTrial = await _createTrial(db);
      await _createSession(db, otherTrial, endedAt: DateTime.now());

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'sessions_without_creator'),
        isFalse,
      );
    });
  });

  // ── plots_without_treatment ───────────────────────────────────────────────

  group('plots_without_treatment', () {
    test('clean when all plots have treatment via Plot.treatmentId', () async {
      final trialId = await _createTrial(db);
      final trtId = await _createTreatment(db, trialId);
      await _createPlot(db, trialId, treatmentId: trtId);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'plots_without_treatment'),
        isFalse,
      );
    });

    test('clean when all plots have treatment via Assignment', () async {
      final trialId = await _createTrial(db);
      final trtId = await _createTreatment(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      await _createAssignment(db, trialId, plotPk, treatmentId: trtId);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'plots_without_treatment'),
        isFalse,
      );
    });

    test('issue detected when plot has no treatment', () async {
      final trialId = await _createTrial(db);
      await _createPlot(db, trialId);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'plots_without_treatment'),
        isTrue,
      );
    });

    test('isRepairable is false for plots_without_treatment', () async {
      final trialId = await _createTrial(db);
      await _createPlot(db, trialId);

      final result = await _run(container, trialId);
      final issue =
          result.issues.firstWhere((i) => i.code == 'plots_without_treatment');
      expect(issue.isRepairable, false);
    });
  });

  // ── closed_sessions_no_ratings ────────────────────────────────────────────

  group('closed_sessions_no_ratings', () {
    test('clean when closed session has at least one current rating', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, endedAt: DateTime.now());
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      await _createRating(db, trialId, plotPk, assessmentId, sessionId);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'closed_sessions_no_ratings'),
        isFalse,
      );
    });

    test('issue detected when closed session has zero current ratings', () async {
      final trialId = await _createTrial(db);
      await _createSession(db, trialId, endedAt: DateTime.now());

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'closed_sessions_no_ratings'),
        isTrue,
      );
    });

    test('isRepairable is false for closed_sessions_no_ratings', () async {
      final trialId = await _createTrial(db);
      await _createSession(db, trialId, endedAt: DateTime.now());

      final result = await _run(container, trialId);
      final issue = result.issues
          .firstWhere((i) => i.code == 'closed_sessions_no_ratings');
      expect(issue.isRepairable, false);
    });

    test('open session with no ratings does not trigger issue', () async {
      final trialId = await _createTrial(db);
      await _createSession(db, trialId);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'closed_sessions_no_ratings'),
        isFalse,
      );
    });
  });

  // ── corrections_missing_reason ────────────────────────────────────────────

  group('corrections_missing_reason', () {
    test('clean when all corrections have a reason', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      final ratingId =
          await _createRating(db, trialId, plotPk, assessmentId, sessionId);
      await _createCorrection(db, ratingId, reason: 'typo');

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'corrections_missing_reason'),
        isFalse,
      );
    });

    test('issue detected when correction has empty reason', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      final ratingId =
          await _createRating(db, trialId, plotPk, assessmentId, sessionId);
      await _createCorrection(db, ratingId, reason: '');

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'corrections_missing_reason'),
        isTrue,
      );
    });

    test('isRepairable is false for corrections_missing_reason', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      final ratingId =
          await _createRating(db, trialId, plotPk, assessmentId, sessionId);
      await _createCorrection(db, ratingId, reason: '');

      final result = await _run(container, trialId);
      final issue = result.issues
          .firstWhere((i) => i.code == 'corrections_missing_reason');
      expect(issue.isRepairable, false);
    });

    test('corrections on other trials are not counted', () async {
      final trialId = await _createTrial(db);
      final otherTrial = await _createTrial(db);
      final sessionId = await _createSession(db, otherTrial);
      final plotPk = await _createPlot(db, otherTrial);
      final assessmentId = await _createAssessment(db, otherTrial);
      final ratingId = await _createRating(
          db, otherTrial, plotPk, assessmentId, sessionId);
      await _createCorrection(db, ratingId, reason: '');

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'corrections_missing_reason'),
        isFalse,
      );
    });
  });

  // ── corrections_missing_corrected_by ─────────────────────────────────────

  group('corrections_missing_corrected_by', () {
    test('clean when all corrections have correctedByUserId', () async {
      final trialId = await _createTrial(db);
      final userId = await db
          .into(db.users)
          .insert(UsersCompanion.insert(displayName: 'U'));
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      final ratingId =
          await _createRating(db, trialId, plotPk, assessmentId, sessionId);
      await _createCorrection(db, ratingId, correctedByUserId: userId);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'corrections_missing_corrected_by'),
        isFalse,
      );
    });

    test('issue detected when correction has null correctedByUserId', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      final ratingId =
          await _createRating(db, trialId, plotPk, assessmentId, sessionId);
      await _createCorrection(db, ratingId);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'corrections_missing_corrected_by'),
        isTrue,
      );
    });

    test('isRepairable is false for corrections_missing_corrected_by', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      final ratingId =
          await _createRating(db, trialId, plotPk, assessmentId, sessionId);
      await _createCorrection(db, ratingId);

      final result = await _run(container, trialId);
      final issue = result.issues
          .firstWhere((i) => i.code == 'corrections_missing_corrected_by');
      expect(issue.isRepairable, false);
    });
  });

  // ── ratings_missing_provenance ────────────────────────────────────────────

  group('ratings_missing_provenance', () {
    test('clean when all current live ratings have createdAppVersion', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      await _createRating(db, trialId, plotPk, assessmentId, sessionId,
          createdAppVersion: '1.0.0');

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'ratings_missing_provenance'),
        isFalse,
      );
    });

    test('issue detected when current live rating has null createdAppVersion',
        () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      await _createRating(db, trialId, plotPk, assessmentId, sessionId);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'ratings_missing_provenance'),
        isTrue,
      );
    });

    test('isRepairable is false for ratings_missing_provenance', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      await _createRating(db, trialId, plotPk, assessmentId, sessionId);

      final result = await _run(container, trialId);
      final issue = result.issues
          .firstWhere((i) => i.code == 'ratings_missing_provenance');
      expect(issue.isRepairable, false);
    });

    test('deleted rating with null provenance does not trigger issue', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      await _createRating(db, trialId, plotPk, assessmentId, sessionId,
          isDeleted: true);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'ratings_missing_provenance'),
        isFalse,
      );
    });
  });

  // ── trials_with_no_plots ──────────────────────────────────────────────────

  group('trials_with_no_plots', () {
    test('clean when trial has at least one live plot', () async {
      final trialId = await _createTrial(db);
      await _createPlot(db, trialId);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'trials_with_no_plots'),
        isFalse,
      );
    });

    test('issue detected when trial has no plots', () async {
      final trialId = await _createTrial(db);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'trials_with_no_plots'),
        isTrue,
      );
    });

    test('isRepairable is false for trials_with_no_plots', () async {
      final trialId = await _createTrial(db);

      final result = await _run(container, trialId);
      final issue =
          result.issues.firstWhere((i) => i.code == 'trials_with_no_plots');
      expect(issue.isRepairable, false);
    });

    test('plots in other trials do not satisfy this trial', () async {
      final trialId = await _createTrial(db);
      final otherTrial = await _createTrial(db);
      await _createPlot(db, otherTrial);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'trials_with_no_plots'),
        isTrue,
      );
    });
  });

  // ── duplicate_current_ratings ─────────────────────────────────────────────

  group('duplicate_current_ratings', () {
    test('clean when each logical key has exactly one current rating', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      await _createRating(db, trialId, plotPk, assessmentId, sessionId);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'duplicate_current_ratings'),
        isFalse,
      );
    });

    test('issue detected when two current ratings share the same key', () async {
      await _allowDuplicateCurrentRatings(db);
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      await _createRating(db, trialId, plotPk, assessmentId, sessionId);
      await _createRating(db, trialId, plotPk, assessmentId, sessionId);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'duplicate_current_ratings'),
        isTrue,
      );
    });

    test('isRepairable is true for duplicate_current_ratings', () async {
      await _allowDuplicateCurrentRatings(db);
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      await _createRating(db, trialId, plotPk, assessmentId, sessionId);
      await _createRating(db, trialId, plotPk, assessmentId, sessionId);

      final result = await _run(container, trialId);
      final issue = result.issues
          .firstWhere((i) => i.code == 'duplicate_current_ratings');
      expect(issue.isRepairable, true);
    });

    test('deleted duplicates do not trigger issue', () async {
      await _allowDuplicateCurrentRatings(db);
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      await _createRating(db, trialId, plotPk, assessmentId, sessionId);
      await _createRating(db, trialId, plotPk, assessmentId, sessionId,
          isDeleted: true);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'duplicate_current_ratings'),
        isFalse,
      );
    });

    test('duplicates in other trials do not affect this trial', () async {
      await _allowDuplicateCurrentRatings(db);
      final trialId = await _createTrial(db);
      final otherTrial = await _createTrial(db);
      final sessionId = await _createSession(db, otherTrial);
      final plotPk = await _createPlot(db, otherTrial);
      final assessmentId = await _createAssessment(db, otherTrial);
      await _createRating(db, otherTrial, plotPk, assessmentId, sessionId);
      await _createRating(db, otherTrial, plotPk, assessmentId, sessionId);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'duplicate_current_ratings'),
        isFalse,
      );
    });
  });

  // ── duplicate_session_assessments ─────────────────────────────────────────

  group('duplicate_session_assessments', () {
    test('clean when each session+assessment pair is unique', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      await _createSessionAssessment(db, sessionId, assessmentId);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'duplicate_session_assessments'),
        isFalse,
      );
    });

    test('issue detected when same session+assessment inserted twice', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      await _createSessionAssessment(db, sessionId, assessmentId);
      await _createSessionAssessment(db, sessionId, assessmentId);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'duplicate_session_assessments'),
        isTrue,
      );
    });

    test('isRepairable is false for duplicate_session_assessments', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      await _createSessionAssessment(db, sessionId, assessmentId);
      await _createSessionAssessment(db, sessionId, assessmentId);

      final result = await _run(container, trialId);
      final issue = result.issues
          .firstWhere((i) => i.code == 'duplicate_session_assessments');
      expect(issue.isRepairable, false);
    });

    test('duplicates in deleted sessions do not trigger issue', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      await (db.update(db.sessions)..where((s) => s.id.equals(sessionId)))
          .write(const SessionsCompanion(isDeleted: Value(true)));
      final assessmentId = await _createAssessment(db, trialId);
      await _createSessionAssessment(db, sessionId, assessmentId);
      await _createSessionAssessment(db, sessionId, assessmentId);

      final result = await _run(container, trialId);
      expect(
        result.issues.any((i) => i.code == 'duplicate_session_assessments'),
        isFalse,
      );
    });
  });

  // ── trial isolation ───────────────────────────────────────────────────────

  group('trial isolation', () {
    test('issues from one trial do not appear in a different trial', () async {
      final targetTrial = await _createTrial(db);
      final otherTrial = await _createTrial(db);
      // otherTrial has no plots → trials_with_no_plots fires for it.
      // targetTrial has a plot → no such issue.
      await _createPlot(db, targetTrial);

      final targetResult = await _run(container, targetTrial);
      final otherResult = await _run(container, otherTrial);

      expect(
        targetResult.issues.any((i) => i.code == 'trials_with_no_plots'),
        isFalse,
      );
      expect(
        otherResult.issues.any((i) => i.code == 'trials_with_no_plots'),
        isTrue,
      );
    });

    test('isClean true for a trial with no data issues', () async {
      final trialId = await _createTrial(db);
      final plotPk = await _createPlot(db, trialId);
      final trtId = await _createTreatment(db, trialId);
      await _createAssignment(db, trialId, plotPk, treatmentId: trtId);
      final assessmentId = await _createAssessment(db, trialId);
      final userId = await db
          .into(db.users)
          .insert(UsersCompanion.insert(displayName: 'U'));
      final sessionId = await _createSession(db, trialId,
          endedAt: DateTime.now(), createdByUserId: userId);
      await _createRating(db, trialId, plotPk, assessmentId, sessionId,
          createdAppVersion: '1.0.0');

      final result = await _run(container, trialId);
      expect(result.isClean, isTrue);
    });
  });
}
