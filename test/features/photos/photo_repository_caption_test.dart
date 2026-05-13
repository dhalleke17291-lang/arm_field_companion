import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/photos/photo_repository.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PhotoRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = PhotoRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> makePhoto({String? caption}) async {
    final trialId = await db
        .into(db.trials)
        .insert(TrialsCompanion.insert(name: 'Caption Trial'));
    final plotPk = await db.into(db.plots).insert(PlotsCompanion.insert(
          trialId: trialId,
          plotId: '101',
        ));
    final sessionId = await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            trialId: trialId,
            name: 'Session 1',
            sessionDateLocal: '2026-05-11',
          ),
        );
    return db.into(db.photos).insert(
          PhotosCompanion.insert(
            trialId: trialId,
            plotPk: plotPk,
            sessionId: sessionId,
            filePath: 'photo.jpg',
            caption: Value(caption),
          ),
        );
  }

  Future<Photo> loadPhoto(int id) {
    return (db.select(db.photos)..where((p) => p.id.equals(id))).getSingle();
  }

  group('PhotoRepository.updateCaption', () {
    test('PRC-1: writes non-empty caption and audit event', () async {
      final photoId = await makePhoto();

      await repo.updateCaption(
        photoId,
        '  Shows disease pressure near plot edge.  ',
        performedBy: 'Parminder',
        performedByUserId: 7,
      );

      final photo = await loadPhoto(photoId);
      expect(photo.caption, 'Shows disease pressure near plot edge.');

      final events = await db.select(db.auditEvents).get();
      expect(events, hasLength(1));
      expect(events.single.eventType, 'PHOTO_CAPTION_UPDATED');
      expect(events.single.description, 'Photo caption updated');
      expect(events.single.performedBy, 'Parminder');
      expect(events.single.performedByUserId, 7);
    });

    test('PRC-2: normalizes empty caption to null', () async {
      final photoId = await makePhoto(caption: 'Existing caption');

      await repo.updateCaption(photoId, '   ');

      final photo = await loadPhoto(photoId);
      expect(photo.caption, isNull);
    });
  });
}
