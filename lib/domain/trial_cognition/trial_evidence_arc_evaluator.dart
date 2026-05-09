import 'package:drift/drift.dart' as drift;

import '../../core/database/app_database.dart';
import 'trial_evidence_arc_dto.dart';

/// Deterministic evidence-arc computation for a trial.
///
/// Extracted from providers.dart so it can be called by both
/// [trialEvidenceArcProvider] and [FieldExecutionReportAssemblyService]
/// without duplication.
Future<TrialEvidenceArcDto> computeTrialEvidenceArcDto(
  AppDatabase db,
  int trialId,
) async {
  final sessions = await (db.select(db.sessions)
        ..where((s) => s.trialId.equals(trialId)))
      .get();
  final sessionIds = sessions.map((s) => s.id).toList();

  final recordedRatings = sessionIds.isEmpty
      ? 0
      : await (db.select(db.ratingRecords)
              ..where(
                (r) =>
                    r.trialId.equals(trialId) &
                    r.resultStatus.equals('RECORDED') &
                    r.isCurrent.equals(true),
              ))
          .get()
          .then((rows) => rows.length);

  final photos = await (db.select(db.photos)
        ..where((p) => p.trialId.equals(trialId)))
      .get();

  final anchors = await (db.select(db.evidenceAnchors)
        ..where((a) => a.trialId.equals(trialId)))
      .get();

  final plots = await (db.select(db.plots)
        ..where(
          (p) => p.trialId.equals(trialId) & p.isDeleted.equals(false),
        ))
      .get();
  final nonGuardPlots = plots.where((p) => !p.isGuardRow).length;

  final missingItems = <String>[];
  final evidenceAnchorLabels = <String>[];
  final riskFlags = <String>[];

  if (sessions.isEmpty) missingItems.add('No rating sessions recorded');
  if (recordedRatings == 0) missingItems.add('No numeric ratings recorded');
  if (photos.isEmpty) missingItems.add('No photos attached');

  for (final a in anchors) {
    evidenceAnchorLabels.add(a.evidenceType);
  }

  if (nonGuardPlots > 0 && recordedRatings > 0) {
    final coverage = recordedRatings / nonGuardPlots;
    if (coverage < 0.5) {
      riskFlags.add('Low rating coverage (${(coverage * 100).round()}%)');
    }
  }

  final String evidenceState;
  if (sessions.isEmpty && recordedRatings == 0) {
    evidenceState = 'no_evidence';
  } else if (recordedRatings == 0) {
    evidenceState = 'started';
  } else if (missingItems.isNotEmpty) {
    evidenceState = 'partial';
  } else if (riskFlags.isEmpty) {
    evidenceState = 'sufficient_for_review';
  } else {
    evidenceState = 'partial';
  }

  String pl(int n, String singular, String plural) =>
      '$n ${n == 1 ? singular : plural}';
  final actualSummary = sessions.isEmpty
      ? 'No sessions.'
      : '${pl(sessions.length, 'session', 'sessions')} · '
          '${pl(recordedRatings, 'rating', 'ratings')}';

  return TrialEvidenceArcDto(
    trialId: trialId,
    evidenceState: evidenceState,
    plannedEvidenceSummary: '$nonGuardPlots layout plot(s).',
    actualEvidenceSummary: actualSummary,
    missingEvidenceItems: List.unmodifiable(missingItems),
    evidenceAnchors: List.unmodifiable(evidenceAnchorLabels),
    riskFlags: List.unmodifiable(riskFlags),
  );
}
