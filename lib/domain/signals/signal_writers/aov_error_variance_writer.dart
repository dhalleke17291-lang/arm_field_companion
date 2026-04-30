import '../../../core/database/app_database.dart';
import '../signal_models.dart';
import '../signal_repository.dart';

/// Raises `aovPrediction` signals when all plots in a treatment group are
/// rated identically for an assessment column.
///
/// Fires at moment 3 (session close, still on site).
class AovErrorVarianceWriter {
  AovErrorVarianceWriter(this._db, this._signals);

  final AppDatabase _db;
  final SignalRepository _signals;

  Future<List<int>> checkAndRaiseForSession({
    required int trialId,
    required int sessionId,
    int? raisedBy,
  }) async {
    final sessionAssessments = await (_db.select(_db.sessionAssessments)
          ..where((sa) => sa.sessionId.equals(sessionId)))
        .get();

    final raised = <int>[];

    for (final sa in sessionAssessments) {
      final assessment = await (_db.select(_db.assessments)
            ..where((a) => a.id.equals(sa.assessmentId)))
          .getSingleOrNull();
      final seName = assessment?.name ?? 'Assessment ${sa.assessmentId}';

      // Get all current numeric ratings for this assessment in this session.
      final ratings = await (_db.select(_db.ratingRecords)
            ..where((r) => r.sessionId.equals(sessionId))
            ..where((r) => r.assessmentId.equals(sa.assessmentId))
            ..where((r) => r.isCurrent.equals(true))
            ..where((r) => r.isDeleted.equals(false))
            ..where((r) => r.numericValue.isNotNull()))
          .get();

      if (ratings.length < 2) continue;

      // Batch-load the plots that appear in these ratings.
      final plotPks = ratings.map((r) => r.plotPk).toSet().toList();
      final plots = await (_db.select(_db.plots)
            ..where((p) => p.id.isIn(plotPks)))
          .get();
      final plotTreatment = {
        for (final p in plots)
          if (p.treatmentId != null) p.id: p.treatmentId!,
      };

      // Group values by treatment.
      final valuesByTreatment = <int, List<double>>{};
      for (final r in ratings) {
        final tId = plotTreatment[r.plotPk];
        if (tId == null) continue;
        valuesByTreatment.putIfAbsent(tId, () => []).add(r.numericValue!);
      }

      for (final entry in valuesByTreatment.entries) {
        final tId = entry.key;
        final values = entry.value;
        if (values.length < 2) continue;
        if (values.toSet().length != 1) continue; // not all identical

        // Dedup: skip if an open/deferred signal already exists for this
        // (session, assessment column, treatment).
        final seKey = sa.assessmentId.toString();
        final existing =
            await _signals.findOpenAovSignalForSessionAssessmentTreatment(
          sessionId: sessionId,
          seType: seKey,
          treatmentId: tId,
        );
        if (existing != null) {
          raised.add(existing.id);
          continue;
        }

        final treatment = await (_db.select(_db.treatments)
              ..where((t) => t.id.equals(tId)))
            .getSingleOrNull();
        final treatmentName = treatment?.name ?? 'Treatment $tId';

        final id = await _signals.raiseSignal(
          trialId: trialId,
          sessionId: sessionId,
          plotId: null,
          signalType: SignalType.aovPrediction,
          moment: SignalMoment.three,
          severity: SignalSeverity.critical,
          referenceContext: SignalReferenceContext(
            seType: seKey,
            neighborValues: values,
            treatmentId: tId,
          ),
          consequenceText:
              'All plots in $treatmentName have the same value for $seName. '
              'Statistical comparison will not be possible for this column.',
          raisedBy: raisedBy,
        );
        raised.add(id);
      }
    }

    return raised;
  }
}
