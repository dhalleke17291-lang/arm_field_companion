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

/// Lookup key for causal profiles (`se_type` × `trial_type` × `region`).
class SeTypeProfileKey {
  const SeTypeProfileKey({
    required this.seType,
    required this.trialType,
    this.region,
  });

  final String seType;
  final String trialType;

  /// Trial region for region-aware lookup. Null means region-agnostic.
  final String? region;

  @override
  bool operator ==(Object other) =>
      other is SeTypeProfileKey &&
      other.seType == seType &&
      other.trialType == trialType &&
      other.region == region;

  @override
  int get hashCode => Object.hash(seType, trialType, region);
}

final seTypeCausalProfileProvider =
    FutureProvider.family<SeTypeCausalProfile?, SeTypeProfileKey>(
        (ref, key) async {
  final database = ref.watch(databaseProvider);
  return lookupCausalProfile(database, key.seType, key.trialType, key.region);
});

final seTypeCausalProfilesAllProvider =
    FutureProvider<List<SeTypeCausalProfile>>((ref) async {
  final database = ref.watch(databaseProvider);
  final rows = await (database.select(database.seTypeCausalProfiles)
        ..orderBy([(p) => drift_sql.OrderingTerm.asc(p.seType)]))
      .get();
  return rows.map(SeTypeCausalProfile.fromDrift).toList();
});

/// Looks up the causal profile for a (seType, trialType, region) triple.
///
/// 3-step resolution:
///   1. Profile matching seType AND trialType AND region (exact region match).
///   2. Profile matching seType AND trialType AND region IS NULL (universal fallback).
///   3. No profile — returns null.
///
/// This never calls getSingleOrNull() on an unfiltered (seType, trialType)
/// result, so it is safe when both NULL-region and region-specific rows exist.
Future<SeTypeCausalProfile?> lookupCausalProfile(
  db.AppDatabase database,
  String seType,
  String trialType,
  String? region,
) async {
  // Step 1: region-specific match (skipped when region is null).
  if (region != null) {
    final row = await (database.select(database.seTypeCausalProfiles)
          ..where((p) => p.seType.equals(seType))
          ..where((p) => p.trialType.equals(trialType))
          ..where((p) => p.region.equals(region)))
        .getSingleOrNull();
    if (row != null) return SeTypeCausalProfile.fromDrift(row);
  }

  // Step 2: universal (null-region) fallback.
  final rows = await (database.select(database.seTypeCausalProfiles)
        ..where((p) => p.seType.equals(seType))
        ..where((p) => p.trialType.equals(trialType))
        ..where((p) => p.region.isNull()))
      .get();
  return rows.isNotEmpty ? SeTypeCausalProfile.fromDrift(rows.first) : null;
}
