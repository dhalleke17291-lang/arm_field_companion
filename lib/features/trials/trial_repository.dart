import 'dart:convert';

import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';
import '../../core/trial_state.dart';

class TrialRepository {
  final AppDatabase _db;

  TrialRepository(this._db);

  // Get all trials ordered by most recent
  Stream<List<Trial>> watchAllTrials() {
    return (_db.select(_db.trials)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  // Get single trial by id
  Future<Trial?> getTrialById(int id) {
    return (_db.select(_db.trials)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  // Create new trial — checks for duplicate name first
  Future<int> createTrial({
    required String name,
    String? crop,
    String? location,
    String? season,
  }) async {
    // Duplicate name check — silent overwrite forbidden per spec
    final existing = await (_db.select(_db.trials)
          ..where((t) => t.name.equals(name) & t.isDeleted.equals(false)))
        .getSingleOrNull();

    if (existing != null) {
      throw DuplicateTrialException(name);
    }

    return _db.into(_db.trials).insert(
          TrialsCompanion.insert(
            name: name,
            crop: Value(crop),
            location: Value(location),
            season: Value(season),
            status: const Value(kTrialStatusDraft),
          ),
        );
  }

  // Update trial
  Future<bool> updateTrial(Trial trial) {
    return _db.update(_db.trials).replace(trial);
  }

  /// Update only trial setup fields (protocol, location, plot dimensions, soil, etc.).
  /// Does not touch lifecycle fields (status, createdAt, updatedAt) or session data.
  Future<int> updateTrialSetup(int trialId, TrialsCompanion companion) async {
    return (_db.update(_db.trials)..where((t) => t.id.equals(trialId)))
        .write(companion);
  }

  /// Update trial lifecycle status (draft → ready → active → closed → archived).
  Future<bool> updateTrialStatus(int trialId, String status) async {
    final t = await getTrialById(trialId);
    if (t == null) return false;
    return updateTrial(t.copyWith(status: status));
  }

  // Get trial with treatment and plot counts
  Future<TrialSummary> getTrialSummary(int trialId) async {
    final trial = await getTrialById(trialId);
    if (trial == null) throw TrialNotFoundException(trialId);

    final plotCount = await (_db.select(_db.plots)
          ..where((p) =>
              p.trialId.equals(trialId) & p.isDeleted.equals(false)))
        .get()
        .then((list) => list.length);

    final treatmentCount = await (_db.select(_db.treatments)
          ..where((t) => t.trialId.equals(trialId)))
        .get()
        .then((list) => list.length);

    final assessmentCount = await (_db.select(_db.assessments)
          ..where((a) => a.trialId.equals(trialId)))
        .get()
        .then((list) => list.length);

    return TrialSummary(
      trial: trial,
      plotCount: plotCount,
      treatmentCount: treatmentCount,
      assessmentCount: assessmentCount,
    );
  }

  /// Soft-delete trial and cascade: sessions, plots, and all rating_records for the trial.
  /// [deletedByUserId] optional; stored on audit event as [performedByUserId].
  Future<void> softDeleteTrial(int trialId,
      {String? deletedBy, int? deletedByUserId}) async {
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      final deletedSessionsCount = await (_db.select(_db.sessions)
            ..where((s) => s.trialId.equals(trialId)))
          .get()
          .then((l) => l.length);
      final deletedPlotsCount = await (_db.select(_db.plots)
            ..where((p) => p.trialId.equals(trialId)))
          .get()
          .then((l) => l.length);
      final deletedRatingsCount = await (_db.select(_db.ratingRecords)
            ..where((r) => r.trialId.equals(trialId)))
          .get()
          .then((l) => l.length);

      await (_db.update(_db.ratingRecords)
            ..where((r) => r.trialId.equals(trialId)))
          .write(RatingRecordsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        deletedBy: Value(deletedBy),
      ));
      await (_db.update(_db.sessions)..where((s) => s.trialId.equals(trialId)))
          .write(SessionsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        deletedBy: Value(deletedBy),
      ));
      await (_db.update(_db.plots)..where((p) => p.trialId.equals(trialId)))
          .write(PlotsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        deletedBy: Value(deletedBy),
      ));
      await (_db.update(_db.trials)..where((t) => t.id.equals(trialId)))
          .write(TrialsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        deletedBy: Value(deletedBy),
      ));

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(trialId),
              eventType: 'TRIAL_DELETED',
              description: 'Trial deleted and moved to Recovery',
              performedBy: Value(deletedBy),
              performedByUserId: Value(deletedByUserId),
              metadata: Value(jsonEncode({
                'deleted_sessions_count': deletedSessionsCount,
                'deleted_plots_count': deletedPlotsCount,
                'deleted_ratings_count': deletedRatingsCount,
              })),
            ),
          );
    });
  }

  /// Recovery: soft-deleted trials only, newest deletion first.
  Future<List<Trial>> getDeletedTrials() {
    return (_db.select(_db.trials)
          ..where((t) => t.isDeleted.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
        .get();
  }

  /// Recovery: single soft-deleted trial by id, or null.
  Future<Trial?> getDeletedTrialById(int id) {
    return (_db.select(_db.trials)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(true)))
        .getSingleOrNull();
  }
}

// ─────────────────────────────────────────────
// VALUE OBJECTS
// ─────────────────────────────────────────────

class TrialSummary {
  final Trial trial;
  final int plotCount;
  final int treatmentCount;
  final int assessmentCount;

  const TrialSummary({
    required this.trial,
    required this.plotCount,
    required this.treatmentCount,
    required this.assessmentCount,
  });
}

// ─────────────────────────────────────────────
// EXCEPTIONS
// ─────────────────────────────────────────────

class DuplicateTrialException implements Exception {
  final String trialName;
  DuplicateTrialException(this.trialName);

  @override
  String toString() =>
      'Trial "$trialName" already exists. Rename or cancel import.';
}

class TrialNotFoundException implements Exception {
  final int trialId;
  TrialNotFoundException(this.trialId);

  @override
  String toString() => 'Trial with id $trialId not found.';
}
