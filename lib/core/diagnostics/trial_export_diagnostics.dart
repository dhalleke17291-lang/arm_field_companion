import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'diagnostic_finding.dart';

/// Snapshot from the latest [ExportTrialUseCase] publish for a trial (in-memory only).
class TrialExportDiagnosticsSnapshot {
  const TrialExportDiagnosticsSnapshot({
    required this.findings,
    required this.publishedAt,
  });

  final List<DiagnosticFinding> findings;
  final DateTime publishedAt;
}

/// In-memory, app-session–scoped cache of the last export-time diagnostics
/// per trial (validation + ARM confidence). Not persisted to disk.
class TrialExportDiagnosticsMapNotifier
    extends StateNotifier<Map<int, TrialExportDiagnosticsSnapshot>> {
  TrialExportDiagnosticsMapNotifier() : super(const {});

  /// Replaces the snapshot for [trialId]. [publishedAt] is set to now on every call.
  void setTrialSnapshot(int trialId, List<DiagnosticFinding> findings) {
    state = {
      ...state,
      trialId: TrialExportDiagnosticsSnapshot(
        findings: List<DiagnosticFinding>.unmodifiable(findings),
        publishedAt: DateTime.now(),
      ),
    };
  }
}

final trialExportDiagnosticsMapProvider = StateNotifierProvider<
    TrialExportDiagnosticsMapNotifier,
    Map<int, TrialExportDiagnosticsSnapshot>>((ref) {
  return TrialExportDiagnosticsMapNotifier();
});
