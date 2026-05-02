import '../../../core/database/app_database.dart';
import '../signal_models.dart';
import '../signal_repository.dart';

const String _sessionAttributionSeType = 'session_attribution';

/// Session-close check for **rater attribution consistency** among recorded
/// ratings (provenance only — no statistical or cross-session comparisons).
///
/// Raises at most one [SignalType.raterDrift] per session while an active row
/// exists; discriminator [SignalReferenceContext.seType] is
/// `'session_attribution'`.
class RaterDriftWriter {
  RaterDriftWriter(this._db, this._signals);

  final AppDatabase _db;
  final SignalRepository _signals;

  /// Returns a new signal id, an existing active duplicate's id, or `null`
  /// when no inconsistency or no usable ratings.
  Future<int?> checkAndRaiseForSession({
    required int sessionId,
    int? raisedBy,
  }) async {
    final session = await (_db.select(_db.sessions)
          ..where((s) => s.id.equals(sessionId)))
        .getSingleOrNull();
    if (session == null) return null;

    final ratings = await (_db.select(_db.ratingRecords)
          ..where((r) => r.sessionId.equals(sessionId))
          ..where((r) => r.isCurrent.equals(true))
          ..where((r) => r.isDeleted.equals(false))
          ..where((r) => r.resultStatus.equals('RECORDED')))
        .get();
    if (ratings.isEmpty) return null;

    final distinctNames = <String>{};
    var anyBlank = false;
    var anyNonBlank = false;
    for (final r in ratings) {
      final n = _normalizeRaterName(r.raterName);
      if (n == null) {
        anyBlank = true;
      } else {
        anyNonBlank = true;
        distinctNames.add(n);
      }
    }

    final multipleDistinctNames = distinctNames.length >= 2;
    final mixedBlankAndFilled = anyBlank && anyNonBlank;

    if (!multipleDistinctNames && !mixedBlankAndFilled) {
      return null;
    }

    final existing =
        await _signals.findOpenRaterDriftSessionAttribution(sessionId: sessionId);
    if (existing != null) return existing.id;

    final consequenceText = multipleDistinctNames
        ? _consequenceMultipleNames(distinctNames)
        : 'Some recorded ratings include a rater name and others have none '
            'for this session.';

    return _signals.raiseSignal(
      trialId: session.trialId,
      sessionId: sessionId,
      plotId: null,
      signalType: SignalType.raterDrift,
      moment: SignalMoment.three,
      severity: SignalSeverity.review,
      referenceContext: const SignalReferenceContext(
        seType: _sessionAttributionSeType,
      ),
      consequenceText: consequenceText,
      raisedBy: raisedBy,
    );
  }
}

String _consequenceMultipleNames(Set<String> names) {
  final sorted = [...names]..sort();
  final quoted = sorted.map((n) => '"$n"').join(', ');
  return 'Recorded ratings show more than one rater name in this session '
      '($quoted).';
}

/// Trims and treats blank strings as absent.
String? _normalizeRaterName(String? raw) {
  if (raw == null) return null;
  final t = raw.trim();
  return t.isEmpty ? null : t;
}
