import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../relationships/evidence_anchors_provider.dart';
import '../relationships/protocol_divergence.dart';
import '../relationships/protocol_divergence_provider.dart';
import '../signals/signal_models.dart';
import '../signals/signal_providers.dart';
import 'trial_story_event.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Assembles a chronological list of [TrialStoryEvent] for [trialId] by
/// composing six upstream providers in parallel, then joining their data
/// using session id as the common key.
///
/// Active signals: openSignalsForTrialProvider excludes resolved, expired,
/// and suppressed signals — only open/deferred/investigating signals appear
/// in each session's [ActiveSignalSummary].
///
/// Does NOT read the evidence_anchors DB table directly; evidence state is
/// computed from source tables via evidenceAnchorsProvider.
///
/// Does NOT modify chronologyProvider or the Timeline tab.
final trialStoryProvider =
    FutureProvider.autoDispose.family<List<TrialStoryEvent>, int>(
        (ref, trialId) async {
  // ── Parallel load ─────────────────────────────────────────────────────────
  final results = await Future.wait([
    ref.watch(sessionsForTrialProvider(trialId).future),          // 0
    ref.watch(seedingEventForTrialProvider(trialId).future),      // 1
    ref.watch(trialApplicationsForTrialProvider(trialId).future), // 2
    ref.watch(openSignalsForTrialProvider(trialId).future),       // 3
    ref.watch(protocolDivergenceProvider(trialId).future),        // 4
    ref.watch(evidenceAnchorsProvider(trialId).future),           // 5
  ]);

  final sessions      = results[0] as List<Session>;
  final seedingEvent  = results[1] as SeedingEvent?;
  final applications  = results[2] as List<TrialApplicationEvent>;
  final activeSignals = results[3] as List<Signal>;
  final divergences   = results[4] as List<ProtocolDivergence>;
  final evidence      = results[5] as List<TrialEvidenceSummary>;

  // ── Index structures ──────────────────────────────────────────────────────

  // Active signals keyed by Signal.sessionId (int). Trial-level signals
  // (sessionId == null) are not attached to any session story event.
  final activeSignalsBySession = <int, List<Signal>>{};
  for (final s in activeSignals) {
    if (s.sessionId != null) {
      activeSignalsBySession.putIfAbsent(s.sessionId!, () => []).add(s);
    }
  }

  // Protocol divergences keyed by ProtocolDivergence.entityId.
  // For sessions, entityId == session.id.toString().
  final divergencesByEntityId = <String, List<ProtocolDivergence>>{};
  for (final d in divergences) {
    divergencesByEntityId.putIfAbsent(d.entityId, () => []).add(d);
  }

  // Evidence keyed by TrialEvidenceSummary.eventId.
  // For sessions, eventId == session.id.toString().
  final evidenceByEventId = <String, TrialEvidenceSummary>{};
  for (final e in evidence) {
    evidenceByEventId[e.eventId] = e;
  }

  // ── Build story events ────────────────────────────────────────────────────
  final events = <TrialStoryEvent>[];

  if (seedingEvent != null) {
    events.add(TrialStoryEvent(
      id: seedingEvent.id,
      type: TrialStoryEventType.seeding,
      occurredAt: seedingEvent.seedingDate,
      title: 'Seeding',
      subtitle: seedingEvent.variety ?? '',
      seedingSummary: SeedingSummary(
        variety: seedingEvent.variety,
        seedLotNumber: seedingEvent.seedLotNumber,
        seedingRate: seedingEvent.seedingRate,
        seedingRateUnit: seedingEvent.seedingRateUnit,
      ),
    ));
  }

  for (final app in applications) {
    events.add(TrialStoryEvent(
      id: app.id,
      type: TrialStoryEventType.application,
      occurredAt: app.applicationDate,
      title: 'Application',
      subtitle: app.productName ?? '',
      applicationSummary: ApplicationSummary(
        productName: app.productName,
        rate: app.rate,
        rateUnit: app.rateUnit,
        status: app.status,
      ),
    ));
  }

  for (final session in sessions) {
    final sessionKey = session.id.toString();
    final signals    = activeSignalsBySession[session.id] ?? [];
    final divs       = divergencesByEntityId[sessionKey] ?? [];
    final ev         = evidenceByEventId[sessionKey];

    events.add(TrialStoryEvent(
      id: sessionKey,
      type: TrialStoryEventType.session,
      occurredAt: session.startedAt,
      title: session.name,
      subtitle: session.sessionDateLocal,
      activeSignalSummary: ActiveSignalSummary(
        count: signals.length,
        hasCritical: signals
            .any((s) => s.severity == SignalSeverity.critical.dbValue),
        consequenceTexts: signals.map((s) => s.consequenceText).toList(),
      ),
      divergenceSummary: DivergenceSummary(
        count: divs.length,
        hasMissing:    divs.any((d) => d.isMissing),
        hasUnexpected: divs.any((d) => d.isUnexpected),
        hasTiming:     divs.any((d) => d.type == DivergenceType.timing),
      ),
      evidenceSummary: ev != null
          ? EvidenceSummary(
              hasGps:       ev.hasGps,
              hasWeather:   ev.hasWeather,
              hasTimestamp: ev.hasTimestamp,
              photoCount:   ev.photoIds.length,
            )
          : const EvidenceSummary(
              hasGps:       false,
              hasWeather:   false,
              hasTimestamp: false,
              photoCount:   0,
            ),
    ));
  }

  // ── Chronological sort ────────────────────────────────────────────────────
  events.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

  return events;
});
