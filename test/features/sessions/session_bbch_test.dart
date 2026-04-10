import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('createSession stores cropStageBbch', () async {
    final trialId =
        await TrialRepository(db).createTrial(name: 'T', workspaceType: 'efficacy');
    final assessmentId = await db.into(db.assessments).insert(
          AssessmentsCompanion.insert(
            trialId: trialId,
            name: 'A1',
          ),
        );
    final repo = SessionRepository(db);
    final session = await repo.createSession(
      trialId: trialId,
      name: 'S1',
      sessionDateLocal: '2026-04-01',
      assessmentIds: [assessmentId],
      cropStageBbch: 32,
    );
    expect(session.cropStageBbch, 32);
    final again = await repo.getSessionById(session.id);
    expect(again?.cropStageBbch, 32);
  });

  test('createSession without BBCH leaves null', () async {
    final trialId =
        await TrialRepository(db).createTrial(name: 'T2', workspaceType: 'efficacy');
    final assessmentId = await db.into(db.assessments).insert(
          AssessmentsCompanion.insert(
            trialId: trialId,
            name: 'A1',
          ),
        );
    final repo = SessionRepository(db);
    final session = await repo.createSession(
      trialId: trialId,
      name: 'S1',
      sessionDateLocal: '2026-04-01',
      assessmentIds: [assessmentId],
    );
    expect(session.cropStageBbch, isNull);
  });

  test('updateSessionCropStageBbch', () async {
    final trialId =
        await TrialRepository(db).createTrial(name: 'T3', workspaceType: 'efficacy');
    final assessmentId = await db.into(db.assessments).insert(
          AssessmentsCompanion.insert(
            trialId: trialId,
            name: 'A1',
          ),
        );
    final repo = SessionRepository(db);
    final session = await repo.createSession(
      trialId: trialId,
      name: 'S1',
      sessionDateLocal: '2026-04-01',
      assessmentIds: [assessmentId],
      cropStageBbch: 10,
    );
    await repo.updateSessionCropStageBbch(session.id, 55);
    final updated = await repo.getSessionById(session.id);
    expect(updated?.cropStageBbch, 55);
  });
}
