import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import 'signal_decision_dto.dart';
import 'signal_repository.dart';
import 'signal_review_projection.dart';
import 'signal_review_projection_mapper.dart';

/// Trial-scoped variant of the signalDecisionEvents watch.
/// Only emits when a decision event for a signal belonging to [trialId] is
/// written — prevents cross-trial spurious recomputes in cognition providers.
final signalDecisionEventsForTrialProvider =
    StreamProvider.family<List<SignalDecisionEvent>, int>((ref, trialId) {
  return ref
      .read(signalRepositoryProvider)
      .watchDecisionEventsForTrial(trialId);
});

final signalRepositoryProvider = Provider<SignalRepository>((ref) {
  return SignalRepository(ref);
});

final openSignalsForSessionProvider =
    FutureProvider.family<List<Signal>, int>((ref, sessionId) async {
  return ref.read(signalRepositoryProvider).getOpenSignalsForSession(sessionId);
});

final openSignalsForTrialProvider =
    StreamProvider.family<List<Signal>, int>((ref, trialId) {
  return ref.read(signalRepositoryProvider).watchOpenSignalsForTrial(trialId);
});

final projectedOpenSignalsForTrialProvider =
    StreamProvider.family<List<SignalReviewProjection>, int>((ref, trialId) {
  final signalsAsync = ref.watch(openSignalsForTrialProvider(trialId));
  return signalsAsync.when(
    data: (signals) => Stream.value(projectSignalsForReview(signals)),
    loading: () => const Stream<List<SignalReviewProjection>>.empty(),
    error: (error, stackTrace) =>
        Stream<List<SignalReviewProjection>>.error(error, stackTrace),
  );
});

final projectedOpenSignalGroupsForTrialProvider =
    StreamProvider.family<List<SignalReviewGroupProjection>, int>(
        (ref, trialId) {
  final signalsAsync = ref.watch(openSignalsForTrialProvider(trialId));
  return signalsAsync.when(
    data: (signals) => Stream.value(projectSignalGroupsForReview(signals)),
    loading: () => const Stream<List<SignalReviewGroupProjection>>.empty(),
    error: (error, stackTrace) =>
        Stream<List<SignalReviewGroupProjection>>.error(error, stackTrace),
  );
});

/// Decision events for a single signal, as DTOs with resolved actorName.
final signalDecisionHistoryProvider =
    FutureProvider.family<List<SignalDecisionDto>, int>((ref, signalId) async {
  return ref.read(signalRepositoryProvider).getDecisionHistoryDtos(signalId);
});

final unresolvedSignalsBeforeExportProvider =
    FutureProvider.family<List<Signal>, int>((ref, trialId) async {
  return ref
      .read(signalRepositoryProvider)
      .getUnresolvedSignalsBeforeExport(trialId);
});
