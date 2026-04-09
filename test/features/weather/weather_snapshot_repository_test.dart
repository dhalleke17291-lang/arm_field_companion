import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/weather_snapshot_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late WeatherSnapshotRepository repo;
  late int trialId;
  late int sessionId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = WeatherSnapshotRepository(db);
    trialId = await TrialRepository(db).createTrial(
      name: 'W',
      workspaceType: 'efficacy',
    );
    sessionId = await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            trialId: trialId,
            name: 'S1',
            sessionDateLocal: '2026-06-15',
            startedAt: drift.Value(DateTime.utc(2026, 6, 15, 10)),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('insert and retrieve by parent', () async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = await repo.upsertWeatherSnapshot(
      WeatherSnapshotsCompanion.insert(
        uuid: 'u1',
        trialId: trialId,
        parentId: sessionId,
        recordedAt: now,
        createdAt: now,
        modifiedAt: now,
        createdBy: 'Tester',
        temperature: const drift.Value(22.5),
        temperatureUnit: const drift.Value('C'),
        parentType: const drift.Value(kWeatherParentTypeRatingSession),
      ),
    );
    expect(id, greaterThan(0));
    final got = await repo.getWeatherSnapshotForParent(
      kWeatherParentTypeRatingSession,
      sessionId,
    );
    expect(got, isNotNull);
    expect(got!.temperature, 22.5);
    expect(got.temperatureUnit, 'C');
  });

  test('returns null when no snapshot exists for parent', () async {
    final got = await repo.getWeatherSnapshotForParent(
      kWeatherParentTypeRatingSession,
      sessionId,
    );
    expect(got, isNull);
  });

  test('getWeatherSnapshotsForTrial returns all rows', () async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final s2 = await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            trialId: trialId,
            name: 'S2',
            sessionDateLocal: '2026-06-16',
            startedAt: drift.Value(DateTime.utc(2026, 6, 16)),
          ),
        );
    await repo.upsertWeatherSnapshot(
      WeatherSnapshotsCompanion.insert(
        uuid: 'a',
        trialId: trialId,
        parentId: sessionId,
        recordedAt: now,
        createdAt: now,
        modifiedAt: now,
        createdBy: 'A',
        parentType: const drift.Value(kWeatherParentTypeRatingSession),
      ),
    );
    await repo.upsertWeatherSnapshot(
      WeatherSnapshotsCompanion.insert(
        uuid: 'b',
        trialId: trialId,
        parentId: s2,
        recordedAt: now + 1,
        createdAt: now + 1,
        modifiedAt: now + 1,
        createdBy: 'B',
        parentType: const drift.Value(kWeatherParentTypeRatingSession),
      ),
    );
    final list = await repo.getWeatherSnapshotsForTrial(trialId);
    expect(list.length, 2);
    expect(list.map((e) => e.uuid).toSet(), {'a', 'b'});
  });

  test('update existing', () async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = await repo.upsertWeatherSnapshot(
      WeatherSnapshotsCompanion.insert(
        uuid: 'u-up',
        trialId: trialId,
        parentId: sessionId,
        recordedAt: now,
        createdAt: now,
        modifiedAt: now,
        createdBy: 'T',
        humidity: const drift.Value(55),
        parentType: const drift.Value(kWeatherParentTypeRatingSession),
      ),
    );
    final later = now + 9999;
    await repo.updateWeatherSnapshot(
      id,
      WeatherSnapshotsCompanion(
        humidity: const drift.Value(60),
        modifiedAt: drift.Value(later),
        recordedAt: drift.Value(later),
      ),
    );
    final got = await repo.getWeatherSnapshotForParent(
      kWeatherParentTypeRatingSession,
      sessionId,
    );
    expect(got!.humidity, 60);
    expect(got.modifiedAt, later);
  });

  test('insert with all optional fields set', () async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await repo.upsertWeatherSnapshot(
      WeatherSnapshotsCompanion.insert(
        uuid: 'full',
        trialId: trialId,
        parentId: sessionId,
        recordedAt: now,
        createdAt: now,
        modifiedAt: now,
        createdBy: 'T',
        parentType: const drift.Value(kWeatherParentTypeRatingSession),
        temperature: const drift.Value(20),
        temperatureUnit: const drift.Value('C'),
        humidity: const drift.Value(65),
        windSpeed: const drift.Value(12),
        windSpeedUnit: const drift.Value('km/h'),
        windDirection: const drift.Value('NE'),
        cloudCover: const drift.Value('overcast'),
        precipitation: const drift.Value('light'),
        soilCondition: const drift.Value('moist'),
        notes: const drift.Value('Breezy'),
      ),
    );
    final got = await repo.getWeatherSnapshotForParent(
      kWeatherParentTypeRatingSession,
      sessionId,
    );
    expect(got!.windDirection, 'NE');
    expect(got.cloudCover, 'overcast');
    expect(got.precipitation, 'light');
    expect(got.soilCondition, 'moist');
    expect(got.notes, 'Breezy');
  });

  test('second upsert for same parent preserves uuid and updates row', () async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await repo.upsertWeatherSnapshot(
      WeatherSnapshotsCompanion.insert(
        uuid: 'first-uuid',
        trialId: trialId,
        parentId: sessionId,
        recordedAt: now,
        createdAt: now,
        modifiedAt: now,
        createdBy: 'A',
        humidity: const drift.Value(40),
        parentType: const drift.Value(kWeatherParentTypeRatingSession),
      ),
    );
    await repo.upsertWeatherSnapshot(
      WeatherSnapshotsCompanion.insert(
        uuid: 'second-uuid',
        trialId: trialId,
        parentId: sessionId,
        recordedAt: now + 1,
        createdAt: now + 1,
        modifiedAt: now + 1,
        createdBy: 'B',
        humidity: const drift.Value(70),
        parentType: const drift.Value(kWeatherParentTypeRatingSession),
      ),
    );
    final list = await repo.getWeatherSnapshotsForTrial(trialId);
    expect(list.length, 1);
    final got = await repo.getWeatherSnapshotForParent(
      kWeatherParentTypeRatingSession,
      sessionId,
    );
    expect(got!.humidity, 70);
    expect(got.uuid, 'first-uuid');
    expect(got.createdBy, 'B');
  });

  test('delete', () async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = await repo.upsertWeatherSnapshot(
      WeatherSnapshotsCompanion.insert(
        uuid: 'u-del',
        trialId: trialId,
        parentId: sessionId,
        recordedAt: now,
        createdAt: now,
        modifiedAt: now,
        createdBy: 'T',
        parentType: const drift.Value(kWeatherParentTypeRatingSession),
      ),
    );
    await repo.deleteWeatherSnapshot(id);
    expect(
      await repo.getWeatherSnapshotForParent(
        kWeatherParentTypeRatingSession,
        sessionId,
      ),
      isNull,
    );
  });
}
