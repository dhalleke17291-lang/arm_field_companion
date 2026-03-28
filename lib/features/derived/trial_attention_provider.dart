import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/trial_operational_watch_merge.dart';
import '../../core/workspace/workspace_config.dart';
import 'trial_attention_service.dart';

/// Returns attention items for a single trial.
/// Recomputes whenever relevant execution or protocol rows change for this trial.
/// Auto-disposes when the widget using it leaves the tree.
/// Family parameter: trialId (int).
final trialAttentionProvider = StreamProvider.autoDispose
    .family<List<AttentionItem>, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return mergeTrialOperationalTableWatches(db, trialId).asyncMap((_) async {
    final trial =
        await ref.read(trialRepositoryProvider).getTrialById(trialId);
    final resolved = workspaceTypeFromStringOrNull(trial?.workspaceType) ??
        WorkspaceType.efficacy;
    final studyType = WorkspaceConfig.forType(resolved).studyType;

    final service = TrialAttentionService(
      studyType: studyType,
      seedingRepository: ref.read(seedingRepositoryProvider),
      applicationRepository: ref.read(applicationRepositoryProvider),
      sessionRepository: ref.read(sessionRepositoryProvider),
      plotRepository: ref.read(plotRepositoryProvider),
      assignmentRepository: ref.read(assignmentRepositoryProvider),
      ratingRepository: ref.read(ratingRepositoryProvider),
      db: db,
    );

    return service.getAttentionItems(trialId);
  });
});
