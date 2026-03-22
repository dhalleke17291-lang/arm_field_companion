import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/trial_state.dart';
import '../../core/workspace/workspace_filter.dart';

/// Live stats for the Trials Hub cards (Custom vs Protocol).
class TrialsHubStats {
  const TrialsHubStats({
    required this.customTrialCount,
    required this.customActiveCount,
    required this.customCompleteCount,
    required this.customCropCount,
    required this.protocolTrialCount,
    required this.protocolActiveCount,
    required this.protocolCompleteCount,
  });

  final int customTrialCount;
  final int customActiveCount;
  final int customCompleteCount;
  final int customCropCount;
  final int protocolTrialCount;
  final int protocolActiveCount;
  final int protocolCompleteCount;

  static const zero = TrialsHubStats(
    customTrialCount: 0,
    customActiveCount: 0,
    customCompleteCount: 0,
    customCropCount: 0,
    protocolTrialCount: 0,
    protocolActiveCount: 0,
    protocolCompleteCount: 0,
  );
}

bool _isActive(String status) =>
    status == kTrialStatusActive || status == kTrialStatusReady;

bool _isComplete(String status) =>
    status == kTrialStatusClosed || status == kTrialStatusArchived;

/// Live, reactive stats for Trials Hub. Updates on any trial/plot change.
final trialsHubStatsProvider = StreamProvider.autoDispose<TrialsHubStats>((ref) async* {
  final trialRepo = ref.watch(trialRepositoryProvider);

  await for (final allTrials in trialRepo.watchAllTrials()) {
    final customTrials = allTrials.where((t) => isStandalone(t.workspaceType)).toList();
    final protocolTrials = allTrials.where((t) => isProtocol(t.workspaceType)).toList();

    final customCropCount = customTrials
        .map((t) => t.crop?.trim().toLowerCase())
        .where((c) => c != null && c.isNotEmpty)
        .toSet()
        .length;

    yield TrialsHubStats(
      customTrialCount: customTrials.length,
      customActiveCount: customTrials.where((t) => _isActive(t.status)).length,
      customCompleteCount:
          customTrials.where((t) => _isComplete(t.status)).length,
      customCropCount: customCropCount,
      protocolTrialCount: protocolTrials.length,
      protocolActiveCount:
          protocolTrials.where((t) => _isActive(t.status)).length,
      protocolCompleteCount:
          protocolTrials.where((t) => _isComplete(t.status)).length,
    );
  }
});
