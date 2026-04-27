import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

/// Persistence for [ArmTreatmentMetadata] (Phase 0b-treatments).
///
/// **ARM-only** data path; core [Treatments] / [TreatmentComponents] stay
/// free of ARM-specific coding (Type, Form Conc, Form Conc Unit, Form
/// Type). Standalone trials have zero rows here.
///
/// Phase 0b introduces this repository as a scaffold — it is not yet
/// wired to any importer or UI. Phase 2 (Treatments-sheet import) will
/// populate rows; the ARM Protocol tab's Treatments sub-section (Phase 6)
/// will read them.
class ArmTreatmentMetadataRepository {
  ArmTreatmentMetadataRepository(this._db);

  final AppDatabase _db;

  /// Fetch the ARM treatment-metadata row for a given core treatment, or
  /// null if none exists (standalone trials, or ARM trials whose
  /// Treatments sheet was never imported).
  Future<ArmTreatmentMetadataData?> getForTreatment(int treatmentId) {
    return (_db.select(_db.armTreatmentMetadata)
          ..where((m) => m.treatmentId.equals(treatmentId)))
        .getSingleOrNull();
  }

  /// Stream version of [getForTreatment], for UI consumers that need to
  /// react to writes (e.g. the ARM Protocol Treatments sub-section).
  Stream<ArmTreatmentMetadataData?> watchForTreatment(int treatmentId) {
    return (_db.select(_db.armTreatmentMetadata)
          ..where((m) => m.treatmentId.equals(treatmentId)))
        .watch()
        .map((rows) => rows.singleOrNull);
  }

  /// All ARM treatment-metadata rows for a trial's treatments, keyed by
  /// `treatmentId`. Convenience for list screens that want one query per
  /// trial rather than N queries per treatment.
  Future<Map<int, ArmTreatmentMetadataData>> getMapForTrial(int trialId) async {
    final query = _db.select(_db.armTreatmentMetadata).join([
      innerJoin(
        _db.treatments,
        _db.treatments.id.equalsExp(_db.armTreatmentMetadata.treatmentId),
      ),
    ])
      ..where(_db.treatments.trialId.equals(trialId));
    final rows = await query.get();
    return {
      for (final r in rows)
        r.readTable(_db.armTreatmentMetadata).treatmentId:
            r.readTable(_db.armTreatmentMetadata),
    };
  }

  /// Upsert an ARM treatment-metadata row. Idempotent on `treatmentId`.
  Future<void> upsert(ArmTreatmentMetadataCompanion row) {
    return _db.into(_db.armTreatmentMetadata).insertOnConflictUpdate(row);
  }

  /// Bulk insert for the Treatments-sheet importer (Phase 2). Uses a
  /// transaction so partial failures roll back.
  Future<void> insertBulk(List<ArmTreatmentMetadataCompanion> rows) {
    return _db.batch((b) {
      b.insertAll(_db.armTreatmentMetadata, rows);
    });
  }

  /// Delete all ARM treatment-metadata rows for a trial (used when
  /// re-importing the Treatments sheet or resetting ARM linkage).
  Future<int> deleteForTrial(int trialId) async {
    final treatmentIds = await (_db.select(_db.treatments)
          ..where((t) => t.trialId.equals(trialId)))
        .get()
        .then((rows) => rows.map((r) => r.id).toList());
    if (treatmentIds.isEmpty) return 0;
    return (_db.delete(_db.armTreatmentMetadata)
          ..where((m) => m.treatmentId.isIn(treatmentIds)))
        .go();
  }
}
