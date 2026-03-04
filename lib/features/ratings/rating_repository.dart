import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';

class RatingRepository {
  final AppDatabase _db;

  RatingRepository(this._db);

  // Get current rating for a plot/assessment/session combination
  Future<RatingRecord?> getCurrentRating({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
    int? subUnitId,
  }) {
    return (_db.select(_db.ratingRecords)
          ..where((r) =>
              r.trialId.equals(trialId) &
              r.plotPk.equals(plotPk) &
              r.assessmentId.equals(assessmentId) &
              r.sessionId.equals(sessionId) &
              r.isCurrent.equals(true)))
        .getSingleOrNull();
  }

  // Watch current rating reactively
  Stream<RatingRecord?> watchCurrentRating({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
  }) {
    return (_db.select(_db.ratingRecords)
          ..where((r) =>
              r.trialId.equals(trialId) &
              r.plotPk.equals(plotPk) &
              r.assessmentId.equals(assessmentId) &
              r.sessionId.equals(sessionId) &
              r.isCurrent.equals(true)))
        .watchSingleOrNull();
  }

  // Save rating — implements version chain invariant
  Future<RatingRecord> saveRating({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
    required String resultStatus,
    double? numericValue,
    String? textValue,
    int? subUnitId,
    String? raterName,
  }) async {
    // Enforce spec rule: numeric_value must be NULL if status != RECORDED
    if (resultStatus != 'RECORDED' && numericValue != null) {
      throw RatingIntegrityException(
          'numericValue must be null when resultStatus is $resultStatus');
    }

    return _db.transaction(() async {
      // Find existing current rating
      final existing = await getCurrentRating(
        trialId: trialId,
        plotPk: plotPk,
        assessmentId: assessmentId,
        sessionId: sessionId,
        subUnitId: subUnitId,
      );

      // Mark existing as not current
      if (existing != null) {
        await (_db.update(_db.ratingRecords)
              ..where((r) => r.id.equals(existing.id)))
            .write(const RatingRecordsCompanion(
                isCurrent: Value(false)));
      }

      // Insert new current record
      final newId = await _db.into(_db.ratingRecords).insert(
            RatingRecordsCompanion.insert(
              trialId: trialId,
              plotPk: plotPk,
              assessmentId: assessmentId,
              sessionId: sessionId,
              subUnitId: Value(subUnitId),
              resultStatus: Value(resultStatus),
              numericValue: Value(numericValue),
              textValue: Value(textValue),
              isCurrent: const Value(true),
              previousId: Value(existing?.id),
              raterName: Value(raterName),
            ),
          );

      // Write audit event
      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(trialId),
              sessionId: Value(sessionId),
              plotPk: Value(plotPk),
              eventType: 'RATING_SAVED',
              description:
                  'Rating saved: $resultStatus ${numericValue ?? ""}',
              performedBy: Value(raterName),
            ),
          );

      return await (_db.select(_db.ratingRecords)
            ..where((r) => r.id.equals(newId)))
          .getSingle();
    });
  }

  // Undo — reverts to previous rating in chain
  Future<void> undoRating({
    required int currentRatingId,
    String? raterName,
  }) async {
    return _db.transaction(() async {
      final current = await (_db.select(_db.ratingRecords)
            ..where((r) => r.id.equals(currentRatingId)))
          .getSingleOrNull();

      if (current == null) return;

      // Mark current as not current
      await (_db.update(_db.ratingRecords)
            ..where((r) => r.id.equals(currentRatingId)))
          .write(const RatingRecordsCompanion(isCurrent: Value(false)));

      // Restore previous if exists
      if (current.previousId != null) {
        await (_db.update(_db.ratingRecords)
              ..where((r) => r.id.equals(current.previousId!)))
            .write(const RatingRecordsCompanion(isCurrent: Value(true)));
      }

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(current.trialId),
              sessionId: Value(current.sessionId),
              plotPk: Value(current.plotPk),
              eventType: 'RATING_UNDONE',
              description: 'Rating undone',
              performedBy: Value(raterName),
            ),
          );
    });
  }

  // Void rating — marks invalid, creates deviation flag
  Future<void> voidRating({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
    required String reason,
    String? raterName,
  }) async {
    await saveRating(
      trialId: trialId,
      plotPk: plotPk,
      assessmentId: assessmentId,
      sessionId: sessionId,
      resultStatus: 'VOID',
      raterName: raterName,
    );

    await _db.into(_db.deviationFlags).insert(
          DeviationFlagsCompanion.insert(
            trialId: trialId,
            sessionId: sessionId,
            plotPk: Value(plotPk),
            deviationType: 'VOID_RATING',
            description: Value(reason),
            raterName: Value(raterName),
          ),
        );
  }

  // Get all current ratings for a session
  Future<List<RatingRecord>> getCurrentRatingsForSession(int sessionId) {
    return (_db.select(_db.ratingRecords)
          ..where((r) =>
              r.sessionId.equals(sessionId) & r.isCurrent.equals(true)))
        .get();
  }

  // Get rated plot IDs for a session/assessment
  Future<Set<int>> getRatedPlotPks({
    required int sessionId,
    required int assessmentId,
  }) async {
    final ratings = await (_db.select(_db.ratingRecords)
          ..where((r) =>
              r.sessionId.equals(sessionId) &
              r.assessmentId.equals(assessmentId) &
              r.isCurrent.equals(true)))
        .get();
    return ratings.map((r) => r.plotPk).toSet();
  }
}

class RatingIntegrityException implements Exception {
  final String message;
  RatingIntegrityException(this.message);

  @override
  String toString() => 'Rating integrity violation: $message';
}
