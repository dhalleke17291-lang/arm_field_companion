import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/domain/trial_story/trial_story_event.dart';
import 'package:arm_field_companion/domain/trial_story/trial_story_provider.dart';
import 'package:arm_field_companion/features/trials/trial_story_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Trial _trial({int id = 1, String name = 'Test Trial'}) => Trial(
      id: id,
      name: name,
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      isDeleted: false,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TrialStoryScreen', () {
    testWidgets('empty provider → shows No events recorded yet',
        (WidgetTester tester) async {
      final trial = _trial();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trialStoryProvider(trial.id).overrideWith(
              (ref) async => const <TrialStoryEvent>[],
            ),
          ],
          child: MaterialApp(
            home: TrialStoryScreen(trial: trial),
          ),
        ),
      );

      // First pump resolves the FutureProvider.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No events recorded yet'), findsOneWidget);
    });

    testWidgets('AppBar shows Trial Story title', (WidgetTester tester) async {
      final trial = _trial(name: 'Wheat 2026');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trialStoryProvider(trial.id).overrideWith(
              (ref) async => const <TrialStoryEvent>[],
            ),
          ],
          child: MaterialApp(
            home: TrialStoryScreen(trial: trial),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Trial Story'), findsOneWidget);
      expect(find.text('Wheat 2026'), findsOneWidget);
    });

    testWidgets('data list → renders event title in tile',
        (WidgetTester tester) async {
      final trial = _trial();
      final events = [
        TrialStoryEvent(
          id: 'seed-1',
          type: TrialStoryEventType.seeding,
          occurredAt: DateTime(2026, 1, 15),
          title: 'Seeding',
          subtitle: 'Var. Pioneer P9910',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trialStoryProvider(trial.id).overrideWith(
              (ref) async => events,
            ),
          ],
          child: MaterialApp(
            home: TrialStoryScreen(trial: trial),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Seeding'), findsOneWidget);
      expect(find.text('Var. Pioneer P9910'), findsOneWidget);
    });
  });
}
