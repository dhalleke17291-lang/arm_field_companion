import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

/// Well-known CTQ factor keys.
const List<String> kCtqDefaultFactorKeys = [
  'application_timing',
  'rating_window',
  'disease_pressure',
  'crop_stage',
  'rainfall_after_application',
  'plot_completeness',
  'treatment_identity',
  'rater_consistency',
  'photo_evidence',
  'gps_evidence',
  'data_variance',
  'untreated_check_pressure',
];

const _kDefaultCtqFactors = [
  (key: 'application_timing', label: 'Application Timing', type: 'operational', importance: 'critical'),
  (key: 'rating_window', label: 'Rating Window', type: 'operational', importance: 'critical'),
  (key: 'disease_pressure', label: 'Disease Pressure', type: 'field_condition', importance: 'standard'),
  (key: 'crop_stage', label: 'Crop Stage', type: 'field_condition', importance: 'standard'),
  (key: 'rainfall_after_application', label: 'Rainfall After Application', type: 'field_condition', importance: 'standard'),
  (key: 'plot_completeness', label: 'Plot Completeness', type: 'data_completeness', importance: 'critical'),
  (key: 'treatment_identity', label: 'Treatment Identity', type: 'data_integrity', importance: 'critical'),
  (key: 'rater_consistency', label: 'Rater Consistency', type: 'data_integrity', importance: 'standard'),
  (key: 'photo_evidence', label: 'Photo Evidence', type: 'documentation', importance: 'standard'),
  (key: 'gps_evidence', label: 'GPS Evidence', type: 'documentation', importance: 'supplementary'),
  (key: 'data_variance', label: 'Data Variance', type: 'interpretation_risk', importance: 'high'),
  (key: 'untreated_check_pressure', label: 'Untreated Check Pressure', type: 'interpretation_risk', importance: 'high'),
];

class CtqFactorDefinitionRepository {
  CtqFactorDefinitionRepository(this._db);

  final AppDatabase _db;

  Stream<List<CtqFactorDefinition>> watchCtqFactorsForTrial(int trialId) {
    return (_db.select(_db.ctqFactorDefinitions)
          ..where(
            (f) => f.trialId.equals(trialId) & f.retiredAt.isNull(),
          )
          ..orderBy([(f) => OrderingTerm.asc(f.createdAt)]))
        .watch();
  }

  /// Returns factors scoped to a single purpose version. Use this instead of
  /// [watchCtqFactorsForTrial] when evaluating the current purpose to avoid
  /// mixing factors from superseded purpose versions.
  Stream<List<CtqFactorDefinition>> watchCtqFactorsForPurpose(
      int trialPurposeId) {
    return (_db.select(_db.ctqFactorDefinitions)
          ..where(
            (f) =>
                f.trialPurposeId.equals(trialPurposeId) & f.retiredAt.isNull(),
          )
          ..orderBy([(f) => OrderingTerm.asc(f.createdAt)]))
        .watch();
  }

  Future<int> addCtqFactorDefinition({
    required int trialId,
    required int trialPurposeId,
    required String factorKey,
    required String factorLabel,
    required String factorType,
    String importance = 'standard',
    String? expectedEvidenceType,
    String? evaluationRuleKey,
    String? description,
    required String source,
  }) {
    return _db.into(_db.ctqFactorDefinitions).insert(
          CtqFactorDefinitionsCompanion.insert(
            trialId: trialId,
            trialPurposeId: trialPurposeId,
            factorKey: factorKey,
            factorLabel: factorLabel,
            factorType: factorType,
            importance: Value(importance),
            expectedEvidenceType: Value(expectedEvidenceType),
            evaluationRuleKey: Value(evaluationRuleKey),
            description: Value(description),
            source: source,
          ),
        );
  }

  Future<void> retireCtqFactorDefinition(int id) {
    return (_db.update(_db.ctqFactorDefinitions)
          ..where((f) => f.id.equals(id)))
        .write(CtqFactorDefinitionsCompanion(
      retiredAt: Value(DateTime.now().toUtc()),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
  }

  /// Seeds default CTQ factors for a purpose. Additive per key — inserts only
  /// keys that are not already present, leaving existing rows untouched.
  Future<void> seedDefaultCtqFactorsForPurpose({
    required int trialId,
    required int trialPurposeId,
  }) async {
    final existing = await (_db.select(_db.ctqFactorDefinitions)
          ..where((f) => f.trialPurposeId.equals(trialPurposeId)))
        .get();
    final existingKeys = existing.map((f) => f.factorKey).toSet();
    final toSeed =
        _kDefaultCtqFactors.where((f) => !existingKeys.contains(f.key));
    for (final f in toSeed) {
      await addCtqFactorDefinition(
        trialId: trialId,
        trialPurposeId: trialPurposeId,
        factorKey: f.key,
        factorLabel: f.label,
        factorType: f.type,
        importance: f.importance,
        source: 'system_default',
      );
    }
  }
}
