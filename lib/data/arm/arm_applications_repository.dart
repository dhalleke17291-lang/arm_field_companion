import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

/// One application event joined with its ARM **Applications** sheet row.
typedef ArmSheetApplicationRow = ({
  TrialApplicationEvent event,
  ArmApplication arm,
});

/// Persistence for [ArmApplications] (Phase 3a — Applications sheet ARM
/// extension). One row per [TrialApplicationEvents] when populated by the
/// shell importer (Phase 3c). Standalone trials have zero rows.
///
/// [ArmApplications.row01]–[row79] are verbatim Applications-sheet cells; see
/// `test/fixtures/arm_shells/README.md`.
class ArmApplicationsRepository {
  ArmApplicationsRepository(this._db);

  final AppDatabase _db;

  Future<ArmApplication?> getForEvent(String trialApplicationEventId) {
    return (_db.select(_db.armApplications)
          ..where((a) =>
              a.trialApplicationEventId.equals(trialApplicationEventId)))
        .getSingleOrNull();
  }

  Stream<ArmApplication?> watchForEvent(String trialApplicationEventId) {
    return (_db.select(_db.armApplications)
          ..where((a) =>
              a.trialApplicationEventId.equals(trialApplicationEventId)))
        .watch()
        .map((rows) => rows.singleOrNull);
  }

  /// All ARM application descriptor rows for a trial (joins core events).
  Future<List<ArmApplication>> getAllForTrial(int trialId) async {
    final query = _db.select(_db.armApplications).join([
      innerJoin(
        _db.trialApplicationEvents,
        _db.trialApplicationEvents.id
            .equalsExp(_db.armApplications.trialApplicationEventId),
      ),
    ])
      ..where(_db.trialApplicationEvents.trialId.equals(trialId));
    final rows = await query.get();
    return [for (final r in rows) r.readTable(_db.armApplications)];
  }

  void _sortArmSheetRows(List<ArmSheetApplicationRow> list) {
    list.sort((a, b) {
      final byDate = a.event.applicationDate.compareTo(b.event.applicationDate);
      if (byDate != 0) return byDate;
      final ai = a.arm.armSheetColumnIndex ?? (1 << 20);
      final bi = b.arm.armSheetColumnIndex ?? (1 << 20);
      return ai.compareTo(bi);
    });
  }

  /// Same rows as [watchArmSheetApplicationsForTrial], for one-shot reads
  /// (tests, diagnostics).
  Future<List<ArmSheetApplicationRow>> getArmSheetApplicationsForTrial(
    int trialId,
  ) {
    return watchArmSheetApplicationsForTrial(trialId).first;
  }

  /// [TrialApplicationEvent] rows that have an `arm_applications` extension,
  /// ordered by application date then worksheet column index.
  Stream<List<ArmSheetApplicationRow>> watchArmSheetApplicationsForTrial(
    int trialId,
  ) {
    final query = _db.select(_db.armApplications).join([
      innerJoin(
        _db.trialApplicationEvents,
        _db.trialApplicationEvents.id
            .equalsExp(_db.armApplications.trialApplicationEventId),
      ),
    ])..where(_db.trialApplicationEvents.trialId.equals(trialId));

    return query.watch().map((rows) {
      final list = <ArmSheetApplicationRow>[
        for (final r in rows)
          (
            event: r.readTable(_db.trialApplicationEvents),
            arm: r.readTable(_db.armApplications),
          ),
      ];
      _sortArmSheetRows(list);
      return list;
    });
  }

  Future<int> insert(ArmApplicationsCompanion row) {
    return _db.into(_db.armApplications).insert(row);
  }

  /// Replace the row for [trialApplicationEventId] if one exists; otherwise
  /// insert. Used by the Phase 3c importer for idempotent re-runs.
  Future<void> upsertForEvent(
    String trialApplicationEventId,
    ArmApplicationsCompanion data,
  ) async {
    final existing = await getForEvent(trialApplicationEventId);
    if (existing == null) {
      await _db.into(_db.armApplications).insert(data);
      return;
    }
    await (_db.update(_db.armApplications)
          ..where((a) => a.id.equals(existing.id)))
        .write(data);
  }

  Future<int> deleteForTrial(int trialId) async {
    final events = await (_db.select(_db.trialApplicationEvents)
          ..where((e) => e.trialId.equals(trialId)))
        .get();
    if (events.isEmpty) return 0;
    final ids = events.map((e) => e.id).toList();
    return (_db.delete(_db.armApplications)
          ..where((a) => a.trialApplicationEventId.isIn(ids)))
        .go();
  }
}
