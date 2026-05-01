import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../domain/signals/signal_providers.dart';
import '../../domain/signals/signal_writers/aov_error_variance_writer.dart';
import '../../domain/signals/signal_writers/replication_warning_writer.dart';
import '../../domain/signals/signal_writers/timing_window_violation_writer.dart';

/// Runs session-close signal writers in sequence. Each writer is isolated: a
/// failure is logged and does not skip the remaining writers.
///
/// After all attempts, [openSignalsForSessionProvider] for [sessionId] is
/// invalidated so [SessionCloseDiagnostic] observes fresh open signals.
Future<void> runSessionCloseSignalWriters(
  WidgetRef ref, {
  required int trialId,
  required int sessionId,
}) async {
  final db = ref.read(databaseProvider);
  final signalRepo = ref.read(signalRepositoryProvider);

  try {
    await AovErrorVarianceWriter(db, signalRepo).checkAndRaiseForSession(
      trialId: trialId,
      sessionId: sessionId,
    );
  } catch (e) {
    debugPrint('[session close writers] aov: $e');
  }

  try {
    await ReplicationWarningWriter(db, signalRepo).checkAndRaiseForSession(
      trialId: trialId,
      sessionId: sessionId,
    );
  } catch (e) {
    debugPrint('[session close writers] replication: $e');
  }

  try {
    await TimingWindowViolationWriter(db, signalRepo).checkAndRaiseForSession(
      sessionId: sessionId,
    );
  } catch (e) {
    debugPrint('[session close writers] timing: $e');
  }

  ref.invalidate(openSignalsForSessionProvider(sessionId));
}
