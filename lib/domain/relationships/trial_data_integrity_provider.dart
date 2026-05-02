import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../features/diagnostics/integrity_check_result.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class TrialIntegrityState {
  final List<IntegrityIssue> issues;

  const TrialIntegrityState({required this.issues});

  bool get isClean => issues.isEmpty;
  int get issueCount => issues.length;
  bool get hasRepairableIssues => issues.any((i) => i.isRepairable);

  String get summaryText {
    if (issues.isEmpty) return 'clean';
    if (issues.length == 1) {
      final issue = issues.first;
      return '${issue.count} ${_labelForCode(issue.code, issue.count)}';
    }
    final n = issueCount;
    return n == 1 ? '1 issue found' : '$n issues found';
  }
}

String _labelForCode(String code, int count) {
  final plural = count != 1;
  return switch (code) {
    'duplicate_current_ratings' =>
      plural ? 'duplicate ratings' : 'duplicate rating',
    'sessions_without_creator' =>
      plural ? 'sessions without creator' : 'session without creator',
    'plots_without_treatment' =>
      plural ? 'plots without treatment' : 'plot without treatment',
    'closed_sessions_no_ratings' =>
      plural ? 'closed sessions with no ratings' : 'closed session with no ratings',
    'corrections_missing_reason' =>
      plural ? 'corrections missing reason' : 'correction missing reason',
    'corrections_missing_corrected_by' =>
      plural ? 'corrections missing attribution' : 'correction missing attribution',
    'ratings_missing_provenance' =>
      plural ? 'ratings missing provenance' : 'rating missing provenance',
    'trials_with_no_plots' =>
      plural ? 'trials with no plots' : 'trial with no plots',
    'duplicate_session_assessments' =>
      plural ? 'duplicate session assessments' : 'duplicate session assessment',
    _ => plural ? 'issues found' : 'issue found',
  };
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final trialDataIntegrityProvider =
    FutureProvider.autoDispose.family<TrialIntegrityState, int>(
        (ref, trialId) async {
  final repo = ref.watch(integrityCheckRepositoryProvider);
  final issues = await repo.runChecksForTrial(trialId);
  return TrialIntegrityState(issues: issues);
});
