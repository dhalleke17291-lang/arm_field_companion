import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart' show debugPrint;
import '../../../core/database/app_database.dart';
import '../../../core/plot_analysis_eligibility.dart';
import '../../ratings/rating_repository.dart';

/// ExportRepository
/// Builds export rows for a session using your exact Drift field names.
class ExportRepository {
  final AppDatabase db;
  final RatingRepository? _ratingRepo;

  ExportRepository(this.db, {RatingRepository? ratingRepository})
      : _ratingRepo = ratingRepository;

  /// Exports ONLY current ratings (isCurrent == true).
  /// Includes provenance and effective value when a correction exists.
  /// Sort order: rep -> plot_sort_index -> assessment name.
  Future<List<Map<String, Object?>>> buildSessionExportRows({
    required int sessionId,
  }) async {
    // Repair any is_current drift before querying export data so stale or
    // duplicate flags can't silently produce wrong rows for the CRO.
    try {
      await _ratingRepo?.repairCurrentFlagsForExport(sessionId: sessionId);
    } catch (e) {
      debugPrint('[ExportRepository] repairCurrentFlagsForExport: $e');
    }
    final rr = db.ratingRecords;
    final p = db.plots;
    final a = db.assessments;
    final asg = db.assignments;
    final t = db.treatments;

    final query = db.select(rr).join([
      drift.innerJoin(p, p.id.equalsExp(rr.plotPk)),
      drift.innerJoin(a, a.id.equalsExp(rr.assessmentId)),
      drift.leftOuterJoin(
          asg, asg.plotId.equalsExp(p.id) & asg.trialId.equalsExp(p.trialId)),
      drift.leftOuterJoin(t, t.id.equalsExp(asg.treatmentId)),
    ])
      ..where(rr.sessionId.equals(sessionId) &
          rr.isCurrent.equals(true) &
          rr.isDeleted.equals(false) &
          p.isDeleted.equals(false) &
          p.isGuardRow.equals(false))
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
      final assignment = row.readTableOrNull(asg);
      final treatment = row.readTableOrNull(t);
      final correction = corrections[rating.id];

      final effectiveStatus =
          correction?.newResultStatus ?? rating.resultStatus;
      final effectiveNumeric =
          correction?.newNumericValue ?? rating.numericValue;
      final effectiveText = correction?.newTextValue ?? rating.textValue;

      final map = <String, Object?>{
        // Plot
        'plot_id': plot.plotId,
        'rep': plot.rep,
        'plot_excluded': !isAnalyzablePlot(plot),
        // Treatment via Assignment (Plot → Assignment → Treatment)
        'treatment_id': assignment?.treatmentId ?? plot.treatmentId,
        'treatment_code': treatment?.code,
        'treatment_name': treatment?.name,
        'assignment_source':
            assignment?.assignmentSource ?? plot.assignmentSource,
        'assignment_updated_at_utc':
            (assignment?.assignedAt ?? plot.assignmentUpdatedAt)
                ?.toUtc()
                .toIso8601String(),
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
        map['corrected_at_utc'] =
            correction.correctedAt.toUtc().toIso8601String();
      }

      return map;
    }).toList();
  }

  /// Exports all current ratings for a trial across all sessions.
  /// Same join and sort as buildSessionExportRows but scoped to trialId.
  /// Includes resultDirection from AssessmentDefinitions when trialAssessmentId present.
  Future<List<Map<String, Object?>>> buildTrialExportRows({
    required int trialId,
  }) async {
    try {
      await _ratingRepo?.repairCurrentFlagsForExport(trialId: trialId);
    } catch (e) {
      debugPrint('[ExportRepository] repairCurrentFlagsForExport: $e');
    }
    final rr = db.ratingRecords;
    final p = db.plots;
    final a = db.assessments;
    final asg = db.assignments;
    final t = db.treatments;
    final ta = db.trialAssessments;
    final ad = db.assessmentDefinitions;

    final query = db.select(rr).join([
      drift.innerJoin(p, p.id.equalsExp(rr.plotPk)),
      drift.innerJoin(a, a.id.equalsExp(rr.assessmentId)),
      drift.leftOuterJoin(
          asg,
          asg.plotId.equalsExp(p.id) &
              asg.trialId.equalsExp(p.trialId)),
      drift.leftOuterJoin(t, t.id.equalsExp(asg.treatmentId)),
      drift.leftOuterJoin(ta, ta.id.equalsExp(rr.trialAssessmentId)),
      drift.leftOuterJoin(ad, ad.id.equalsExp(ta.assessmentDefinitionId)),
    ])
      ..where(rr.trialId.equals(trialId) &
          rr.isCurrent.equals(true) &
          rr.isDeleted.equals(false) &
          p.isDeleted.equals(false) &
          p.isGuardRow.equals(false))
      ..orderBy([
        drift.OrderingTerm.asc(p.rep),
        drift.OrderingTerm.asc(p.plotSortIndex),
        drift.OrderingTerm.asc(a.name),
      ]);

    final result = await query.get();
    final ratingIds =
        result.map((row) => row.readTable(rr).id).toList();

    final corrections = ratingIds.isEmpty
        ? <int, RatingCorrection>{}
        : await _getLatestCorrectionsByRatingId(ratingIds);

    return result.map((row) {
      final rating = row.readTable(rr);
      final plot = row.readTable(p);
      final assessment = row.readTable(a);
      final assignment = row.readTableOrNull(asg);
      final treatment = row.readTableOrNull(t);
      final definition = row.readTableOrNull(ad);
      final correction = corrections[rating.id];

      final effectiveNumeric =
          correction?.newNumericValue ?? rating.numericValue;
      final effectiveText =
          correction?.newTextValue ?? rating.textValue;
      final effectiveStatus =
          correction?.newResultStatus ?? rating.resultStatus;

      final value = effectiveNumeric != null
          ? effectiveNumeric.toStringAsFixed(2)
              .replaceAll(RegExp(r'\.?0+$'), '')
          : (effectiveText ?? '-');

      return <String, Object?>{
        'plot_id': plot.plotId,
        'rep': plot.rep ?? 0,
        'treatment_code':
            treatment?.code ?? assignment?.treatmentId?.toString() ?? '-',
        'assessment_name': assessment.name,
        'unit': assessment.unit ?? '',
        'value': value,
        'result_status': effectiveStatus,
        'result_direction': definition?.resultDirection ?? 'neutral',
        'plot_excluded': !isAnalyzablePlot(plot),
        'session_id': rating.sessionId,
      };
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

  /// Session-scoped audit events for export (SESSION_STARTED, SESSION_CLOSED, RATING_SAVED, etc.).
  /// Sort order: created_at ascending.
  Future<List<Map<String, Object?>>> buildSessionAuditExportRows({
    required int sessionId,
  }) async {
    final rows = await (db.select(db.auditEvents)
          ..where((e) => e.sessionId.equals(sessionId))
          ..orderBy([(e) => drift.OrderingTerm.asc(e.createdAt)]))
        .get();
    return rows
        .map((e) => <String, Object?>{
              'trial_id': e.trialId,
              'session_id': e.sessionId,
              'audit_id': e.id,
              'event_type': e.eventType,
              'description': e.description,
              'performed_by': e.performedBy,
              'performed_by_user_id': e.performedByUserId,
              'created_at_utc': e.createdAt.toUtc().toIso8601String(),
              'metadata': e.metadata,
            })
        .toList();
  }
}
