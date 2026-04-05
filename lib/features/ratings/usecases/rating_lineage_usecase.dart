import '../../../core/database/app_database.dart';
import '../rating_repository.dart';

/// One event in the rating lineage timeline (GLP transparency).
enum RatingLineageEntryType {
  recorded,
  superseded,
  voided,
  undone,
}

class RatingCorrectionEntry {
  const RatingCorrectionEntry({
    required this.correctedAt,
    required this.oldResultStatus,
    required this.newResultStatus,
    this.oldNumericValue,
    this.newNumericValue,
    this.oldTextValue,
    this.newTextValue,
    required this.reason,
    this.correctedByUserId,
  });

  final DateTime correctedAt;
  final String oldResultStatus;
  final String newResultStatus;
  final double? oldNumericValue;
  final double? newNumericValue;
  final String? oldTextValue;
  final String? newTextValue;
  final String reason;
  final int? correctedByUserId;
}

class RatingLineageEntry {
  const RatingLineageEntry({
    required this.timestamp,
    required this.entryType,
    required this.resultStatus,
    this.numericValue,
    this.textValue,
    this.previousNumericValue,
    this.previousTextValue,
    this.previousResultStatus,
    this.reason,
    this.performedBy,
    this.performedByUserId,
    this.confidence,
    this.ratingMethod,
    this.corrections = const [],
    this.voidReason,
  });

  final DateTime timestamp;
  final RatingLineageEntryType entryType;
  final String resultStatus;
  final double? numericValue;
  final String? textValue;
  final double? previousNumericValue;
  final String? previousTextValue;
  final String? previousResultStatus;
  final String? reason;
  final String? performedBy;
  final int? performedByUserId;
  final String? confidence;
  final String? ratingMethod;

  /// Post-close corrections that apply to this version row, oldest first.
  final List<RatingCorrectionEntry> corrections;

  /// Void workflow reason from deviation flags (VOID versions only).
  final String? voidReason;
}

class RatingLineage {
  const RatingLineage({
    required this.plotPk,
    required this.assessmentId,
    required this.sessionId,
    required this.entries,
  });

  final int plotPk;
  final int assessmentId;
  final int sessionId;

  /// Chronological order, oldest first (rating versions only).
  final List<RatingLineageEntry> entries;

  RatingLineageEntry? get currentEntry =>
      entries.isEmpty ? null : entries.last;

  /// Effective status after applying the latest correction on [currentEntry], if any.
  String? get effectiveResultStatus {
    final c = currentEntry;
    if (c == null) return null;
    if (c.corrections.isNotEmpty) {
      return c.corrections.last.newResultStatus;
    }
    return c.resultStatus;
  }

  /// Effective numeric value after the latest correction on [currentEntry], if any.
  double? get effectiveNumericValue {
    final c = currentEntry;
    if (c == null) return null;
    if (c.corrections.isNotEmpty) {
      return c.corrections.last.newNumericValue;
    }
    return c.numericValue;
  }

  /// Effective text value after the latest correction on [currentEntry], if any.
  String? get effectiveTextValue {
    final c = currentEntry;
    if (c == null) return null;
    if (c.corrections.isNotEmpty) {
      return c.corrections.last.newTextValue;
    }
    return c.textValue;
  }
}

/// Builds a read-only timeline of rating versions, corrections, and void reasons.
/// Void reasons use [RatingRepository.getVoidDeviationFlags].
class RatingLineageUseCase {
  RatingLineageUseCase(this._ratingRepository);

  final RatingRepository _ratingRepository;

  Future<RatingLineage> execute({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
  }) async {
    final chain = await _ratingRepository.getRatingChainForPlotAssessmentSession(
      trialId: trialId,
      plotPk: plotPk,
      assessmentId: assessmentId,
      sessionId: sessionId,
    );

    if (chain.isEmpty) {
      return RatingLineage(
        plotPk: plotPk,
        assessmentId: assessmentId,
        sessionId: sessionId,
        entries: [],
      );
    }

    final byId = {for (final r in chain) r.id: r};
    final ratingIds = chain.map((r) => r.id).toList();
    final correctionRows = await _ratingRepository.getCorrectionsForRatingIds(
      ratingIds,
    );
    final voidFlags = await _ratingRepository.getVoidDeviationFlags(
      trialId: trialId,
      sessionId: sessionId,
      plotPk: plotPk,
    );

    final voidReasonByRatingId = _matchVoidReasons(chain, voidFlags);

    final correctionsByRatingId = <int, List<RatingCorrection>>{};
    for (final c in correctionRows) {
      correctionsByRatingId.putIfAbsent(c.ratingId, () => []).add(c);
    }
    for (final list in correctionsByRatingId.values) {
      list.sort((a, b) {
        final t = a.correctedAt.compareTo(b.correctedAt);
        if (t != 0) return t;
        return a.id.compareTo(b.id);
      });
    }

    final List<RatingLineageEntry> out = [];

    for (final row in chain) {
      final entryType = _entryTypeForRow(row);
      final prev = row.previousId != null ? byId[row.previousId] : null;
      final rawList = correctionsByRatingId[row.id] ?? const <RatingCorrection>[];
      final nested = <RatingCorrectionEntry>[
        for (final c in rawList)
          RatingCorrectionEntry(
            correctedAt: c.correctedAt,
            oldResultStatus: c.oldResultStatus,
            newResultStatus: c.newResultStatus,
            oldNumericValue: c.oldNumericValue,
            newNumericValue: c.newNumericValue,
            oldTextValue: c.oldTextValue,
            newTextValue: c.newTextValue,
            reason: c.reason,
            correctedByUserId: c.correctedByUserId,
          ),
      ];

      out.add(
        RatingLineageEntry(
          timestamp: row.createdAt,
          entryType: entryType,
          resultStatus: row.resultStatus,
          numericValue: row.numericValue,
          textValue: row.textValue,
          previousNumericValue: prev?.numericValue,
          previousTextValue: prev?.textValue,
          previousResultStatus: prev?.resultStatus,
          reason: row.resultStatus != 'VOID' &&
                  row.amendmentReason?.isNotEmpty == true
              ? row.amendmentReason
              : null,
          performedBy: row.raterName,
          performedByUserId: row.lastEditedByUserId,
          confidence: row.confidence,
          ratingMethod: row.ratingMethod,
          corrections: nested,
          voidReason: row.resultStatus == 'VOID'
              ? voidReasonByRatingId[row.id]
              : null,
        ),
      );
    }

    return RatingLineage(
      plotPk: plotPk,
      assessmentId: assessmentId,
      sessionId: sessionId,
      entries: out,
    );
  }

  static RatingLineageEntryType _entryTypeForRow(RatingRecord row) {
    if (row.resultStatus == 'VOID') {
      return RatingLineageEntryType.voided;
    }
    if (row.previousId == null) {
      return RatingLineageEntryType.recorded;
    }
    return RatingLineageEntryType.superseded;
  }

  /// Greedy match: each VOID row gets the closest unused VOID_RATING flag by time.
  static Map<int, String?> _matchVoidReasons(
    List<RatingRecord> chain,
    List<DeviationFlag> flags,
  ) {
    final voidRows = chain.where((r) => r.resultStatus == 'VOID').toList();
    final available = List<DeviationFlag>.from(flags);
    final map = <int, String?>{};

    for (final vr in voidRows) {
      DeviationFlag? best;
      var bestMs = 1 << 62;
      for (final f in available) {
        final ms = (f.createdAt.difference(vr.createdAt)).inMilliseconds.abs();
        if (ms < bestMs) {
          bestMs = ms;
          best = f;
        }
      }
      if (best != null) {
        available.remove(best);
        map[vr.id] = best.description;
      }
    }
    return map;
  }
}
