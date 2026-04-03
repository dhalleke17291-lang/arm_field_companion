import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'diagnostic_finding.dart';

/// In-memory, app-session–scoped cache of the last export-time diagnostics
/// per trial (validation + ARM confidence). Not persisted to disk.
class TrialExportDiagnosticsMapNotifier
    extends StateNotifier<Map<int, List<DiagnosticFinding>>> {
  TrialExportDiagnosticsMapNotifier() : super(const {});

  void setTrialFindings(int trialId, List<DiagnosticFinding> findings) {
    state = {
      ...state,
      trialId: List<DiagnosticFinding>.unmodifiable(findings),
    };
  }
}

final trialExportDiagnosticsMapProvider = StateNotifierProvider<
    TrialExportDiagnosticsMapNotifier, Map<int, List<DiagnosticFinding>>>((ref) {
  return TrialExportDiagnosticsMapNotifier();
});
