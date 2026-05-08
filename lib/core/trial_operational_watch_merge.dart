import 'dart:async';

import 'database/app_database.dart';

/// Emits whenever any of [streams] emits (used to trigger provider recomputation).
Stream<int> mergeTableWatchStreams(List<Stream<dynamic>> streams) {
  late StreamController<int> controller;
  controller = StreamController<int>(
    onListen: () {
      void pump() {
        if (!controller.isClosed) {
          controller.add(0);
        }
      }

      final subscriptions = <StreamSubscription<dynamic>>[];

      for (final stream in streams) {
        subscriptions.add(
          stream.listen(
            (_) => pump(),
            onError: controller.addError,
          ),
        );
      }

      controller.onCancel = () {
        for (final sub in subscriptions) {
          sub.cancel();
        }
      };
    },
  );
  return controller.stream;
}

/// Drift [watch] on tables that reflect operational trial state for [trialId].
/// Any write to these tables should trigger consumers that merge this stream.
Stream<int> mergeTrialOperationalTableWatches(AppDatabase db, int trialId) {
  return mergeTableWatchStreams([
    (db.select(db.seedingEvents)..where((s) => s.trialId.equals(trialId)))
        .watch(),
    (db.select(db.sessions)..where((s) => s.trialId.equals(trialId))).watch(),
    (db.select(db.trialApplicationEvents)
          ..where((e) => e.trialId.equals(trialId)))
        .watch(),
    (db.select(db.plots)..where((p) => p.trialId.equals(trialId))).watch(),
    (db.select(db.assignments)..where((a) => a.trialId.equals(trialId)))
        .watch(),
    (db.select(db.ratingRecords)..where((r) => r.trialId.equals(trialId)))
        .watch(),
    (db.select(db.trialAssessments)..where((t) => t.trialId.equals(trialId)))
        .watch(),
    (db.select(db.assessments)..where((a) => a.trialId.equals(trialId)))
        .watch(),
    (db.select(db.trials)..where((t) => t.id.equals(trialId))).watch(),
    (db.select(db.treatments)..where((t) => t.trialId.equals(trialId))).watch(),
    (db.select(db.treatmentComponents)..where((c) => c.trialId.equals(trialId)))
        .watch(),
    (db.select(db.signals)..where((s) => s.trialId.equals(trialId))).watch(),
    db.select(db.signalDecisionEvents).watch(),
    (db.select(db.trialPurposes)..where((p) => p.trialId.equals(trialId)))
        .watch(),
    (db.select(db.ctqFactorDefinitions)
          ..where((f) => f.trialId.equals(trialId)))
        .watch(),
    (db.select(db.ctqFactorAcknowledgments)
          ..where((a) => a.trialId.equals(trialId)))
        .watch(),
  ]);
}

/// Tables read by [TodayActivityRepository] (activity feed + date index).
/// Any change here should re-run day aggregation.
Stream<int> mergeTodayActivityTableWatches(AppDatabase db) {
  return mergeTableWatchStreams([
    db.select(db.sessions).watch(),
    db.select(db.auditEvents).watch(),
    db.select(db.ratingRecords).watch(),
    db.select(db.plotFlags).watch(),
    db.select(db.photos).watch(),
    db.select(db.assignments).watch(),
    db.select(db.trials).watch(),
  ]);
}
