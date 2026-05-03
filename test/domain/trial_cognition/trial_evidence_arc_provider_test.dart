import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_evidence_arc_dto.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Replicate _computeTrialEvidenceArc logic for isolated unit testing.
Future<TrialEvidenceArcDto> computeEvidenceArc(
  AppDatabase db,
  int trialId,
) async {
  final sessions = await (db.select(db.sessions)
        ..where((s) => s.trialId.equals(trialId)))
      .get();
  final recordedRatings = sessions.isEmpty
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
  if (sessions.isEmpty) missingItems.add('No rating sessions recorded');
  if (recordedRatings == 0) missingItems.add('No numeric ratings recorded');
  if (photos.isEmpty) missingItems.add('No photos attached');
  final riskFlags = <String>[];
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
  final actualSummary = sessions.isEmpty
      ? 'No sessions.'
      : '${sessions.length} session(s), $recordedRatings rating(s), ${photos.length} photo(s).';
  return TrialEvidenceArcDto(
    trialId: trialId,
    evidenceState: evidenceState,
    plannedEvidenceSummary: '$nonGuardPlots layout plot(s).',
    actualEvidenceSummary: actualSummary,
    missingEvidenceItems: List.unmodifiable(missingItems),
    evidenceAnchors: List.unmodifiable(anchors.map((a) => a.evidenceType).toList()),
    riskFlags: List.unmodifiable(riskFlags),
  );
}

void main() {
  late AppDatabase db;
  late TrialRepository trialRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    trialRepo = TrialRepository(db);
  });

  tearDown(() async => db.close());

  Future<int> makeTrial() =>
      trialRepo.createTrial(name: 'T${DateTime.now().microsecondsSinceEpoch}');

  test('returns no_evidence for an empty trial', () async {
    final trialId = await makeTrial();
    final dto = await computeEvidenceArc(db, trialId);
    expect(dto.evidenceState, 'no_evidence');
    expect(dto.hasEvidence, false);
    expect(dto.missingEvidenceItems, contains('No rating sessions recorded'));
  });

  test('returns started when session exists but no ratings', () async {
    final trialId = await makeTrial();
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            trialId: trialId,
            name: 'Session 1',
            sessionDateLocal: '2026-05-01',
          ),
        );
    final dto = await computeEvidenceArc(db, trialId);
    expect(dto.evidenceState, 'started');
    expect(dto.hasEvidence, true);
  });

  test('recognizes existing sessions without overclaiming', () async {
    final trialId = await makeTrial();
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            trialId: trialId,
            name: 'Session 1',
            sessionDateLocal: '2026-05-01',
          ),
        );
    final dto = await computeEvidenceArc(db, trialId);
    expect(dto.evidenceState, isNot('sufficient_for_review'));
    expect(dto.evidenceState, isNot('export_ready_candidate'));
    expect(dto.isSufficientForReview, false);
  });
}
