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
import 'package:arm_field_companion/features/sessions/session_summary_screen.dart';
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

  // Rating entry from session hub (SessionSummaryScreen).
  //
  // Migrated from 'Rating entry from SessionDetail':
  //   SUCCESS path → hub plot tap → RatingScreen pushed (covered below).
  //   FAILURE path → 'Cannot Start Rating' dialog CANNOT be migrated to the hub:
  //     SessionSummaryScreen bypasses startOrContinueRatingUseCaseProvider entirely
  //     and pushes RatingScreen directly on plot tap. The use case failure handling
  //     survives in trial_list_screen, main_shell_screen, and work_log_screen, and
  //     is unit-tested in start_or_continue_rating_usecase_test.dart.
  group('Rating entry from session hub', () {
    testWidgets('plot tap pushes RatingScreen', (WidgetTester tester) async {
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(800, 1400));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            plotsForTrialProvider(trial.id)
                .overrideWith((ref) => Stream.value(plots)),
            sessionRatingsProvider(session.id)
                .overrideWith((ref) => Stream.value([])),
            sessionAssessmentsProvider(session.id)
                .overrideWith((ref) => Stream.value(assessments)),
            ratedPlotPksProvider(session.id)
                .overrideWith((ref) => Stream.value({})),
            treatmentsForTrialProvider(trial.id)
                .overrideWith((ref) => Stream.value([])),
            assignmentsForTrialProvider(trial.id)
                .overrideWith((ref) => Stream.value([])),
            flaggedPlotIdsForSessionProvider(session.id)
                .overrideWith((ref) => Stream.value({})),
          ],
          child: MaterialApp(
            home: SessionSummaryScreen(trial: trial, session: session),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Plot (rep=1, position=1 in rep) renders as '101' in the frozen column.
      // getDisplayPlotNumber: 1 * 100 + 1 = 101.
      final plotLabel = find.text('101');
      expect(plotLabel, findsOneWidget);
      await tester.tap(plotLabel);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(RatingScreen), findsOneWidget);
    });
  });
}
