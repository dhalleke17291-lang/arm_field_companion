import 'package:drift/drift.dart' as drift_sql;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart' as db;
import '../../core/providers.dart';

/// Domain mirror of `se_type_causal_profiles` (EPPO-aligned seeds).
class SeTypeCausalProfile {
  const SeTypeCausalProfile({
    required this.id,
    required this.seType,
    required this.trialType,
    required this.causalWindowDaysMin,
    required this.causalWindowDaysMax,
    required this.expectedResponseDirection,
    this.expectedChangeRatePerWeek,
    required this.spatialClusteringExpected,
    required this.untreatedExcludedFromMean,
    required this.baseThresholdSdMultiplier,
    required this.source,
    this.sourceReference,
    required this.createdAt,
  });

  final int id;
  final String seType;
  final String trialType;
  final int causalWindowDaysMin;
  final int causalWindowDaysMax;
  final String expectedResponseDirection;
  final double? expectedChangeRatePerWeek;
  final bool spatialClusteringExpected;
  final bool untreatedExcludedFromMean;
  final double baseThresholdSdMultiplier;
  final String source;
  final String? sourceReference;
  final int createdAt;

  factory SeTypeCausalProfile.fromDrift(db.SeTypeCausalProfile row) {
    return SeTypeCausalProfile(
      id: row.id,
      seType: row.seType,
      trialType: row.trialType,
      causalWindowDaysMin: row.causalWindowDaysMin,
      causalWindowDaysMax: row.causalWindowDaysMax,
      expectedResponseDirection: row.expectedResponseDirection,
      expectedChangeRatePerWeek: row.expectedChangeRatePerWeek,
      spatialClusteringExpected: row.spatialClusteringExpected,
      untreatedExcludedFromMean: row.untreatedExcludedFromMean,
      baseThresholdSdMultiplier: row.baseThresholdSdMultiplier,
      source: row.source,
      sourceReference: row.sourceReference,
      createdAt: row.createdAt,
    );
  }
}

/// Lookup key for causal profiles (`se_type` × `trial_type`).
class SeTypeProfileKey {
  const SeTypeProfileKey({
    required this.seType,
    required this.trialType,
  });

  final String seType;
  final String trialType;

  @override
  bool operator ==(Object other) =>
      other is SeTypeProfileKey &&
      other.seType == seType &&
      other.trialType == trialType;

  @override
  int get hashCode => Object.hash(seType, trialType);
}

final seTypeCausalProfileProvider =
    FutureProvider.family<SeTypeCausalProfile?, SeTypeProfileKey>(
        (ref, key) async {
  final database = ref.watch(databaseProvider);
  final row = await (database.select(database.seTypeCausalProfiles)
        ..where((p) => p.seType.equals(key.seType))
        ..where((p) => p.trialType.equals(key.trialType)))
      .getSingleOrNull();
  return row != null ? SeTypeCausalProfile.fromDrift(row) : null;
});

final seTypeCausalProfilesAllProvider =
    FutureProvider<List<SeTypeCausalProfile>>((ref) async {
  final database = ref.watch(databaseProvider);
  final rows = await (database.select(database.seTypeCausalProfiles)
        ..orderBy([(p) => drift_sql.OrderingTerm.asc(p.seType)]))
      .get();
  return rows.map(SeTypeCausalProfile.fromDrift).toList();
});

/// Looks up the causal profile for a (seType, trialType) pair.
///
/// Matches on (seType, trialType) only. Region-aware lookup is deferred until
/// the se_type_causal_profiles schema adds a region column.
/// Returns null if no matching row exists.
Future<SeTypeCausalProfile?> lookupCausalProfile(
  db.AppDatabase database,
  String seType,
  String trialType,
) async {
  final row = await (database.select(database.seTypeCausalProfiles)
        ..where((p) => p.seType.equals(seType))
        ..where((p) => p.trialType.equals(trialType)))
      .getSingleOrNull();
  return row != null ? SeTypeCausalProfile.fromDrift(row) : null;
}
