import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

/// ExportRepository
/// Builds export rows for a session using your exact Drift field names.
class ExportRepository {
  final AppDatabase db;
  ExportRepository(this.db);

  /// Exports ONLY current ratings (isCurrent == true).
  /// Sort order: rep -> plot_sort_index -> assessment name.
  Future<List<Map<String, Object?>>> buildSessionExportRows({
    required int sessionId,
  }) async {
    final rr = db.ratingRecords;
    final p = db.plots;
    final a = db.assessments;

    final query = db.select(rr).join([
      innerJoin(p, p.id.equalsExp(rr.plotPk)),
      innerJoin(a, a.id.equalsExp(rr.assessmentId)),
    ])
      ..where(rr.sessionId.equals(sessionId) & rr.isCurrent.equals(true))
      ..orderBy([
        OrderingTerm.asc(p.rep),
        OrderingTerm.asc(p.plotSortIndex),
        OrderingTerm.asc(a.name),
      ]);

    final result = await query.get();

    return result.map((row) {
      final rating = row.readTable(rr);
      final plot = row.readTable(p);
      final assessment = row.readTable(a);

      return <String, Object?>{
        // Plot
        'plot_id': plot.plotId,
        'rep': plot.rep,
        'row': plot.row,
        'column': plot.column,
        'plot_sort_index': plot.plotSortIndex,

        // Assessment
        'assessment_name': assessment.name,
        'unit': assessment.unit,
        'min': assessment.minValue,
        'max': assessment.maxValue,

        // Rating (your exact fields)
        'result_status': rating.resultStatus,
        'numeric_value': rating.numericValue,
        'text_value': rating.textValue,
        'created_at': rating.createdAt.toIso8601String(),
        'rater_name': rating.raterName,

        // Traceability IDs
        'trial_id': rating.trialId,
        'session_id': rating.sessionId,
        'rating_record_id': rating.id,
        'previous_id': rating.previousId,
        'plot_pk': rating.plotPk,
        'assessment_id': rating.assessmentId,
        'sub_unit_id': rating.subUnitId,
      };
    }).toList();
  }
}
