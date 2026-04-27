import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Latest session start time per trial. Refreshes when the global trial list
/// stream updates (new trial rows). Pull-to-refresh on the portfolio screen
/// should also invalidate this provider.
final portfolioLastSessionByTrialProvider =
    FutureProvider.autoDispose<Map<int, DateTime>>((ref) async {
  ref.watch(trialsStreamProvider);
  return ref.read(sessionRepositoryProvider).getLatestSessionStartedAtByTrial();
});
