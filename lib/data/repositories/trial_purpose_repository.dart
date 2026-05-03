import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

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
    String sourceMode = 'manual_revelation',
    String? claimBeingTested,
    String? trialPurpose,
    String? regulatoryContext,
    String? primaryEndpoint,
    String? treatmentRoleSummary,
    String? knownInterpretationFactors,
  }) {
    return _db.into(_db.trialPurposes).insert(
          TrialPurposesCompanion.insert(
            trialId: trialId,
            status: Value(status),
            sourceMode: Value(sourceMode),
            claimBeingTested: Value(claimBeingTested),
            trialPurpose: Value(trialPurpose),
            regulatoryContext: Value(regulatoryContext),
            primaryEndpoint: Value(primaryEndpoint),
            treatmentRoleSummary: Value(treatmentRoleSummary),
            knownInterpretationFactors: Value(knownInterpretationFactors),
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
