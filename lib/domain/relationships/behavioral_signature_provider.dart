import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

enum BehavioralSignalType {
  paceChange,
  confidenceTrend,
  editFrequency,
}

class BehavioralSignal {
  final int sessionId;
  final BehavioralSignalType type;
  final double value;

  const BehavioralSignal({
    required this.sessionId,
    required this.type,
    required this.value,
  });
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final behavioralSignatureProvider =
    FutureProvider.autoDispose.family<List<BehavioralSignal>, int>(
        (ref, sessionId) async {
  final db = ref.watch(databaseProvider);

  final records = await (db.select(db.ratingRecords)
        ..where((r) =>
            r.sessionId.equals(sessionId) &
            r.isCurrent.equals(true) &
            r.isDeleted.equals(false))
        ..orderBy([(r) => drift.OrderingTerm.asc(r.createdAt)]))
      .get();

  if (records.isEmpty) return [];

  final signals = <BehavioralSignal>[];

  // ── editFrequency ─────────────────────────────────────────────────────────
  final editCount = records
      .where((r) => r.amended || r.previousId != null)
      .length
      .toDouble();
  signals.add(BehavioralSignal(
    sessionId: sessionId,
    type: BehavioralSignalType.editFrequency,
    value: editCount,
  ));

  // ── paceChange ───────────────────────────────────────────────────────────
  if (records.length >= 4) {
    final gaps = <double>[];
    for (var i = 1; i < records.length; i++) {
      gaps.add(records[i]
          .createdAt
          .difference(records[i - 1].createdAt)
          .inSeconds
          .toDouble());
    }
    final delta = _splitMeanDelta(gaps);
    if (delta != null) {
      signals.add(BehavioralSignal(
        sessionId: sessionId,
        type: BehavioralSignalType.paceChange,
        value: delta,
      ));
    }
  }

  // ── confidenceTrend ───────────────────────────────────────────────────────
  final confidenceValues = <double>[];
  for (final r in records) {
    final mapped = _mapConfidence(r.confidence);
    if (mapped != null) confidenceValues.add(mapped);
  }
  if (confidenceValues.length >= 4) {
    final delta = _splitMeanDelta(confidenceValues);
    if (delta != null) {
      signals.add(BehavioralSignal(
        sessionId: sessionId,
        type: BehavioralSignalType.confidenceTrend,
        value: delta,
      ));
    }
  }

  return signals;
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

double? _mapConfidence(String? raw) {
  switch (raw) {
    case 'certain':
      return 1.0;
    case 'estimated':
      return 0.5;
    case 'uncertain':
      return 0.0;
    default:
      return null;
  }
}

/// Splits [values] into first half and second half (discarding the middle
/// element when the count is odd), then returns lateMean - earlyMean.
double? _splitMeanDelta(List<double> values) {
  if (values.length < 2) return null;

  final int n = values.length;
  final int half = n ~/ 2;

  final early = values.sublist(0, half);
  final late = n.isOdd ? values.sublist(half + 1) : values.sublist(half);

  if (early.isEmpty || late.isEmpty) return null;

  final earlyMean = early.fold(0.0, (a, b) => a + b) / early.length;
  final lateMean = late.fold(0.0, (a, b) => a + b) / late.length;

  return lateMean - earlyMean;
}
