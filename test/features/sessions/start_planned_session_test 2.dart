import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/session_state.dart';
import 'package:arm_field_companion/data/arm/arm_column_mapping_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 1c: planned-session surface.
///
/// [SessionRepository.startPlannedSession] is the single core-side entry point
/// that flips an importer-created placeholder into an open, ratable session.
/// The tests below pin the three invariants the UI relies on:
/// 1. happy path — planned row becomes open with a fresh `startedAt`
/// 2. conflict guard — another open session on the same trial blocks the flip
/// 3. type guard — rejecting non-planned rows so the helper can never be
///    mis-routed to short-circuit the normal create-session flow
///
/// The ARM-metadata read ([ArmColumnMappingRepository.getSessionMetadata])
/// lives in the same file because its only consumer is the same planned-tile
/// surface.
void main() {
  late AppDatabase db;
  late SessionRepository sessionRepo;
  late ArmColumnMappingRepository armRepo;
  late int trialId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sessionRepo = SessionRepository(db);
    armRepo = ArmColumnMappingRepository(db);
    trialId = await TrialRepository(db)
        .createTrial(name: 'T', workspaceType: 'efficacy');
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertPlannedSession({required String date}) async {
    return db.into(db.sessions).insert(
          SessionsCompanion.insert(
            trialId: trialId,
            name: 'Planned — $date',
            sessionDateLocal: date,
            status: const Value(kSessionStatusPlanned),
          ),
        );
  }

  group('startPlannedSession', () {
    test('flips planned to open and stamps startedAt', () async {
      final sessionId = await insertPlannedSession(date: '2026-04-02');

      final before = DateTime.now();
      final started = await sessionRepo.startPlannedSession(sessionId);
      final after = DateTime.now();

      expect(started.status, kSessionStatusOpen);
      expect(
        started.startedAt.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        started.startedAt.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
      expect(started.sessionDateLocal, '2026-04-02');

      // getOpenSession must now see it as the open session for the trial.
      final open = await sessionRepo.getOpenSession(trialId);
      expect(open?.id, sessionId);
    });

    test('records SESSION_STARTED audit event with planned session name',
        () async {
      final sessionId = await insertPlannedSession(date: '2026-04-02');

      await sessionRepo.startPlannedSession(sessionId, raterName: 'Alice');

      final events = await (db.select(db.auditEvents)
            ..where((e) => e.sessionId.equals(sessionId)))
          .get();
      expect(events, hasLength(1));
      expect(events.single.eventType, 'SESSION_STARTED');
      expect(events.single.description, contains('Planned'));
      expect(events.single.performedBy, 'Alice');
    });

    test('rejects when another session on the trial is already open',
        () async {
      // Existing "open" session.
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'Ad-hoc',
              sessionDateLocal: '2026-04-01',
            ),
          );

      final plannedId = await insertPlannedSession(date: '2026-04-02');

      expect(
        () => sessionRepo.startPlannedSession(plannedId),
        throwsA(isA<OpenSessionExistsException>()),
      );

      // Planned row must be untouched on the failure path.
      final row = await sessionRepo.getSessionById(plannedId);
      expect(row?.status, kSessionStatusPlanned);
    });

    test('writes cropStageBbch to session row when provided', () async {
      final sessionId = await insertPlannedSession(date: '2026-04-02');

      final started = await sessionRepo.startPlannedSession(
        sessionId,
        cropStageBbch: 65,
      );

      expect(started.cropStageBbch, 65);
    });

    test('leaves cropStageBbch null when not provided', () async {
      final sessionId = await insertPlannedSession(date: '2026-04-02');

      final started = await sessionRepo.startPlannedSession(sessionId);

      expect(started.cropStageBbch, isNull);
    });

    test('rejects non-planned sessions', () async {
      final openId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'Already open',
              sessionDateLocal: '2026-04-02',
            ),
          );

      expect(
        () => sessionRepo.startPlannedSession(openId),
        throwsA(isA<PlannedSessionStartException>()),
      );
    });

    test('throws SessionNotFoundException for unknown id', () async {
      expect(
        () => sessionRepo.startPlannedSession(9999),
        throwsA(isA<SessionNotFoundException>()),
      );
    });

    test('populates session_assessments from arm_column_mappings on start',
        () async {
      // Set up: assessment_definition → assessment → trial_assessment → arm mapping
      final asmtDefId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'WEDCON',
              name: 'Weed Control',
              category: 'percent',
            ),
          );
      final asmtId = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(trialId: trialId, name: 'Weed Control'),
          );
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: asmtDefId,
              legacyAssessmentId: Value(asmtId),
            ),
          );
      final sessionId = await insertPlannedSession(date: '2026-04-02');
      await db.into(db.armColumnMappings).insert(
            ArmColumnMappingsCompanion.insert(
              trialId: trialId,
              armColumnId: '1',
              armColumnIndex: 0,
              trialAssessmentId: Value(taId),
              sessionId: Value(sessionId),
            ),
          );

      await sessionRepo.startPlannedSession(sessionId);

      final sa = await (db.select(db.sessionAssessments)
            ..where((r) => r.sessionId.equals(sessionId)))
          .get();
      expect(sa, hasLength(1));
      expect(sa.single.assessmentId, asmtId);
    });

    test(
        'falls back to defaultInSessions assessments when no arm column mappings',
        () async {
      final asmtDefId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'WEDCON',
              name: 'Weed Control',
              category: 'percent',
            ),
          );
      final asmtId = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(trialId: trialId, name: 'Weed Control'),
          );
      await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: asmtDefId,
              legacyAssessmentId: Value(asmtId),
              // defaultInSessions defaults to true
            ),
          );
      final sessionId = await insertPlannedSession(date: '2026-04-02');
      // No arm_column_mappings inserted

      await sessionRepo.startPlannedSession(sessionId);

      final sa = await (db.select(db.sessionAssessments)
            ..where((r) => r.sessionId.equals(sessionId)))
          .get();
      expect(sa, hasLength(1));
      expect(sa.single.assessmentId, asmtId);
    });
  });

  group('startPlannedSession on-demand legacy assessment', () {
    test(
        'creates legacy Assessment row when trial_assessment.legacyAssessmentId is null',
        () async {
      // This is the ARM rating-shell import shape: trial_assessments are created
      // without a legacyAssessmentId, so the legacy Assessment row has to be
      // materialized at session-start time.
      final asmtDefId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'WEDCON',
              name: 'Weed Control',
              category: 'percent',
            ),
          );
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: asmtDefId,
              // legacyAssessmentId intentionally null
            ),
          );
      final sessionId = await insertPlannedSession(date: '2026-04-02');
      await db.into(db.armColumnMappings).insert(
            ArmColumnMappingsCompanion.insert(
              trialId: trialId,
              armColumnId: '1',
              armColumnIndex: 0,
              trialAssessmentId: Value(taId),
              sessionId: Value(sessionId),
            ),
          );

      await sessionRepo.startPlannedSession(sessionId);

      // Legacy Assessment row was created and linked back to the trial_assessment
      final assessments = await sessionRepo.getSessionAssessments(sessionId);
      expect(assessments, hasLength(1));
      // Clean display name (no "— TA$id" suffix) so the rating screen doesn't
      // surface internal row ids.
      expect(assessments.single.name, 'Weed Control');

      final taAfter = await (db.select(db.trialAssessments)
            ..where((t) => t.id.equals(taId)))
          .getSingle();
      expect(taAfter.legacyAssessmentId, isNotNull);
    });
  });

  group('ARM session name back-fill', () {
    test('renames "Planned — date" to comma-joined assessment names', () async {
      // An ARM-imported planned session shows up initially as "Planned — date".
      // After the session is populated with assessments we rename it to the
      // cleaner comma-joined form so the session tile's date isn't duplicated.
      final asmtId = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(trialId: trialId, name: 'CONTRO'),
          );
      final asmt2 = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(trialId: trialId, name: 'LODGIN'),
          );
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'Planned — 2026-04-02',
              sessionDateLocal: '2026-04-02',
            ),
          );
      await db.into(db.sessionAssessments).insert(
            SessionAssessmentsCompanion.insert(
                sessionId: sessionId,
                assessmentId: asmtId,
                sortOrder: const Value(0)),
          );
      await db.into(db.sessionAssessments).insert(
            SessionAssessmentsCompanion.insert(
                sessionId: sessionId,
                assessmentId: asmt2,
                sortOrder: const Value(1)),
          );

      await sessionRepo.getSessionAssessments(sessionId);

      final session = await (db.select(db.sessions)
            ..where((s) => s.id.equals(sessionId)))
          .getSingle();
      expect(session.name, 'CONTRO, LODGIN');
    });

    test('leaves user-customized session names untouched', () async {
      final asmtId = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(trialId: trialId, name: 'CONTRO'),
          );
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'Week 1 rating walk',
              sessionDateLocal: '2026-04-02',
            ),
          );
      await db.into(db.sessionAssessments).insert(
            SessionAssessmentsCompanion.insert(
                sessionId: sessionId,
                assessmentId: asmtId,
                sortOrder: const Value(0)),
          );

      await sessionRepo.getSessionAssessments(sessionId);

      final session = await (db.select(db.sessions)
            ..where((s) => s.id.equals(sessionId)))
          .getSingle();
      expect(session.name, 'Week 1 rating walk');
    });
  });

  group('getSessionAssessments self-heal', () {
    test(
        'populates session_assessments on read when empty and mappings exist',
        () async {
      // Simulates a pre-fix ARM session: started (not planned) but with no
      // session_assessments rows. getSessionAssessments should back-fill from
      // arm_column_mappings so the rating screen has something to show.
      final asmtDefId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'WEDCON',
              name: 'Weed Control',
              category: 'percent',
            ),
          );
      final asmtId = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(trialId: trialId, name: 'Weed Control'),
          );
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: asmtDefId,
              legacyAssessmentId: Value(asmtId),
            ),
          );
      // Insert a session directly in 'open' status — no planned→open flip —
      // matching the pre-fix broken state on-device.
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'Pre-fix open session',
              sessionDateLocal: '2026-04-02',
            ),
          );
      await db.into(db.armColumnMappings).insert(
            ArmColumnMappingsCompanion.insert(
              trialId: trialId,
              armColumnId: '1',
              armColumnIndex: 0,
              trialAssessmentId: Value(taId),
              sessionId: Value(sessionId),
            ),
          );

      final assessments = await sessionRepo.getSessionAssessments(sessionId);

      expect(assessments, hasLength(1));
      expect(assessments.single.id, asmtId);

      // And session_assessments row was persisted, not just returned on-the-fly
      final sa = await (db.select(db.sessionAssessments)
            ..where((r) => r.sessionId.equals(sessionId)))
          .get();
      expect(sa, hasLength(1));
    });
  });

  group('ArmColumnMappingRepository.getSessionMetadata', () {
    test('returns null when no metadata row exists', () async {
      final sessionId = await insertPlannedSession(date: '2026-04-02');

      final meta = await armRepo.getSessionMetadata(sessionId);

      expect(meta, isNull);
    });

    test('returns the single metadata row when present', () async {
      final sessionId = await insertPlannedSession(date: '2026-04-02');
      await armRepo.insertSessionMetadataBulk([
        ArmSessionMetadataCompanion.insert(
          sessionId: sessionId,
          armRatingDate: '2026-04-02',
          timingCode: const Value('A3'),
          cropStageMaj: const Value('BBCH 20'),
          trtEvalInterval: const Value('0 DA-A'),
          plantEvalInterval: const Value('14 DA-P'),
        ),
      ]);

      final meta = await armRepo.getSessionMetadata(sessionId);

      expect(meta, isNotNull);
      expect(meta!.armRatingDate, '2026-04-02');
      expect(meta.timingCode, 'A3');
      expect(meta.cropStageMaj, 'BBCH 20');
      expect(meta.trtEvalInterval, '0 DA-A');
      expect(meta.plantEvalInterval, '14 DA-P');
    });

    test('getSessionMetadatasForTrial returns rows in date order', () async {
      final earlyId = await insertPlannedSession(date: '2026-04-02');
      final lateId = await insertPlannedSession(date: '2026-04-23');
      await armRepo.insertSessionMetadataBulk([
        ArmSessionMetadataCompanion.insert(
          sessionId: lateId,
          armRatingDate: '2026-04-23',
        ),
        ArmSessionMetadataCompanion.insert(
          sessionId: earlyId,
          armRatingDate: '2026-04-02',
        ),
      ]);

      final rows = await armRepo.getSessionMetadatasForTrial(trialId);

      expect(rows.map((r) => r.sessionId), [earlyId, lateId]);
    });
  });
}
