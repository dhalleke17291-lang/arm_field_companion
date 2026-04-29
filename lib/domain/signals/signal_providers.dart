import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import 'signal_repository.dart';

final signalRepositoryProvider = Provider<SignalRepository>((ref) {
  return SignalRepository(ref);
});

final openSignalsForSessionProvider =
    FutureProvider.family<List<Signal>, int>((ref, sessionId) async {
  return ref.read(signalRepositoryProvider).getOpenSignalsForSession(sessionId);
});

final openSignalsForTrialProvider =
    FutureProvider.family<List<Signal>, int>((ref, trialId) async {
  return ref.read(signalRepositoryProvider).getOpenSignalsForTrial(trialId);
});

final signalDecisionHistoryProvider =
    FutureProvider.family<List<SignalDecisionEvent>, int>(
        (ref, signalId) async {
  return ref.read(signalRepositoryProvider).getDecisionHistory(signalId);
});

final unresolvedSignalsBeforeExportProvider =
    FutureProvider.family<List<Signal>, int>((ref, trialId) async {
  return ref
      .read(signalRepositoryProvider)
      .getUnresolvedSignalsBeforeExport(trialId);
});
