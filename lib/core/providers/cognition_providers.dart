import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../trial_operational_watch_merge.dart';
import '../../data/repositories/ctq_factor_definition_repository.dart';
import '../../data/repositories/intent_revelation_event_repository.dart';
import '../../data/repositories/protocol_document_reference_repository.dart';
import '../../data/repositories/trial_purpose_repository.dart';
import '../../domain/environmental/inter_event_weather_dto.dart';
import '../../domain/signals/signal_providers.dart';
import '../../domain/trial_cognition/environmental_window_evaluator.dart';
import '../../domain/trial_cognition/mode_c_revelation_model.dart';
import '../../domain/trial_cognition/trial_coherence_dto.dart';
import '../../domain/trial_cognition/trial_coherence_evaluator.dart';
import '../../domain/trial_cognition/trial_ctq_dto.dart';
import '../../domain/trial_cognition/trial_ctq_evaluator.dart';
import '../../domain/trial_cognition/trial_decision_summary_dto.dart';
import '../../domain/trial_cognition/trial_evidence_arc_dto.dart';
import '../../domain/trial_cognition/trial_evidence_arc_evaluator.dart';
import '../../domain/trial_cognition/trial_intent_inferrer.dart';
import '../../domain/trial_cognition/trial_intent_seeder.dart';
import '../../domain/trial_cognition/trial_interpretation_risk_dto.dart';
import '../../domain/trial_cognition/trial_interpretation_risk_evaluator.dart';
import '../../domain/trial_cognition/trial_purpose_dto.dart';
import '../../domain/trial_cognition/trial_readiness_statement.dart';
import 'infrastructure_providers.dart';

// ─── Trial Cognition V1 — repositories ───────────────────────────────────────

final trialPurposeRepositoryProvider = Provider<TrialPurposeRepository>((ref) {
  return TrialPurposeRepository(ref.watch(databaseProvider));
});

final trialIntentSeederProvider = Provider<TrialIntentSeeder>((ref) {
  return TrialIntentSeeder(
    ref.watch(databaseProvider),
    ref.watch(trialPurposeRepositoryProvider),
  );
});

final intentRevelationEventRepositoryProvider =
    Provider<IntentRevelationEventRepository>((ref) {
  return IntentRevelationEventRepository(ref.watch(databaseProvider));
});

final ctqFactorDefinitionRepositoryProvider =
    Provider<CtqFactorDefinitionRepository>((ref) {
  return CtqFactorDefinitionRepository(ref.watch(databaseProvider));
});

final protocolDocumentReferenceRepositoryProvider =
    Provider<ProtocolDocumentReferenceRepository>((ref) {
  return ProtocolDocumentReferenceRepository(ref.watch(databaseProvider));
});

// ─── Trial Cognition V1 — deterministic providers ────────────────────────────

/// What is this trial trying to prove? Is purpose unknown, partial, or confirmed?
final trialPurposeProvider =
    StreamProvider.autoDispose.family<TrialPurposeDto, int>((ref, trialId) {
  return ref
      .watch(trialPurposeRepositoryProvider)
      .watchCurrentTrialPurpose(trialId)
      .map((purpose) => _computeTrialPurposeDto(trialId, purpose));
});

/// What evidence exists, what is missing, what are the risk flags?
final trialEvidenceArcProvider =
    StreamProvider.autoDispose.family<TrialEvidenceArcDto, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return mergeTableWatchStreams([
    (db.select(db.sessions)..where((s) => s.trialId.equals(trialId))).watch(),
    (db.select(db.ratingRecords)..where((r) => r.trialId.equals(trialId)))
        .watch(),
    (db.select(db.photos)..where((p) => p.trialId.equals(trialId))).watch(),
    (db.select(db.evidenceAnchors)..where((a) => a.trialId.equals(trialId)))
        .watch(),
    (db.select(db.plots)..where((p) => p.trialId.equals(trialId))).watch(),
  ]).asyncMap((_) => computeTrialEvidenceArcDto(db, trialId));
});

/// Deterministic CTQ readiness/evidence status.
/// Factors are scoped to the current (non-superseded) purpose version so that
/// re-confirms never mix factors from old purpose rows.
/// Each item is enriched with the latest researcher acknowledgment (if any).
final trialCriticalToQualityProvider =
    StreamProvider.autoDispose.family<TrialCtqDto, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  final ctqRepo = ref.watch(ctqFactorDefinitionRepositoryProvider);
  final purposeRepo = ref.watch(trialPurposeRepositoryProvider);

  return mergeTableWatchStreams([
    (db.select(db.trialPurposes)..where((p) => p.trialId.equals(trialId)))
        .watch(),
    (db.select(db.ctqFactorDefinitions)
          ..where((f) => f.trialId.equals(trialId)))
        .watch(),
    (db.select(db.ctqFactorAcknowledgments)
          ..where((a) => a.trialId.equals(trialId)))
        .watch(),
    (db.select(db.treatments)..where((t) => t.trialId.equals(trialId))).watch(),
    (db.select(db.photos)..where((p) => p.trialId.equals(trialId))).watch(),
    (db.select(db.ratingRecords)..where((r) => r.trialId.equals(trialId)))
        .watch(),
    (db.select(db.plots)..where((p) => p.trialId.equals(trialId))).watch(),
    (db.select(db.signals)..where((s) => s.trialId.equals(trialId))).watch(),
    (db.select(db.trialApplicationEvents)
          ..where((a) => a.trialId.equals(trialId)))
        .watch(),
    (db.select(db.assignments)..where((a) => a.trialId.equals(trialId)))
        .watch(),
    (db.select(db.treatmentComponents)..where((c) => c.trialId.equals(trialId)))
        .watch(),
    (db.select(db.trials)..where((t) => t.id.equals(trialId))).watch(),
    db.select(db.users).watch(),
  ]).asyncMap((_) async {
    final currentPurpose = await purposeRepo.getCurrentTrialPurpose(trialId);
    if (currentPurpose == null) {
      return TrialCtqDto(
        trialId: trialId,
        ctqItems: const [],
        blockerCount: 0,
        warningCount: 0,
        reviewCount: 0,
        satisfiedCount: 0,
        overallStatus: 'unknown',
      );
    }
    var factors =
        await ctqRepo.watchCtqFactorsForPurpose(currentPurpose.id).first;
    // Re-seed if existing trials are missing newly added default keys.
    if (factors.length < kCtqDefaultFactorKeys.length) {
      await ctqRepo.seedDefaultCtqFactorsForPurpose(
        trialId: trialId,
        trialPurposeId: currentPurpose.id,
      );
      factors =
          await ctqRepo.watchCtqFactorsForPurpose(currentPurpose.id).first;
    }
    final base = await computeTrialCtqDtoV1(db, trialId, factors);
    final enriched = await Future.wait(base.ctqItems.map((item) async {
      final ack = await ctqRepo.getLatestAcknowledgment(
        trialId: trialId,
        factorKey: item.factorKey,
      );
      if (ack == null) return item;
      return TrialCtqItemDto(
        factorKey: item.factorKey,
        label: item.label,
        importance: item.importance,
        status: item.status,
        evidenceSummary: item.evidenceSummary,
        reason: item.reason,
        source: item.source,
        isAcknowledged: true,
        latestAcknowledgment: ack,
      );
    }));
    return TrialCtqDto(
      trialId: base.trialId,
      ctqItems: List.unmodifiable(enriched),
      blockerCount: base.blockerCount,
      warningCount: base.warningCount,
      reviewCount: base.reviewCount,
      satisfiedCount: base.satisfiedCount,
      overallStatus: base.overallStatus,
    );
  });
});

/// Cross-factor coherence: four deterministic checks that verify whether the
/// trial's evidence, application timing, replication, and open signals are
/// internally consistent with the stated claim.
final trialCoherenceProvider =
    StreamProvider.autoDispose.family<TrialCoherenceDto, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  final signalRepo = ref.read(signalRepositoryProvider);
  return mergeTableWatchStreams([
    (db.select(db.trialPurposes)..where((p) => p.trialId.equals(trialId)))
        .watch(),
    (db.select(db.assessments)..where((a) => a.trialId.equals(trialId)))
        .watch(),
    (db.select(db.trialApplicationEvents)
          ..where((a) => a.trialId.equals(trialId)))
        .watch(),
    (db.select(db.treatments)..where((t) => t.trialId.equals(trialId))).watch(),
    (db.select(db.treatmentComponents)..where((c) => c.trialId.equals(trialId)))
        .watch(),
    (db.select(db.trials)..where((t) => t.id.equals(trialId))).watch(),
    (db.select(db.assignments)..where((a) => a.trialId.equals(trialId)))
        .watch(),
    (db.select(db.signals)..where((s) => s.trialId.equals(trialId))).watch(),
    signalRepo.watchDecisionEventsForTrial(trialId),
    db.select(db.users).watch(),
  ]).asyncMap((_) => computeTrialCoherenceDto(
        db: db,
        trialId: trialId,
        signalRepo: signalRepo,
      ));
});

/// Five cross-factor risk factors that surface interpretation hazards:
/// data variability (CV), untreated check pressure, application timing
/// deviation (from coherence provider), primary endpoint completeness,
/// and rater consistency.
final trialInterpretationRiskProvider = StreamProvider.autoDispose
    .family<TrialInterpretationRiskDto, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  final signalRepo = ref.read(signalRepositoryProvider);
  return mergeTableWatchStreams([
    (db.select(db.trialPurposes)..where((p) => p.trialId.equals(trialId)))
        .watch(),
    (db.select(db.assessments)..where((a) => a.trialId.equals(trialId)))
        .watch(),
    (db.select(db.trialApplicationEvents)
          ..where((a) => a.trialId.equals(trialId)))
        .watch(),
    (db.select(db.treatments)..where((t) => t.trialId.equals(trialId))).watch(),
    (db.select(db.treatmentComponents)..where((c) => c.trialId.equals(trialId)))
        .watch(),
    (db.select(db.trials)..where((t) => t.id.equals(trialId))).watch(),
    (db.select(db.assignments)..where((a) => a.trialId.equals(trialId)))
        .watch(),
    (db.select(db.signals)..where((s) => s.trialId.equals(trialId))).watch(),
    (db.select(db.ratingRecords)..where((r) => r.trialId.equals(trialId)))
        .watch(),
    (db.select(db.plots)..where((p) => p.trialId.equals(trialId))).watch(),
    signalRepo.watchDecisionEventsForTrial(trialId),
    db.select(db.users).watch(),
    (db.select(db.trialEnvironmentalRecords)
          ..where((r) => r.trialId.equals(trialId)))
        .watch(),
  ]).asyncMap((_) async {
    final coherenceDto = await computeTrialCoherenceDto(
      db: db,
      trialId: trialId,
      signalRepo: signalRepo,
    );
    final envRepo = ref.read(trialEnvironmentalRepositoryProvider);
    final allEnvRecords = await envRepo.getRecordsForTrial(trialId);
    EnvironmentalSeasonSummaryDto? environmentalSummary;
    if (allEnvRecords.isNotEmpty) {
      final trial = await (db.select(db.trials)
            ..where((t) => t.id.equals(trialId)))
          .getSingleOrNull();
      environmentalSummary = computeSeasonSummary(
        allEnvRecords,
        trial?.createdAt ?? DateTime.now(),
        trial?.harvestDate ?? DateTime.now(),
      );
    }
    return computeTrialInterpretationRiskDto(
      db: db,
      trialId: trialId,
      coherenceDto: coherenceDto,
      environmentalSummary: environmentalSummary,
    );
  });
});

typedef TrialReadinessStatementProviderArgs = ({
  int trialId,
  String trialState,
});

final trialReadinessStatementProvider = Provider.autoDispose.family<
    AsyncValue<TrialReadinessStatement>,
    TrialReadinessStatementProviderArgs>((ref, args) {
  final ctqAsync = ref.watch(trialCriticalToQualityProvider(args.trialId));
  final coherenceAsync = ref.watch(trialCoherenceProvider(args.trialId));
  final riskAsync = ref.watch(trialInterpretationRiskProvider(args.trialId));
  final purposeAsync = ref.watch(trialPurposeProvider(args.trialId));

  return ctqAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
    data: (ctq) => coherenceAsync.when(
      loading: () => const AsyncValue.loading(),
      error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
      data: (coherence) => riskAsync.when(
        loading: () => const AsyncValue.loading(),
        error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
        data: (risk) => AsyncValue.data(
          computeTrialReadinessStatement(
            coherenceDto: coherence,
            riskDto: risk,
            ctqDto: ctq,
            trialState: args.trialState,
            knownInterpretationFactors:
                purposeAsync.valueOrNull?.knownInterpretationFactors,
          ),
        ),
      ),
    ),
  );
});

/// Provenance metadata derived from a trial's environmental records:
/// dominant data source, most recent fetch timestamp, overall confidence,
/// and whether multiple sources are present.
class EnvironmentalProvenanceDto {
  const EnvironmentalProvenanceDto({
    required this.dataSource,
    required this.fetchedAtMs,
    required this.overallConfidence,
    required this.isMultiSource,
    required this.dominantCount,
    this.siteLatitude,
    this.siteLongitude,
  });

  /// Most common data source value across all records (e.g. 'open_meteo').
  final String? dataSource;

  /// Epoch milliseconds of the most recently fetched record.
  final int? fetchedAtMs;

  /// Worst confidence level across all records (measured < estimated < unavailable).
  final String? overallConfidence;

  /// True when records originate from more than one distinct source.
  final bool isMultiSource;

  /// Number of records attributed to [dataSource].
  final int dominantCount;

  final double? siteLatitude;
  final double? siteLongitude;

  DateTime? get fetchedAt => fetchedAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(fetchedAtMs!, isUtc: true);

  String? get confidence => overallConfidence;
}

String? _worseConfidence(String? a, String? b) {
  const order = ['measured', 'estimated', 'unavailable'];
  final ai = order.indexOf(a ?? '');
  final bi = order.indexOf(b ?? '');
  if (bi == -1) return a;
  if (ai == -1) return b;
  return ai > bi ? a : b;
}

/// Provenance for the environmental data of a trial.
/// Returns null when no records exist for the trial.
final trialEnvironmentalProvenanceProvider = StreamProvider.autoDispose
    .family<EnvironmentalProvenanceDto?, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.trialEnvironmentalRecords)
        ..where((r) => r.trialId.equals(trialId))
        ..orderBy([(r) => drift.OrderingTerm.desc(r.recordDate)]))
      .watch()
      .map((records) {
    if (records.isEmpty) return null;

    int? latestFetch;
    TrialEnvironmentalRecord? latestRow;
    for (final r in records) {
      if (latestFetch == null || r.fetchedAt > latestFetch) {
        latestFetch = r.fetchedAt;
        latestRow = r;
      }
    }

    final sourceCounts = <String, int>{};
    for (final r in records) {
      sourceCounts[r.dataSource] = (sourceCounts[r.dataSource] ?? 0) + 1;
    }

    String? dominantSource;
    var dominantCount = 0;
    for (final entry in sourceCounts.entries) {
      if (entry.value > dominantCount) {
        dominantCount = entry.value;
        dominantSource = entry.key;
      }
    }

    String? worstConf;
    for (final r in records) {
      worstConf = _worseConfidence(worstConf, r.confidence);
    }

    return EnvironmentalProvenanceDto(
      dataSource: dominantSource,
      fetchedAtMs: latestFetch,
      overallConfidence: worstConf,
      isMultiSource: sourceCounts.length > 1,
      dominantCount: dominantCount,
      siteLatitude: latestRow?.siteLatitude,
      siteLongitude: latestRow?.siteLongitude,
    );
  });
});

/// Season-level environmental summary for a trial: total precipitation,
/// frost events, excessive rainfall events, and data completeness.
final trialEnvironmentalSummaryProvider = StreamProvider.autoDispose
    .family<EnvironmentalSeasonSummaryDto, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  final envRepo = ref.read(trialEnvironmentalRepositoryProvider);

  return (db.select(db.trialEnvironmentalRecords)
        ..where((r) => r.trialId.equals(trialId)))
      .watch()
      .asyncMap((_) async {
    final trial = await (db.select(db.trials)
          ..where((t) => t.id.equals(trialId)))
        .getSingleOrNull();
    final records = await envRepo.getRecordsForTrial(trialId);

    final startDate = trial?.createdAt ?? DateTime.now();
    final endDate = trial?.harvestDate ?? DateTime.now();

    return computeSeasonSummary(records, startDate, endDate);
  });
});

/// Pre- and post-application environmental windows for a specific
/// application event. Reads the application date then calls both
/// window computations against the trial's environmental records.
final applicationEnvironmentalContextProvider = FutureProvider.autoDispose
    .family<ApplicationEnvironmentalContextDto,
        ApplicationEnvironmentalRequest>((ref, request) async {
  final db = ref.watch(databaseProvider);
  final envRepo = ref.read(trialEnvironmentalRepositoryProvider);

  final appEvent = await (db.select(db.trialApplicationEvents)
        ..where((a) => a.id.equals(request.applicationEventId)))
      .getSingleOrNull();
  final records = await envRepo.getRecordsForTrial(request.trialId);

  if (appEvent == null) {
    return const ApplicationEnvironmentalContextDto(
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
      unavailableReason: 'application event not found.',
    );
  }

  if (appEvent.trialId != request.trialId) {
    return const ApplicationEnvironmentalContextDto(
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
      unavailableReason: 'application event does not belong to this trial.',
    );
  }

  return ApplicationEnvironmentalContextDto(
    preWindow: computePreApplicationWindow(records, appEvent.applicationDate),
    postWindow: computePostApplicationWindow(records, appEvent.applicationDate),
  );
});

@immutable
class InterEventWeatherRequest {
  final int trialId;
  final DateTime from;
  final DateTime to;

  const InterEventWeatherRequest({
    required this.trialId,
    required this.from,
    required this.to,
  });

  @override
  bool operator ==(Object other) =>
      other is InterEventWeatherRequest &&
      other.trialId == trialId &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(trialId, from, to);
}

final interEventWeatherProvider = FutureProvider.autoDispose
    .family<InterEventWeatherDto, InterEventWeatherRequest>((ref, req) async {
  final repo = ref.read(trialEnvironmentalRepositoryProvider);
  final allRecords = await repo.getRecordsForTrial(req.trialId);
  return computeInterEventWindow(allRecords, req.from, req.to);
});

/// All researcher-authored decisions and CTQ acknowledgments for a trial,
/// excluding canned system notes. Used by the "Decisions and reasoning"
/// section in Trial Story.
final trialDecisionSummaryProvider = FutureProvider.autoDispose
    .family<TrialDecisionSummaryDto, int>((ref, trialId) async {
  final signalRepo = ref.read(signalRepositoryProvider);
  final ctqRepo = ref.read(ctqFactorDefinitionRepositoryProvider);

  final signalDecisions =
      await signalRepo.getAllResearcherDecisionEventsForTrial(trialId);
  final ctqAcks = await ctqRepo.getAllAcknowledgmentsForTrial(trialId);

  return TrialDecisionSummaryDto(
    trialId: trialId,
    signalDecisions: signalDecisions,
    ctqAcknowledgments: ctqAcks,
    hasAnyResearcherReasoning: signalDecisions.isNotEmpty || ctqAcks.isNotEmpty,
  );
});

// ─── Trial Cognition V1 — computation helpers ─────────────────────────────────

TrialPurposeDto _computeTrialPurposeDto(int trialId, TrialPurpose? purpose) {
  if (purpose == null) {
    return TrialPurposeDto(
      trialId: trialId,
      purposeStatus: 'unknown',
      missingIntentFields: List.unmodifiable(ModeCQuestionKeys.required),
      provenanceSummary: 'No purpose captured.',
      canDriveReadinessClaims: false,
    );
  }

  final requiresConfirmation = purpose.requiresConfirmation == 1;

  // Parse inferred confidence JSON when the row is pending confirmation.
  InferredTrialPurpose? inferredPurpose;
  if (requiresConfirmation && purpose.inferredFieldsJson != null) {
    try {
      inferredPurpose =
          InferredTrialPurpose.fromJsonString(purpose.inferredFieldsJson!);
    } catch (_) {
      // Malformed JSON — treat as no inference data.
    }
  }

  // When inferred and pending confirmation, filter out low/cannotInfer fields
  // so evaluators only see what can be used for preliminary assessment.
  bool confUsable(FieldConfidence c) =>
      c == FieldConfidence.high || c == FieldConfidence.moderate;

  String? claim = purpose.claimBeingTested;
  String? endpoint = purpose.primaryEndpoint;
  String? regulatory = purpose.regulatoryContext;

  if (requiresConfirmation && inferredPurpose != null) {
    if (!confUsable(inferredPurpose.claimConfidence)) claim = null;
    if (!confUsable(inferredPurpose.primaryEndpointConfidence)) endpoint = null;
    if (!confUsable(inferredPurpose.regulatoryContextConfidence)) {
      regulatory = null;
    }
  }

  final missing = <String>[
    if (claim == null) ModeCQuestionKeys.claimBeingTested,
    if (purpose.trialPurpose == null) ModeCQuestionKeys.trialPurposeContext,
    if (endpoint == null) ModeCQuestionKeys.primaryEndpoint,
    if (purpose.treatmentRoleSummary == null) ModeCQuestionKeys.treatmentRoles,
  ];

  final effectiveStatus = () {
    if (purpose.status == 'confirmed' && missing.isEmpty) return 'confirmed';
    if (missing.length < ModeCQuestionKeys.required.length) return 'partial';
    return purpose.status;
  }();

  // Inferred rows never drive readiness claims without researcher confirmation.
  final canDrive = !requiresConfirmation &&
      effectiveStatus == 'confirmed' &&
      missing.isEmpty;

  final provenance = requiresConfirmation
      ? 'Inferred from ${purpose.sourceMode.replaceAll('_', ' ')} — pending confirmation.'
      : purpose.confirmedAt != null
          ? 'Confirmed${purpose.confirmedBy != null ? ' by ${purpose.confirmedBy}' : ''}.'
          : '${missing.length} required field(s) missing.';

  return TrialPurposeDto(
    trialId: trialId,
    purposeStatus: effectiveStatus,
    claimBeingTested: claim,
    trialPurpose: purpose.trialPurpose,
    regulatoryContext: regulatory,
    primaryEndpoint: endpoint,
    treatmentRoles: purpose.treatmentRoleSummary,
    knownInterpretationFactors: purpose.knownInterpretationFactors,
    readinessCriteriaSummary: purpose.readinessCriteriaSummary,
    missingIntentFields: List.unmodifiable(missing),
    provenanceSummary: provenance,
    canDriveReadinessClaims: canDrive,
    requiresConfirmation: requiresConfirmation,
    inferenceSource: purpose.sourceMode,
    inferredPurpose: inferredPurpose,
  );
}
