import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/plot_analysis_eligibility.dart';
import '../../core/providers.dart';
import '../../core/session_state.dart';
import '../../core/ui/assessment_display_helper.dart';
import '../../core/utils/check_treatment_helper.dart';
import '../../core/widgets/loading_error_widgets.dart';
import '../../core/workspace/workspace_config.dart';
import 'domain/trial_data_computer.dart';
import 'widgets/insight_row.dart';

// ---------------------------------------------------------------------------
// Package-visible helpers (used by widget + tests)
// ---------------------------------------------------------------------------

/// Returns the display suffix for the execution row of the summary header.
///
/// Each element describes one application event: its completion status and
/// whether any product deviation was flagged.
String computeExecutionRowSuffix(
    List<({String status, bool hasDeviation})> appStates) {
  if (appStates.isEmpty) return 'no applications recorded';
  final toReview =
      appStates.where((a) => a.status != 'completed' || a.hasDeviation).length;
  if (toReview == 0) return 'complete';
  return '$toReview item${toReview == 1 ? '' : 's'} to review';
}

/// Returns the display suffix for the data quality row of the summary header.
String computeDataQualityRowSuffix({
  required int closedCount,
  required int openCount,
  required int amendedCount,
  required int outlierCount,
}) {
  if (closedCount == 0) return 'no closed sessions yet';
  final issues = openCount + amendedCount + outlierCount;
  if (issues == 0) return 'clean';
  return '$issues issue${issues == 1 ? '' : 's'} found';
}

/// Formats the main weather detail line for a session snapshot.
///
/// Includes temperature, precipitation label (text, not numeric), and
/// appends "manual entry" when [WeatherSnapshot.source] == 'manual'.
/// Returns empty string when no fields are present.
String formatWeatherMainLine(WeatherSnapshot w) {
  final parts = <String>[];
  if (w.temperature != null) {
    parts.add('${w.temperature!.toStringAsFixed(1)}°${w.temperatureUnit}');
  }
  if (w.precipitation != null && w.precipitation!.isNotEmpty) {
    parts.add(w.precipitation!);
  }
  if (w.source == 'manual') parts.add('manual entry');
  return parts.join(' · ');
}

// ---------------------------------------------------------------------------
// Screen-local data classes
// ---------------------------------------------------------------------------

/// Minimal weather display model for application bundles.
/// Constructed from inline event columns (primary) or a proximity
/// WeatherSnapshot (fallback) — both produce the same fields.
class _AppWeather {
  const _AppWeather({
    required this.temperature,
    required this.temperatureUnit,
    required this.precipitation,
  });
  final double? temperature;
  final String temperatureUnit;
  final String? precipitation;
}

class _AppBundle {
  const _AppBundle({
    required this.event,
    required this.products,
    required this.plotCount,
    required this.weather,
  });
  final TrialApplicationEvent event;
  final List<TrialApplicationProduct> products;
  final int plotCount;
  final _AppWeather? weather;
}

class _AnalysisData {
  const _AnalysisData({
    required this.allSessions,
    required this.closedSessions,
    required this.allRatings,
    required this.closedRatings,
    required this.allPlots,
    required this.analyzablePlots,
    required this.excludedPlots,
    required this.assignments,
    required this.treatments,
    required this.legacyAssessments,
    required this.assessmentDisplayNames,
    required this.assessmentOrder,
    required this.treatmentResults,
    required this.outlierCandidates,
    required this.amendedRatings,
    required this.unattributedRatings,
    required this.plotTreatmentMap,
  });

  final List<Session> allSessions;
  final List<Session> closedSessions;
  final List<RatingRecord> allRatings;
  final List<RatingRecord> closedRatings;
  final List<Plot> allPlots;
  final List<Plot> analyzablePlots;
  final List<Plot> excludedPlots;
  final List<Assignment> assignments;
  final List<Treatment> treatments;
  final List<Assessment> legacyAssessments;
  final Map<int, String> assessmentDisplayNames;
  final List<int> assessmentOrder;
  final Map<int, Map<int, TreatmentCellData>> treatmentResults;
  final Set<(int, int)> outlierCandidates;
  final List<RatingRecord> amendedRatings;
  final List<RatingRecord> unattributedRatings;
  final Map<int, int> plotTreatmentMap;
}

// ---------------------------------------------------------------------------
// Screen-local providers
// ---------------------------------------------------------------------------

final _trialAppBundlesProvider =
    FutureProvider.autoDispose.family<List<_AppBundle>, int>((ref, trialId) async {
  final eventsFuture = ref.read(trialApplicationsForTrialProvider(trialId).future);
  final sessionsFuture = ref.read(sessionsForTrialProvider(trialId).future);
  final snapshotsFuture = ref.read(weatherSnapshotsForTrialProvider(trialId).future);
  final events = await eventsFuture;
  final sessions = await sessionsFuture;
  final snapshots = await snapshotsFuture;

  final productRepo = ref.read(applicationProductRepositoryProvider);
  final assignmentRepo = ref.read(applicationPlotAssignmentRepositoryProvider);

  final bundles = <_AppBundle>[];
  for (final event in events) {
    final productsFuture = productRepo.getProductsForEvent(event.id);
    final assignmentsFuture = assignmentRepo.getForEvent(event.id);
    final products = await productsFuture;
    final assignments = await assignmentsFuture;
    _AppWeather? weather;
    if (event.temperature != null) {
      weather = _AppWeather(
        temperature: event.temperature,
        temperatureUnit: 'C',
        precipitation: event.precipitation,
      );
    } else {
      final snapshot = TrialDataComputer.findApplicationWeather(
        applicationDate: event.applicationDate,
        sessions: sessions,
        snapshots: snapshots,
      );
      if (snapshot != null) {
        weather = _AppWeather(
          temperature: snapshot.temperature,
          temperatureUnit: snapshot.temperatureUnit,
          precipitation: snapshot.precipitation,
        );
      }
    }
    bundles.add(_AppBundle(
      event: event,
      products: products,
      plotCount: assignments.length,
      weather: weather,
    ));
  }
  return bundles;
});

final _trialAnalysisDataProvider =
    FutureProvider.autoDispose.family<_AnalysisData, int>((ref, trialId) async {
  // Fire futures in parallel
  final sessionsFuture = ref.read(sessionsForTrialProvider(trialId).future);
  final ratingsFuture = ref.read(allSessionRatingsForTrialProvider(trialId).future);
  final plotsFuture = ref.read(plotsForTrialProvider(trialId).future);
  final assignmentsFuture = ref.read(assignmentsForTrialProvider(trialId).future);
  final treatmentsFuture = ref.read(treatmentsForTrialProvider(trialId).future);
  final legacyAssessmentsFuture =
      ref.read(assessmentsForTrialProvider(trialId).future);
  final taPairsFuture =
      ref.read(trialAssessmentsWithDefinitionsForTrialProvider(trialId).future);

  final sessions = await sessionsFuture;
  final allRatings = await ratingsFuture;
  final plots = await plotsFuture;
  final assignments = await assignmentsFuture;
  final treatments = await treatmentsFuture;
  final legacyAssessments = await legacyAssessmentsFuture;
  final taPairs = await taPairsFuture;

  final closedSessions =
      sessions.where((s) => s.status == kSessionStatusClosed).toList();
  final closedSessionIds = {for (final s in closedSessions) s.id};
  final closedRatings =
      allRatings.where((r) => closedSessionIds.contains(r.sessionId)).toList();

  // Assessment display names (two-pass: TA pairs first, then legacy fallback)
  final assessmentDisplayNames = <int, String>{};
  final assessmentOrder = <int>[];
  final sortedPairs = List.of(taPairs)
    ..sort((a, b) => a.$1.sortOrder.compareTo(b.$1.sortOrder));
  for (final (ta, def) in sortedPairs) {
    final lid = ta.legacyAssessmentId;
    if (lid != null) {
      assessmentDisplayNames[lid] =
          AssessmentDisplayHelper.compactName(ta, def: def);
      assessmentOrder.add(lid);
    }
  }
  final legacyById = {for (final a in legacyAssessments) a.id: a};
  for (final r in closedRatings) {
    if (!assessmentDisplayNames.containsKey(r.assessmentId)) {
      final a = legacyById[r.assessmentId];
      if (a != null) {
        assessmentDisplayNames[r.assessmentId] =
            AssessmentDisplayHelper.legacyAssessmentDisplayName(a.name);
        if (!assessmentOrder.contains(r.assessmentId)) {
          assessmentOrder.add(r.assessmentId);
        }
      }
    }
  }

  // Plot → treatment map
  final plotTreatmentMap = <int, int>{};
  for (final a in assignments) {
    if (a.treatmentId != null) plotTreatmentMap[a.plotId] = a.treatmentId!;
  }
  for (final p in plots) {
    if (!plotTreatmentMap.containsKey(p.id) && p.treatmentId != null) {
      plotTreatmentMap[p.id] = p.treatmentId!;
    }
  }

  final assessmentsForCompute = assessmentOrder
      .map((id) => legacyById[id])
      .whereType<Assessment>()
      .toList();

  final analyzablePlots = plots.where(isAnalyzablePlot).toList();
  final excludedPlots =
      plots.where((p) => !p.isGuardRow && p.excludeFromAnalysis == true).toList();

  final treatmentResults = TrialDataComputer.computeTreatmentMeans(
    treatments: treatments,
    plots: plots,
    assignments: assignments,
    assessments: assessmentsForCompute,
    ratings: closedRatings,
  );

  final outlierCandidates = TrialDataComputer.computeOutlierCandidates(
    plots: plots,
    assignments: assignments,
    assessments: assessmentsForCompute,
    ratings: closedRatings,
  );

  final amendedRatings = TrialDataComputer.findAmendedRatings(allRatings);
  final unattributedRatings =
      TrialDataComputer.findUnattributedRatings(allRatings);

  return _AnalysisData(
    allSessions: sessions,
    closedSessions: closedSessions,
    allRatings: allRatings,
    closedRatings: closedRatings,
    allPlots: plots,
    analyzablePlots: analyzablePlots,
    excludedPlots: excludedPlots,
    assignments: assignments,
    treatments: treatments,
    legacyAssessments: legacyAssessments,
    assessmentDisplayNames: assessmentDisplayNames,
    assessmentOrder: assessmentOrder,
    treatmentResults: treatmentResults,
    outlierCandidates: outlierCandidates,
    amendedRatings: amendedRatings,
    unattributedRatings: unattributedRatings,
    plotTreatmentMap: plotTreatmentMap,
  );
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class TrialDataScreen extends ConsumerStatefulWidget {
  const TrialDataScreen({super.key, required this.trial});

  final Trial trial;

  @override
  ConsumerState<TrialDataScreen> createState() => _TrialDataScreenState();
}

class _TrialDataScreenState extends ConsumerState<TrialDataScreen> {
  bool _footerExpanded = false;
  final Set<int> _expandedTreatmentIds = {};

  static const double _kTreatColWidth = 160.0;
  static const double _kAssessColWidth = 86.0;

  @override
  Widget build(BuildContext context) {
    final trial = widget.trial;
    final config = safeConfigFromString(trial.workspaceType);

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.primary,
        foregroundColor: AppDesignTokens.onPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trial.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Text(
              'Trial data',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSummaryHeader(trial),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              children: [
                _buildSection1(trial, config),
                const SizedBox(height: 12),
                _buildSection2(trial),
                const SizedBox(height: 12),
                _buildSection3(trial),
                const SizedBox(height: 12),
                _buildSection4(trial),
                const SizedBox(height: 12),
                _buildSection5(trial),
                const SizedBox(height: 12),
                _buildSection6(trial),
                const SizedBox(height: 12),
                _buildFooter(trial, config),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Summary header
  // -------------------------------------------------------------------------

  Widget _buildSummaryHeader(Trial trial) {
    final bundlesAsync = ref.watch(_trialAppBundlesProvider(trial.id));
    final analysisAsync = ref.watch(_trialAnalysisDataProvider(trial.id));

    final isLoading = bundlesAsync.isLoading || analysisAsync.isLoading;
    if (isLoading) {
      return ColoredBox(
        color: AppDesignTokens.sectionHeaderBg,
        child: const SizedBox(height: 120),
      );
    }
    if (bundlesAsync.hasError || analysisAsync.hasError) {
      return const SizedBox.shrink();
    }

    final bundles = bundlesAsync.value!;
    final data = analysisAsync.value!;

    final appStates = bundles
        .map((b) => (
              status: b.event.status,
              hasDeviation: b.products.any((p) => p.deviationFlag == true),
            ))
        .toList();

    final execSuffix = computeExecutionRowSuffix(appStates);
    final openCount = data.allSessions.length - data.closedSessions.length;
    final qualitySuffix = computeDataQualityRowSuffix(
      closedCount: data.closedSessions.length,
      openCount: openCount,
      amendedCount: data.amendedRatings.length,
      outlierCount: data.outlierCandidates.length,
    );

    final closedX = data.closedSessions.length;
    final treatY = data.treatments.length;
    final assessZ = data.assessmentOrder.length;
    final resultsSuffix =
        '$closedX closed session${closedX == 1 ? '' : 's'} · '
        '$treatY treatment${treatY == 1 ? '' : 's'} · '
        '$assessZ assessment${assessZ == 1 ? '' : 's'}';

    // TODO: wire tap-to-scroll when section keys are established in a future refactor.
    return ColoredBox(
      color: AppDesignTokens.sectionHeaderBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _summaryRow(label: 'Execution', suffix: execSuffix),
          const Divider(
              height: 1, thickness: 0.5, color: AppDesignTokens.borderCrisp),
          _summaryRow(label: 'Data quality', suffix: qualitySuffix),
          const Divider(
              height: 1, thickness: 0.5, color: AppDesignTokens.borderCrisp),
          _summaryRow(label: 'Results', suffix: resultsSuffix),
        ],
      ),
    );
  }

  Widget _summaryRow({required String label, required String suffix}) {
    final Color suffixColor;
    if (suffix.endsWith('to review') || suffix.endsWith('found')) {
      suffixColor = AppDesignTokens.warningFg;
    } else if (suffix == 'no applications recorded' ||
        suffix == 'no closed sessions yet') {
      suffixColor = AppDesignTokens.secondaryText;
    } else {
      suffixColor = AppDesignTokens.primaryText;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing16,
        vertical: AppDesignTokens.spacing12,
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          Expanded(
            child: Text(
              suffix,
              style: TextStyle(fontSize: 13, color: suffixColor),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Section 1 — Site and crop
  // -------------------------------------------------------------------------

  Widget _buildSection1(Trial trial, WorkspaceConfig config) {
    final cropDescAsync = ref.watch(cropDescriptionForTrialProvider(trial.id));
    return _SectionCard(
      title: '1. Site and crop',
      child: cropDescAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(error: e),
        data: (cropDesc) => _buildSiteAndCropContent(trial, config, cropDesc),
      ),
    );
  }

  Widget _buildSiteAndCropContent(
    Trial trial,
    WorkspaceConfig config,
    CropDescription? cropDesc,
  ) {
    String _fmtDate(DateTime? dt) =>
        dt == null ? '—' : DateFormat('d MMM yyyy').format(dt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldRow(label: 'Crop', value: trial.crop ?? '—'),
        _FieldRow(
          label: 'Variety',
          value: cropDesc?.varietyOrHybrid ?? trial.cultivar ?? '—',
        ),
        _FieldRow(label: 'Sown', value: _fmtDate(cropDesc?.plantingDate)),
        _FieldRow(label: 'Emerged', value: _fmtDate(cropDesc?.emergenceDate)),
        _FieldRow(label: 'Location', value: trial.location ?? '—'),
        _FieldRow(
          label: 'Design',
          value: trial.experimentalDesign ?? '—',
        ),
        if (config.isProtocol) ...[
          const _SectionDivider(),
          _FieldRow(label: 'Protocol', value: trial.protocolNumber ?? '—'),
          _FieldRow(
            label: 'Investigator',
            value: trial.investigatorName ?? '—',
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Section 2 — Applications
  // -------------------------------------------------------------------------

  Widget _buildSection2(Trial trial) {
    final bundlesAsync = ref.watch(_trialAppBundlesProvider(trial.id));
    return _SectionCard(
      title: '2. Applications',
      child: bundlesAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(error: e),
        data: (bundles) {
          if (bundles.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No applications recorded.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < bundles.length; i++) ...[
                if (i > 0) const _SectionDivider(),
                _buildAppBundle(bundles[i]),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBundle(_AppBundle bundle) {
    final event = bundle.event;
    final dateStr = DateFormat('d MMM yyyy').format(event.applicationDate);
    final hasDeviation =
        bundle.products.any((p) => p.deviationFlag == true);
    final statusStr =
        '${event.status[0].toUpperCase()}${event.status.substring(1)}';
    final bbch = event.growthStageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              dateStr,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.primaryText,
              ),
            ),
            if (bbch != null) ...[
              const SizedBox(width: 8),
              Text(
                'BBCH $bbch',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
            ],
            const Spacer(),
            Text(
              statusStr,
              style: TextStyle(
                fontSize: 12,
                color: hasDeviation
                    ? AppDesignTokens.warningFg
                    : AppDesignTokens.secondaryText,
                fontWeight:
                    hasDeviation ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final p in bundle.products)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              _productLine(p),
              style: const TextStyle(
                fontSize: 12,
                color: AppDesignTokens.primaryText,
              ),
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '${bundle.plotCount} plot${bundle.plotCount == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 12,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            if (bundle.weather != null) ...[
              const SizedBox(width: 12),
              Text(
                _weatherSummary(bundle.weather!),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
            ],
          ],
        ),
        if (hasDeviation)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              'Rate deviation recorded',
              style: TextStyle(
                fontSize: 11,
                color: AppDesignTokens.warningFg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  String _productLine(TrialApplicationProduct p) {
    final parts = [
      p.productName,
      if (p.rate != null) '${_fmtNum(p.rate!)} ${p.rateUnit ?? ''}'.trim(),
    ];
    return parts.join(' — ');
  }

  // -------------------------------------------------------------------------
  // Section 3 — Assessment quality
  // -------------------------------------------------------------------------

  Widget _buildSection3(Trial trial) {
    final analysisAsync = ref.watch(_trialAnalysisDataProvider(trial.id));
    return _SectionCard(
      title: '3. Assessment quality',
      child: analysisAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(error: e),
        data: (data) => _buildQualityContent(data),
      ),
    );
  }

  Widget _buildQualityContent(_AnalysisData data) {
    final totalSessions = data.allSessions.length;
    final closedCount = data.closedSessions.length;
    final openCount = totalSessions - closedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GroupHeader(label: 'SESSIONS'),
        _FieldRow(label: 'Total', value: '$totalSessions'),
        _FieldRow(label: 'Closed', value: '$closedCount'),
        if (openCount > 0)
          _FieldRow(label: 'Open', value: '$openCount'),
        const _SectionDivider(),
        _GroupHeader(label: 'AMENDMENTS'),
        _FieldRow(
          label: 'Amended',
          value: data.amendedRatings.isEmpty
              ? 'None'
              : '${data.amendedRatings.length} rating${data.amendedRatings.length == 1 ? '' : 's'}',
        ),
        const _SectionDivider(),
        _GroupHeader(label: 'EXCLUDED PLOTS'),
        if (data.excludedPlots.isEmpty)
          const _FieldRow(label: 'Count', value: '0')
        else
          _FieldRow(
            label: 'Count',
            value: data.excludedPlots.length.toString(),
          ),
        const _SectionDivider(),
        _GroupHeader(label: 'OUTLIER CANDIDATES'),
        _FieldRow(
          label: '>2 SD',
          value: data.outlierCandidates.isEmpty
              ? 'None'
              : '${data.outlierCandidates.length} rating${data.outlierCandidates.length == 1 ? '' : 's'}',
        ),
        const _SectionDivider(),
        _GroupHeader(label: 'ATTRIBUTION'),
        _FieldRow(
          label: 'Unattributed',
          value: data.unattributedRatings.isEmpty
              ? 'None'
              : '${data.unattributedRatings.length} rating${data.unattributedRatings.length == 1 ? '' : 's'}',
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Section 4 — Results
  // -------------------------------------------------------------------------

  Widget _buildSection4(Trial trial) {
    final analysisAsync = ref.watch(_trialAnalysisDataProvider(trial.id));
    return _SectionCard(
      title: '4. Results',
      child: analysisAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(error: e),
        data: (data) => _buildResultsContent(data),
      ),
    );
  }

  Widget _buildResultsContent(_AnalysisData data) {
    if (data.closedSessions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No closed sessions.',
          style: TextStyle(fontSize: 13, color: AppDesignTokens.secondaryText),
        ),
      );
    }
    if (data.assessmentOrder.isEmpty || data.treatments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No results to display.',
          style: TextStyle(fontSize: 13, color: AppDesignTokens.secondaryText),
        ),
      );
    }

    // Only show assessments that have at least one result
    final visibleAssessments = data.assessmentOrder
        .where((aid) => data.treatmentResults.values.any((m) => m.containsKey(aid)))
        .toList();

    if (visibleAssessments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No numeric results in closed sessions.',
          style: TextStyle(fontSize: 13, color: AppDesignTokens.secondaryText),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResultsHeader(data, visibleAssessments),
          for (final treatment in data.treatments)
            _buildTreatmentRow(data, treatment, visibleAssessments),
        ],
      ),
    );
  }

  Widget _buildResultsHeader(_AnalysisData data, List<int> assessmentIds) {
    return Row(
      children: [
        SizedBox(
          width: _kTreatColWidth,
          child: Text(
            'Treatment',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.secondaryText,
            ),
          ),
        ),
        for (final aid in assessmentIds)
          SizedBox(
            width: _kAssessColWidth,
            child: Text(
              data.assessmentDisplayNames[aid] ?? 'A$aid',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.secondaryText,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTreatmentRow(
    _AnalysisData data,
    Treatment treatment,
    List<int> assessmentIds,
  ) {
    final isExpanded = _expandedTreatmentIds.contains(treatment.id);
    final treatmentCells = data.treatmentResults[treatment.id] ?? {};
    final closedBySession = <int, Map<int, List<double>>>{};
    for (final r in data.closedRatings) {
      if (!r.isCurrent || r.isDeleted) continue;
      if (r.resultStatus != 'RECORDED' || r.numericValue == null) continue;
      final tid = data.plotTreatmentMap[r.plotPk];
      if (tid != treatment.id) continue;
      closedBySession
          .putIfAbsent(r.sessionId, () => {})
          .putIfAbsent(r.assessmentId, () => [])
          .add(r.numericValue!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: AppDesignTokens.borderCrisp),
        InkWell(
          onTap: () => setState(() {
            if (isExpanded) {
              _expandedTreatmentIds.remove(treatment.id);
            } else {
              _expandedTreatmentIds.add(treatment.id);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: _kTreatColWidth,
                  child: Row(
                    children: [
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 14,
                        color: AppDesignTokens.secondaryText,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${treatment.code} ${treatment.name}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppDesignTokens.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final aid in assessmentIds)
                  _buildResultCell(
                    data: data,
                    treatment: treatment,
                    assessmentId: aid,
                    cellData: treatmentCells[aid],
                  ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          _buildSessionExpansion(data, treatment, assessmentIds, closedBySession),
      ],
    );
  }

  Widget _buildResultCell({
    required _AnalysisData data,
    required Treatment treatment,
    required int assessmentId,
    required TreatmentCellData? cellData,
  }) {
    if (cellData == null) {
      return SizedBox(
        width: _kAssessColWidth,
        child: const Text(
          '—',
          style: TextStyle(fontSize: 13, color: AppDesignTokens.secondaryText),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showCellDetail(
        context,
        treatment: treatment,
        assessmentId: assessmentId,
        cellData: cellData,
        assessmentName: data.assessmentDisplayNames[assessmentId] ?? 'A$assessmentId',
      ),
      child: SizedBox(
        width: _kAssessColWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _fmtNum(cellData.mean),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppDesignTokens.primaryText,
              ),
            ),
            Text(
              'n=${cellData.n}${cellData.cv != null ? '  CV ${cellData.cv!.toStringAsFixed(1)}%' : ''}',
              style: const TextStyle(
                fontSize: 10,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            if (cellData.separation != null)
              Text(
                _fmtSeparation(cellData.separation!),
                style: TextStyle(
                  fontSize: 10,
                  color: cellData.separation! >= 0
                      ? AppDesignTokens.appliedColor
                      : AppDesignTokens.missedColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionExpansion(
    _AnalysisData data,
    Treatment treatment,
    List<int> assessmentIds,
    Map<int, Map<int, List<double>>> closedBySession,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppDesignTokens.sectionHeaderBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final session in data.closedSessions) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: _kTreatColWidth - 18,
                    child: Text(
                      _sessionLabel(session),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppDesignTokens.secondaryText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (final aid in assessmentIds)
                    SizedBox(
                      width: _kAssessColWidth,
                      child: Builder(builder: (_) {
                        final vals =
                            closedBySession[session.id]?[aid] ?? [];
                        if (vals.isEmpty) {
                          return const Text(
                            '—',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppDesignTokens.secondaryText,
                            ),
                          );
                        }
                        final mean =
                            vals.reduce((a, b) => a + b) / vals.length;
                        return Text(
                          _fmtNum(mean),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppDesignTokens.primaryText,
                          ),
                        );
                      }),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCellDetail(
    BuildContext context, {
    required Treatment treatment,
    required int assessmentId,
    required TreatmentCellData cellData,
    required String assessmentName,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppDesignTokens.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              assessmentName,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.secondaryText,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${treatment.code} ${treatment.name}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.primaryText,
              ),
            ),
            const SizedBox(height: 16),
            _DetailRow(label: 'Mean', value: _fmtNum(cellData.mean)),
            _DetailRow(label: 'n', value: cellData.n.toString()),
            if (cellData.cv != null)
              _DetailRow(
                  label: 'CV', value: '${cellData.cv!.toStringAsFixed(1)}%'),
            if (cellData.separation != null)
              _DetailRow(
                label: 'vs check',
                value: _fmtSeparation(cellData.separation!),
              ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Section 5 — Weather
  // -------------------------------------------------------------------------

  Widget _buildSection5(Trial trial) {
    final sessionsAsync = ref.watch(sessionsForTrialProvider(trial.id));
    final snapshotsAsync = ref.watch(weatherSnapshotsForTrialProvider(trial.id));
    return _SectionCard(
      title: '5. Weather',
      child: sessionsAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(error: e),
        data: (sessions) => snapshotsAsync.when(
          loading: () => const AppLoadingView(),
          error: (e, _) => AppErrorView(error: e),
          data: (snapshots) {
            final closed = sessions
                .where((s) => s.status == kSessionStatusClosed)
                .toList();
            if (closed.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No closed sessions.',
                  style: TextStyle(
                      fontSize: 13, color: AppDesignTokens.secondaryText),
                ),
              );
            }
            if (snapshots.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Weather not recorded for this trial.',
                  style: TextStyle(
                      fontSize: 13, color: AppDesignTokens.secondaryText),
                ),
              );
            }
            final snapshotBySession = <int, WeatherSnapshot>{
              for (final s in snapshots) s.parentId: s,
            };
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < closed.length; i++) ...[
                  if (i > 0) const _SectionDivider(),
                  _buildWeatherRow(
                    closed[i],
                    snapshotBySession[closed[i].id],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWeatherRow(Session session, WeatherSnapshot? snapshot) {
    final headerLine = '${session.name} · ${_sessionLabel(session)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headerLine,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppDesignTokens.primaryText,
          ),
        ),
        const SizedBox(height: 2),
        if (snapshot == null)
          const Text(
            'Weather not recorded',
            style: TextStyle(fontSize: 12, color: AppDesignTokens.secondaryText),
          )
        else ...[
          _buildWeatherMainLine(snapshot),
          if (snapshot.humidity != null)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                '${snapshot.humidity!.toStringAsFixed(0)}% humidity',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
            ),
          if (_hasWeatherExtras(snapshot))
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                _formatWeatherExtras(snapshot),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildWeatherMainLine(WeatherSnapshot w) {
    final line = formatWeatherMainLine(w);
    if (line.isEmpty) {
      return const Text(
        'Weather recorded',
        style: TextStyle(fontSize: 12, color: AppDesignTokens.secondaryText),
      );
    }
    return Text(
      line,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppDesignTokens.primaryText,
      ),
    );
  }

  static bool _hasWeatherExtras(WeatherSnapshot w) =>
      (w.soilCondition != null && w.soilCondition!.isNotEmpty) ||
      (w.notes != null && w.notes!.isNotEmpty);

  static String _formatWeatherExtras(WeatherSnapshot w) {
    final parts = <String>[];
    if (w.soilCondition != null && w.soilCondition!.isNotEmpty) {
      parts.add(w.soilCondition!);
    }
    if (w.notes != null && w.notes!.isNotEmpty) parts.add(w.notes!);
    return parts.join(' · ');
  }

  // -------------------------------------------------------------------------
  // Section 6 — Observations
  // -------------------------------------------------------------------------

  Widget _buildSection6(Trial trial) {
    final insightsAsync = ref.watch(trialInsightsProvider(trial.id));
    return _SectionCard(
      title: '6. Observations',
      child: insightsAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(error: e),
        data: (insights) {
          final visible = insights
              .where((i) => i.basis.minimumDataMet)
              .toList()
            ..sort((a, b) {
              final sc = b.severity.index.compareTo(a.severity.index);
              if (sc != 0) return sc;
              return a.title.compareTo(b.title);
            });
          if (visible.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No observations — minimum data not yet met.',
                style: TextStyle(
                    fontSize: 13, color: AppDesignTokens.secondaryText),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < visible.length; i++) ...[
                if (i > 0) const _SectionDivider(),
                InsightRow(insight: visible[i]),
              ],
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Footer — What this is based on
  // -------------------------------------------------------------------------

  Widget _buildFooter(Trial trial, WorkspaceConfig config) {
    final analysisAsync = ref.watch(_trialAnalysisDataProvider(trial.id));
    final snapshotsAsync = ref.watch(weatherSnapshotsForTrialProvider(trial.id));

    return _SectionCard(
      title: 'What this is based on',
      isCollapsible: true,
      expanded: _footerExpanded,
      onToggle: () => setState(() => _footerExpanded = !_footerExpanded),
      child: analysisAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(error: e),
        data: (data) => snapshotsAsync.when(
          loading: () => const AppLoadingView(),
          error: (e, _) => AppErrorView(error: e),
          data: (snapshots) => _buildFooterContent(
            trial: trial,
            config: config,
            data: data,
            snapshots: snapshots,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterContent({
    required Trial trial,
    required WorkspaceConfig config,
    required _AnalysisData data,
    required List<WeatherSnapshot> snapshots,
  }) {
    final checks = data.treatments.where(isCheckTreatment).toList();
    final weatherGaps = TrialDataComputer.findWeatherGaps(
      closedSessions: data.closedSessions,
      snapshots: snapshots,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GroupHeader(label: 'CHECK IDENTIFICATION'),
        if (checks.isEmpty)
          const _FieldRow(label: 'Check', value: 'None identified')
        else
          for (final t in checks)
            _FieldRow(label: t.code, value: t.name),
        const _SectionDivider(),
        _GroupHeader(label: 'COUNTS'),
        _FieldRow(
          label: 'Sessions',
          value:
              '${data.closedSessions.length} closed of ${data.allSessions.length}',
        ),
        _FieldRow(
          label: 'Ratings',
          value: '${data.closedRatings.length}',
        ),
        _FieldRow(
          label: 'Analyzable plots',
          value: '${data.analyzablePlots.length}',
        ),
        if (data.excludedPlots.isNotEmpty) ...[
          const _SectionDivider(),
          _GroupHeader(label: 'EXCLUDED PLOTS'),
          for (final p in data.excludedPlots)
            _FieldRow(label: p.plotId, value: 'Excluded from analysis'),
        ],
        if (weatherGaps.isNotEmpty) ...[
          const _SectionDivider(),
          _GroupHeader(label: 'WEATHER GAPS'),
          for (final s in weatherGaps)
            _FieldRow(
              label: _sessionLabel(s),
              value: 'No weather recorded',
            ),
        ],
        if (config.isProtocol) ...[
          const _SectionDivider(),
          _GroupHeader(label: 'PROTOCOL'),
          _FieldRow(
            label: 'Mode',
            value: config.isGlp ? 'GLP' : 'GEP',
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Formatting helpers
  // -------------------------------------------------------------------------

  static String _fmtNum(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  static String _fmtSeparation(double v) {
    final s = _fmtNum(v.abs());
    return v >= 0 ? '+$s' : '-$s';
  }

  static String _weatherSummary(_AppWeather w) {
    final parts = <String>[];
    if (w.temperature != null) {
      parts.add('${w.temperature!.toStringAsFixed(1)} °${w.temperatureUnit}');
    }
    if (w.precipitation != null && w.precipitation!.isNotEmpty) {
      parts.add(w.precipitation!);
    }
    return parts.isEmpty ? 'Weather recorded' : parts.join('  ');
  }

  static String _sessionLabel(Session s) {
    final parsed = DateTime.tryParse(s.sessionDateLocal);
    if (parsed != null) return DateFormat('d MMM').format(parsed);
    return s.sessionDateLocal;
  }
}

// ---------------------------------------------------------------------------
// Private helper widgets
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.isCollapsible = false,
    this.expanded = true,
    this.onToggle,
  });

  final String title;
  final Widget child;
  final bool isCollapsible;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppDesignTokens.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        side: const BorderSide(color: AppDesignTokens.borderCrisp),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isCollapsible
              ? InkWell(
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppDesignTokens.primaryText,
                            ),
                          ),
                        ),
                        Icon(
                          expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                          color: AppDesignTokens.secondaryText,
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.primaryText,
                    ),
                  ),
                ),
          if (!isCollapsible || expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppDesignTokens.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppDesignTokens.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: AppDesignTokens.secondaryText.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, color: AppDesignTokens.borderCrisp),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppDesignTokens.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppDesignTokens.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
