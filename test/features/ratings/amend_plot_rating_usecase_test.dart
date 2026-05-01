import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/domain/ratings/rating_integrity_guard.dart';
import 'package:arm_field_companion/domain/signals/signal_models.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/ratings/usecases/amend_plot_rating_usecase.dart';
import 'package:arm_field_companion/features/ratings/usecases/save_rating_usecase.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AmendPlotRatingUseCase — scale violation wiring', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      container.dispose();
      await db.close();
    });

    test('raises scale violation signal when amended value exceeds scale max',
        () async {
      // Arrange: insert trial, session, plot, and session-assessment link.
      const assessmentId = 1;
      final trialId = await db
          .into(db.trials)
          .insert(TrialsCompanion.insert(name: 'AmendTest'));
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-04-01',
            ),
          );
      final plotPk = await db
          .into(db.plots)
          .insert(PlotsCompanion.insert(trialId: trialId, plotId: 'P1'));
      // Required so RatingIntegrityGuard.assertAssessmentInSession passes.
      await db.into(db.sessionAssessments).insert(
            SessionAssessmentsCompanion.insert(
              sessionId: sessionId,
              assessmentId: assessmentId,
            ),
          );

      final sessionRepo = SessionRepository(db);
      final ratingRepo = RatingRepository(db);
      final plotRepo = PlotRepository(db);
      final treatmentRepo = TreatmentRepository(db);
      final integrityGuard =
          RatingIntegrityGuard(plotRepo, sessionRepo, treatmentRepo);
      final saveUseCase = SaveRatingUseCase(ratingRepo, integrityGuard);
      final signalRepo = container.read(signalRepositoryProvider);

      final useCase = AmendPlotRatingUseCase(
        sessionRepo,
        saveUseCase,
        ratingRepo,
        signalRepo,
        db,
      );

      // Act: amend with value 150 — above maxValue of 100.
      await useCase.execute(AmendPlotRatingInput(
        trialId: trialId,
        plotPk: plotPk,
        assessmentId: assessmentId,
        sessionId: sessionId,
        rawValue: '150',
        dataType: 'numeric',
        resultStatus: 'RECORDED',
        minValue: 0.0,
        maxValue: 100.0,
        amendmentReason: 'correction',
        amendedBy: 'tester',
        seType: 'CONTRO',
      ));

      // Assert: one scaleViolation signal was raised.
      final signals = await db.select(db.signals).get();
      expect(signals, hasLength(1));
      expect(signals.single.signalType, SignalType.scaleViolation.dbValue);
    });

    test('does not raise signal when amended value is within scale bounds',
        () async {
      const assessmentId = 1;
      final trialId = await db
          .into(db.trials)
          .insert(TrialsCompanion.insert(name: 'AmendInBounds'));
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-04-01',
            ),
          );
      final plotPk = await db
          .into(db.plots)
          .insert(PlotsCompanion.insert(trialId: trialId, plotId: 'P1'));
      await db.into(db.sessionAssessments).insert(
            SessionAssessmentsCompanion.insert(
              sessionId: sessionId,
              assessmentId: assessmentId,
            ),
          );

      final sessionRepo = SessionRepository(db);
      final ratingRepo = RatingRepository(db);
      final plotRepo = PlotRepository(db);
      final treatmentRepo = TreatmentRepository(db);
      final integrityGuard =
          RatingIntegrityGuard(plotRepo, sessionRepo, treatmentRepo);
      final saveUseCase = SaveRatingUseCase(ratingRepo, integrityGuard);
      final signalRepo = container.read(signalRepositoryProvider);

      final useCase = AmendPlotRatingUseCase(
        sessionRepo,
        saveUseCase,
        ratingRepo,
        signalRepo,
        db,
      );

      await useCase.execute(AmendPlotRatingInput(
        trialId: trialId,
        plotPk: plotPk,
        assessmentId: assessmentId,
        sessionId: sessionId,
        rawValue: '75',  // within [0, 100]
        dataType: 'numeric',
        resultStatus: 'RECORDED',
        minValue: 0.0,
        maxValue: 100.0,
        amendmentReason: 'correction',
        amendedBy: 'tester',
        seType: 'CONTRO',
      ));

      final signals = await db.select(db.signals).get();
      expect(signals, isEmpty);
    });
  });

  group('AmendPlotRatingUseCase — trialAssessmentId propagation', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      container.dispose();
      await db.close();
    });

    test('amended rating row carries trialAssessmentId in the DB', () async {
      final trialId = await db
          .into(db.trials)
          .insert(TrialsCompanion.insert(name: 'TAITest'));
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-05-01',
            ),
          );
      final plotPk = await db
          .into(db.plots)
          .insert(PlotsCompanion.insert(trialId: trialId, plotId: 'P1'));
      final assessmentId = await db
          .into(db.assessments)
          .insert(AssessmentsCompanion.insert(trialId: trialId, name: 'A'));
      await db.into(db.sessionAssessments).insert(
            SessionAssessmentsCompanion.insert(
              sessionId: sessionId,
              assessmentId: assessmentId,
            ),
          );

      // ARM chain providing trialAssessmentId.
      final defId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'TST',
              name: 'Test',
              category: 'pest',
            ),
          );
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
            ),
          );

      final sessionRepo = SessionRepository(db);
      final ratingRepo = RatingRepository(db);
      final plotRepo = PlotRepository(db);
      final treatmentRepo = TreatmentRepository(db);
      final integrityGuard =
          RatingIntegrityGuard(plotRepo, sessionRepo, treatmentRepo);
      final saveUseCase = SaveRatingUseCase(ratingRepo, integrityGuard);
      final signalRepo = container.read(signalRepositoryProvider);

      final useCase = AmendPlotRatingUseCase(
        sessionRepo,
        saveUseCase,
        ratingRepo,
        signalRepo,
        db,
      );

      final result = await useCase.execute(AmendPlotRatingInput(
        trialId: trialId,
        plotPk: plotPk,
        assessmentId: assessmentId,
        sessionId: sessionId,
        rawValue: '50',
        dataType: 'numeric',
        resultStatus: 'RECORDED',
        minValue: 0.0,
        maxValue: 100.0,
        amendmentReason: 'test',
        amendedBy: 'tester',
        trialAssessmentId: taId,
      ));

      expect(result.isSuccess, isTrue);

      final ratings = await db.select(db.ratingRecords).get();
      final current = ratings.where((r) => r.isCurrent).toList();
      expect(current, hasLength(1));
      expect(current.single.trialAssessmentId, taId);
    });

    test(
        'amend outside timing window raises causal_context_flag and keeps trialAssessmentId',
        () async {
      final trialId = await db
          .into(db.trials)
          .insert(TrialsCompanion.insert(
            name: 'AmendTiming',
            workspaceType: const Value('efficacy'),
          ));
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-06-10',
            ),
          );
      final plotPk = await db
          .into(db.plots)
          .insert(PlotsCompanion.insert(trialId: trialId, plotId: 'P1'));
      final assessmentId = await db
          .into(db.assessments)
          .insert(AssessmentsCompanion.insert(trialId: trialId, name: 'A'));
      await db.into(db.sessionAssessments).insert(
            SessionAssessmentsCompanion.insert(
              sessionId: sessionId,
              assessmentId: assessmentId,
            ),
          );

      // ARM chain + metadata used by timing writer.
      final defId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'TST',
              name: 'Test',
              category: 'pest',
            ),
          );
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
            ),
          );
      await db.into(db.armAssessmentMetadata).insert(
            ArmAssessmentMetadataCompanion.insert(
              trialAssessmentId: taId,
              ratingType: const Value('CONTRO'),
            ),
          );
      await db.into(db.trialApplicationEvents).insert(
            TrialApplicationEventsCompanion(
              trialId: Value(trialId),
              applicationDate: Value(DateTime.now().toUtc()),
              status: const Value('applied'),
            ),
          );

      final sessionRepo = SessionRepository(db);
      final ratingRepo = RatingRepository(db);
      final plotRepo = PlotRepository(db);
      final treatmentRepo = TreatmentRepository(db);
      final integrityGuard =
          RatingIntegrityGuard(plotRepo, sessionRepo, treatmentRepo);
      final saveUseCase = SaveRatingUseCase(ratingRepo, integrityGuard);
      final signalRepo = container.read(signalRepositoryProvider);

      final useCase = AmendPlotRatingUseCase(
        sessionRepo,
        saveUseCase,
        ratingRepo,
        signalRepo,
        db,
      );

      final result = await useCase.execute(AmendPlotRatingInput(
        trialId: trialId,
        plotPk: plotPk,
        assessmentId: assessmentId,
        sessionId: sessionId,
        rawValue: '55',
        dataType: 'numeric',
        resultStatus: 'RECORDED',
        minValue: 0.0,
        maxValue: 100.0,
        amendmentReason: 'timing test',
        amendedBy: 'tester',
        trialAssessmentId: taId,
      ));

      expect(result.isSuccess, isTrue);

      final ratings = await db.select(db.ratingRecords).get();
      final current = ratings.where((r) => r.isCurrent).toList();
      expect(current, hasLength(1));
      expect(current.single.trialAssessmentId, taId);

      // Timing writer runs unawaited inside AmendPlotRatingUseCase.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final signals = await db.select(db.signals).get();
      expect(signals, hasLength(1));
      expect(signals.single.signalType, SignalType.causalContextFlag.dbValue);
    });
  });
}
