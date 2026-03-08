import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';

/// ExportRepository
/// Builds export rows for a session using your exact Drift field names.
class ExportRepository {
  final AppDatabase db;
  ExportRepository(this.db);

  /// Exports ONLY current ratings (isCurrent == true).
  /// Includes provenance and effective value when a correction exists.
  /// Sort order: rep -> plot_sort_index -> assessment name.
  Future<List<Map<String, Object?>>> buildSessionExportRows({
    required int sessionId,
  }) async {
    final rr = db.ratingRecords;
    final p = db.plots;
    final a = db.assessments;
    final t = db.treatments;

    final query = db.select(rr).join([
      drift.innerJoin(p, p.id.equalsExp(rr.plotPk)),
      drift.innerJoin(a, a.id.equalsExp(rr.assessmentId)),
      drift.leftOuterJoin(t, t.id.equalsExp(p.treatmentId)),
    ])
      ..where(rr.sessionId.equals(sessionId) & rr.isCurrent.equals(true))
      ..orderBy([
        drift.OrderingTerm.asc(p.rep),
        drift.OrderingTerm.asc(p.plotSortIndex),
        drift.OrderingTerm.asc(a.name),
      ]);

    final result = await query.get();
    final ratingIds = result.map((row) => row.readTable(rr).id).toList();

    // Latest correction per rating (for effective value and correction metadata)
    final corrections = ratingIds.isEmpty
        ? <int, RatingCorrection>{}
        : await _getLatestCorrectionsByRatingId(ratingIds);

    return result.map((row) {
      final rating = row.readTable(rr);
      final plot = row.readTable(p);
      final assessment = row.readTable(a);
      final treatment = row.readTableOrNull(t);
      final correction = corrections[rating.id];

      final effectiveStatus = correction?.newResultStatus ?? rating.resultStatus;
      final effectiveNumeric = correction?.newNumericValue ?? rating.numericValue;
      final effectiveText = correction?.newTextValue ?? rating.textValue;

      final map = <String, Object?>{
        // Plot
        'plot_id': plot.plotId,
        'rep': plot.rep,
        // Treatment (full lineage per Charter PART 10)
        'treatment_id': plot.treatmentId,
        'treatment_code': treatment?.code,
        'treatment_name': treatment?.name,
        'assignment_source': plot.assignmentSource,
        'assignment_updated_at_utc': plot.assignmentUpdatedAt?.toUtc().toIso8601String(),
        'row': plot.row,
        'column': plot.column,
        'plot_sort_index': plot.plotSortIndex,

        // Assessment
        'assessment_name': assessment.name,
        'unit': assessment.unit,
        'min': assessment.minValue,
        'max': assessment.maxValue,

        // Rating (original fields)
        'result_status': rating.resultStatus,
        'numeric_value': rating.numericValue,
        'text_value': rating.textValue,
        'created_at': rating.createdAt.toIso8601String(),
        'rater_name': rating.raterName,

        // Provenance (nullable for legacy rows)
        'record_created_at_utc': rating.createdAt.toUtc().toIso8601String(),
        'record_app_version': rating.createdAppVersion,
        'record_device_info': rating.createdDeviceInfo,
        'record_latitude': rating.capturedLatitude,
        'record_longitude': rating.capturedLongitude,

        // Traceability IDs
        'trial_id': rating.trialId,
        'session_id': rating.sessionId,
        'rating_record_id': rating.id,
        'previous_id': rating.previousId,
        'plot_pk': rating.plotPk,
        'assessment_id': rating.assessmentId,
        'sub_unit_id': rating.subUnitId,

        // Effective value (after correction if any)
        'effective_result_status': effectiveStatus,
        'effective_numeric_value': effectiveNumeric,
        'effective_text_value': effectiveText,
      };

      if (correction != null) {
        map['original_numeric_value'] = rating.numericValue;
        map['original_text_value'] = rating.textValue;
        map['original_result_status'] = rating.resultStatus;
        map['correction_reason'] = correction.reason;
        map['corrected_by_user_id'] = correction.correctedByUserId;
        map['corrected_at_utc'] = correction.correctedAt.toUtc().toIso8601String();
      }

      return map;
    }).toList();
  }

  Future<Map<int, RatingCorrection>> _getLatestCorrectionsByRatingId(
      List<int> ratingIds) async {
    if (ratingIds.isEmpty) return {};
    final list = await (db.select(db.ratingCorrections)
          ..where((c) => c.ratingId.isIn(ratingIds))
          ..orderBy([(c) => drift.OrderingTerm.desc(c.correctedAt)]))
        .get();
    final byRating = <int, RatingCorrection>{};
    for (final c in list) {
      byRating.putIfAbsent(c.ratingId, () => c);
    }
    return byRating;
  }
}
