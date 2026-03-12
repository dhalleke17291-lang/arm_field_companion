import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'domain/derived_calc.dart';
import 'domain/derived_snapshot.dart';

/// Builds a [DerivedSnapshot] for a session (rated count, total plots, progress).
/// [calcVersion] is derived from session and counts so cache can invalidate when data changes.
final derivedSnapshotForSessionProvider =
    FutureProvider.autoDispose.family<DerivedSnapshot?, int>((ref, sessionId) async {
  final sessionRepo = ref.read(sessionRepositoryProvider);
  final plotRepo = ref.read(plotRepositoryProvider);
  final ratingRepo = ref.read(ratingRepositoryProvider);

  final session = await sessionRepo.getSessionById(sessionId);
  if (session == null) return null;

  final plots = await plotRepo.getPlotsForTrial(session.trialId);
  final totalPlotCount = plots.length;
  final ratings = await ratingRepo.getCurrentRatingsForSession(sessionId);
  final ratedPlotPks = ratings.map((r) => r.plotPk).toSet();
  final ratedPlotCount = ratedPlotPks.length;

  final progressFraction = sessionProgressFraction(ratedPlotCount, totalPlotCount);
  final calcVersion = sessionId.hashCode +
      totalPlotCount.hashCode +
      ratedPlotCount.hashCode +
      session.startedAt.millisecondsSinceEpoch.hashCode;

  return DerivedSnapshot(
    sessionId: sessionId,
    calcVersion: calcVersion,
    ratedPlotCount: ratedPlotCount,
    totalPlotCount: totalPlotCount,
    progressFraction: progressFraction,
  );
});
