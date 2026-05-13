import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<int> makeTrial() {
    return db.into(db.trials).insert(TrialsCompanion.insert(name: 'Wheat'));
  }

  Future<int> makePlot(
    int trialId, {
    String plotId = '101',
    int? rep = 1,
    String? plotNotes,
  }) {
    return db.into(db.plots).insert(PlotsCompanion.insert(
          trialId: trialId,
          plotId: plotId,
          rep: Value(rep),
          plotNotes: Value(plotNotes),
        ));
  }

  Future<int> makeSession(int trialId) {
    return db.into(db.sessions).insert(SessionsCompanion.insert(
          trialId: trialId,
          name: 'Session 1',
          sessionDateLocal: '2026-05-11',
        ));
  }

  Future<int> makeAssessment(int trialId) {
    return db.into(db.assessments).insert(AssessmentsCompanion.insert(
          trialId: trialId,
          name: '% disease severity',
        ));
  }

  Future<int> makeRating({
    required int trialId,
    required int plotPk,
    required int sessionId,
    required int assessmentId,
    String? amendmentReason,
    DateTime? amendedAt,
  }) {
    return db.into(db.ratingRecords).insert(RatingRecordsCompanion.insert(
          trialId: trialId,
          plotPk: plotPk,
          sessionId: sessionId,
          assessmentId: assessmentId,
          resultStatus: const Value('RECORDED'),
          numericValue: const Value(12),
          amendmentReason: Value(amendmentReason),
          amendedBy: const Value('Parminder'),
          amendedAt: Value(amendedAt),
        ));
  }

  Future<List<ResearcherContextEntry>> loadEntries(int trialId) async {
    final container = makeContainer();
    return container.read(researcherContextEntriesProvider(trialId).future);
  }

  ResearcherContextEntry onlyEntryOf(
    List<ResearcherContextEntry> entries,
    String type,
  ) {
    return entries.where((entry) => entry.contextType == type).single;
  }

  group('researcherContextEntriesProvider assembler', () {
    test('RC-1: assembler includes plot notes', () async {
      final trialId = await makeTrial();
      await makePlot(trialId, plotNotes: 'North edge has standing water.');

      final entries = await loadEntries(trialId);
      final entry = onlyEntryOf(entries, 'Plot notes');

      expect(entry.title, 'Plot 101');
      expect(entry.text, 'North edge has standing water.');
      expect(entry.detail, 'Rep 1');
    });

    test('RC-2: assembler includes field and session notes', () async {
      final trialId = await makeTrial();
      final plotPk = await makePlot(trialId);
      final sessionId = await makeSession(trialId);

      await db.into(db.notes).insert(NotesCompanion.insert(
            trialId: trialId,
            content: 'Field entrance was wet.',
            raterName: const Value('Parminder'),
            createdAt: Value(DateTime(2026, 5, 11, 9)),
          ));
      await db.into(db.notes).insert(NotesCompanion.insert(
            trialId: trialId,
            plotPk: Value(plotPk),
            sessionId: Value(sessionId),
            content: 'Recheck crop response after rain.',
            createdAt: Value(DateTime(2026, 5, 11, 10)),
          ));

      final entries = await loadEntries(trialId);
      final field = onlyEntryOf(entries, 'Field notes');
      final session = onlyEntryOf(entries, 'Session notes');

      expect(field.title, 'Field note');
      expect(field.text, 'Field entrance was wet.');
      expect(field.author, 'Parminder');
      expect(session.title, 'Session 1 · Plot 101');
      expect(session.text, 'Recheck crop response after rain.');
    });

    test('RC-3: assembler includes plot flags', () async {
      final trialId = await makeTrial();
      final plotPk = await makePlot(trialId);
      final sessionId = await makeSession(trialId);

      await db.into(db.plotFlags).insert(PlotFlagsCompanion.insert(
            trialId: trialId,
            plotPk: plotPk,
            sessionId: sessionId,
            flagType: 'FIELD_OBSERVATION',
            description: const Value('Spray drift visible on west edge.'),
            raterName: const Value('Parminder'),
            createdAt: Value(DateTime(2026, 5, 11, 11)),
          ));

      final entries = await loadEntries(trialId);
      final entry = onlyEntryOf(entries, 'Plot flags');

      expect(entry.title, 'Plot 101');
      expect(entry.text, 'Spray drift visible on west edge.');
      expect(entry.detail, 'Session 1');
      expect(entry.author, 'Parminder');
    });

    test('RC-4: assembler includes amendment reasons', () async {
      final trialId = await makeTrial();
      final plotPk = await makePlot(trialId);
      final sessionId = await makeSession(trialId);
      final assessmentId = await makeAssessment(trialId);
      await makeRating(
        trialId: trialId,
        plotPk: plotPk,
        sessionId: sessionId,
        assessmentId: assessmentId,
        amendmentReason: 'Corrected typo after source-sheet check.',
        amendedAt: DateTime(2026, 5, 11, 12),
      );

      final entries = await loadEntries(trialId);
      final entry = onlyEntryOf(entries, 'Amendment reasons');

      expect(entry.title, '% disease severity · Plot 101');
      expect(entry.text, 'Corrected typo after source-sheet check.');
      expect(entry.detail, 'Session 1');
      expect(entry.author, 'Parminder');
    });

    test('RC-5: assembler includes correction reasons', () async {
      final trialId = await makeTrial();
      final plotPk = await makePlot(trialId);
      final sessionId = await makeSession(trialId);
      final assessmentId = await makeAssessment(trialId);
      final ratingId = await makeRating(
        trialId: trialId,
        plotPk: plotPk,
        sessionId: sessionId,
        assessmentId: assessmentId,
      );
      await db.into(db.ratingCorrections).insert(
            RatingCorrectionsCompanion.insert(
              ratingId: ratingId,
              oldResultStatus: 'RECORDED',
              newResultStatus: 'RECORDED',
              reason: 'Corrected value after reviewing plot photo.',
              sessionId: Value(sessionId),
              plotPk: Value(plotPk),
              correctedAt: Value(DateTime(2026, 5, 11, 13)),
            ),
          );

      final entries = await loadEntries(trialId);
      final entry = onlyEntryOf(entries, 'Correction reasons');

      expect(entry.title, '% disease severity · Plot 101');
      expect(entry.text, 'Corrected value after reviewing plot photo.');
      expect(entry.detail, 'Session 1');
    });

    test('RC-6: assembler includes photo captions', () async {
      final trialId = await makeTrial();
      final plotPk = await makePlot(trialId);
      final sessionId = await makeSession(trialId);

      await db.into(db.photos).insert(PhotosCompanion.insert(
            trialId: trialId,
            plotPk: plotPk,
            sessionId: sessionId,
            filePath: '/tmp/photo.jpg',
            caption: const Value('Shows uneven disease pressure in T2.'),
            createdAt: Value(DateTime(2026, 5, 11, 13, 30)),
          ));

      final entries = await loadEntries(trialId);
      final entry = onlyEntryOf(entries, 'Photo captions');

      expect(entry.title, 'Plot 101');
      expect(entry.text, 'Shows uneven disease pressure in T2.');
      expect(entry.detail, 'Session 1');
    });

    test('RC-7: assembler includes CTQ acknowledgment reasons', () async {
      final trialId = await makeTrial();
      await db.into(db.ctqFactorAcknowledgments).insert(
            CtqFactorAcknowledgmentsCompanion.insert(
              trialId: trialId,
              factorKey: 'photo_evidence',
              acknowledgedAt: DateTime(2026, 5, 11, 14).millisecondsSinceEpoch,
              reason: 'Photo gap accepted because field notes document damage.',
              factorStatusAtAcknowledgment: 'review_needed',
            ),
          );

      final entries = await loadEntries(trialId);
      final entry = onlyEntryOf(entries, 'CTQ acknowledgment reasons');

      expect(entry.title, 'photo_evidence');
      expect(entry.text,
          'Photo gap accepted because field notes document damage.');
      expect(entry.detail, 'review_needed');
    });

    test('RC-8: assembler includes signal decision notes', () async {
      final trialId = await makeTrial();
      final signalId = await db.into(db.signals).insert(
            SignalsCompanion.insert(
              trialId: trialId,
              signalType: 'scale_violation',
              moment: 2,
              severity: 'review',
              raisedAt: DateTime(2026, 5, 11, 15).millisecondsSinceEpoch,
              referenceContext: '{}',
              consequenceText: 'Value outside expected range.',
              createdAt: DateTime(2026, 5, 11, 15).millisecondsSinceEpoch,
            ),
          );
      await db.into(db.signalDecisionEvents).insert(
            SignalDecisionEventsCompanion.insert(
              signalId: signalId,
              eventType: 'confirm',
              occurredAt: DateTime(2026, 5, 11, 16).millisecondsSinceEpoch,
              note: const Value('Confirmed as real field variability.'),
              resultingStatus: 'resolved',
              createdAt: DateTime(2026, 5, 11, 16).millisecondsSinceEpoch,
            ),
          );

      final entries = await loadEntries(trialId);
      final entry = onlyEntryOf(entries, 'Signal decision notes');

      expect(entry.title, 'Signal $signalId · confirm');
      expect(entry.text, 'Confirmed as real field variability.');
      expect(entry.detail, 'resolved');
    });

    test('RC-9: assembler includes trial intent answers', () async {
      final trialId = await makeTrial();
      await db.into(db.intentRevelationEvents).insert(
            IntentRevelationEventsCompanion.insert(
              trialId: trialId,
              touchpoint: 'mode_c',
              questionKey: 'primary_endpoint',
              questionText: 'What is the primary endpoint?',
              answerValue: const Value('% disease severity'),
              answerState: const Value('captured'),
              source: 'researcher',
              capturedBy: const Value('Parminder'),
              capturedAt: Value(DateTime(2026, 5, 11, 17)),
            ),
          );

      final entries = await loadEntries(trialId);
      final entry = onlyEntryOf(entries, 'Trial intent answers');

      expect(entry.title, 'What is the primary endpoint?');
      expect(entry.text, '% disease severity');
      expect(entry.detail, 'captured');
      expect(entry.author, 'Parminder');
    });

    test('RC-10: null optional columns return no context entries', () async {
      final trialId = await makeTrial();
      final plotPk = await makePlot(trialId);
      final sessionId = await makeSession(trialId);

      await db.into(db.photos).insert(PhotosCompanion.insert(
            trialId: trialId,
            plotPk: plotPk,
            sessionId: sessionId,
            filePath: '/tmp/photo.jpg',
          ));
      await db.into(db.assignments).insert(AssignmentsCompanion.insert(
            trialId: trialId,
            plotId: plotPk,
          ));
      await db.into(db.evidenceAnchors).insert(
            EvidenceAnchorsCompanion.insert(
              trialId: trialId,
              evidenceType: 'photo',
              evidenceId: 1,
              claimType: 'session',
              claimId: sessionId,
              anchoredAt: DateTime(2026, 5, 11, 18).millisecondsSinceEpoch,
              createdAt: DateTime(2026, 5, 11, 18).millisecondsSinceEpoch,
            ),
          );

      final entries = await loadEntries(trialId);
      final types = entries.map((entry) => entry.contextType).toSet();

      expect(types, isNot(contains('Photo captions')));
      expect(types, isNot(contains('Assignment notes')));
      expect(types, isNot(contains('Evidence anchor reasons')));
    });
  });
}
