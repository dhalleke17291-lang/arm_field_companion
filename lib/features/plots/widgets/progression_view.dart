import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../models/plot_analysis_models.dart';
import '../providers/plot_analysis_providers.dart';
import 'analysis_banner.dart';
import 'progression_painter.dart';

class ProgressionView extends ConsumerStatefulWidget {
  const ProgressionView({
    super.key,
    required this.trial,
    required this.sessions,
  });

  final Trial trial;
  final List<Session> sessions;

  @override
  ConsumerState<ProgressionView> createState() => _ProgressionViewState();
}

class _ProgressionViewState extends ConsumerState<ProgressionView> {
  int? _pickedAssessmentId;

  @override
  Widget build(BuildContext context) {
    if (widget.sessions.isEmpty) {
      return const AppEmptyState(
        icon: Icons.show_chart,
        title: 'No sessions yet',
        subtitle: 'Start rating sessions to see progression across time.',
      );
    }

    // Use first session to get assessment list (shared across sessions for trial)
    final firstSessionId = widget.sessions.first.id;
    final assessmentsAsync =
        ref.watch(sessionAssessmentsProvider(firstSessionId));

    return assessmentsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppDesignTokens.primary),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (assessments) {
        if (assessments.isEmpty) {
          return const AppEmptyState(
            icon: Icons.show_chart,
            title: 'No assessments',
            subtitle: 'This trial has no numeric assessments yet.',
          );
        }

        final ids = assessments.map((a) => a.id).toSet();
        final resolvedAssessmentId =
            (_pickedAssessmentId != null && ids.contains(_pickedAssessmentId))
                ? _pickedAssessmentId!
                : assessments.first.id;
        final selectedAssessment =
            assessments.firstWhere((a) => a.id == resolvedAssessmentId);

        final params = PlotProgressionParams(
          trialId: widget.trial.id,
          assessmentId: resolvedAssessmentId,
        );
        final progressionAsync = ref.watch(plotProgressionProvider(params));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              child: progressionAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: AppDesignTokens.primary),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (result) => _buildBody(result, selectedAssessment),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(ProgressionResult result, Assessment selectedAssessment) {
    if (result.series.isEmpty) {
      return const AppEmptyState(
        icon: Icons.show_chart,
        title: 'No data yet',
        subtitle:
            'Record numeric ratings across multiple sessions to see progression.',
      );
    }

    final series = result.series;
    final hasSingleSession = result.sessionLabels.length == 1;
    final colors = List.generate(
      series.length,
      (i) => AppDesignTokens
          .treatmentPalette[i % AppDesignTokens.treatmentPalette.length],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasSingleSession)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: AnalysisBanner(
              message:
                  'Only one session has data — add more sessions to see progression trends.',
              severity: AnalysisBannerSeverity.info,
            ),
          ),
        // Assessment unit label
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Text(
            selectedAssessment.unit != null &&
                    selectedAssessment.unit!.trim().isNotEmpty
                ? '${selectedAssessment.name} (${selectedAssessment.unit})'
                : selectedAssessment.name,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.secondaryText,
              letterSpacing: 0.3,
            ),
          ),
        ),
        // Chart
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: CustomPaint(
              painter: ProgressionPainter(
                result: result,
                colors: colors,
              ),
            ),
          ),
        ),
        // Legend
        _buildLegend(series, colors),
      ],
    );
  }

  Widget _buildLegend(List<ProgressionSeries> series, List<Color> colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (var i = 0; i < series.length; i++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Solid line for regular, dashed indicator for CHK
                if (series[i].isCheck)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 1.5,
                          color: colors[i % colors.length]),
                      const SizedBox(width: 2),
                      Container(width: 3, height: 1.5,
                          color: colors[i % colors.length]
                              .withValues(alpha: 0.3)),
                    ],
                  )
                else
                  Container(
                    width: 10,
                    height: 2,
                    color: colors[i % colors.length],
                  ),
                const SizedBox(width: 4),
                Text(
                  series[i].treatmentCode,
                  style: TextStyle(
                    fontSize: 10,
                    color: colors[i % colors.length],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
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
