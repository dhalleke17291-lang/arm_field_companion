import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/features/sessions/usecases/create_session_usecase.dart';
import 'package:arm_field_companion/features/ratings/rating_screen.dart';
import 'package:arm_field_companion/features/sessions/session_detail_screen.dart';
import 'package:arm_field_companion/features/sessions/usecases/start_or_continue_rating_usecase.dart';
import 'package:arm_field_companion/features/trials/trial_list_screen.dart';
import 'start_or_continue_rating_fakes.dart';

void main() {
  late Trial trial;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });
  late Session session;
  late List<Plot> plots;
  late List<Assessment> assessments;
  late FakeStartOrContinueRatingUseCase fakeUseCase;

  setUp(() {
    trial = Trial(
      id: 1,
      name: 'Test Trial',
      crop: null,
      location: null,
      season: null,
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      isDeleted: false,
      isArmLinked: false,
    );
    session = Session(
      id: 10,
      trialId: trial.id,
      name: 'Test Session',
      startedAt: DateTime(2026, 1, 2),
      endedAt: null,
      sessionDateLocal: '2026-01-02',
      raterName: 'R',
      createdByUserId: null,
      status: 'open',
      isDeleted: false,
    );
    plots = [
      Plot(
        id: 101,
        trialId: trial.id,
        plotId: '1',
        plotSortIndex: 1,
        rep: 1,
        treatmentId: null,
        notes: null,
        row: null,
        column: null,
        fieldRow: null,
        fieldColumn: null,
        assignmentSource: null,
        assignmentUpdatedAt: null,
        isGuardRow: false,
        isDeleted: false,
        excludeFromAnalysis: false,
      ),
    ];
    assessments = [
      Assessment(
        id: 201,
        trialId: trial.id,
        name: 'Score',
        unit: null,
        dataType: 'numeric',
        minValue: 0,
        maxValue: 100,
        isActive: true,
      ),
    ];
    fakeUseCase = FakeStartOrContinueRatingUseCase();
  });

  group('Continue Session (trial list)', () {
    testWidgets(
        'tapping Continue Session runs use case and navigates to RatingScreen',
        (WidgetTester tester) async {
      fakeUseCase.result = StartOrContinueRatingResult.success(
        trial: trial,
        session: session,
        allPlotsSerpentine: plots,
        assessments: assessments,
        startPlotIndex: 0,
        isSessionComplete: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trialsStreamProvider.overrideWith((ref) => Stream.value([trial])),
            openSessionProvider(1).overrideWith((ref) => Stream.value(session)),
            startOrContinueRatingUseCaseProvider.overrideWithValue(fakeUseCase),
          ],
          child: const MaterialApp(
            home: TrialListScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Continue Session'), findsOneWidget);
      await tester.tap(find.text('Continue Session'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(RatingScreen), findsOneWidget);
    });
  });

  group('Quick Rate (trial list, no open session)', () {
    testWidgets(
        'tapping Quick Rate creates session and navigates to RatingScreen',
        (WidgetTester tester) async {
      fakeUseCase.result = StartOrContinueRatingResult.success(
        trial: trial,
        session: session,
        allPlotsSerpentine: plots,
        assessments: assessments,
        startPlotIndex: 0,
        isSessionComplete: false,
      );

      final fakeSessionRepo = FakeSessionRepository(
        sessions: const [],
        sessionAssessments: const {},
        sessionToReturnFromCreate: session,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trialsStreamProvider.overrideWith((ref) => Stream.value([trial])),
            openSessionProvider(1).overrideWith((ref) => Stream.value(null)),
            assessmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value(assessments)),
            sessionRepositoryProvider.overrideWithValue(fakeSessionRepo),
            createSessionUseCaseProvider.overrideWith((ref) {
              final sessionRepo = ref.watch(sessionRepositoryProvider);
              return CreateSessionUseCase(
                sessionRepo,
                promoteTrialToActiveIfReady: (_) async {},
              );
            }),
            startOrContinueRatingUseCaseProvider.overrideWithValue(fakeUseCase),
          ],
          child: const MaterialApp(
            home: TrialListScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Quick Rate'), findsOneWidget);
      await tester.tap(find.text('Quick Rate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(RatingScreen), findsOneWidget);
    });
  });

  group('Rating entry from SessionDetail', () {
    testWidgets('Start Rating success: use case called, RatingScreen pushed',
        (WidgetTester tester) async {
      fakeUseCase.result = StartOrContinueRatingResult.success(
        trial: trial,
        session: session,
        allPlotsSerpentine: plots,
        assessments: assessments,
        startPlotIndex: 0,
        isSessionComplete: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            plotsForTrialProvider(1).overrideWith((ref) => Stream.value(plots)),
            sessionRatingsProvider(10).overrideWith((ref) => Stream.value([])),
            sessionAssessmentsProvider(10)
                .overrideWith((ref) => Stream.value(assessments)),
            treatmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value([])),
            assignmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value([])),
            flaggedPlotIdsForSessionProvider(10)
                .overrideWith((ref) => Stream.value({})),
            startOrContinueRatingUseCaseProvider.overrideWithValue(fakeUseCase),
          ],
          child: MaterialApp(
            home: SessionDetailScreen(trial: trial, session: session),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Rate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Start Rating'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(RatingScreen), findsOneWidget);
    });

    testWidgets('Start Rating failure: error dialog shown',
        (WidgetTester tester) async {
      fakeUseCase.result =
          StartOrContinueRatingResult.failure('No plots in trial.');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            plotsForTrialProvider(1).overrideWith((ref) => Stream.value(plots)),
            sessionRatingsProvider(10).overrideWith((ref) => Stream.value([])),
            sessionAssessmentsProvider(10)
                .overrideWith((ref) => Stream.value(assessments)),
            treatmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value([])),
            assignmentsForTrialProvider(1)
                .overrideWith((ref) => Stream.value([])),
            flaggedPlotIdsForSessionProvider(10)
                .overrideWith((ref) => Stream.value({})),
            startOrContinueRatingUseCaseProvider.overrideWithValue(fakeUseCase),
          ],
          child: MaterialApp(
            home: SessionDetailScreen(trial: trial, session: session),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Rate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Start Rating'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byType(RatingScreen), findsNothing);
      expect(find.text('Cannot Start Rating'), findsOneWidget);
      expect(find.text('No plots in trial.'), findsOneWidget);
    });
  });
}
