import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/relationships/causal_context_provider.dart';
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

Future<int> _createSession(AppDatabase db, int trialId) =>
    db.into(db.sessions).insert(
          SessionsCompanion.insert(
            trialId: trialId,
            name: 'S',
            sessionDateLocal: '2026-06-10',
          ),
        );

Future<int> _createPlot(AppDatabase db, int trialId) =>
    db.into(db.plots).insert(
          PlotsCompanion.insert(trialId: trialId, plotId: 'P'),
        );

Future<int> _createAssessment(AppDatabase db, int trialId) =>
    db.into(db.assessments).insert(
          AssessmentsCompanion.insert(trialId: trialId, name: 'A'),
        );

Future<int> _createRating(
  AppDatabase db,
  int trialId,
  int sessionId,
  int plotPk,
  int assessmentId, {
  DateTime? createdAt,
  int? trialAssessmentId,
}) =>
    db.into(db.ratingRecords).insert(
          RatingRecordsCompanion.insert(
            trialId: trialId,
            plotPk: plotPk,
            assessmentId: assessmentId,
            sessionId: sessionId,
            createdAt: createdAt != null
                ? Value(createdAt)
                : const Value.absent(),
            trialAssessmentId: trialAssessmentId != null
                ? Value(trialAssessmentId)
                : const Value.absent(),
          ),
        );

Future<int> _createAssessmentDefinition(AppDatabase db) =>
    db.into(db.assessmentDefinitions).insert(
          AssessmentDefinitionsCompanion.insert(
            code: 'TST',
            name: 'Test Assessment',
            category: 'pest',
          ),
        );

Future<int> _createTrialAssessment(
  AppDatabase db,
  int trialId,
  int defId,
) =>
    db.into(db.trialAssessments).insert(
          TrialAssessmentsCompanion.insert(
            trialId: trialId,
            assessmentDefinitionId: defId,
          ),
        );

Future<void> _createArmAssessmentMetadata(
  AppDatabase db,
  int trialAssessmentId, {
  String? ratingType,
}) =>
    db.into(db.armAssessmentMetadata).insert(
          ArmAssessmentMetadataCompanion.insert(
            trialAssessmentId: trialAssessmentId,
            ratingType: ratingType != null ? Value(ratingType) : const Value.absent(),
          ),
        );

Future<void> _createApplication(
  AppDatabase db,
  int trialId, {
  required DateTime applicationDate,
  DateTime? appliedAt,
  String status = 'pending',
}) =>
    db.into(db.trialApplicationEvents).insert(
          TrialApplicationEventsCompanion(
            trialId: Value(trialId),
            applicationDate: Value(applicationDate),
            appliedAt: Value(appliedAt),
            status: Value(status),
          ),
        );

Future<void> _createWeatherSnapshot(
  AppDatabase db,
  int trialId,
  int sessionId, {
  required int recordedAtMs,
}) async {
  await db.into(db.weatherSnapshots).insert(
        WeatherSnapshotsCompanion.insert(
          uuid: 'uuid-$sessionId-$recordedAtMs',
          trialId: trialId,
          parentId: sessionId,
          recordedAt: recordedAtMs,
          createdAt: recordedAtMs,
          modifiedAt: recordedAtMs,
          createdBy: 'test',
        ),
      );
}

Future<CausalContext> _run(ProviderContainer c, int ratingId) =>
    c.read(causalContextProvider(ratingId).future);

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

  // ── Rating not found ──────────────────────────────────────────────────────

  group('rating not found', () {
    test('returns CausalContext with empty priorEvents when ratingId is unknown',
        () async {
      final result = await _run(container, 99999);
      expect(result.ratingId, 99999);
      expect(result.priorEvents, isEmpty);
    });
  });

  // ── No applications ───────────────────────────────────────────────────────

  group('no applications', () {
    test('returns empty priorEvents when trial has no applications', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
      );

      final result = await _run(container, ratingId);
      expect(
        result.priorEvents.where((e) => e.type == CausalEventType.application),
        isEmpty,
      );
    });
  });

  // ── Application inclusion and exclusion ───────────────────────────────────

  group('application filters', () {
    late int trialId;
    late int sessionId;
    late int plotPk;
    late int assessmentId;

    setUp(() async {
      trialId = await _createTrial(db);
      sessionId = await _createSession(db, trialId);
      plotPk = await _createPlot(db, trialId);
      assessmentId = await _createAssessment(db, trialId);
    });

    test('confirmed application (status applied) before rating is included',
        () async {
      await _createApplication(
        db, trialId,
        applicationDate: DateTime.utc(2026, 6, 5),
        status: 'applied',
      );
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
      );

      final result = await _run(container, ratingId);
      final appEvents =
          result.priorEvents.where((e) => e.type == CausalEventType.application);
      expect(appEvents, hasLength(1));
    });

    test('same-day application is included with daysBefore = 0', () async {
      await _createApplication(
        db, trialId,
        applicationDate: DateTime.utc(2026, 6, 10, 8, 0),
        status: 'applied',
      );
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10, 14, 0),
      );

      final result = await _run(container, ratingId);
      final appEvent = result.priorEvents
          .firstWhere((e) => e.type == CausalEventType.application);
      expect(appEvent.daysBefore, 0);
    });

    test('application after rating date is excluded', () async {
      await _createApplication(
        db, trialId,
        applicationDate: DateTime.utc(2026, 6, 15),
        status: 'applied',
      );
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
      );

      final result = await _run(container, ratingId);
      expect(
        result.priorEvents.where((e) => e.type == CausalEventType.application),
        isEmpty,
      );
    });

    test('pending application is excluded', () async {
      await _createApplication(
        db, trialId,
        applicationDate: DateTime.utc(2026, 6, 5),
        status: 'pending',
      );
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
      );

      final result = await _run(container, ratingId);
      expect(
        result.priorEvents.where((e) => e.type == CausalEventType.application),
        isEmpty,
      );
    });

    test('cancelled application is excluded', () async {
      await _createApplication(
        db, trialId,
        applicationDate: DateTime.utc(2026, 6, 5),
        status: 'cancelled',
      );
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
      );

      final result = await _run(container, ratingId);
      expect(
        result.priorEvents.where((e) => e.type == CausalEventType.application),
        isEmpty,
      );
    });

    test('complete status is included', () async {
      await _createApplication(
        db, trialId,
        applicationDate: DateTime.utc(2026, 6, 5),
        appliedAt: DateTime.utc(2026, 6, 5, 10),
        status: 'complete',
      );
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
      );

      final result = await _run(container, ratingId);
      expect(
        result.priorEvents.where((e) => e.type == CausalEventType.application),
        hasLength(1),
      );
    });

    test('appliedAt is used as eventDate when set (preferred over applicationDate)',
        () async {
      final appliedAt = DateTime.utc(2026, 6, 6, 9, 30);
      final applicationDate = DateTime.utc(2026, 6, 4);
      await _createApplication(
        db, trialId,
        applicationDate: applicationDate,
        appliedAt: appliedAt,
        status: 'applied',
      );
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
      );

      final result = await _run(container, ratingId);
      final appEvent = result.priorEvents
          .firstWhere((e) => e.type == CausalEventType.application);
      // Drift reads back DateTimes in local time; compare as instant.
      expect(appEvent.eventDate!.isAtSameMomentAs(appliedAt), isTrue);
    });

    test('applicationDate used as eventDate when appliedAt is null', () async {
      final applicationDate = DateTime.utc(2026, 6, 5, 12);
      await _createApplication(
        db, trialId,
        applicationDate: applicationDate,
        status: 'applied',
      );
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10, 12),
      );

      final result = await _run(container, ratingId);
      final appEvent = result.priorEvents
          .firstWhere((e) => e.type == CausalEventType.application);
      expect(appEvent.eventDate!.isAtSameMomentAs(applicationDate), isTrue);
    });

    test('application with appliedAt != null is confirmed regardless of status',
        () async {
      await _createApplication(
        db, trialId,
        applicationDate: DateTime.utc(2026, 6, 5),
        appliedAt: DateTime.utc(2026, 6, 5, 10),
        status: 'pending',
      );
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
      );

      final result = await _run(container, ratingId);
      expect(
        result.priorEvents.where((e) => e.type == CausalEventType.application),
        hasLength(1),
      );
    });

    test('date comparison uses calendar date only, not time', () async {
      // Both at safe midday UTC hours so no timezone crosses midnight boundary.
      await _createApplication(
        db, trialId,
        applicationDate: DateTime.utc(2026, 6, 10, 8),
        status: 'applied',
      );
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10, 20),
      );

      final result = await _run(container, ratingId);
      final appEvents =
          result.priorEvents.where((e) => e.type == CausalEventType.application);
      expect(appEvents, hasLength(1));
      expect(appEvents.first.daysBefore, 0);
    });

    test('daysBefore is correct number of calendar days apart', () async {
      await _createApplication(
        db, trialId,
        applicationDate: DateTime.utc(2026, 6, 3),
        status: 'applied',
      );
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
      );

      final result = await _run(container, ratingId);
      final appEvent = result.priorEvents
          .firstWhere((e) => e.type == CausalEventType.application);
      expect(appEvent.daysBefore, 7);
    });

    test('application label is "Application"', () async {
      await _createApplication(
        db, trialId,
        applicationDate: DateTime.utc(2026, 6, 5),
        status: 'applied',
      );
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
      );

      final result = await _run(container, ratingId);
      final appEvent = result.priorEvents
          .firstWhere((e) => e.type == CausalEventType.application);
      expect(appEvent.label, 'Application');
    });
  });

  // ── Weather snapshot ──────────────────────────────────────────────────────

  group('weather snapshot', () {
    late int trialId;
    late int sessionId;
    late int plotPk;
    late int assessmentId;

    setUp(() async {
      trialId = await _createTrial(db);
      sessionId = await _createSession(db, trialId);
      plotPk = await _createPlot(db, trialId);
      assessmentId = await _createAssessment(db, trialId);
    });

    test('weather snapshot for session is included', () async {
      final nowMs = DateTime.utc(2026, 6, 10, 9).millisecondsSinceEpoch;
      await _createWeatherSnapshot(db, trialId, sessionId, recordedAtMs: nowMs);
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
      );

      final result = await _run(container, ratingId);
      final weatherEvents =
          result.priorEvents.where((e) => e.type == CausalEventType.weather);
      expect(weatherEvents, hasLength(1));
    });

    test('weather recordedAt is converted from epoch millis to UTC DateTime',
        () async {
      final expectedDt = DateTime.utc(2026, 6, 10, 9, 30);
      final ms = expectedDt.millisecondsSinceEpoch;
      await _createWeatherSnapshot(db, trialId, sessionId, recordedAtMs: ms);
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
      );

      final result = await _run(container, ratingId);
      final weatherEvent =
          result.priorEvents.firstWhere((e) => e.type == CausalEventType.weather);
      expect(weatherEvent.eventDate, expectedDt);
    });

    test('weather event has null daysBefore', () async {
      final nowMs = DateTime.utc(2026, 6, 10, 9).millisecondsSinceEpoch;
      await _createWeatherSnapshot(db, trialId, sessionId, recordedAtMs: nowMs);
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
      );

      final result = await _run(container, ratingId);
      final weatherEvent =
          result.priorEvents.firstWhere((e) => e.type == CausalEventType.weather);
      expect(weatherEvent.daysBefore, isNull);
    });

    test('weather event label is correct', () async {
      final nowMs = DateTime.utc(2026, 6, 10, 9).millisecondsSinceEpoch;
      await _createWeatherSnapshot(db, trialId, sessionId, recordedAtMs: nowMs);
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
      );

      final result = await _run(container, ratingId);
      final weatherEvent =
          result.priorEvents.firstWhere((e) => e.type == CausalEventType.weather);
      expect(weatherEvent.label, 'Weather conditions recorded for session');
    });

    test('no weather event when session has no snapshot', () async {
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
      );

      final result = await _run(container, ratingId);
      expect(
        result.priorEvents.where((e) => e.type == CausalEventType.weather),
        isEmpty,
      );
    });
  });

  // ── SE type + causal profile ──────────────────────────────────────────────

  group('SE type and causal profile', () {
    test('seType and profile are null when rating has no trialAssessmentId',
        () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
      );

      final result = await _run(container, ratingId);
      expect(result.seType, isNull);
      expect(result.profile, isNull);
    });

    test(
        'seType and profile are null when ARM metadata has no ratingType',
        () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      final defId = await _createAssessmentDefinition(db);
      final taId = await _createTrialAssessment(db, trialId, defId);
      await _createArmAssessmentMetadata(db, taId); // no ratingType
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
        trialAssessmentId: taId,
      );

      final result = await _run(container, ratingId);
      expect(result.seType, isNull);
      expect(result.profile, isNull);
    });

    test('seType is set and profile resolved for ARM rating with CONTRO/efficacy',
        () async {
      // Seed data provides CONTRO × efficacy row; forTesting DB runs onCreate seeds.
      final trialId = await db.into(db.trials).insert(
            TrialsCompanion.insert(
              name: 'ARM Trial',
              workspaceType: const Value('efficacy'),
            ),
          );
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      final defId = await _createAssessmentDefinition(db);
      final taId = await _createTrialAssessment(db, trialId, defId);
      await _createArmAssessmentMetadata(db, taId, ratingType: 'CONTRO');
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
        trialAssessmentId: taId,
      );

      final result = await _run(container, ratingId);
      expect(result.seType, 'CONTRO');
      expect(result.profile, isNotNull);
      expect(result.profile!.seType, 'CONTRO');
      expect(result.profile!.trialType, 'efficacy');
      expect(result.profile!.causalWindowDaysMin, greaterThanOrEqualTo(0));
    });

    test('profile is null when seType has no matching row in se_type_causal_profiles',
        () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      final defId = await _createAssessmentDefinition(db);
      final taId = await _createTrialAssessment(db, trialId, defId);
      await _createArmAssessmentMetadata(db, taId, ratingType: 'UNKNWN');
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
        trialAssessmentId: taId,
      );

      final result = await _run(container, ratingId);
      expect(result.seType, 'UNKNWN');
      expect(result.profile, isNull);
    });

    test('existing priorEvents are preserved alongside profile fields', () async {
      final trialId = await db.into(db.trials).insert(
            TrialsCompanion.insert(
              name: 'ARM Trial',
              workspaceType: const Value('efficacy'),
            ),
          );
      final sessionId = await _createSession(db, trialId);
      final plotPk = await _createPlot(db, trialId);
      final assessmentId = await _createAssessment(db, trialId);
      final defId = await _createAssessmentDefinition(db);
      final taId = await _createTrialAssessment(db, trialId, defId);
      await _createArmAssessmentMetadata(db, taId, ratingType: 'PESINC');
      await _createApplication(
        db, trialId,
        applicationDate: DateTime.utc(2026, 6, 5),
        status: 'applied',
      );
      final ratingId = await _createRating(
        db, trialId, sessionId, plotPk, assessmentId,
        createdAt: DateTime.utc(2026, 6, 10),
        trialAssessmentId: taId,
      );

      final result = await _run(container, ratingId);
      expect(
        result.priorEvents.where((e) => e.type == CausalEventType.application),
        hasLength(1),
      );
      expect(result.seType, 'PESINC');
      expect(result.profile, isNotNull);
    });
  });
}
