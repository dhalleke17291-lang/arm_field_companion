import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
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

bool _isComplete(String status) =>
    status == kTrialStatusClosed || status == kTrialStatusArchived;

TrialsHubStats _computeTrialsHubStats(
  List<Trial> allTrials,
  Set<int> openTrialIds,
) {
  final customTrials =
      allTrials.where((t) => isStandalone(t.workspaceType)).toList();
  final protocolTrials =
      allTrials.where((t) => isProtocol(t.workspaceType)).toList();

  final customCropCount = customTrials
      .map((t) => t.crop?.trim().toLowerCase())
      .where((c) => c != null && c.isNotEmpty)
      .toSet()
      .length;

  int listedActiveCount(List<Trial> trials) => trials
      .where(
        (t) => trialIsListedAsActive(
          trialStatus: t.status,
          hasOpenFieldSession: openTrialIds.contains(t.id),
        ),
      )
      .length;

  return TrialsHubStats(
    customTrialCount: customTrials.length,
    customActiveCount: listedActiveCount(customTrials),
    customCompleteCount:
        customTrials.where((t) => _isComplete(t.status)).length,
    customCropCount: customCropCount,
    protocolTrialCount: protocolTrials.length,
    protocolActiveCount: listedActiveCount(protocolTrials),
    protocolCompleteCount:
        protocolTrials.where((t) => _isComplete(t.status)).length,
  );
}

/// Live, reactive stats for Trials Hub (same classification as [customTrialsProvider] / [protocolTrialsProvider]).
/// Active counts use [trialIsListedAsActive] with [openTrialIdsForFieldWorkProvider], matching [TrialListScreen]
/// header pills and Active filter (draft + open field session counts as active).
/// Trials with null, blank, or unknown [Trial.workspaceType] are counted in neither custom nor protocol totals.
final trialsHubStatsProvider =
    Provider.autoDispose<AsyncValue<TrialsHubStats>>((ref) {
  final trialsAsync = ref.watch(trialsStreamProvider);
  final openIdsAsync = ref.watch(openTrialIdsForFieldWorkProvider);

  return trialsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (allTrials) {
      final openIds = openIdsAsync.valueOrNull ?? <int>{};
      return AsyncValue.data(_computeTrialsHubStats(allTrials, openIds));
    },
  );
});
