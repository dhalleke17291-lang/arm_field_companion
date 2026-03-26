import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/workspace/workspace_config.dart';
import 'trial_attention_service.dart';

/// Returns attention items for a single trial.
/// Auto-disposes when the widget using it leaves the tree.
/// Family parameter: trialId (int).
final trialAttentionProvider = FutureProvider.autoDispose
    .family<List<AttentionItem>, int>((ref, trialId) async {
  final trial =
      await ref.watch(trialRepositoryProvider).getTrialById(trialId);
  final resolved = workspaceTypeFromStringOrNull(trial?.workspaceType) ??
      WorkspaceType.efficacy;
  final studyType = WorkspaceConfig.forType(resolved).studyType;

  final service = TrialAttentionService(
    studyType: studyType,
    seedingRepository: ref.watch(seedingRepositoryProvider),
    applicationRepository: ref.watch(applicationRepositoryProvider),
    sessionRepository: ref.watch(sessionRepositoryProvider),
    plotRepository: ref.watch(plotRepositoryProvider),
    assignmentRepository: ref.watch(assignmentRepositoryProvider),
    ratingRepository: ref.watch(ratingRepositoryProvider),
  );

  return service.getAttentionItems(trialId);
});
