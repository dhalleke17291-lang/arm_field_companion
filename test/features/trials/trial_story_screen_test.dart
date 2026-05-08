import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/trial_cognition/ctq_factor_acknowledgment_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_ctq_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_decision_summary_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_evidence_arc_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_purpose_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/environmental_window_evaluator.dart';
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
      region: 'eppo_eu',
      isDeleted: false,
    );

TrialPurposeDto _purposeDto({
  String status = 'unknown',
  String? claim,
  List<String> missing = const [],
}) =>
    TrialPurposeDto(
      trialId: 1,
      purposeStatus: status,
      claimBeingTested: claim,
      missingIntentFields: missing,
      provenanceSummary: 'test',
      canDriveReadinessClaims: status == 'confirmed',
    );

TrialEvidenceArcDto _arcDto({String state = 'no_evidence'}) =>
    TrialEvidenceArcDto(
      trialId: 1,
      evidenceState: state,
      plannedEvidenceSummary: '',
      actualEvidenceSummary: '',
      missingEvidenceItems: const [],
      evidenceAnchors: const [],
      riskFlags: const [],
    );

TrialCtqDto _ctqDto({
  String status = 'unknown',
  int blockers = 0,
  int warnings = 0,
  int review = 0,
  int satisfied = 0,
  List<TrialCtqItemDto> items = const [],
}) =>
    TrialCtqDto(
      trialId: 1,
      overallStatus: status,
      blockerCount: blockers,
      warningCount: warnings,
      reviewCount: review,
      satisfiedCount: satisfied,
      ctqItems: items,
    );

Signal _signal({
  int id = 1,
  String type = 'scale_violation',
  String status = 'open',
  String severity = 'review',
  String consequenceText = 'Raw generated signal text.',
}) =>
    Signal(
      id: id,
      trialId: 1,
      sessionId: null,
      plotId: null,
      signalType: type,
      moment: 2,
      severity: severity,
      raisedAt: 1000,
      raisedBy: null,
      referenceContext: '{}',
      magnitudeContext: null,
      consequenceText: consequenceText,
      status: status,
      createdAt: 1000,
    );

Widget _wrap(
  Widget child, {
  List<Override> overrides = const [],
}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: child),
    );

/// Silences only the two new signal/decision providers added in Commit 4.
/// Use this in tests that already manually override the cognition providers.
List<Override> _silenceSignalDecision(int trialId) => [
      openSignalsForTrialProvider(trialId).overrideWith(
        (ref) => Stream.value(const <Signal>[]),
      ),
      trialDecisionSummaryProvider(trialId).overrideWith(
        (ref) async => TrialDecisionSummaryDto(
          trialId: trialId,
          signalDecisions: const [],
          ctqAcknowledgments: const <CtqFactorAcknowledgmentDto>[],
          hasAnyResearcherReasoning: false,
        ),
      ),
    ];

// Minimal overrides that silence all cognition providers so existing
// timeline-only tests don't fail due to missing database.
List<Override> _silenceCognition(int trialId) => [
      trialPurposeProvider(trialId).overrideWith(
        (ref) => Stream.value(_purposeDto()),
      ),
      trialEvidenceArcProvider(trialId).overrideWith(
              (ref) => Stream.value(_arcDto()),
      ),
      trialCriticalToQualityProvider(trialId).overrideWith(
          (ref) => Stream.value(_ctqDto()),
        ),
      openSignalsForTrialProvider(trialId).overrideWith(
        (ref) => Stream.value(const <Signal>[]),
      ),
      trialDecisionSummaryProvider(trialId).overrideWith(
        (ref) async => TrialDecisionSummaryDto(
          trialId: trialId,
          signalDecisions: const [],
          ctqAcknowledgments: const <CtqFactorAcknowledgmentDto>[],
          hasAnyResearcherReasoning: false,
        ),
      ),
    ];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TrialStoryScreen — timeline (existing)', () {
    testWidgets('empty provider → shows No trial story yet with subtitle',
        (WidgetTester tester) async {
      final trial = _trial();

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id).overrideWith(
              (ref) async => const <TrialStoryEvent>[],
            ),
            ..._silenceCognition(trial.id),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No trial story yet'), findsOneWidget);
      expect(
        find.textContaining('Seeding, applications, and sessions'),
        findsOneWidget,
      );
      expect(find.text('No events recorded yet'), findsNothing);
    });

    testWidgets('AppBar shows Trial Story title', (WidgetTester tester) async {
      final trial = _trial(name: 'Wheat 2026');

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id).overrideWith(
              (ref) async => const <TrialStoryEvent>[],
            ),
            ..._silenceCognition(trial.id),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Trial Story'), findsOneWidget);
      expect(find.text('Wheat 2026'), findsOneWidget);
    });

    testWidgets('non-empty list → shows unresolved signal context helper text',
        (WidgetTester tester) async {
      final trial = _trial();
      final events = [
        TrialStoryEvent(
          id: 'seed-1',
          type: TrialStoryEventType.seeding,
          occurredAt: DateTime(2026, 1, 15),
          title: 'Seeding',
          subtitle: '',
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id).overrideWith(
              (ref) async => events,
            ),
            ..._silenceCognition(trial.id),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('current unresolved signal context'),
        findsOneWidget,
      );
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
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id).overrideWith(
              (ref) async => events,
            ),
            ..._silenceCognition(trial.id),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Seeding'), findsOneWidget);
      expect(find.text('Var. Pioneer P9910'), findsOneWidget);
    });

    testWidgets(
        'session with bbchAtSession → shows BBCH label in session details',
        (WidgetTester tester) async {
      final trial = _trial();
      final events = [
        TrialStoryEvent(
          id: '1',
          type: TrialStoryEventType.session,
          occurredAt: DateTime(2026, 5, 10),
          title: 'Session 1',
          subtitle: '2026-05-10',
          bbchAtSession: 15,
          activeSignalSummary: const ActiveSignalSummary(
            count: 0,
            hasCritical: false,
            consequenceTexts: [],
          ),
          divergenceSummary: const DivergenceSummary(
            count: 0,
            hasMissing: false,
            hasUnexpected: false,
            hasTiming: false,
          ),
          evidenceSummary: const EvidenceSummary(
            hasGps: false,
            hasWeather: false,
            hasTimestamp: false,
            photoCount: 0,
          ),
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id).overrideWith(
              (ref) async => events,
            ),
            ..._silenceCognition(trial.id),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('BBCH 15'), findsOneWidget);
    });

    testWidgets(
        'session with count=3 hasCritical=true → shows Critical signal present, not a count',
        (WidgetTester tester) async {
      final trial = _trial();
      final events = [
        TrialStoryEvent(
          id: '42',
          type: TrialStoryEventType.session,
          occurredAt: DateTime(2026, 6, 1),
          title: 'Session 1',
          subtitle: '2026-06-01',
          activeSignalSummary: const ActiveSignalSummary(
            count: 3,
            hasCritical: true,
            consequenceTexts: ['a', 'b', 'c'],
          ),
          divergenceSummary: const DivergenceSummary(
            count: 0,
            hasMissing: false,
            hasUnexpected: false,
            hasTiming: false,
          ),
          evidenceSummary: const EvidenceSummary(
            hasGps: false,
            hasWeather: false,
            hasTimestamp: true,
            photoCount: 0,
          ),
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id).overrideWith(
              (ref) async => events,
            ),
            ..._silenceCognition(trial.id),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Critical signal present'), findsOneWidget);
      expect(find.textContaining('3 critical'), findsNothing);
      expect(find.textContaining(RegExp(r'\d+ critical')), findsNothing);
    });
  });

  group('TrialStoryScreen — signal display projection', () {
    testWidgets('open signals render projection summary instead of raw text',
        (WidgetTester tester) async {
      final trial = _trial();

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id).overrideWith(
              (ref) async => const <TrialStoryEvent>[],
            ),
            trialPurposeProvider(trial.id).overrideWith(
              (ref) => Stream.value(_purposeDto()),
            ),
            trialEvidenceArcProvider(trial.id).overrideWith(
              (ref) => Stream.value(_arcDto()),
            ),
            trialCriticalToQualityProvider(trial.id).overrideWith(
          (ref) => Stream.value(_ctqDto()),
        ),
            openSignalsForTrialProvider(trial.id).overrideWith(
              (ref) => Stream.value([
                _signal(
                  consequenceText: 'Raw value out of range consequence.',
                ),
              ]),
            ),
            trialDecisionSummaryProvider(trial.id).overrideWith(
              (ref) async => TrialDecisionSummaryDto(
                trialId: trial.id,
                signalDecisions: const [],
                ctqAcknowledgments: const <CtqFactorAcknowledgmentDto>[],
                hasAnyResearcherReasoning: false,
              ),
            ),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('OPEN SIGNALS'), findsOneWidget);
      expect(find.text('Needs review'), findsOneWidget);
      expect(find.text('Recorded values may need review'), findsOneWidget);
      expect(
        find.text(
          'A recorded value was outside the expected assessment range.',
        ),
        findsOneWidget,
      );
      expect(find.text('Raw value out of range consequence.'), findsNothing);
      expect(find.text('Decide →'), findsOneWidget);
    });
  });

  // ── Cognition card tests ──────────────────────────────────────────────────

  group('TrialStoryScreen — Purpose card', () {
    testWidgets('unknown status → shows Not captured yet + Capture intent',
        (WidgetTester tester) async {
      final trial = _trial();

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id)
                .overrideWith((ref) async => const <TrialStoryEvent>[]),
            trialPurposeProvider(trial.id).overrideWith(
              (ref) => Stream.value(_purposeDto(status: 'unknown')),
            ),
            trialEvidenceArcProvider(trial.id).overrideWith(
              (ref) => Stream.value(_arcDto())),
            trialCriticalToQualityProvider(trial.id)
                .overrideWith((ref) => Stream.value(_ctqDto())),
            ..._silenceSignalDecision(trial.id),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Not captured yet.'), findsOneWidget);
      expect(find.text('Capture intent →'), findsOneWidget);
    });

    testWidgets('partial status → shows claim snippet + incomplete count',
        (WidgetTester tester) async {
      final trial = _trial();

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id)
                .overrideWith((ref) async => const <TrialStoryEvent>[]),
            trialPurposeProvider(trial.id).overrideWith(
              (ref) => Stream.value(_purposeDto(
                status: 'partial',
                claim: 'Fungicide efficacy on wheat.',
                missing: ['primaryEndpoint', 'regulatoryContext'],
              )),
            ),
            trialEvidenceArcProvider(trial.id).overrideWith(
              (ref) => Stream.value(_arcDto())),
            trialCriticalToQualityProvider(trial.id)
                .overrideWith((ref) => Stream.value(_ctqDto())),
            ..._silenceSignalDecision(trial.id),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Fungicide efficacy on wheat.'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.textContaining('Missing:'), findsOneWidget);
      expect(find.text('Review intent →'), findsOneWidget);
    });

    testWidgets('confirmed status → shows Review intent CTA',
        (WidgetTester tester) async {
      final trial = _trial();

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id)
                .overrideWith((ref) async => const <TrialStoryEvent>[]),
            trialPurposeProvider(trial.id).overrideWith(
              (ref) => Stream.value(_purposeDto(
                status: 'confirmed',
                claim: 'Confirmed claim.',
              )),
            ),
            trialEvidenceArcProvider(trial.id).overrideWith(
              (ref) => Stream.value(_arcDto())),
            trialCriticalToQualityProvider(trial.id)
                .overrideWith((ref) => Stream.value(_ctqDto())),
            ..._silenceSignalDecision(trial.id),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Review intent →'), findsOneWidget);
    });
  });

  group('TrialStoryScreen — Evidence Arc card', () {
    testWidgets('no_evidence state → shows No evidence recorded yet',
        (WidgetTester tester) async {
      final trial = _trial();

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id)
                .overrideWith((ref) async => const <TrialStoryEvent>[]),
            trialPurposeProvider(trial.id)
                .overrideWith((ref) => Stream.value(_purposeDto())),
            trialEvidenceArcProvider(trial.id).overrideWith(
              (ref) => Stream.value(_arcDto(state: 'no_evidence')),
            ),
            trialCriticalToQualityProvider(trial.id)
                .overrideWith((ref) => Stream.value(_ctqDto())),
            ..._silenceSignalDecision(trial.id),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No evidence recorded yet.'), findsOneWidget);
    });

    testWidgets('sufficient_for_review state → shows Sufficient for review',
        (WidgetTester tester) async {
      final trial = _trial();

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id)
                .overrideWith((ref) async => const <TrialStoryEvent>[]),
            trialPurposeProvider(trial.id)
                .overrideWith((ref) => Stream.value(_purposeDto())),
            trialEvidenceArcProvider(trial.id).overrideWith(
              (ref) => Stream.value(_arcDto(state: 'sufficient_for_review')),
            ),
            trialCriticalToQualityProvider(trial.id)
                .overrideWith((ref) => Stream.value(_ctqDto())),
            ..._silenceSignalDecision(trial.id),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sufficient for review.'), findsOneWidget);
    });
  });

  group('TrialStoryScreen — CTQ card', () {
    testWidgets('unknown status → shows Not yet evaluated',
        (WidgetTester tester) async {
      final trial = _trial();

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id)
                .overrideWith((ref) async => const <TrialStoryEvent>[]),
            trialPurposeProvider(trial.id)
                .overrideWith((ref) => Stream.value(_purposeDto())),
            trialEvidenceArcProvider(trial.id).overrideWith(
              (ref) => Stream.value(_arcDto())),
            trialCriticalToQualityProvider(trial.id).overrideWith(
          (ref) => Stream.value(_ctqDto(status: 'unknown')),
        ),
            ..._silenceSignalDecision(trial.id),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Not yet evaluated'), findsOneWidget);
    });

    testWidgets('review_needed with counts → shows count summary',
        (WidgetTester tester) async {
      final trial = _trial();

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id)
                .overrideWith((ref) async => const <TrialStoryEvent>[]),
            trialPurposeProvider(trial.id)
                .overrideWith((ref) => Stream.value(_purposeDto())),
            trialEvidenceArcProvider(trial.id).overrideWith(
              (ref) => Stream.value(_arcDto())),
            trialCriticalToQualityProvider(trial.id).overrideWith(
              (ref) => Stream.value(
                _ctqDto(
                  status: 'review_needed',
                  blockers: 1,
                  review: 2,
                  warnings: 3,
                ),
              ),
            ),
            ..._silenceSignalDecision(trial.id),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Needs review'), findsOneWidget);
      expect(find.textContaining('1 check blocked'), findsOneWidget);
      expect(find.textContaining('2 checks need review'), findsOneWidget);
      expect(find.textContaining('3 checks need evidence'), findsOneWidget);
    });

    testWidgets(
        'blocked items appear first in attention list with label prefix',
        (WidgetTester tester) async {
      final trial = _trial();
      const items = [
        TrialCtqItemDto(
          factorKey: 'rater_consistency',
          label: 'Rater Consistency',
          importance: 'standard',
          status: 'blocked',
          evidenceSummary: '1 signal.',
          reason: 'reason',
          source: 'system',
        ),
        TrialCtqItemDto(
          factorKey: 'plot_completeness',
          label: 'Plot Completeness',
          importance: 'critical',
          status: 'missing',
          evidenceSummary: '0/8 plots.',
          reason: 'reason',
          source: 'system',
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id)
                .overrideWith((ref) async => const <TrialStoryEvent>[]),
            trialPurposeProvider(trial.id)
                .overrideWith((ref) => Stream.value(_purposeDto())),
            trialEvidenceArcProvider(trial.id).overrideWith(
              (ref) => Stream.value(_arcDto())),
            trialCriticalToQualityProvider(trial.id).overrideWith(
              (ref) => Stream.value(
                _ctqDto(
                  status: 'review_needed',
                  blockers: 1,
                  warnings: 1,
                  items: items,
                ),
              ),
            ),
            ..._silenceSignalDecision(trial.id),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('· Rater Consistency'), findsOneWidget);
      expect(find.textContaining('· Plot Completeness'), findsOneWidget);
    });

    testWidgets('ready_for_review → shows Ready for review',
        (WidgetTester tester) async {
      final trial = _trial();

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id)
                .overrideWith((ref) async => const <TrialStoryEvent>[]),
            trialPurposeProvider(trial.id)
                .overrideWith((ref) => Stream.value(_purposeDto())),
            trialEvidenceArcProvider(trial.id).overrideWith(
              (ref) => Stream.value(_arcDto())),
            trialCriticalToQualityProvider(trial.id).overrideWith(
          (ref) => Stream.value(_ctqDto(status: 'ready_for_review')),
        ),
            ..._silenceSignalDecision(trial.id),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Ready for review'), findsOneWidget);
      expect(find.text('No checks need attention'), findsOneWidget);
    });

    testWidgets(
        'review_needed item with isAcknowledged=false shows Acknowledge button',
        (WidgetTester tester) async {
      final trial = _trial();
      const items = [
        TrialCtqItemDto(
          factorKey: 'plot_completeness',
          label: 'Plot Completeness',
          importance: 'critical',
          status: 'review_needed',
          evidenceSummary: '4/8 plots.',
          reason: 'Partial evidence.',
          source: 'system',
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id)
                .overrideWith((ref) async => const <TrialStoryEvent>[]),
            trialPurposeProvider(trial.id)
                .overrideWith((ref) => Stream.value(_purposeDto())),
            trialEvidenceArcProvider(trial.id).overrideWith(
              (ref) => Stream.value(_arcDto())),
            trialCriticalToQualityProvider(trial.id).overrideWith(
              (ref) => Stream.value(
                _ctqDto(
                  status: 'review_needed',
                  review: 1,
                  items: items,
                ),
              ),
            ),
            ..._silenceSignalDecision(trial.id),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Acknowledge →'), findsOneWidget);
    });

    testWidgets(
        'review_needed item with isAcknowledged=true shows badge not button',
        (WidgetTester tester) async {
      final trial = _trial();
      final ack = CtqFactorAcknowledgmentDto(
        id: 1,
        factorKey: 'plot_completeness',
        acknowledgedAt: DateTime(2026, 5, 1),
        actorName: null,
        reason: 'Three plots excluded per protocol amendment.',
        factorStatusAtAcknowledgment: 'review_needed',
      );
      final items = [
        TrialCtqItemDto(
          factorKey: 'plot_completeness',
          label: 'Plot Completeness',
          importance: 'critical',
          status: 'review_needed',
          evidenceSummary: '4/8 plots.',
          reason: 'Partial evidence.',
          source: 'system',
          isAcknowledged: true,
          latestAcknowledgment: ack,
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id)
                .overrideWith((ref) async => const <TrialStoryEvent>[]),
            trialPurposeProvider(trial.id)
                .overrideWith((ref) => Stream.value(_purposeDto())),
            trialEvidenceArcProvider(trial.id).overrideWith(
              (ref) => Stream.value(_arcDto())),
            trialCriticalToQualityProvider(trial.id).overrideWith(
              (ref) => Stream.value(
                _ctqDto(
                  status: 'review_needed',
                  review: 1,
                  items: items,
                ),
              ),
            ),
            ..._silenceSignalDecision(trial.id),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Acknowledge →'), findsNothing);
      expect(find.textContaining('Acknowledged'), findsOneWidget);
    });

    testWidgets(
        'hasAnyResearcherReasoning=true shows Decisions and reasoning section',
        (WidgetTester tester) async {
      final trial = _trial();

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id)
                .overrideWith((ref) async => const <TrialStoryEvent>[]),
            trialPurposeProvider(trial.id)
                .overrideWith((ref) => Stream.value(_purposeDto())),
            trialEvidenceArcProvider(trial.id).overrideWith(
              (ref) => Stream.value(_arcDto())),
            trialCriticalToQualityProvider(trial.id)
                .overrideWith((ref) => Stream.value(_ctqDto())),
            openSignalsForTrialProvider(trial.id).overrideWith(
              (ref) => Stream.value(const <Signal>[]),
            ),
            trialDecisionSummaryProvider(trial.id).overrideWith(
              (ref) async => TrialDecisionSummaryDto(
                trialId: trial.id,
                signalDecisions: const [],
                ctqAcknowledgments: [
                  CtqFactorAcknowledgmentDto(
                    id: 1,
                    factorKey: 'plot_completeness',
                    acknowledgedAt: DateTime(2026, 5, 1),
                    actorName: 'Dr. Reed',
                    reason: 'Protocol excludes three marginal plots.',
                    factorStatusAtAcknowledgment: 'review_needed',
                  ),
                ],
                hasAnyResearcherReasoning: true,
              ),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('DECISIONS AND REASONING'), findsOneWidget);
      expect(find.textContaining('Protocol excludes three marginal plots.'),
          findsOneWidget);
    });

    testWidgets('blocked item → Acknowledge button NOT shown',
        (WidgetTester tester) async {
      final trial = _trial();
      const items = [
        TrialCtqItemDto(
          factorKey: 'rater_consistency',
          label: 'Rater Consistency',
          importance: 'standard',
          status: 'blocked',
          evidenceSummary: '1 signal.',
          reason: 'Critical rater signal.',
          source: 'system',
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id)
                .overrideWith((ref) async => const <TrialStoryEvent>[]),
            trialPurposeProvider(trial.id)
                .overrideWith((ref) => Stream.value(_purposeDto())),
            trialEvidenceArcProvider(trial.id).overrideWith(
              (ref) => Stream.value(_arcDto())),
            trialCriticalToQualityProvider(trial.id).overrideWith(
              (ref) => Stream.value(
                _ctqDto(
                  status: 'review_needed',
                  blockers: 1,
                  items: items,
                ),
              ),
            ),
            ..._silenceSignalDecision(trial.id),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Acknowledge →'), findsNothing);
    });

    testWidgets('missing item → Acknowledge button NOT shown',
        (WidgetTester tester) async {
      final trial = _trial();
      const items = [
        TrialCtqItemDto(
          factorKey: 'photo_evidence',
          label: 'Photo Evidence',
          importance: 'standard',
          status: 'missing',
          evidenceSummary: 'No photos.',
          reason: 'No photo evidence has been attached.',
          source: 'system',
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id)
                .overrideWith((ref) async => const <TrialStoryEvent>[]),
            trialPurposeProvider(trial.id)
                .overrideWith((ref) => Stream.value(_purposeDto())),
            trialEvidenceArcProvider(trial.id).overrideWith(
              (ref) => Stream.value(_arcDto())),
            trialCriticalToQualityProvider(trial.id).overrideWith(
              (ref) => Stream.value(
                _ctqDto(
                  status: 'incomplete',
                  warnings: 1,
                  items: items,
                ),
              ),
            ),
            ..._silenceSignalDecision(trial.id),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Acknowledge →'), findsNothing);
    });

    // ── Environmental evidence integration ───────────────────────────────────────

    group('TrialStoryScreen — session environmental context', () {
      testWidgets('TS-E1: session with GPS shows "GPS confirmed"',
          (WidgetTester tester) async {
        final trial = _trial();
        final events = [
          TrialStoryEvent(
            id: '1',
            type: TrialStoryEventType.session,
            occurredAt: DateTime(2026, 5, 1),
            title: 'Session 1',
            subtitle: '2026-05-01',
            activeSignalSummary: const ActiveSignalSummary(
              count: 0,
              hasCritical: false,
              consequenceTexts: [],
            ),
            divergenceSummary: const DivergenceSummary(
              count: 0,
              hasMissing: false,
              hasUnexpected: false,
              hasTiming: false,
            ),
            evidenceSummary: const EvidenceSummary(
              hasGps: true,
              hasWeather: false,
              hasTimestamp: false,
              photoCount: 0,
            ),
          ),
        ];

        await tester.pumpWidget(_wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id).overrideWith((ref) async => events),
            ..._silenceCognition(trial.id),
          ],
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.textContaining('GPS confirmed'), findsOneWidget);
      });

      testWidgets('TS-E2: session with weather shows "Weather captured"',
          (WidgetTester tester) async {
        final trial = _trial();
        final events = [
          TrialStoryEvent(
            id: '1',
            type: TrialStoryEventType.session,
            occurredAt: DateTime(2026, 5, 1),
            title: 'Session 1',
            subtitle: '2026-05-01',
            activeSignalSummary: const ActiveSignalSummary(
              count: 0,
              hasCritical: false,
              consequenceTexts: [],
            ),
            divergenceSummary: const DivergenceSummary(
              count: 0,
              hasMissing: false,
              hasUnexpected: false,
              hasTiming: false,
            ),
            evidenceSummary: const EvidenceSummary(
              hasGps: false,
              hasWeather: true,
              hasTimestamp: false,
              photoCount: 0,
            ),
          ),
        ];

        await tester.pumpWidget(_wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id).overrideWith((ref) async => events),
            ..._silenceCognition(trial.id),
          ],
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.textContaining('Weather captured'), findsOneWidget);
        // No fake temperature placeholders
        expect(find.textContaining('°C'), findsNothing);
      });
    });

    group('TrialStoryScreen — application environmental context', () {
      const appId = 'app-uuid-test-123';

      const emptyWindowDto = ApplicationEnvironmentalContextDto(
        preWindow: EnvironmentalWindowDto(
          frostFlagPresent: false,
          excessiveRainfallFlag: false,
          recordCount: 0,
          confidence: 'unavailable',
        ),
        postWindow: EnvironmentalWindowDto(
          frostFlagPresent: false,
          excessiveRainfallFlag: false,
          recordCount: 0,
          confidence: 'unavailable',
        ),
      );

      testWidgets(
          'TS-E3: applied application with BBCH and GPS shows compact context',
          (WidgetTester tester) async {
        final trial = _trial();
        final events = [
          TrialStoryEvent(
            id: appId,
            type: TrialStoryEventType.application,
            occurredAt: DateTime(2026, 5, 3),
            title: 'Application',
            subtitle: 'Herbicide X',
            bbchAtApplication: 32,
            hasApplicationGps: true,
            applicationSummary: const ApplicationSummary(
              productName: 'Herbicide X',
              rate: null,
              rateUnit: null,
              status: 'applied',
            ),
          ),
        ];

        await tester.pumpWidget(_wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id).overrideWith((ref) async => events),
            applicationEnvironmentalContextProvider(
              ApplicationEnvironmentalRequest(
                trialId: trial.id,
                applicationEventId: appId,
              ),
            ).overrideWith((_) async => emptyWindowDto),
            ..._silenceCognition(trial.id),
          ],
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.textContaining('BBCH 32'), findsOneWidget);
        expect(find.textContaining('GPS confirmed'), findsOneWidget);
      });

      testWidgets(
          'TS-E4: pending application shows confirmation message, not A3 windows',
          (WidgetTester tester) async {
        final trial = _trial();
        final events = [
          TrialStoryEvent(
            id: appId,
            type: TrialStoryEventType.application,
            occurredAt: DateTime(2026, 5, 3),
            title: 'Application',
            subtitle: 'Herbicide X',
            bbchAtApplication: 32,
            applicationSummary: const ApplicationSummary(
              productName: 'Herbicide X',
              rate: null,
              rateUnit: null,
              status: 'pending',
            ),
          ),
        ];

        await tester.pumpWidget(_wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id).overrideWith((ref) async => events),
            ..._silenceCognition(trial.id),
          ],
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.textContaining('after application is confirmed'),
          findsOneWidget,
        );
        expect(find.text('72h before'), findsNothing);
        expect(find.text('48h after'), findsNothing);
      });

      testWidgets(
          'TS-E5: applied application with A3 windows shows pre/post rows',
          (WidgetTester tester) async {
        final trial = _trial();
        final events = [
          TrialStoryEvent(
            id: appId,
            type: TrialStoryEventType.application,
            occurredAt: DateTime(2026, 5, 3),
            title: 'Application',
            subtitle: 'Fungicide Y',
            applicationSummary: const ApplicationSummary(
              productName: 'Fungicide Y',
              rate: null,
              rateUnit: null,
              status: 'applied',
            ),
          ),
        ];

        const measuredWindow = EnvironmentalWindowDto(
          totalPrecipitationMm: 18.2,
          minTempC: 2.0,
          maxTempC: 14.5,
          frostFlagPresent: false,
          excessiveRainfallFlag: false,
          recordCount: 3,
          confidence: 'measured',
        );

        await tester.pumpWidget(_wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id).overrideWith((ref) async => events),
            applicationEnvironmentalContextProvider(
              ApplicationEnvironmentalRequest(
                trialId: trial.id,
                applicationEventId: appId,
              ),
            ).overrideWith(
                (_) async => const ApplicationEnvironmentalContextDto(
                      preWindow: measuredWindow,
                      postWindow: EnvironmentalWindowDto(
                        frostFlagPresent: false,
                        excessiveRainfallFlag: false,
                        recordCount: 0,
                        confidence: 'unavailable',
                      ),
                    )),
            ..._silenceCognition(trial.id),
          ],
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.textContaining('72h before'), findsOneWidget);
        expect(find.textContaining('18.2 mm'), findsOneWidget);
        expect(find.textContaining('48h after'), findsOneWidget);
        expect(find.textContaining('no records'), findsOneWidget);
      });
    });

    testWidgets(
        'hasAnyResearcherReasoning=false hides Decisions and reasoning section',
        (WidgetTester tester) async {
      final trial = _trial();

      await tester.pumpWidget(
        _wrap(
          TrialStoryScreen(trial: trial),
          overrides: [
            trialStoryProvider(trial.id)
                .overrideWith((ref) async => const <TrialStoryEvent>[]),
            trialPurposeProvider(trial.id)
                .overrideWith((ref) => Stream.value(_purposeDto())),
            trialEvidenceArcProvider(trial.id).overrideWith(
              (ref) => Stream.value(_arcDto())),
            trialCriticalToQualityProvider(trial.id)
                .overrideWith((ref) => Stream.value(_ctqDto())),
            ..._silenceSignalDecision(trial.id),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('DECISIONS AND REASONING'), findsNothing);
    });
  });
}
