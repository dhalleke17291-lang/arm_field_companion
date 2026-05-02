import 'package:flutter/foundation.dart' show debugPrint;

import '../../../core/application_state.dart';
import '../../../core/database/app_database.dart' hide SeTypeCausalProfile;
import '../se_type_causal_profile_provider.dart';
import '../signal_models.dart';
import '../signal_repository.dart';

/// Raises `causalContextFlag` signals when a rating occurs outside the
/// biological timing window defined by the resolved causal profile.
///
/// The window is expressed as [SeTypeCausalProfile.causalWindowDaysMin] and
/// [SeTypeCausalProfile.causalWindowDaysMax] — the expected range of days
/// between the most recent confirmed application and the rating date.
///
/// No signal is raised when:
/// - the rating has no [trialAssessmentId] (non-ARM or pre-import rating)
/// - no ARM assessment metadata or seType is found
/// - no causal profile exists for the resolved (seType, trialType) pair
/// - no confirmed application event precedes the rating date
/// - the actual timing falls within [causalWindowDaysMin, causalWindowDaysMax]
class TimingWindowViolationWriter {
  TimingWindowViolationWriter(this._db, this._signals);

  final AppDatabase _db;
  final SignalRepository _signals;

  Future<int?> checkAndRaise({
    required int ratingId,
    /// Optional pre-resolved ARM trialAssessmentId. When provided, this skips
    /// the DB lookup from the rating row — required when new ratings from the
    /// save/amend paths haven't had trialAssessmentId written to the DB yet.
    int? trialAssessmentId,
    int? raisedBy,
  }) async {
    // ── Load rating ───────────────────────────────────────────────────────────
    final rating = await (_db.select(_db.ratingRecords)
          ..where((r) => r.id.equals(ratingId)))
        .getSingleOrNull();
    if (rating == null) return null;

    final taId = trialAssessmentId ?? rating.trialAssessmentId;
    if (taId == null) return null;

    // ── ARM metadata → seType ─────────────────────────────────────────────────
    final meta = await (_db.select(_db.armAssessmentMetadata)
          ..where((m) => m.trialAssessmentId.equals(taId)))
        .getSingleOrNull();
    final seType = meta?.ratingType;
    if (seType == null) return null;

    // ── Causal profile ────────────────────────────────────────────────────────
    final trial = await (_db.select(_db.trials)
          ..where((t) => t.id.equals(rating.trialId)))
        .getSingleOrNull();
    final profile = await lookupCausalProfile(
      _db,
      seType,
      trial?.workspaceType ?? 'efficacy',
      trial?.region,
    );
    if (profile == null) return null;

    // ── Most recent confirmed application before the rating ───────────────────
    final applications = await (_db.select(_db.trialApplicationEvents)
          ..where((e) => e.trialId.equals(rating.trialId)))
        .get();

    final ratingDay = _dayOnly(rating.createdAt);
    int? bestDaysBefore;

    for (final app in applications) {
      final isConfirmed = app.appliedAt != null ||
          app.status == kAppStatusApplied ||
          app.status == 'complete';
      if (!isConfirmed) continue;

      final appDate = app.appliedAt ?? app.applicationDate;
      final days = ratingDay.difference(_dayOnly(appDate)).inDays;
      if (days < 0) continue; // future application

      if (bestDaysBefore == null || days < bestDaysBefore) {
        bestDaysBefore = days;
      }
    }

    if (bestDaysBefore == null) return null;

    // ── Window check ──────────────────────────────────────────────────────────
    final min = profile.causalWindowDaysMin;
    final max = profile.causalWindowDaysMax;
    if (bestDaysBefore >= min && bestDaysBefore <= max) return null;

    // ── Dedup ─────────────────────────────────────────────────────────────────
    final existing =
        await _signals.findOpenTimingWindowViolationForPlotSession(
      sessionId: rating.sessionId,
      plotId: rating.plotPk,
      seType: seType,
    );
    if (existing != null) return existing.id;

    // ── Raise signal ──────────────────────────────────────────────────────────
    return _signals.raiseSignal(
      trialId: rating.trialId,
      sessionId: rating.sessionId,
      plotId: rating.plotPk,
      signalType: SignalType.causalContextFlag,
      moment: SignalMoment.two,
      severity: SignalSeverity.review,
      referenceContext: SignalReferenceContext(
        seType: seType,
        protocolExpectedValue: '$min–${max}d',
      ),
      magnitudeContext: SignalMagnitudeContext(
        absoluteDelta: bestDaysBefore.toDouble(),
      ),
      consequenceText:
          'Rating timing is outside the configured biological window for this '
          'assessment. ($seType: observed ${bestDaysBefore}d after application; '
          'expected $min–${max}d.)',
      raisedBy: raisedBy,
    );
  }

  /// Session-close sweep: checks every current, non-deleted RECORDED rating
  /// in [sessionId] and raises a timing signal for each one outside its
  /// biological window. VOID and other non-RECORDED statuses are excluded —
  /// timing context only applies when a value was actually measured.
  /// Skips ratings without a resolvable causal profile.
  /// Returns the list of signal IDs raised (null entries = no signal needed).
  Future<List<int?>> checkAndRaiseForSession({
    required int sessionId,
    int? raisedBy,
  }) async {
    final ratings = await (_db.select(_db.ratingRecords)
          ..where((r) => r.sessionId.equals(sessionId))
          ..where((r) => r.isCurrent.equals(true))
          ..where((r) => r.isDeleted.equals(false))
          ..where((r) => r.resultStatus.equals('RECORDED')))
        .get();
    final results = <int?>[];
    for (final rating in ratings) {
      try {
        final id = await checkAndRaise(ratingId: rating.id, raisedBy: raisedBy);
        results.add(id);
      } catch (e) {
        debugPrint(
            '[TimingWindowViolationWriter] sweep error for rating ${rating.id}: $e');
      }
    }
    return results;
  }
}

DateTime _dayOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
