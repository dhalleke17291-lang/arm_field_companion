import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

/// Reads and writes the ARM column-mapping bridge introduced in Phase 1a.
///
/// The mapping table is the semantic bridge between ARM's
/// `(measurement × date × timing)` column model and this app's
/// `(assessment × session)` rating model. One row per ARM column in the shell;
/// `trial_assessment_id` / `session_id` may both be null for orphan columns
/// (metadata blank in the shell) that must still round-trip through export.
///
/// **ARM-only.** Lives under `lib/data/arm/` and must never be imported from
/// non-ARM features. See `docs/ARM_SEPARATION.md`. Callers outside ARM
/// folders must be allow-listed in the separation boundary test; the only
/// such callers are the composition root and grandfathered export usecases.
class ArmColumnMappingRepository {
  ArmColumnMappingRepository(this._db);

  final AppDatabase _db;

  /// All mapping rows for [trialId], ordered by ARM column index so the
  /// returned list matches the shell's left-to-right column order.
  Future<List<ArmColumnMapping>> getForTrial(int trialId) {
    return (_db.select(_db.armColumnMappings)
          ..where((m) => m.trialId.equals(trialId))
          ..orderBy([(m) => OrderingTerm.asc(m.armColumnIndex)]))
        .get();
  }

  /// ARM session metadata for [sessionId], or null when the session was not
  /// created by the ARM importer. Phase 1c consumers treat null as "no ARM
  /// expectations for this session" and render the session without the ARM
  /// metadata line.
  Future<ArmSessionMetadataData?> getSessionMetadata(int sessionId) {
    return (_db.select(_db.armSessionMetadata)
          ..where((m) => m.sessionId.equals(sessionId))
          ..limit(1))
        .getSingleOrNull();
  }

  /// All ARM session metadata rows for [trialId], joined through
  /// `sessions.trial_id`. Ordered by ARM Rating Date ascending so callers can
  /// render the protocol schedule in chronological order.
  Future<List<ArmSessionMetadataData>> getSessionMetadatasForTrial(
    int trialId,
  ) async {
    final query = _db.select(_db.armSessionMetadata).join([
      innerJoin(
        _db.sessions,
        _db.sessions.id.equalsExp(_db.armSessionMetadata.sessionId),
      ),
    ])
      ..where(_db.sessions.trialId.equals(trialId))
      ..orderBy([OrderingTerm.asc(_db.armSessionMetadata.armRatingDate)]);
    final rows = await query.get();
    return rows.map((r) => r.readTable(_db.armSessionMetadata)).toList();
  }

  /// True if any mapping row exists for [trialId]. Callers use this as the
  /// "is this trial importable through the new Phase 1b path?" gate; when
  /// the mapping is empty, legacy per-column matching still applies.
  Future<bool> hasMappings(int trialId) async {
    final count = await (_db.selectOnly(_db.armColumnMappings)
          ..addColumns([_db.armColumnMappings.id.count()])
          ..where(_db.armColumnMappings.trialId.equals(trialId)))
        .getSingle()
        .then((row) => row.read(_db.armColumnMappings.id.count()) ?? 0);
    return count > 0;
  }

  /// Bulk insert for import-time wiring. Each companion must have
  /// [ArmColumnMappingsCompanion.trialId], [armColumnId], and
  /// [armColumnIndex] set; [trialAssessmentId] and [sessionId] are null for
  /// orphan ARM columns.
  Future<void> insertBulk(List<ArmColumnMappingsCompanion> rows) async {
    if (rows.isEmpty) return;
    await _db.batch((b) {
      b.insertAll(_db.armColumnMappings, rows);
    });
  }

  /// Companion inserts for per-unique-assessment metadata captured by the
  /// ARM importer (one row per deduplicated trial_assessment).
  Future<void> insertAssessmentMetadataBulk(
    List<ArmAssessmentMetadataCompanion> rows,
  ) async {
    if (rows.isEmpty) return;
    await _db.batch((b) {
      b.insertAll(_db.armAssessmentMetadata, rows);
    });
  }

  /// Companion inserts for per-session metadata captured by the ARM importer
  /// (one row per planned session the importer creates).
  Future<void> insertSessionMetadataBulk(
    List<ArmSessionMetadataCompanion> rows,
  ) async {
    if (rows.isEmpty) return;
    await _db.batch((b) {
      b.insertAll(_db.armSessionMetadata, rows);
    });
  }

  /// Applies ARM Rating Shell per-column metadata to one
  /// [ArmAssessmentMetadata] row (identified by `trialAssessmentId`). If no
  /// row exists yet, one is inserted with the given values so shell-link
  /// proposals can target trials whose v59 backfill produced a blank AAM row.
  ///
  /// Merge semantics mirror [TrialAssessmentRepository.applyArmShellLinkFields]:
  /// only non-empty incoming values are applied, and existing non-empty
  /// values that equal the incoming value are left untouched. String
  /// comparisons are case-insensitive for [pestCode] (ARM codes are
  /// canonically upper-case) and case-sensitive for the rest.
  /// Returns whether any field was written.
  ///
  /// Phase 0b-ta (Unit 5b): [pestCode], [seName], [seDescription], and
  /// [ratingType] were added here so the ARM shell-link flow can drive AAM
  /// directly; the same fields are still dual-written to trial_assessments
  /// via [TrialAssessmentRepository.applyArmShellLinkFields] pending Unit 5d.
  Future<bool> applyShellLinkFieldsForTrialAssessment({
    required int trialAssessmentId,
    String? armShellColumnId,
    String? armShellRatingDate,
    int? armColumnIdInteger,
    String? pestCode,
    String? seName,
    String? seDescription,
    String? ratingType,
  }) async {
    final existing = await (_db.select(_db.armAssessmentMetadata)
          ..where((m) => m.trialAssessmentId.equals(trialAssessmentId))
          ..limit(1))
        .getSingleOrNull();

    String? mergeText(String? current, String? incoming) {
      if (incoming == null) return null;
      final s = incoming.trim();
      if (s.isEmpty) return null;
      final c = current?.trim() ?? '';
      if (c.isNotEmpty && c == s) return null;
      return s;
    }

    String? mergePest(String? current, String? incoming) {
      if (incoming == null) return null;
      final s = incoming.trim();
      if (s.isEmpty) return null;
      final c = current?.trim() ?? '';
      if (c.isNotEmpty && c.toUpperCase() == s.toUpperCase()) return null;
      return s;
    }

    final nextColId = mergeText(existing?.armShellColumnId, armShellColumnId);
    final nextRatingDate =
        mergeText(existing?.armShellRatingDate, armShellRatingDate);
    final incomingColInt = armColumnIdInteger;
    final nextColInt = (incomingColInt != null &&
            incomingColInt != existing?.armColumnIdInteger)
        ? incomingColInt
        : null;
    final nextPestCode = mergePest(existing?.pestCode, pestCode);
    final nextSeName = mergeText(existing?.seName, seName);
    final nextSeDesc = mergeText(existing?.seDescription, seDescription);
    final nextRatingType = mergeText(existing?.ratingType, ratingType);

    final touched = nextColId != null ||
        nextRatingDate != null ||
        nextColInt != null ||
        nextPestCode != null ||
        nextSeName != null ||
        nextSeDesc != null ||
        nextRatingType != null;
    if (!touched) return false;

    if (existing == null) {
      await _db.into(_db.armAssessmentMetadata).insert(
            ArmAssessmentMetadataCompanion.insert(
              trialAssessmentId: trialAssessmentId,
              armShellColumnId: Value(nextColId),
              armShellRatingDate: Value(nextRatingDate),
              armColumnIdInteger: Value(nextColInt),
              pestCode: Value(nextPestCode),
              seName: Value(nextSeName),
              seDescription: Value(nextSeDesc),
              ratingType: Value(nextRatingType),
            ),
          );
      return true;
    }

    final companion = ArmAssessmentMetadataCompanion(
      armShellColumnId:
          nextColId == null ? const Value.absent() : Value(nextColId),
      armShellRatingDate: nextRatingDate == null
          ? const Value.absent()
          : Value(nextRatingDate),
      armColumnIdInteger:
          nextColInt == null ? const Value.absent() : Value(nextColInt),
      pestCode:
          nextPestCode == null ? const Value.absent() : Value(nextPestCode),
      seName: nextSeName == null ? const Value.absent() : Value(nextSeName),
      seDescription:
          nextSeDesc == null ? const Value.absent() : Value(nextSeDesc),
      ratingType: nextRatingType == null
          ? const Value.absent()
          : Value(nextRatingType),
    );
    await (_db.update(_db.armAssessmentMetadata)
          ..where((m) => m.trialAssessmentId.equals(trialAssessmentId)))
        .write(companion);
    return true;
  }

  /// ARM assessment header rows for [trialId] (deduplicated per trial assessment).
  Future<List<ArmAssessmentMetadataData>> getAssessmentMetadatasForTrial(
    int trialId,
  ) async {
    final q = _db.select(_db.armAssessmentMetadata).join([
      innerJoin(
        _db.trialAssessments,
        _db.trialAssessments.id
            .equalsExp(_db.armAssessmentMetadata.trialAssessmentId),
      ),
    ])
      ..where(_db.trialAssessments.trialId.equals(trialId))
      ..orderBy([OrderingTerm.asc(_db.armAssessmentMetadata.id)]);
    final rows = await q.get();
    return rows.map((r) => r.readTable(_db.armAssessmentMetadata)).toList();
  }
}
