import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

class ApplicationPlotAssignmentRepository {
  ApplicationPlotAssignmentRepository(this._db);

  final AppDatabase _db;

  /// Returns all plot assignments for an application event.
  Future<List<ApplicationPlotAssignment>> getForEvent(
      String applicationEventId) {
    return (_db.select(_db.applicationPlotAssignments)
          ..where(
              (a) => a.applicationEventId.equals(applicationEventId)))
        .get();
  }

  /// Replaces all plot assignments for an application event.
  ///
  /// [plotSelections] is a list of (plotLabel, plotId?) pairs.
  /// Called alongside the existing plotsTreated TEXT write.
  Future<void> saveForEvent(
    String applicationEventId,
    List<({String label, int? plotId})> plotSelections,
  ) async {
    await _db.transaction(() async {
      await (_db.delete(_db.applicationPlotAssignments)
            ..where(
                (a) => a.applicationEventId.equals(applicationEventId)))
          .go();
      for (final sel in plotSelections) {
        await _db.into(_db.applicationPlotAssignments).insert(
              ApplicationPlotAssignmentsCompanion.insert(
                applicationEventId: applicationEventId,
                plotLabel: sel.label,
                plotId: Value(sel.plotId),
              ),
            );
      }
    });
  }
}
