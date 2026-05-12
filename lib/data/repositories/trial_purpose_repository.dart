import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../domain/trial_cognition/trial_intent_inferrer.dart';

class TrialPurposeRepository {
  TrialPurposeRepository(this._db);

  final AppDatabase _db;

  /// Current active purpose = newest non-superseded row for this trial.
  Future<TrialPurpose?> getCurrentTrialPurpose(int trialId) {
    return (_db.select(_db.trialPurposes)
          ..where(
            (p) => p.trialId.equals(trialId) & p.supersededAt.isNull(),
          )
          ..orderBy([(p) => OrderingTerm.desc(p.version)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Returns the newest non-superseded row only if its status is 'confirmed'.
  /// Used by ARM import to guard against re-seeding when a confirmed row exists,
  /// while still allowing the import to proceed when only a draft row is present.
  Future<TrialPurpose?> getConfirmedTrialPurpose(int trialId) {
    return (_db.select(_db.trialPurposes)
          ..where(
            (p) =>
                p.trialId.equals(trialId) &
                p.supersededAt.isNull() &
                p.status.equals('confirmed'),
          )
          ..orderBy([(p) => OrderingTerm.desc(p.version)])
          ..limit(1))
        .getSingleOrNull();
  }

  Stream<TrialPurpose?> watchCurrentTrialPurpose(int trialId) {
    final q = _db.select(_db.trialPurposes)
      ..where(
        (p) => p.trialId.equals(trialId) & p.supersededAt.isNull(),
      )
      ..orderBy([(p) => OrderingTerm.desc(p.version)])
      ..limit(1);
    return q.watch().map((rows) => rows.isEmpty ? null : rows.first);
  }

  Future<int> createInitialTrialPurpose({
    required int trialId,
    String status = 'draft',
    int requiresConfirmation = 1,
    String sourceMode = 'manual_revelation',
    String? claimBeingTested,
    String? trialPurpose,
    String? regulatoryContext,
    String? primaryEndpoint,
    String? treatmentRoleSummary,
    String? knownInterpretationFactors,
    String? inferredFieldsJson,
    String? plannedDatByAssessment,
    int? protocolTimingWindow,
  }) {
    return _db.into(_db.trialPurposes).insert(
          TrialPurposesCompanion.insert(
            trialId: trialId,
            status: Value(status),
            requiresConfirmation: Value(requiresConfirmation),
            sourceMode: Value(sourceMode),
            claimBeingTested: Value(claimBeingTested),
            trialPurpose: Value(trialPurpose),
            regulatoryContext: Value(regulatoryContext),
            primaryEndpoint: Value(primaryEndpoint),
            treatmentRoleSummary: Value(treatmentRoleSummary),
            knownInterpretationFactors: Value(knownInterpretationFactors),
            inferredFieldsJson: Value(inferredFieldsJson),
            plannedDatByAssessment: Value(plannedDatByAssessment),
            protocolTimingWindow: Value(protocolTimingWindow),
          ),
        );
  }

  /// Creates a new version and marks the previous one superseded.
  Future<int> createNewTrialPurposeVersion(
    TrialPurpose previous,
    TrialPurposesCompanion updates,
  ) {
    return _db.transaction(() async {
      await supersedeTrialPurpose(previous.id);
      return _db.into(_db.trialPurposes).insert(
            updates.copyWith(
              trialId: Value(previous.trialId),
              version: Value(previous.version + 1),
              supersededAt: const Value(null),
            ),
          );
    });
  }

  Future<void> confirmTrialPurpose(int purposeId, {String? confirmedBy}) {
    return (_db.update(_db.trialPurposes)
          ..where((p) => p.id.equals(purposeId)))
        .write(TrialPurposesCompanion(
      status: const Value('confirmed'),
      confirmedAt: Value(DateTime.now().toUtc()),
      confirmedBy: Value(confirmedBy),
      requiresConfirmation: const Value(0),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
  }

  /// Writes an inferred purpose row for [trialId].
  /// Stores confidence JSON in [inferredFieldsJson] alongside text values
  /// in the named columns. Sets [requiresConfirmation] = 1 so Section 1
  /// shows the confirmation banner until the researcher reviews it.
  Future<int> createInferredTrialPurpose({
    required int trialId,
    required InferredTrialPurpose inferred,
    required String sourceMode,
  }) {
    final testItems = inferred.treatmentRoles
        .where((r) => r.inferredRole == 'test_item')
        .map((r) => r.treatmentName)
        .join(', ');
    final checkTreatments = inferred.treatmentRoles
        .where((r) => r.inferredRole == 'untreated_check' ||
            r.inferredRole == 'reference_standard')
        .map((r) => '${r.treatmentName} (${r.inferredRole})')
        .join(', ');
    final rolesSummary = [
      if (testItems.isNotEmpty) 'Test items: $testItems',
      if (checkTreatments.isNotEmpty) 'Controls/standards: $checkTreatments',
    ].join('; ');

    return _db.into(_db.trialPurposes).insert(
          TrialPurposesCompanion.insert(
            trialId: trialId,
            status: const Value('draft'),
            sourceMode: Value(sourceMode),
            claimBeingTested: Value(
              inferred.claimConfidence == FieldConfidence.high ||
                      inferred.claimConfidence == FieldConfidence.moderate
                  ? inferred.claimStatement
                  : null,
            ),
            primaryEndpoint: Value(
              inferred.primaryEndpointConfidence == FieldConfidence.high ||
                      inferred.primaryEndpointConfidence ==
                          FieldConfidence.moderate
                  ? inferred.primaryEndpointAssessmentKey
                  : null,
            ),
            treatmentRoleSummary: Value(rolesSummary.isEmpty ? null : rolesSummary),
            regulatoryContext: Value(
              inferred.regulatoryContextConfidence == FieldConfidence.high ||
                      inferred.regulatoryContextConfidence ==
                          FieldConfidence.moderate
                  ? inferred.regulatoryContext
                  : null,
            ),
            inferredFieldsJson: Value(inferred.toJsonString()),
            requiresConfirmation: const Value(1),
          ),
        );
  }

  /// Updates only [regulatoryContext] on the current active purpose row.
  ///
  /// Does not create a new version, does not touch [requiresConfirmation],
  /// [inferredFieldsJson], or any other field. No-op when no active row exists.
  Future<void> updateRegulatoryContext(int trialId, String value) {
    return (_db.update(_db.trialPurposes)
          ..where(
            (p) => p.trialId.equals(trialId) & p.supersededAt.isNull(),
          ))
        .write(TrialPurposesCompanion(
      regulatoryContext: Value(value),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
  }

  /// Updates only [knownInterpretationFactors] on the current active purpose row.
  ///
  /// Does not create a new version, does not touch [regulatoryContext],
  /// [trialPurpose], [requiresConfirmation], or any other field.
  /// Creates an initial purpose row if none exists so first-session answers are
  /// preserved instead of being silently dropped by a zero-row update.
  Future<void> updateKnownInterpretationFactors(int trialId, String? json) async {
    // Guard: if no active row exists the update silently matches zero rows.
    // Create the row first so the write is guaranteed to land.
    final existing = await getCurrentTrialPurpose(trialId);
    if (existing == null) {
      await createInitialTrialPurpose(trialId: trialId);
    }

    await (_db.update(_db.trialPurposes)
          ..where(
            (p) => p.trialId.equals(trialId) & p.supersededAt.isNull(),
          ))
        .write(TrialPurposesCompanion(
      knownInterpretationFactors: Value(json),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
  }

  Future<void> supersedeTrialPurpose(int purposeId) {
    return (_db.update(_db.trialPurposes)
          ..where((p) => p.id.equals(purposeId)))
        .write(TrialPurposesCompanion(
      status: const Value('superseded'),
      supersededAt: Value(DateTime.now().toUtc()),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
  }
}
