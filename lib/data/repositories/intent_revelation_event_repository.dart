import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

class IntentRevelationEventRepository {
  IntentRevelationEventRepository(this._db);

  final AppDatabase _db;

  Future<int> addIntentRevelationEvent({
    required int trialId,
    int? trialPurposeId,
    required String touchpoint,
    required String questionKey,
    required String questionText,
    String? answerValue,
    String answerState = 'unknown',
    required String source,
    String? capturedBy,
  }) {
    return _db.into(_db.intentRevelationEvents).insert(
          IntentRevelationEventsCompanion.insert(
            trialId: trialId,
            trialPurposeId: Value(trialPurposeId),
            touchpoint: touchpoint,
            questionKey: questionKey,
            questionText: questionText,
            answerValue: Value(answerValue),
            answerState: Value(answerState),
            source: source,
            capturedBy: Value(capturedBy),
          ),
        );
  }

  Stream<List<IntentRevelationEvent>> watchIntentRevelationEventsForTrial(
    int trialId,
  ) {
    return (_db.select(_db.intentRevelationEvents)
          ..where((e) => e.trialId.equals(trialId))
          ..orderBy([(e) => OrderingTerm.asc(e.capturedAt)]))
        .watch();
  }

  Future<List<IntentRevelationEvent>> getIntentRevelationEventsForPurpose(
    int trialPurposeId,
  ) {
    return (_db.select(_db.intentRevelationEvents)
          ..where((e) => e.trialPurposeId.equals(trialPurposeId))
          ..orderBy([(e) => OrderingTerm.asc(e.capturedAt)]))
        .get();
  }
}
