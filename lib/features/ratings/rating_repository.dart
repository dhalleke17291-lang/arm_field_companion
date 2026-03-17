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
              r.isCurrent.equals(true) &
              r.isDeleted.equals(false)))
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
              r.isCurrent.equals(true) &
              r.isDeleted.equals(false)))
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
    int? performedByUserId,
    required bool isSessionClosed,
    String? createdAppVersion,
    String? createdDeviceInfo,
    double? capturedLatitude,
    double? capturedLongitude,
    String? ratingTime,
    String? ratingMethod,
    String? confidence,
  }) async {
    if (isSessionClosed) throw SessionClosedException();

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
            .write(const RatingRecordsCompanion(isCurrent: Value(false)));
      }

      // Insert new current record (with optional provenance and rating metadata)
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
              createdAppVersion: Value(createdAppVersion),
              createdDeviceInfo: Value(createdDeviceInfo),
              capturedLatitude: Value(capturedLatitude),
              capturedLongitude: Value(capturedLongitude),
              ratingTime: Value(ratingTime),
              ratingMethod: Value(ratingMethod),
              confidence: Value(confidence),
            ),
          );

      // Write audit event
      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(trialId),
              sessionId: Value(sessionId),
              plotPk: Value(plotPk),
              eventType: 'RATING_SAVED',
              description: 'Rating saved: $resultStatus ${numericValue ?? ""}',
              performedBy: Value(raterName),
              performedByUserId: Value(performedByUserId),
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
    required int sessionId,
    String? raterName,
    int? performedByUserId,
  }) async {
    final session = await (_db.select(_db.sessions)
          ..where((s) => s.id.equals(sessionId) & s.isDeleted.equals(false)))
        .getSingleOrNull();
    if (session != null && session.endedAt != null) {
      throw SessionClosedException();
    }

    return _db.transaction(() async {
      final current = await (_db.select(_db.ratingRecords)
            ..where((r) =>
                r.id.equals(currentRatingId) & r.isDeleted.equals(false)))
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
              performedByUserId: Value(performedByUserId),
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
    required bool isSessionClosed,
    String? raterName,
  }) async {
    await saveRating(
      trialId: trialId,
      plotPk: plotPk,
      assessmentId: assessmentId,
      sessionId: sessionId,
      resultStatus: 'VOID',
      raterName: raterName,
      isSessionClosed: isSessionClosed,
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

  /// Get a single rating by id (for edit/amendment flow).
  Future<RatingRecord?> getRatingById(int id) {
    return (_db.select(_db.ratingRecords)
          ..where((r) => r.id.equals(id) & r.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// Update an existing rating (edit flow). Applies amendment logic: if the
  /// stored value is changed and there was an existing value, sets amended=true,
  /// amended_at=now(), and preserves original_value only if currently null.
  Future<RatingRecord> updateRating({
    required int ratingId,
    double? numericValue,
    String? textValue,
    String? resultStatus,
    String? amendmentReason,
    String? amendedBy,
    String? confidence,
  }) async {
    final existing = await getRatingById(ratingId);
    if (existing == null) throw RatingIntegrityException('Rating not found: $ratingId');

    final newNum = numericValue ?? existing.numericValue;
    final newText = textValue ?? existing.textValue;
    final newStatus = resultStatus ?? existing.resultStatus;

    final existingValueStr = existing.numericValue?.toString() ?? existing.textValue ?? '';
    final newValueStr = newNum?.toString() ?? newText ?? '';
    final valueChanged = existingValueStr != newValueStr && existingValueStr.isNotEmpty;

    bool amended = existing.amended;
    DateTime? amendedAt = existing.amendedAt;
    String? originalValue = existing.originalValue;

    if (valueChanged) {
      amended = true;
      amendedAt = DateTime.now().toUtc();
      if (originalValue == null || originalValue.isEmpty) {
        originalValue = existingValueStr;
      }
    }

    await (_db.update(_db.ratingRecords)..where((r) => r.id.equals(ratingId)))
        .write(
      RatingRecordsCompanion(
        numericValue: Value(newNum),
        textValue: Value(newText),
        resultStatus: Value(newStatus),
        amended: Value(amended),
        amendedAt: Value(amendedAt),
        originalValue: Value(originalValue),
        amendmentReason: amendmentReason != null ? Value(amendmentReason) : const Value.absent(),
        amendedBy: amendedBy != null ? Value(amendedBy) : const Value.absent(),
        confidence: confidence != null ? Value(confidence) : const Value.absent(),
      ),
    );

    return (await getRatingById(ratingId))!;
  }

  // Get all current ratings for a session
  Future<List<RatingRecord>> getCurrentRatingsForSession(int sessionId) {
    return (_db.select(_db.ratingRecords)
          ..where((r) =>
              r.sessionId.equals(sessionId) &
              r.isCurrent.equals(true) &
              r.isDeleted.equals(false)))
        .get();
  }

  /// Recovery export: every [rating_records] row for [sessionId], including
  /// soft-deleted ratings and non-current chain members. Ordered by id ascending.
  Future<List<RatingRecord>> getRatingRecordsForSessionRecoveryExport(
      int sessionId) {
    return (_db.select(_db.ratingRecords)
          ..where((r) => r.sessionId.equals(sessionId))
          ..orderBy([(r) => OrderingTerm.asc(r.id)]))
        .get();
  }

  /// Recovery export: all [rating_records] for [trialId] (any isDeleted / isCurrent).
  /// Ordered by id ascending for stable analysis dumps.
  Future<List<RatingRecord>> getRatingRecordsForTrialRecoveryExport(
      int trialId) {
    return (_db.select(_db.ratingRecords)
          ..where((r) => r.trialId.equals(trialId))
          ..orderBy([(r) => OrderingTerm.asc(r.id)]))
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
              r.isCurrent.equals(true) &
              r.isDeleted.equals(false)))
        .get();
    return ratings.map((r) => r.plotPk).toSet();
  }

  /// Count of distinct plots with at least one current rating for this trial (Trial Summary).
  Future<int> getRatedPlotCountForTrial(int trialId) async {
    final ratings = await (_db.select(_db.ratingRecords)
          ..where((r) =>
              r.trialId.equals(trialId) &
              r.isCurrent.equals(true) &
              r.isDeleted.equals(false)))
        .get();
    return ratings.map((r) => r.plotPk).toSet().length;
  }

  // --- Correction (immutable; original rating unchanged) ---

  Future<RatingCorrection?> getLatestCorrectionForRating(int ratingId) {
    return (_db.select(_db.ratingCorrections)
          ..where((c) => c.ratingId.equals(ratingId))
          ..orderBy([(c) => OrderingTerm.desc(c.correctedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<RatingCorrection>> getCorrectionsForRating(int ratingId) {
    return (_db.select(_db.ratingCorrections)
          ..where((c) => c.ratingId.equals(ratingId))
          ..orderBy([(c) => OrderingTerm.desc(c.correctedAt)]))
        .get();
  }

  /// Applies a correction (closed sessions only). Original rating is never updated.
  Future<RatingCorrection> applyCorrection({
    required int ratingId,
    required String oldResultStatus,
    required String newResultStatus,
    double? oldNumericValue,
    double? newNumericValue,
    String? oldTextValue,
    String? newTextValue,
    required String reason,
    int? correctedByUserId,
    int? sessionId,
    int? plotPk,
  }) async {
    final id = await _db.into(_db.ratingCorrections).insert(
          RatingCorrectionsCompanion.insert(
            ratingId: ratingId,
            oldResultStatus: oldResultStatus,
            newResultStatus: newResultStatus,
            oldNumericValue: Value(oldNumericValue),
            newNumericValue: Value(newNumericValue),
            oldTextValue: Value(oldTextValue),
            newTextValue: Value(newTextValue),
            reason: reason,
            correctedByUserId: Value(correctedByUserId),
            sessionId: Value(sessionId),
            plotPk: Value(plotPk),
          ),
        );
    final correction = await (_db.select(_db.ratingCorrections)
          ..where((c) => c.id.equals(id)))
        .getSingle();

    final rating = await (_db.select(_db.ratingRecords)
          ..where((r) => r.id.equals(ratingId)))
        .getSingleOrNull();
    if (rating != null) {
      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(rating.trialId),
              sessionId: Value(rating.sessionId),
              plotPk: Value(rating.plotPk),
              eventType: 'RATING_CORRECTED',
              description: 'Correction: $reason',
              performedByUserId: Value(correctedByUserId),
            ),
          );
    }
    return correction;
  }
}

class RatingIntegrityException implements Exception {
  final String message;
  RatingIntegrityException(this.message);

  @override
  String toString() => 'Rating integrity violation: $message';
}

/// Thrown when a write is attempted on a closed session.
class SessionClosedException implements Exception {
  @override
  String toString() =>
      'Session is closed. Data is read-only. Use correction workflow if changes are required.';
}
