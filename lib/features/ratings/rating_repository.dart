import 'dart:developer' show log;

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../domain/ratings/rating_integrity_exception.dart';
import '../../domain/ratings/result_status.dart';

class RatingRepository {
  final AppDatabase _db;

  RatingRepository(this._db);

  /// Selects candidate **current** rows for the logical key used by
  /// `idx_rating_current` (includes [subUnitId] null vs non-null).
  SimpleSelectStatement<$RatingRecordsTable, RatingRecord>
      _selectCurrentRatingsForLogicalKey({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
    required int? subUnitId,
  }) {
    return _db.select(_db.ratingRecords)
      ..where((r) {
        final base = r.trialId.equals(trialId) &
            r.plotPk.equals(plotPk) &
            r.assessmentId.equals(assessmentId) &
            r.sessionId.equals(sessionId) &
            r.isCurrent.equals(true) &
            r.isDeleted.equals(false);
        if (subUnitId == null) {
          return base & r.subUnitId.isNull();
        }
        return base & r.subUnitId.equals(subUnitId);
      });
  }

  /// Picks the canonical current row; if legacy duplicates exist, keeps the
  /// highest [RatingRecord.id] and clears `is_current` on the rest.
  Future<RatingRecord?> _pickCurrentAndDedupe(
    List<RatingRecord> rows, {
    required String logContext,
  }) async {
    if (rows.isEmpty) return null;
    if (rows.length == 1) return rows.single;
    final sorted = [...rows]..sort((a, b) => b.id.compareTo(a.id));
    final keeper = sorted.first;
    final otherIds = sorted.skip(1).map((r) => r.id).toList();
    log(
      '$logContext: duplicate current ratings (${rows.length}); '
      'keeping id=${keeper.id}; clearing is_current on $otherIds',
      name: 'RatingRepository',
    );
    await (_db.update(_db.ratingRecords)..where((r) => r.id.isIn(otherIds)))
        .write(const RatingRecordsCompanion(isCurrent: Value(false)));
    return keeper;
  }

  // Get current rating for a plot/assessment/session combination
  Future<RatingRecord?> getCurrentRating({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
    int? subUnitId,
  }) async {
    final rows = await _selectCurrentRatingsForLogicalKey(
      trialId: trialId,
      plotPk: plotPk,
      assessmentId: assessmentId,
      sessionId: sessionId,
      subUnitId: subUnitId,
    ).get();
    return _pickCurrentAndDedupe(rows, logContext: 'getCurrentRating');
  }

  // Watch current rating reactively
  Stream<RatingRecord?> watchCurrentRating({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
    int? subUnitId,
  }) {
    return _selectCurrentRatingsForLogicalKey(
      trialId: trialId,
      plotPk: plotPk,
      assessmentId: assessmentId,
      sessionId: sessionId,
      subUnitId: subUnitId,
    ).watch().asyncMap(
          (rows) => _pickCurrentAndDedupe(
            rows,
            logContext: 'watchCurrentRating',
          ),
        );
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

    // Defensive gate: [SaveRatingUseCase] / [RatingValueValidator] own full rules.
    // Repository only enforces status vs numeric column without assessment metadata.
    _assertCoreNumericColumnIntegrity(resultStatus, numericValue);

    return _db.transaction(() => _persistRatingVersionAndAudit(
          trialId: trialId,
          plotPk: plotPk,
          assessmentId: assessmentId,
          sessionId: sessionId,
          resultStatus: resultStatus,
          numericValue: numericValue,
          textValue: textValue,
          subUnitId: subUnitId,
          raterName: raterName,
          performedByUserId: performedByUserId,
          createdAppVersion: createdAppVersion,
          createdDeviceInfo: createdDeviceInfo,
          capturedLatitude: capturedLatitude,
          capturedLongitude: capturedLongitude,
          ratingTime: ratingTime,
          ratingMethod: ratingMethod,
          confidence: confidence,
        ));
  }

  /// New rating row + `RATING_SAVED` audit. Caller must run inside [AppDatabase.transaction].
  Future<RatingRecord> _persistRatingVersionAndAudit({
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
    String? createdAppVersion,
    String? createdDeviceInfo,
    double? capturedLatitude,
    double? capturedLongitude,
    String? ratingTime,
    String? ratingMethod,
    String? confidence,
  }) async {
    final existing = await getCurrentRating(
      trialId: trialId,
      plotPk: plotPk,
      assessmentId: assessmentId,
      sessionId: sessionId,
      subUnitId: subUnitId,
    );

    if (existing != null) {
      await (_db.update(_db.ratingRecords)
            ..where((r) => r.id.equals(existing.id)))
          .write(const RatingRecordsCompanion(isCurrent: Value(false)));
    }

    final nowUtc = DateTime.now().toUtc();
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
            lastEditedAt: existing != null ? Value(nowUtc) : const Value.absent(),
            lastEditedByUserId: existing != null && performedByUserId != null
                ? Value(performedByUserId)
                : const Value.absent(),
          ),
        );

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
    int? performedByUserId,
  }) async {
    if (isSessionClosed) throw SessionClosedException();
    _assertCoreNumericColumnIntegrity('VOID', null);

    await _db.transaction(() async {
      await _persistRatingVersionAndAudit(
        trialId: trialId,
        plotPk: plotPk,
        assessmentId: assessmentId,
        sessionId: sessionId,
        resultStatus: 'VOID',
        numericValue: null,
        textValue: null,
        subUnitId: null,
        raterName: raterName,
        performedByUserId: performedByUserId,
        createdAppVersion: null,
        createdDeviceInfo: null,
        capturedLatitude: null,
        capturedLongitude: null,
        ratingTime: null,
        ratingMethod: null,
        confidence: null,
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
    });
  }

  /// Get a single rating by id (for edit/amendment flow).
  Future<RatingRecord?> getRatingById(int id) {
    return (_db.select(_db.ratingRecords)
          ..where((r) => r.id.equals(id) & r.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// Metadata-only updates on an existing rating row (e.g. [amendmentReason],
  /// [amendedBy], [confidence], editor attribution).
  ///
  /// **Policy:** [saveRating] is the only path that may change [numericValue],
  /// [textValue], or [resultStatus] (new version-chain row + audit). Callers
  /// must route value/status edits through [saveRating] (e.g. via
  /// `SaveRatingUseCase`).
  ///
  /// At least one optional field must be non-null or this throws — there is no
  /// silent no-op for accidental misuse.
  Future<RatingRecord> updateRating({
    required int ratingId,
    String? amendmentReason,
    String? amendedBy,
    String? confidence,
    int? lastEditedByUserId,
  }) async {
    final existing = await getRatingById(ratingId);
    if (existing == null) {
      throw RatingIntegrityException('Rating not found: $ratingId');
    }

    final hasAmendmentReason = amendmentReason != null;
    final hasAmendedBy = amendedBy != null;
    final hasConfidence = confidence != null;
    final hasEditor = lastEditedByUserId != null;
    if (!hasAmendmentReason &&
        !hasAmendedBy &&
        !hasConfidence &&
        !hasEditor) {
      throw RatingIntegrityException(
        'No metadata fields to update. Rating value/status changes must use saveRating.',
      );
    }

    final nowUtc = DateTime.now().toUtc();
    await (_db.update(_db.ratingRecords)..where((r) => r.id.equals(ratingId)))
        .write(
      RatingRecordsCompanion(
        amendmentReason:
            hasAmendmentReason ? Value(amendmentReason) : const Value.absent(),
        amendedBy: hasAmendedBy ? Value(amendedBy) : const Value.absent(),
        confidence: hasConfidence ? Value(confidence) : const Value.absent(),
        lastEditedByUserId:
            hasEditor ? Value(lastEditedByUserId) : const Value.absent(),
        lastEditedAt: Value(nowUtc),
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

  /// Distinct plot PKs with at least one current rating in [sessionId] (any assessment).
  /// Matches [ratedPlotPksProvider] snapshot semantics.
  Future<Set<int>> getRatedPlotPksForSession(int sessionId) async {
    final ratings = await (_db.select(_db.ratingRecords)
          ..where((r) =>
              r.sessionId.equals(sessionId) &
              r.isCurrent.equals(true) &
              r.isDeleted.equals(false)))
        .get();
    return ratings.map((r) => r.plotPk).toSet();
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

  /// Distinct session IDs among [sessionIds] that have at least one
  /// [rating_corrections] row with matching [sessionId] (batched query).
  Future<Set<int>> getSessionIdsWithCorrections(Iterable<int> sessionIds) async {
    final wanted = sessionIds.toSet();
    if (wanted.isEmpty) return {};
    final list = wanted.toList();
    final rows = await (_db.select(_db.ratingCorrections)
          ..where((c) => c.sessionId.isIn(list)))
        .get();
    final out = <int>{};
    for (final c in rows) {
      final sid = c.sessionId;
      if (sid != null && wanted.contains(sid)) out.add(sid);
    }
    return out;
  }

  /// Plot primary keys with at least one correction recorded for [sessionId].
  Future<Set<int>> getPlotPksWithCorrectionsForSession(int sessionId) async {
    final rows = await (_db.select(_db.ratingCorrections)
          ..where((c) =>
              c.sessionId.equals(sessionId) & c.plotPk.isNotNull()))
        .get();
    return {for (final c in rows) if (c.plotPk != null) c.plotPk!};
  }

  /// All non-deleted rating versions for plot / assessment / session (version chain).
  /// Ordered by [RatingRecord.id] ascending (oldest version first).
  Future<List<RatingRecord>> getRatingChainForPlotAssessmentSession({
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
              r.isDeleted.equals(false))
          ..orderBy([(r) => OrderingTerm.asc(r.id)]))
        .get();
  }

  /// Corrections for any rating in [ratingIds], oldest first by [RatingCorrection.correctedAt].
  Future<List<RatingCorrection>> getCorrectionsForRatingIds(
      List<int> ratingIds) async {
    if (ratingIds.isEmpty) return [];
    return (_db.select(_db.ratingCorrections)
          ..where((c) => c.ratingId.isIn(ratingIds))
          ..orderBy([
            (c) => OrderingTerm.asc(c.correctedAt),
            (c) => OrderingTerm.asc(c.id),
          ]))
        .get();
  }

  /// [VOID_RATING] deviation rows for this plot context (void reason text).
  Future<List<DeviationFlag>> getVoidDeviationFlags({
    required int trialId,
    required int sessionId,
    required int plotPk,
  }) {
    return (_db.select(_db.deviationFlags)
          ..where((d) =>
              d.trialId.equals(trialId) &
              d.sessionId.equals(sessionId) &
              d.plotPk.equals(plotPk) &
              d.deviationType.equals('VOID_RATING'))
          ..orderBy([(d) => OrderingTerm.asc(d.createdAt)]))
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
    return _db.transaction(() async {
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

      await (_db.update(_db.ratingRecords)..where((r) => r.id.equals(ratingId)))
          .write(
        RatingRecordsCompanion(
          lastEditedAt: Value(correction.correctedAt),
          lastEditedByUserId: correctedByUserId != null
              ? Value(correctedByUserId)
              : const Value.absent(),
        ),
      );

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
    });
  }
}

/// Non-recorded statuses must not persist a numeric value; unknown statuses reject.
void _assertCoreNumericColumnIntegrity(String resultStatus, double? numericValue) {
  final status = resultStatusFromDb(resultStatus);
  if (status == null) {
    throw RatingIntegrityException('Unknown result status: $resultStatus');
  }
  if (status.mustClearNumericValue && numericValue != null) {
    throw RatingIntegrityException(
      'numericValue must be null when status is ${status.dbString}',
    );
  }
}

/// Thrown when a write is attempted on a closed session.
class SessionClosedException implements Exception {
  @override
  String toString() =>
      'Session is closed. Data is read-only. Use correction workflow if changes are required.';
}
