import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arm_field_companion/core/current_user.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/features/sessions/usecases/create_session_usecase.dart';
import 'package:arm_field_companion/features/ratings/rating_screen.dart';
import 'package:arm_field_companion/features/sessions/session_detail_screen.dart';
import 'package:arm_field_companion/features/sessions/usecases/start_or_continue_rating_usecase.dart';
import 'start_or_continue_rating_fakes.dart';

/// Empty [sessions] so Quick Rate stays visible, but [getSessionById] resolves
/// for StartOrContinueRating after create.
class _QuickRateFakeSessionRepository extends FakeSessionRepository {
  _QuickRateFakeSessionRepository({
    required super.sessionToReturnFromCreate,
    required this.resolveSession,
    required super.sessionAssessments,
  }) : super(sessions: const []);

  final Session resolveSession;

  @override
  Future<Session?> getSessionById(int sessionId) async =>
      sessionId == resolveSession.id ? resolveSession : null;
}

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
        row: null,
        column: null,
        fieldRow: null,
        fieldColumn: null,
        assignmentSource: null,
        assignmentUpdatedAt: null,
        plotLengthM: null,
        plotWidthM: null,
        plotAreaM2: null,
        harvestLengthM: null,
        harvestWidthM: null,
        harvestAreaM2: null,
        plotDirection: null,
        soilSeries: null,
        plotNotes: null,
        isGuardRow: false,
        isDeleted: false,
        deletedAt: null,
        deletedBy: null,
        excludeFromAnalysis: false,
        exclusionReason: null,
        damageType: null,
        armPlotNumber: null,
        armImportDataRowIndex: null,
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

  group('Quick Rate (trial list, no open session)', () {
    late AppDatabase testDb;
    late int quickUserId;

    setUp(() async {
      testDb = AppDatabase.forTesting(NativeDatabase.memory());
      quickUserId = await testDb.into(testDb.users).insert(
            UsersCompanion.insert(displayName: 'Quick Rater'),
          );
      SharedPreferences.setMockInitialValues({kCurrentUserIdKey: quickUserId});
    });

    tearDown(() async {
      await testDb.close();
    });

    test('harness: quick path matches CreateSession with rater + user id', () async {
      final fakeSessionRepo = _QuickRateFakeSessionRepository(
        sessionToReturnFromCreate: session,
        resolveSession: session,
        sessionAssessments: {session.id: assessments},
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          assessmentsForTrialProvider(1)
              .overrideWith((ref) => Stream.value(assessments)),
        ],
      );
      addTearDown(container.dispose);
      final legacy =
          await container.read(assessmentsForTrialProvider(1).future);
      expect(legacy, isNotEmpty);
      final uid = await container.read(currentUserIdProvider.future);
      expect(uid, quickUserId);
      final u = await container.read(userRepositoryProvider).getUserById(
            uid!,
          );
      expect(u, isNotNull);
      expect(u!.displayName, 'Quick Rater');
      final create = CreateSessionUseCase(
        fakeSessionRepo,
        promoteTrialToActiveIfReady: (_) async {},
      );
      const dateStr = '2026-01-02';
      final r = await create.execute(
        CreateSessionInput(
          trialId: 1,
          name: '$dateStr Quick',
          sessionDateLocal: dateStr,
          assessmentIds: [201],
          raterName: u.displayName,
          createdByUserId: uid,
        ),
      );
      expect(r.success, isTrue, reason: r.errorMessage);
      expect(r.session?.id, 10);
    });
  });

  group('Rating entry from SessionDetail', () {
    testWidgets('Start Rating success: use case called, RatingScreen pushed',
        (WidgetTester tester) async {
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(800, 1400));

      fakeUseCase.result = StartOrContinueRatingResult.success(
        trial: trial,
        session: session,
        allPlotsSerpentine: plots,
        assessments: assessments,
        startPlotIndex: 0,
        isWalkEndReachedWithAnyRating: false,
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

      final startRatingFinder = find.text('Start Rating');
      await tester.ensureVisible(startRatingFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(startRatingFinder, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(RatingScreen), findsOneWidget);
    });

    testWidgets('Start Rating failure: error dialog shown',
        (WidgetTester tester) async {
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(800, 1400));

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

      final startRatingFinder = find.text('Start Rating');
      await tester.ensureVisible(startRatingFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(startRatingFinder, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(find.byType(RatingScreen), findsNothing);
      expect(find.text('Cannot Start Rating'), findsOneWidget);
      expect(find.text('No plots in trial.'), findsOneWidget);
    });
  });
}
