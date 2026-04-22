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
