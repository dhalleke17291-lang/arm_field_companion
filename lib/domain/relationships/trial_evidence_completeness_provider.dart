import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/plot_analysis_eligibility.dart';
import '../../core/providers.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum EvidenceCompletenessState { complete, partial, incomplete }

enum DimensionRelevance { required, relevant, notRequired, notAssessed }

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class EvidenceDimension {
  final String id;
  final String label;
  final EvidenceCompletenessState state;
  final DimensionRelevance relevance;
  final String summary;
  final String? detail;
  final bool isActionable;
  final Map<String, int> sourceCounts;

  const EvidenceDimension({
    required this.id,
    required this.label,
    required this.state,
    required this.relevance,
    required this.summary,
    this.detail,
    required this.isActionable,
    this.sourceCounts = const {},
  });
}

class TrialEvidenceCompleteness {
  final List<EvidenceDimension> dimensions;
  final EvidenceCompletenessState overallState;
  final String summaryText;

  const TrialEvidenceCompleteness({
    required this.dimensions,
    required this.overallState,
    required this.summaryText,
  });
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final trialEvidenceCompletenessProvider =
    FutureProvider.autoDispose.family<TrialEvidenceCompleteness, int>(
        (ref, trialId) async {
  final db = ref.watch(databaseProvider);
  final appRepo = ref.watch(applicationRepositoryProvider);

  // ── Parallel base queries (no session or plot dependency) ─────────────────
  final baseResults = await Future.wait<dynamic>([
    // 0: non-deleted sessions
    (db.select(db.sessions)
          ..where((s) => s.trialId.equals(trialId) & s.isDeleted.equals(false)))
        .get(),
    // 1: all non-deleted plots for trial
    (db.select(db.plots)
          ..where((p) => p.trialId.equals(trialId) & p.isDeleted.equals(false)))
        .get(),
    // 2: seeding events for trial
    (db.select(db.seedingEvents)
          ..where((se) => se.trialId.equals(trialId)))
        .get(),
    // 3: canonical application events (no soft-delete column)
    appRepo.getApplicationsForTrial(trialId),
    // 4: non-deleted photos
    (db.select(db.photos)
          ..where((p) => p.trialId.equals(trialId) & p.isDeleted.equals(false)))
        .get(),
    // 5: non-deleted treatments — count drives applications relevance
    (db.select(db.treatments)
          ..where(
              (t) => t.trialId.equals(trialId) & t.isDeleted.equals(false)))
        .get(),
  ]);

  final sessions = baseResults[0] as List<Session>;
  final allPlots = baseResults[1] as List<Plot>;
  final seedingEventsList = baseResults[2] as List<SeedingEvent>;
  final applications = baseResults[3] as List<TrialApplicationEvent>;
  final photos = baseResults[4] as List<Photo>;
  final treatmentCount = (baseResults[5] as List<Treatment>).length;

  final sessionIds = sessions.map((s) => s.id).toList();
  final analyzablePlots = allPlots.where(isAnalyzablePlot).toList();
  final analyzablePlotPks = analyzablePlots.map((p) => p.id).toList();

  // ── Second wave: session- and plot-dependent queries ──────────────────────
  final List<RatingRecord> analyzableRatings;
  final List<WeatherSnapshot> weatherSnapshots;

  if (analyzablePlotPks.isEmpty && sessionIds.isEmpty) {
    analyzableRatings = [];
    weatherSnapshots = [];
  } else {
    final waveTwo = await Future.wait<dynamic>([
      // current non-deleted ratings for analyzable plots
      analyzablePlotPks.isEmpty
          ? Future.value(<RatingRecord>[])
          : (db.select(db.ratingRecords)
                ..where((r) =>
                    r.plotPk.isIn(analyzablePlotPks) &
                    r.isCurrent.equals(true) &
                    r.isDeleted.equals(false)))
              .get(),
      // weather snapshots linked to rating sessions
      sessionIds.isEmpty
          ? Future.value(<WeatherSnapshot>[])
          : (db.select(db.weatherSnapshots)
                ..where((w) =>
                    w.parentId.isIn(sessionIds) &
                    w.parentType.equals('rating_session')))
              .get(),
    ]);
    analyzableRatings = waveTwo[0] as List<RatingRecord>;
    weatherSnapshots = waveTwo[1] as List<WeatherSnapshot>;
  }

  // ── Dimension 1: Rating coverage (required) ───────────────────────────────
  final ratedPlotPks = analyzableRatings.map((r) => r.plotPk).toSet();
  final ratedCount = ratedPlotPks.length;
  final totalAnalyzable = analyzablePlots.length;

  final EvidenceCompletenessState ratingState;
  final String ratingSummary;
  if (ratedCount >= 3) {
    ratingState = EvidenceCompletenessState.complete;
    ratingSummary = '$ratedCount plots rated';
  } else if (ratedCount > 0) {
    ratingState = EvidenceCompletenessState.partial;
    final plotWord = ratedCount == 1 ? 'plot' : 'plots';
    ratingSummary = '$ratedCount $plotWord rated — need ≥3 for analysis';
  } else {
    ratingState = EvidenceCompletenessState.incomplete;
    ratingSummary = 'No plots rated';
  }

  final ratingDim = EvidenceDimension(
    id: 'rating_coverage',
    label: 'Rating coverage',
    state: ratingState,
    relevance: DimensionRelevance.required,
    summary: ratingSummary,
    isActionable: ratingState != EvidenceCompletenessState.complete,
    sourceCounts: {'rated': ratedCount, 'total': totalAnalyzable},
  );

  // ── Dimension 2: Crop growth stage (relevant) ─────────────────────────────
  final sessionsWithBbch =
      sessions.where((s) => s.cropStageBbch != null).length;
  final bbchState = sessionsWithBbch > 0
      ? EvidenceCompletenessState.complete
      : EvidenceCompletenessState.incomplete;

  final bbchDim = EvidenceDimension(
    id: 'crop_stage',
    label: 'Crop growth stage',
    state: bbchState,
    relevance: DimensionRelevance.relevant,
    summary: sessionsWithBbch > 0
        ? '$sessionsWithBbch ${sessionsWithBbch == 1 ? 'session' : 'sessions'} with BBCH recorded'
        : 'No BBCH recorded',
    isActionable: bbchState == EvidenceCompletenessState.incomplete,
    sourceCounts: {'sessionsWithBbch': sessionsWithBbch},
  );

  // ── Dimension 3: Establishment / seeding (relevant) ───────────────────────
  final SeedingEvent? seedingEvent =
      seedingEventsList.isNotEmpty ? seedingEventsList.first : null;

  final EvidenceCompletenessState seedingState;
  final String seedingSummary;
  if (seedingEvent == null) {
    seedingState = EvidenceCompletenessState.incomplete;
    seedingSummary = 'No seeding record';
  } else if (seedingEvent.status == 'pending') {
    seedingState = EvidenceCompletenessState.partial;
    seedingSummary = 'Seeding record pending completion';
  } else {
    seedingState = EvidenceCompletenessState.complete;
    seedingSummary = 'Seeding recorded';
  }

  final seedingDim = EvidenceDimension(
    id: 'establishment',
    label: 'Establishment',
    state: seedingState,
    relevance: DimensionRelevance.relevant,
    summary: seedingSummary,
    isActionable: seedingState != EvidenceCompletenessState.complete,
    sourceCounts: {'events': seedingEvent == null ? 0 : 1},
  );

  // ── Dimension 4: Treatment applications (relevant or notRequired) ─────────
  final appRelevance = treatmentCount > 0
      ? DimensionRelevance.relevant
      : DimensionRelevance.notRequired;
  final appCount = applications.length;
  final appState = appCount > 0
      ? EvidenceCompletenessState.complete
      : EvidenceCompletenessState.incomplete;

  final applicationsDim = EvidenceDimension(
    id: 'treatment_applications',
    label: 'Treatment applications',
    state: appState,
    relevance: appRelevance,
    summary: appCount > 0
        ? '$appCount ${appCount == 1 ? 'application' : 'applications'} recorded'
        : 'No applications recorded',
    isActionable: appRelevance == DimensionRelevance.relevant &&
        appState == EvidenceCompletenessState.incomplete,
    sourceCounts: {'applications': appCount},
  );

  // ── Dimension 5: Weather (relevant) ──────────────────────────────────────
  final sessionsWithWeather =
      weatherSnapshots.map((w) => w.parentId).toSet().length;
  final weatherState = sessionsWithWeather > 0
      ? EvidenceCompletenessState.complete
      : EvidenceCompletenessState.incomplete;

  final weatherDim = EvidenceDimension(
    id: 'weather',
    label: 'Weather',
    state: weatherState,
    relevance: DimensionRelevance.relevant,
    summary: sessionsWithWeather > 0
        ? '$sessionsWithWeather ${sessionsWithWeather == 1 ? 'session' : 'sessions'} with weather'
        : 'No weather recorded',
    isActionable: weatherState == EvidenceCompletenessState.incomplete,
    sourceCounts: {'sessionsWithWeather': sessionsWithWeather},
  );

  // ── Dimension 6: GPS (relevant) ───────────────────────────────────────────
  final gpsCount = analyzableRatings
      .where(
          (r) => r.capturedLatitude != null && r.capturedLongitude != null)
      .length;
  final gpsState = gpsCount > 0
      ? EvidenceCompletenessState.complete
      : EvidenceCompletenessState.incomplete;

  final gpsDim = EvidenceDimension(
    id: 'gps',
    label: 'GPS',
    state: gpsState,
    relevance: DimensionRelevance.relevant,
    summary: gpsCount > 0
        ? '$gpsCount ${gpsCount == 1 ? 'rating' : 'ratings'} with GPS'
        : 'No GPS captured',
    isActionable: gpsState == EvidenceCompletenessState.incomplete,
    sourceCounts: {'recordsWithGps': gpsCount},
  );

  // ── Dimension 7: Photo documentation (relevant) ───────────────────────────
  final photoCount = photos.length;
  final photoState = photoCount > 0
      ? EvidenceCompletenessState.complete
      : EvidenceCompletenessState.incomplete;

  final photoDim = EvidenceDimension(
    id: 'photos',
    label: 'Photos',
    state: photoState,
    relevance: DimensionRelevance.relevant,
    summary: photoCount > 0
        ? '$photoCount ${photoCount == 1 ? 'photo' : 'photos'}'
        : 'No photos',
    isActionable: photoState == EvidenceCompletenessState.incomplete,
    sourceCounts: {'photos': photoCount},
  );

  // ── Aggregate ─────────────────────────────────────────────────────────────
  final dimensions = [
    ratingDim,
    bbchDim,
    seedingDim,
    applicationsDim,
    weatherDim,
    gpsDim,
    photoDim,
  ];

  final relevantDims = dimensions.where((d) =>
      d.relevance == DimensionRelevance.required ||
      d.relevance == DimensionRelevance.relevant);

  final EvidenceCompletenessState overallState;
  if (relevantDims.any((d) => d.state == EvidenceCompletenessState.incomplete)) {
    overallState = EvidenceCompletenessState.incomplete;
  } else if (relevantDims
      .any((d) => d.state == EvidenceCompletenessState.partial)) {
    overallState = EvidenceCompletenessState.partial;
  } else {
    overallState = EvidenceCompletenessState.complete;
  }

  final incompleteDimLabels = relevantDims
      .where((d) => d.state != EvidenceCompletenessState.complete)
      .map((d) => d.summary)
      .toList();
  final summaryText =
      incompleteDimLabels.isEmpty ? 'complete' : incompleteDimLabels.join(' · ');

  return TrialEvidenceCompleteness(
    dimensions: dimensions,
    overallState: overallState,
    summaryText: summaryText,
  );
});
