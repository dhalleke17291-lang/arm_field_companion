import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/weather_snapshot_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart' as uuid_pkg;

void main() {
  late AppDatabase db;
  late WeatherSnapshotRepository repo;
  late TrialRepository trialRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = WeatherSnapshotRepository(db);
    trialRepo = TrialRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<({int trialId, int sessionId})> createTrialAndSession() async {
    final trialId = await trialRepo.createTrial(
      name: 'Trial ${DateTime.now().microsecondsSinceEpoch}',
    );
    final sessionId = await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            trialId: trialId,
            name: 'Session 1',
            sessionDateLocal: '2026-04-12',
          ),
        );
    return (trialId: trialId, sessionId: sessionId);
  }

  WeatherSnapshotsCompanion makeCompanion({
    required int trialId,
    required int parentId,
    Value<double?> temperature = const Value.absent(),
    Value<double?> humidity = const Value.absent(),
    Value<double?> windSpeed = const Value.absent(),
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return WeatherSnapshotsCompanion.insert(
      uuid: const uuid_pkg.Uuid().v4(),
      trialId: trialId,
      parentId: parentId,
      temperature: temperature,
      humidity: humidity,
      windSpeed: windSpeed,
      recordedAt: now,
      createdAt: now,
      modifiedAt: now,
      createdBy: 'test',
    );
  }

  group('upsertWeatherSnapshot', () {
    test('inserts new snapshot', () async {
      final ctx = await createTrialAndSession();

      final id = await repo.upsertWeatherSnapshot(
        makeCompanion(
          trialId: ctx.trialId,
          parentId: ctx.sessionId,
          temperature: const Value(22.5),
          humidity: const Value(65.0),
        ),
      );
      expect(id, greaterThan(0));

      final snap = await repo.getWeatherSnapshotForParent(
          kWeatherParentTypeRatingSession, ctx.sessionId);
      expect(snap, isNotNull);
      expect(snap!.temperature, 22.5);
      expect(snap.humidity, 65.0);
    });

    test('updates existing snapshot on second upsert', () async {
      final ctx = await createTrialAndSession();

      await repo.upsertWeatherSnapshot(
        makeCompanion(
          trialId: ctx.trialId,
          parentId: ctx.sessionId,
          temperature: const Value(20.0),
        ),
      );

      await repo.upsertWeatherSnapshot(
        makeCompanion(
          trialId: ctx.trialId,
          parentId: ctx.sessionId,
          temperature: const Value(25.0),
        ),
      );

      final snap = await repo.getWeatherSnapshotForParent(
          kWeatherParentTypeRatingSession, ctx.sessionId);
      expect(snap!.temperature, 25.0);
    });
  });

  group('getWeatherSnapshotForParent', () {
    test('returns null when no snapshot exists', () async {
      final snap = await repo.getWeatherSnapshotForParent(
          kWeatherParentTypeRatingSession, 99999);
      expect(snap, isNull);
    });
  });

  group('deleteWeatherSnapshot', () {
    test('removes snapshot by id', () async {
      final ctx = await createTrialAndSession();

      final id = await repo.upsertWeatherSnapshot(
        makeCompanion(
          trialId: ctx.trialId,
          parentId: ctx.sessionId,
          temperature: const Value(20.0),
        ),
      );

      await repo.deleteWeatherSnapshot(id);

      final snap = await repo.getWeatherSnapshotForParent(
          kWeatherParentTypeRatingSession, ctx.sessionId);
      expect(snap, isNull);
    });
  });

  group('getWeatherSnapshotsForTrial', () {
    test('returns all snapshots for trial', () async {
      final ctx = await createTrialAndSession();
      // Create a second session
      final s2 = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: ctx.trialId,
              name: 'Session 2',
              sessionDateLocal: '2026-04-12',
            ),
          );

      await repo.upsertWeatherSnapshot(
        makeCompanion(
            trialId: ctx.trialId, parentId: ctx.sessionId),
      );
      await repo.upsertWeatherSnapshot(
        makeCompanion(trialId: ctx.trialId, parentId: s2),
      );

      final all = await repo.getWeatherSnapshotsForTrial(ctx.trialId);
      expect(all.length, 2);
    });
  });
}
