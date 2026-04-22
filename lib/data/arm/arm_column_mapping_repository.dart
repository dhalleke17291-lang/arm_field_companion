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
}
