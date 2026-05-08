import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_coherence_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_purpose_dto.dart';
import 'package:arm_field_companion/features/trials/tabs/trial_overview/section_7_coherence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Trial _trial({int id = 1}) => Trial(
      id: id,
      name: 'T1',
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      region: 'eppo_eu',
      isDeleted: false,
    );

TrialPurposeDto _emptyPurpose() => const TrialPurposeDto(
      trialId: 1,
      purposeStatus: 'unknown',
      missingIntentFields: [],
      provenanceSummary: 'test',
      canDriveReadinessClaims: false,
    );

TrialCoherenceDto _coherence({
  required int aligned,
  required int reviewNeeded,
  int cannotEvaluate = 0,
}) {
  final checks = [
    for (var i = 0; i < aligned; i++)
      TrialCoherenceCheckDto(
        checkKey: 'aligned_$i',
        label: 'Aligned check $i',
        status: 'aligned',
        reason: 'OK.',
        sourceFields: const [],
      ),
    for (var i = 0; i < reviewNeeded; i++)
      TrialCoherenceCheckDto(
        checkKey: 'review_$i',
        label: 'Review check $i',
        status: 'review_needed',
        reason: 'Needs review.',
        sourceFields: const [],
      ),
    for (var i = 0; i < cannotEvaluate; i++)
      TrialCoherenceCheckDto(
        checkKey: 'cannot_$i',
        label: 'Cannot evaluate $i',
        status: 'cannot_evaluate',
        reason: 'Missing input.',
        sourceFields: const [],
      ),
  ];
  final state = reviewNeeded > 0 || cannotEvaluate > 0
      ? 'review_needed'
      : 'aligned';
  return TrialCoherenceDto(
    coherenceState: state,
    checks: checks,
    computedAt: DateTime(2026, 1, 1),
  );
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _wrap({
  required Trial trial,
  required TrialCoherenceDto coherence,
  TrialPurposeDto? purpose,
}) {
  return ProviderScope(
    overrides: [
      trialCoherenceProvider(trial.id)
          .overrideWith((_) => Stream.value(coherence)),
      trialPurposeProvider(trial.id)
          .overrideWith((_) => Stream.value(purpose ?? _emptyPurpose())),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Section7Coherence(trial: trial),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Section7Coherence — summary header', () {
    testWidgets(
        'S7-H1: all aligned → header shows N of N checks aligned.',
        (tester) async {
      await tester.pumpWidget(
        _wrap(trial: _trial(), coherence: _coherence(aligned: 4, reviewNeeded: 0)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('4 of 4 checks aligned.'), findsOneWidget);
    });

    testWidgets(
        'S7-H2: some review_needed → header shows aligned count and review count',
        (tester) async {
      await tester.pumpWidget(
        _wrap(trial: _trial(), coherence: _coherence(aligned: 3, reviewNeeded: 1)),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('3 of 4 checks aligned.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('1 needs review'),
        findsOneWidget,
      );
    });

    testWidgets(
        'S7-H3: plural needs review → header uses "need"',
        (tester) async {
      await tester.pumpWidget(
        _wrap(trial: _trial(), coherence: _coherence(aligned: 2, reviewNeeded: 2)),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('2 of 4 checks aligned.'),
        findsOneWidget,
      );
      expect(find.textContaining('2 need review'), findsOneWidget);
    });

    testWidgets(
        'S7-H4: no checks → shows No coherence concerns without summary header',
        (tester) async {
      final emptyCoherence = TrialCoherenceDto(
        coherenceState: 'aligned',
        checks: const [],
        computedAt: DateTime(2026, 1, 1),
      );
      await tester.pumpWidget(
        _wrap(trial: _trial(), coherence: emptyCoherence),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('of 0 checks'), findsNothing);
      expect(
        find.textContaining('No coherence concerns identified.'),
        findsOneWidget,
      );
    });
  });
}
