import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arm_field_companion/main.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/core/current_user.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/ratings/rating_screen.dart';

AppDatabase _makeTestDb() => AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Critical navigation flows', () {
    late AppDatabase db;

    setUp(() async {
      db = _makeTestDb();
      SharedPreferences.setMockInitialValues({kCurrentUserIdKey: 1});
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const ArmFieldCompanionApp(),
        ),
      );
    }

    Future<void> waitForTrialList(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 2700));
      await tester.pumpAndSettle();
    }

    Future<void> seedOpenSession(AppDatabase db) async {
      final trialId = await db.into(db.trials).insert(
            TrialsCompanion.insert(
              name: 'Test Trial',
              status: const drift.Value('draft'),
              crop: const drift.Value('Corn'),
              location: const drift.Value('Field A'),
              season: const drift.Value('2026'),
            ),
          );

      await db.into(db.plots).insert(
            PlotsCompanion.insert(
              trialId: trialId,
              plotId: '1',
            ),
          );

      final assessmentId = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(
              trialId: trialId,
              name: 'Yield',
            ),
          );

      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'Session 1',
              sessionDateLocal: '2026-03-11',
              startedAt: drift.Value(DateTime.now()),
            ),
          );

      await db.into(db.sessionAssessments).insert(
            SessionAssessmentsCompanion.insert(
              sessionId: sessionId,
              assessmentId: assessmentId,
            ),
          );
    }

    /// Trial with plots and assessments but no session (for Quick Rate).
    Future<void> seedTrialNoSession(AppDatabase db) async {
      final trialId = await db.into(db.trials).insert(
            TrialsCompanion.insert(
              name: 'Quick Rate Trial',
              status: const drift.Value('draft'),
              crop: const drift.Value('Wheat'),
              location: const drift.Value('Field B'),
              season: const drift.Value('2026'),
            ),
          );
      await db.into(db.plots).insert(
            PlotsCompanion.insert(
              trialId: trialId,
              plotId: '1',
            ),
          );
      await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(
              trialId: trialId,
              name: 'Score',
            ),
          );
    }

    testWidgets('Continue Session from home → lands on RatingScreen',
        (tester) async {
      await seedOpenSession(db);
      await pumpApp(tester);
      await waitForTrialList(tester);

      expect(find.text('Test Trial'), findsOneWidget);
      expect(find.text('Continue Session'), findsOneWidget);

      await tester.tap(find.text('Continue Session'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byType(RatingScreen), findsOneWidget);
    });

    testWidgets('Open session from trial → PlotQueueScreen → RatingScreen',
        (tester) async {
      await seedOpenSession(db);
      await pumpApp(tester);
      await waitForTrialList(tester);

      // Open trial detail.
      await tester.tap(find.text('Test Trial'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tap Sessions bar to switch to sessions view.
      await tester.tap(find.text('Sessions').first);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tap the open session tile → navigates to PlotQueueScreen.
      await tester.tap(find.text('Session 1'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should be on PlotQueueScreen — tap the single plot tile.
      // Plot has no rep set so fallback label = plotId = '1'.
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should land on RatingScreen.
      expect(find.byType(RatingScreen), findsOneWidget);
    });

    testWidgets('Quick Rate (no open session) → creates session → RatingScreen',
        (tester) async {
      await seedTrialNoSession(db);
      await pumpApp(tester);
      await waitForTrialList(tester);

      expect(find.text('Quick Rate Trial'), findsOneWidget);
      expect(find.text('Quick Rate'), findsOneWidget);

      await tester.tap(find.text('Quick Rate'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(RatingScreen), findsOneWidget);
    });

    // Error path covered by widget test rating_entry_widget_test.dart (Start Rating failure).
    testWidgets('Start Rating error path: no plots → error dialog',
        (tester) async {
      final trialId = await db.into(db.trials).insert(
            TrialsCompanion.insert(
              name: 'No Plots Trial',
              status: const drift.Value('draft'),
            ),
          );
      final assessmentId = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(
              trialId: trialId,
              name: 'Yield',
            ),
          );
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'Empty Session',
              sessionDateLocal: '2026-03-11',
              startedAt: drift.Value(DateTime.now()),
            ),
          );
      await db.into(db.sessionAssessments).insert(
            SessionAssessmentsCompanion.insert(
              sessionId: sessionId,
              assessmentId: assessmentId,
            ),
          );

      await pumpApp(tester);
      await waitForTrialList(tester);

      await tester.tap(find.text('No Plots Trial'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.tap(find.text('Sessions').first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.tap(find.text('Empty Session'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Switch to Rate tab (dock shows "Plots" and "Rate").
      await tester.tap(find.text('Rate'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('Start Rating'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Cannot Start Rating'), findsOneWidget);
    }, skip: true); // Rate tab finder flaky on device; widget test covers error dialog
  });
}
