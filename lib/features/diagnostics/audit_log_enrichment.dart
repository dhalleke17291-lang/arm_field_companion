import '../../core/database/app_database.dart';
import '../../core/plot_display.dart';
import '../plots/plot_repository.dart';
import '../sessions/session_repository.dart';
import '../trials/trial_repository.dart';

/// Enriched audit event for display: event plus resolved trial/session/plot labels.
class EnrichedAuditEvent {
  const EnrichedAuditEvent({
    required this.event,
    this.trialName,
    this.sessionName,
    this.plotLabel,
  });

  final AuditEvent event;
  final String? trialName;
  final String? sessionName;
  final String? plotLabel;

  /// Context line for UI: "TrialName · SessionName · Plot 101" (or fallbacks).
  String get contextLine {
    final parts = <String>[];
    if (trialName != null && trialName!.isNotEmpty) parts.add(trialName!);
    if (sessionName != null && sessionName!.isNotEmpty) parts.add(sessionName!);
    if (plotLabel != null && plotLabel!.isNotEmpty) parts.add('Plot $plotLabel');
    if (parts.isEmpty) {
      if (event.trialId != null) parts.add('Trial ${event.trialId}');
      if (event.sessionId != null) parts.add('Session ${event.sessionId}');
      if (event.plotPk != null) parts.add('Plot ${event.plotPk}');
    }
    return parts.join(' · ');
  }
}

/// Resolves trial/session/plot names and plot display label (e.g. 101) for audit events.
Future<List<EnrichedAuditEvent>> enrichAuditEvents(
  List<AuditEvent> events, {
  required TrialRepository trialRepo,
  required SessionRepository sessionRepo,
  required PlotRepository plotRepo,
}) async {
  if (events.isEmpty) return [];

  final trialIds = events.map((e) => e.trialId).whereType<int>().toSet();
  final sessionIds = events.map((e) => e.sessionId).whereType<int>().toSet();
  final trialPlotPks = <int, Set<int>>{};
  for (final e in events) {
    if (e.trialId != null && e.plotPk != null) {
      trialPlotPks.putIfAbsent(e.trialId!, () => {}).add(e.plotPk!);
    }
  }

  final trialById = <int, Trial>{};
  for (final id in trialIds) {
    final t = await trialRepo.getTrialById(id);
    if (t != null) trialById[id] = t;
  }

  final sessionById = <int, Session>{};
  for (final id in sessionIds) {
    final s = await sessionRepo.getSessionById(id);
    if (s != null) sessionById[id] = s;
  }

  final plotLabelByTrialAndPk = <int, Map<int, String>>{};
  for (final trialId in trialPlotPks.keys) {
    final plots = await plotRepo.getPlotsForTrial(trialId);
    final byPk = <int, String>{};
    for (final p in plots) {
      byPk[p.id] = getDisplayPlotLabel(p, plots);
    }
    plotLabelByTrialAndPk[trialId] = byPk;
  }

  return events.map((e) {
    final trialName = e.trialId != null ? trialById[e.trialId!]?.name : null;
    final sessionName = e.sessionId != null ? sessionById[e.sessionId!]?.name : null;
    String? plotLabel;
    if (e.trialId != null && e.plotPk != null) {
      plotLabel = plotLabelByTrialAndPk[e.trialId!]?[e.plotPk!];
    }
    return EnrichedAuditEvent(
      event: e,
      trialName: trialName,
      sessionName: sessionName,
      plotLabel: plotLabel,
    );
  }).toList();
}
