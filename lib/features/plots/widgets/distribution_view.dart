import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../models/plot_analysis_models.dart';
import '../providers/plot_analysis_providers.dart';
import '../utils/plot_analysis_utils.dart';
import 'analysis_banner.dart';
import 'distribution_painter.dart';

class DistributionView extends ConsumerStatefulWidget {
  const DistributionView({
    super.key,
    required this.trial,
    required this.sessions,
  });

  final Trial trial;
  final List<Session> sessions;

  @override
  ConsumerState<DistributionView> createState() => _DistributionViewState();
}

class _DistributionViewState extends ConsumerState<DistributionView> {
  int? _pickedSessionId;
  int? _pickedAssessmentId;

  int _resolveSessionId() {
    final ids = widget.sessions.map((s) => s.id).toSet();
    if (_pickedSessionId != null && ids.contains(_pickedSessionId)) {
      return _pickedSessionId!;
    }
    return widget.sessions.first.id;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sessions.isEmpty) {
      return const AppEmptyState(
        icon: Icons.bar_chart_outlined,
        title: 'No sessions yet',
        subtitle: 'Start a rating session to see distributions.',
      );
    }

    final sessionId = _resolveSessionId();
    final assessmentsAsync = ref.watch(sessionAssessmentsProvider(sessionId));

    return assessmentsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppDesignTokens.primary),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (assessments) {
        if (assessments.isEmpty) {
          return const AppEmptyState(
            icon: Icons.bar_chart_outlined,
            title: 'No assessments',
            subtitle: 'This session has no numeric assessments.',
          );
        }

        final ids = assessments.map((a) => a.id).toSet();
        final resolvedAssessmentId =
            (_pickedAssessmentId != null && ids.contains(_pickedAssessmentId))
                ? _pickedAssessmentId!
                : assessments.first.id;

        final params = PlotAnalysisParams(
          trialId: widget.trial.id,
          sessionId: sessionId,
          assessmentId: resolvedAssessmentId,
        );
        final distAsync = ref.watch(plotDistributionProvider(params));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Session selector
            if (widget.sessions.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: DropdownButtonFormField<int>(
                  // ignore: deprecated_member_use
                  value: sessionId,
                  decoration: _dropdownDecoration('Session'),
                  items: widget.sessions
                      .map((s) => DropdownMenuItem<int>(
                            value: s.id,
                            child: Text(s.name, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    setState(() {
                      _pickedSessionId = id;
                      _pickedAssessmentId = null;
                    });
                  },
                ),
              ),
            // Assessment selector
            if (assessments.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: DropdownButtonFormField<int>(
                  // ignore: deprecated_member_use
                  value: resolvedAssessmentId,
                  decoration: _dropdownDecoration('Assessment'),
                  items: assessments
                      .map((a) => DropdownMenuItem<int>(
                            value: a.id,
                            child: Text(a.name,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    setState(() => _pickedAssessmentId = id);
                  },
                ),
              ),
            Expanded(
              child: distAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: AppDesignTokens.primary),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (result) => _buildBody(result),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(DistributionResult result) {
    if (result.treatments.isEmpty) {
      return const AppEmptyState(
        icon: Icons.bar_chart_outlined,
        title: 'No numeric ratings',
        subtitle:
            'Record numeric ratings in this session to see distributions.',
      );
    }

    final treatments = result.treatments;
    final colors = List.generate(
      treatments.length,
      (i) => AppDesignTokens
          .treatmentPalette[i % AppDesignTokens.treatmentPalette.length],
    );

    final pooledCv = result.pooledCv;
    final hasCv = pooledCv != null;
    final cvTier = hasCv ? getCVTier(pooledCv) : null;
    final zeroVar = detectZeroVariance(treatments.map((d) => d.sd).toList());
    final outlierCount = treatments.where((d) => d.hasOutliers).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banners
        if (hasCv && cvTier != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: AnalysisBanner(
              message: _cvMessage(pooledCv, cvTier),
              severity: switch (cvTier) {
                CVTier.acceptable => AnalysisBannerSeverity.info,
                CVTier.moderate => AnalysisBannerSeverity.warning,
                CVTier.high => AnalysisBannerSeverity.error,
              },
            ),
          ),
        if (zeroVar)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: AnalysisBanner(
              message:
                  'One or more treatments show zero variance — all plots rated identically.',
              severity: AnalysisBannerSeverity.warning,
            ),
          ),
        if (outlierCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: AnalysisBanner(
              message:
                  'Outliers detected in $outlierCount treatment${outlierCount == 1 ? '' : 's'} (Tukey IQR). '
                  'Check flagged plots.',
              severity: AnalysisBannerSeverity.warning,
            ),
          ),
        // Per-treatment dot strips
        Expanded(
          child: ListView(
            children: [
              for (var i = 0; i < treatments.length; i++)
                _buildTreatmentStrip(
                    treatments[i], colors[i % colors.length]),
            ],
          ),
        ),
        _buildAxisLabels(treatments.first),
      ],
    );
  }

  Widget _buildAxisLabels(TreatmentDistribution first) {
    final tickStep = (first.scaleMax - first.scaleMin) / 4;
    final ticks = List.generate(
      5,
      (i) => '${(first.scaleMin + tickStep * i).round()}%',
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Row(
        children: [
          const SizedBox(width: 56),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ticks
                  .map((t) => Text(
                        t,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppDesignTokens.secondaryText,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentStrip(TreatmentDistribution trt, Color color) {
    final outlierIndices = detectOutlierIndices(trt.values);
    final isOutlier = List.generate(
        trt.values.length, (i) => outlierIndices.contains(i));
    final repLabels =
        List.generate(trt.values.length, (i) => '${i + 1}');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trt.treatmentCode,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'n=${trt.n}  μ=${trt.mean.toStringAsFixed(1)}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 44,
              child: CustomPaint(
                painter: DistributionPainter(
                  values: List<double?>.from(trt.values),
                  isOutlier: isOutlier,
                  repLabels: repLabels,
                  mean: trt.mean,
                  treatmentColor: color,
                  scaleMin: trt.scaleMin,
                  scaleMax: trt.scaleMax,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _cvMessage(double cv, CVTier tier) {
    final cvStr = cv.toStringAsFixed(1);
    return switch (tier) {
      CVTier.acceptable =>
        'Pooled CV: $cvStr% — within acceptable range (<15%).',
      CVTier.moderate =>
        'Pooled CV: $cvStr% — moderate field variability (15–25%). Review outliers.',
      CVTier.high =>
        'Pooled CV: $cvStr% — high field variability (>25%). Results may be unreliable.',
    };
  }

  InputDecoration _dropdownDecoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0DDD6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0DDD6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppDesignTokens.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: Colors.white,
      );
}
