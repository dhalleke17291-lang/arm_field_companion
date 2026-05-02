// Tests for trialStoryProvider.
//
// Strategy: override databaseProvider with an in-memory DB for most tests.
// For protocol divergence injection (test 3) the family provider is overridden
// directly so ARM-metadata seeding is not required.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/relationships/chronology_provider.dart';
import 'package:arm_field_companion/domain/relationships/protocol_divergence.dart';
import 'package:arm_field_companion/domain/relationships/protocol_divergence_provider.dart';
import 'package:arm_field_companion/domain/signals/signal_models.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/signals/signal_repository.dart';
import 'package:arm_field_companion/domain/trial_story/trial_story_event.dart';
import 'package:arm_field_companion/domain/trial_story/trial_story_provider.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProviderContainer _container(AppDatabase db,
    {List<Override> extra = const []}) =>
    ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      ...extra,
    ]);

Future<int> _trial(AppDatabase db) =>
    db.into(db.trials).insert(TrialsCompanion.insert(name: 'T'));

Future<int> _session(
  AppDatabase db,
  int trialId, {
  required String dateLocal,
  required DateTime startedAt,
}) =>
    db.into(db.sessions).insert(SessionsCompanion(
      trialId: Value(trialId),
      name: Value('Session $dateLocal'),
      sessionDateLocal: Value(dateLocal),
      startedAt: Value(startedAt),
    ));

Future<void> _seeding(AppDatabase db, int trialId, DateTime date,
    {String? variety, String? seedLotNumber}) async {
  await db.into(db.seedingEvents).insert(SeedingEventsCompanion.insert(
        trialId: trialId,
        seedingDate: date,
        variety: Value(variety),
        seedLotNumber: Value(seedLotNumber),
      ));
}

Future<void> _application(AppDatabase db, int trialId, DateTime date,
    {String? productName, double? rate, String? rateUnit}) async {
  await db.into(db.trialApplicationEvents).insert(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: date,
          productName: Value(productName),
          rate: Value(rate),
          rateUnit: Value(rateUnit),
        ),
      );
}

Future<int> _activeSignal(
  AppDatabase db,
  SignalRepository repo,
  int trialId,
  int sessionId, {
  String severity = 'critical',
  String consequenceText = 'Test signal.',
}) =>
    repo.raiseSignal(
      trialId: trialId,
      sessionId: sessionId,
      signalType: SignalType.scaleViolation,
      moment: SignalMoment.one,
      severity: severity == 'critical'
          ? SignalSeverity.critical
          : SignalSeverity.review,
      referenceContext: const SignalReferenceContext(seType: 'W003'),
      consequenceText: consequenceText,
    );

Future<List<TrialStoryEvent>> _run(ProviderContainer c, int trialId) =>
    c.read(trialStoryProvider(trialId).future);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = _container(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // ── Test 1: chronological ordering ───────────────────────────────────────

  test(
      '1 — seeding, application, and session events sort chronologically',
      () async {
    final trialId = await _trial(db);

    // Insert in reverse order so sort is non-trivial.
    final sessionDate = DateTime.utc(2026, 6, 1, 8, 0);
    await _session(db, trialId,
        dateLocal: '2026-06-01', startedAt: sessionDate);
    await _application(db, trialId, DateTime.utc(2026, 4, 1),
        productName: 'Fungicide A');
    await _seeding(db, trialId, DateTime.utc(2026, 1, 15));

    final events = await _run(container, trialId);

    expect(events, hasLength(3));
    expect(events[0].type, TrialStoryEventType.seeding);
    expect(events[1].type, TrialStoryEventType.application);
    expect(events[2].type, TrialStoryEventType.session);

    // Verify strict ascending order.
    for (var i = 0; i < events.length - 1; i++) {
      expect(
        events[i].occurredAt.isBefore(events[i + 1].occurredAt),
        isTrue,
        reason: 'event $i must precede event ${i + 1}',
      );
    }
  });

  // ── Test 2: session joins active signals by Signal.sessionId ─────────────

  test('2 — session joins active signals by Signal.sessionId', () async {
    final trialId = await _trial(db);
    final s1 = await _session(db, trialId,
        dateLocal: '2026-06-01', startedAt: DateTime.utc(2026, 6, 1));
    final s2 = await _session(db, trialId,
        dateLocal: '2026-06-10', startedAt: DateTime.utc(2026, 6, 10));

    final repo = container.read(signalRepositoryProvider);
    await _activeSignal(db, repo, trialId, s1,
        consequenceText: 'Signal for S1.');
    // No signal for s2.

    final events = await _run(container, trialId);
    final e1 =
        events.firstWhere((e) => e.id == s1.toString());
    final e2 =
        events.firstWhere((e) => e.id == s2.toString());

    expect(e1.activeSignalSummary!.count, 1);
    expect(e1.activeSignalSummary!.consequenceTexts, contains('Signal for S1.'));
    expect(e2.activeSignalSummary!.count, 0,
        reason: 'S2 has no active signals — must not bleed from S1');
  });

  // ── Test 3: session joins protocol divergences by entityId ───────────────

  test(
      '3 — session joins protocol divergences by entityId == session.id.toString()',
      () async {
    final trialId = await _trial(db);
    final s1 = await _session(db, trialId,
        dateLocal: '2026-06-01', startedAt: DateTime.utc(2026, 6, 1));
    final s2 = await _session(db, trialId,
        dateLocal: '2026-06-10', startedAt: DateTime.utc(2026, 6, 10));

    // Override protocolDivergenceProvider to inject divergences without
    // requiring ARM session-metadata rows.
    final c = _container(db, extra: [
      protocolDivergenceProvider.overrideWith(
        (ref, arg) async => [
          ProtocolDivergence(
            entityId: s1.toString(), // matches session 1 only
            eventKind: EventKind.assessment,
            type: DivergenceType.timing,
            isMissing: false,
            isUnexpected: false,
            deltaDays: 3,
          ),
        ],
      ),
    ]);
    addTearDown(c.dispose);

    final events = await c.read(trialStoryProvider(trialId).future);
    final e1 = events.firstWhere((e) => e.id == s1.toString());
    final e2 = events.firstWhere((e) => e.id == s2.toString());

    expect(e1.divergenceSummary!.count, 1);
    expect(e1.divergenceSummary!.hasTiming, isTrue);
    expect(e2.divergenceSummary!.count, 0,
        reason: 'divergence must not bleed to S2');
  });

  // ── Test 4: session joins evidence by eventId == session.id.toString() ────

  test(
      '4 — session joins TrialEvidenceSummary by eventId == session.id.toString()',
      () async {
    final trialId = await _trial(db);
    final plotPk = await db
        .into(db.plots)
        .insert(PlotsCompanion.insert(trialId: trialId, plotId: 'P1'));

    final s1 = await _session(db, trialId,
        dateLocal: '2026-06-01', startedAt: DateTime.utc(2026, 6, 1));
    final s2 = await _session(db, trialId,
        dateLocal: '2026-06-10', startedAt: DateTime.utc(2026, 6, 10));

    // Attach a photo to S1 — evidenceAnchorsProvider will set hasPhoto.
    await db.into(db.photos).insert(PhotosCompanion.insert(
          trialId: trialId,
          sessionId: s1,
          plotPk: plotPk,
          filePath: 'photo_s1.jpg',
        ));

    final events = await _run(container, trialId);
    final e1 = events.firstWhere((e) => e.id == s1.toString());
    final e2 = events.firstWhere((e) => e.id == s2.toString());

    expect(e1.evidenceSummary!.photoCount, 1,
        reason: 'S1 has a photo');
    expect(e2.evidenceSummary!.photoCount, 0,
        reason: 'photo must not bleed to S2');
  });

  // ── Test 5: naming confirms signals are active/current only ──────────────

  test(
      '5 — provider and model names make clear signals are active, not full history',
      () async {
    // Structural/naming test: verify that the field on TrialStoryEvent is
    // named activeSignalSummary (not signalSummary or signalHistory) and
    // that the summary class is named ActiveSignalSummary.
    final trialId = await _trial(db);
    await _session(db, trialId,
        dateLocal: '2026-06-01', startedAt: DateTime.utc(2026, 6, 1));

    final events = await _run(container, trialId);
    final e = events.single;

    // Field exists and is typed as ActiveSignalSummary.
    expect(e.activeSignalSummary, isA<ActiveSignalSummary>());
    // Count is zero — no active signals.
    expect(e.activeSignalSummary!.count, 0);
    expect(e.activeSignalSummary!.hasCritical, isFalse);
  });

  // ── Test 6: clean trial returns events with empty summaries ──────────────

  test('6 — clean trial returns events with empty/zero summaries, not warnings',
      () async {
    final trialId = await _trial(db);
    await _seeding(db, trialId, DateTime.utc(2026, 1, 15));
    await _application(db, trialId, DateTime.utc(2026, 4, 1));
    await _session(db, trialId,
        dateLocal: '2026-06-01', startedAt: DateTime.utc(2026, 6, 1));

    final events = await _run(container, trialId);
    expect(events, hasLength(3));

    final session =
        events.firstWhere((e) => e.type == TrialStoryEventType.session);
    expect(session.activeSignalSummary!.count, 0);
    expect(session.activeSignalSummary!.hasCritical, isFalse);
    expect(session.activeSignalSummary!.consequenceTexts, isEmpty);
    expect(session.divergenceSummary!.count, 0);
    expect(session.evidenceSummary!.photoCount, 0);
    expect(session.evidenceSummary!.hasGps, isFalse);
    expect(session.evidenceSummary!.hasWeather, isFalse);

    final app =
        events.firstWhere((e) => e.type == TrialStoryEventType.application);
    expect(app.activeSignalSummary, isNull);
    expect(app.divergenceSummary, isNull);

    final seed =
        events.firstWhere((e) => e.type == TrialStoryEventType.seeding);
    expect(seed.activeSignalSummary, isNull);
    expect(seed.divergenceSummary, isNull);
  });

  // ── Test 7: application event carries product/rate/status ─────────────────

  test('7 — application event includes productName, rate, rateUnit, status',
      () async {
    final trialId = await _trial(db);
    await _application(db, trialId, DateTime.utc(2026, 4, 1),
        productName: 'Herbicide B', rate: 2.5, rateUnit: 'L/ha');

    final events = await _run(container, trialId);
    expect(events, hasLength(1));

    final app = events.single;
    expect(app.type, TrialStoryEventType.application);
    expect(app.applicationSummary!.productName, 'Herbicide B');
    expect(app.applicationSummary!.rate, 2.5);
    expect(app.applicationSummary!.rateUnit, 'L/ha');
    expect(app.applicationSummary!.status, isNotEmpty);
  });

  // ── Test 8: chronologyProvider and Timeline tab are unmodified ────────────

  test(
      '8 — chronologyProvider exists independently; trialStoryProvider does not replace it',
      () async {
    // Verify both providers resolve without conflict from the same container.
    final trialId = await _trial(db);
    await _session(db, trialId,
        dateLocal: '2026-06-01', startedAt: DateTime.utc(2026, 6, 1));

    // chronologyProvider must still be resolvable.
    final chronology =
        await container.read(chronologyProvider(trialId).future);
    expect(chronology, isA<List>());

    // trialStoryProvider resolves separately.
    final story = await _run(container, trialId);
    expect(story, isA<List<TrialStoryEvent>>());
  });
}
