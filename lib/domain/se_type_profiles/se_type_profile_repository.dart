import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';

/// Read-only access layer for the [SeTypeProfiles] reference table.
///
/// Returns Drift-generated [SeTypeProfile] objects directly — no mapping layer.
/// No computation, no biological logic, no providers.
class SeTypeProfileRepository {
  final AppDatabase _db;

  const SeTypeProfileRepository(this._db);

  /// Returns the profile whose [SeTypeProfile.ratingTypePrefix] exactly matches
  /// [prefix] (case-sensitive), or null if no row exists.
  Future<SeTypeProfile?> getByPrefix(String prefix) =>
      (_db.select(_db.seTypeProfiles)
            ..where((t) => t.ratingTypePrefix.equals(prefix)))
          .getSingleOrNull();

  /// Returns all seeded profiles ordered by prefix ascending.
  Future<List<SeTypeProfile>> getAll() =>
      (_db.select(_db.seTypeProfiles)
            ..orderBy([(t) => OrderingTerm.asc(t.ratingTypePrefix)]))
          .get();
}

/// Returns true if [p] has an observation-window lower bound defined.
/// Checks field presence only — does not compute the window or any DAT value.
bool hasValidWindow(SeTypeProfile p) =>
    p.validObservationWindowMinDat != null;

/// Returns true if [p] has both expected CV bounds defined.
/// Checks field presence only — does not compute or evaluate thresholds.
bool hasCvBounds(SeTypeProfile p) =>
    p.expectedCvMin != null && p.expectedCvMax != null;
