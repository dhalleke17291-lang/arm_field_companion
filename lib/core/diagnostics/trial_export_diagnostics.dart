import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'diagnostic_finding.dart';

/// Shown in trial readiness sheet — identifies [ExportTrialUseCase] snapshots.
const String kTrialExportAttemptLabel = 'Trial Export';

/// Shown in trial readiness sheet — identifies [ExportArmRatingShellUseCase] snapshots.
const String kArmRatingShellExportAttemptLabel = 'ARM Rating Shell';

/// Snapshot from the latest trial-scoped export publish (in-memory only).
class TrialExportDiagnosticsSnapshot {
  const TrialExportDiagnosticsSnapshot({
    required this.findings,
    required this.publishedAt,
    required this.attemptLabel,
  });

  final List<DiagnosticFinding> findings;
  final DateTime publishedAt;

  /// Which export path produced this snapshot (e.g. flat CSV/ZIP vs ARM Rating Shell).
  final String attemptLabel;
}

/// In-memory, app-session–scoped cache of the last export-time diagnostics
/// per trial (validation + ARM confidence). Not persisted to disk.
class TrialExportDiagnosticsMapNotifier
    extends StateNotifier<Map<int, TrialExportDiagnosticsSnapshot>> {
  TrialExportDiagnosticsMapNotifier() : super(const {});

  /// Replaces the snapshot for [trialId]. [publishedAt] is set to now on every call.
  void setTrialSnapshot(
    int trialId,
    List<DiagnosticFinding> findings,
    String attemptLabel,
  ) {
    state = {
      ...state,
      trialId: TrialExportDiagnosticsSnapshot(
        findings: List<DiagnosticFinding>.unmodifiable(findings),
        publishedAt: DateTime.now(),
        attemptLabel: attemptLabel,
      ),
    };
  }
}

final trialExportDiagnosticsMapProvider = StateNotifierProvider<
    TrialExportDiagnosticsMapNotifier,
    Map<int, TrialExportDiagnosticsSnapshot>>((ref) {
  return TrialExportDiagnosticsMapNotifier();
});
