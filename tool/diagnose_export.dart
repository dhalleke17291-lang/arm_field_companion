// Temporary diagnostic: inspect local SQLite DB for export debugging.
//
// Usage (after pulling DB from device, e.g.):
//   adb pull /data/user/0/com.gdmsolutions.armFieldCompanion/app_flutter/arm_field_companion.db ./arm_field_companion.db
//   dart run tool/diagnose_export.dart ./arm_field_companion.db
//
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/diagnose_export.dart <path-to-arm_field_companion.db>\n'
      'On Android, app DB path matches getApplicationDocumentsDirectory() + '
      'arm_field_companion.db (see lib/core/database/app_database.dart).\n'
      'Example:\n'
      '  adb pull .../app_flutter/arm_field_companion.db ./arm_field_companion.db\n'
      '  dart run tool/diagnose_export.dart ./arm_field_companion.db',
    );
    exitCode = 64;
    return;
  }
  final dbPath = args.first;
  final file = File(dbPath);
  if (!file.existsSync()) {
    stderr.writeln('File not found: $dbPath');
    exitCode = 1;
    return;
  }

  final db = AppDatabase.forTesting(NativeDatabase(file));
  try {
    final trials = await db.select(db.trials).get();
    print('=== Trials (${trials.length}) ===');
    for (final t in trials) {
      print(
        'id=${t.id} name=${t.name} isArmLinked=${t.isArmLinked}',
      );
    }

    final armTrials = trials.where((t) => t.isArmLinked).toList();
    if (armTrials.isEmpty) {
      print('\nNo ARM-linked trials.');
      return;
    }

    for (final trial in armTrials) {
      final tid = trial.id;
      print('\n=== ARM-linked trial id=$tid name=${trial.name} ===');

      final plots = await (db.select(db.plots)
            ..where((p) => p.trialId.equals(tid) & p.isDeleted.equals(false))
            ..orderBy([(p) => OrderingTerm.asc(p.id)]))
          .get();
      print('--- Plots (${plots.length}) ---');
      for (final p in plots) {
        print('id=${p.id} plotId=${p.plotId} trialId=${p.trialId}');
      }

      final tas = await (db.select(db.trialAssessments)
            ..where((t) => t.trialId.equals(tid))
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .get();
      print('--- TrialAssessments (${tas.length}) ---');
      for (final ta in tas) {
        print(
          'id=${ta.id} assessmentDefinitionId=${ta.assessmentDefinitionId} '
          'legacyAssessmentId=${ta.legacyAssessmentId} pestCode=${ta.pestCode} '
          'sortOrder=${ta.sortOrder}',
        );
      }

      final sessions = await (db.select(db.sessions)
            ..where((s) => s.trialId.equals(tid) & s.isDeleted.equals(false))
            ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
          .get();
      print('--- Sessions (${sessions.length}) ---');
      for (final s in sessions) {
        print('id=${s.id} name=${s.name} startedAt=${s.startedAt}');
      }

      if (sessions.isEmpty) {
        print('--- No sessions; skipping rating dump ---');
        continue;
      }

      final recent = sessions.first;
      print(
        '\n--- RatingRecords for most recent session '
        'id=${recent.id} name=${recent.name} ---',
      );
      final ratings = await (db.select(db.ratingRecords)
            ..where(
              (r) =>
                  r.trialId.equals(tid) &
                  r.sessionId.equals(recent.id) &
                  r.isDeleted.equals(false),
            )
            ..orderBy([
              (r) => OrderingTerm.asc(r.plotPk),
              (r) => OrderingTerm.asc(r.assessmentId),
            ]))
          .get();
      print('count=${ratings.length}');
      for (final r in ratings) {
        print(
          'plotPk=${r.plotPk} assessmentId=${r.assessmentId} '
          'numericValue=${r.numericValue} textValue=${r.textValue} '
          'isCurrent=${r.isCurrent}',
        );
      }
    }
  } finally {
    await db.close();
  }
}
