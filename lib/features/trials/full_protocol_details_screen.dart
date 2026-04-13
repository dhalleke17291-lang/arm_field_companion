import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/trial_state.dart';
import '../../core/providers.dart';
import '../../core/ui/assessment_display_helper.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../../core/widgets/loading_error_widgets.dart';

/// Read-only drill-down showing full trial protocol: trial info, treatments,
/// assessments, plots count, and assignment summary.
class FullProtocolDetailsScreen extends ConsumerWidget {
  final Trial trial;

  const FullProtocolDetailsScreen({super.key, required this.trial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treatmentsAsync = ref.watch(treatmentsForTrialProvider(trial.id));
    final assessmentsAsync = ref.watch(
        trialAssessmentsWithDefinitionsForTrialProvider(trial.id));
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final assignmentsAsync = ref.watch(assignmentsForTrialProvider(trial.id));

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: const GradientScreenHeader(title: 'Full Protocol'),
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.all(AppDesignTokens.spacing16),
        children: [
          _Section(
            title: 'Trial',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Row('Name', trial.name),
                _Row('Status', labelForTrialStatus(trial.status)),
                if (trial.crop != null) _Row('Crop', trial.crop!),
                if (trial.location != null && trial.location!.isNotEmpty)
                  _Row('Location', trial.location!),
                if (trial.season != null && trial.season!.isNotEmpty)
                  _Row('Season', trial.season!),
                if (trial.plotDimensions != null)
                  _Row('Plot dimensions', trial.plotDimensions!),
                if (trial.plotRows != null)
                  _Row('Number of ranges', trial.plotRows.toString()),
                if (trial.plotSpacing != null)
                  _Row('Plot spacing', trial.plotSpacing!),
              ],
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing16),
          treatmentsAsync.when(
            loading: () =>
                const _Section(title: 'Treatments', child: AppLoadingView()),
            error: (e, _) => _Section(
                title: 'Treatments',
                child: Text('Error: $e',
                    style: const TextStyle(color: Colors.red))),
            data: (list) => _Section(
              title: 'Treatments (${list.length})',
              child: list.isEmpty
                  ? const Text('None',
                      style: TextStyle(
                          color: AppDesignTokens.secondaryText, fontSize: 14))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: list
                          .map((t) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text('${t.code} — ${t.name}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: AppDesignTokens.primaryText)),
                              ))
                          .toList(),
                    ),
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing16),
          assessmentsAsync.when(
            loading: () =>
                const _Section(title: 'Assessments', child: AppLoadingView()),
            error: (e, _) => _Section(
                title: 'Assessments',
                child: Text('Error: $e',
                    style: const TextStyle(color: Colors.red))),
            data: (list) => _Section(
              title: 'Assessments (${list.length})',
              child: list.isEmpty
                  ? const Text('None',
                      style: TextStyle(
                          color: AppDesignTokens.secondaryText, fontSize: 14))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: list.map((pair) {
                        final ta = pair.$1;
                        final def = pair.$2;
                        final dateShort =
                            AssessmentDisplayHelper.ratingDateShort(ta);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  AssessmentDisplayHelper.fullName(ta,
                                      def: def),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: AppDesignTokens.primaryText),
                                ),
                              ),
                              if (dateShort != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  dateShort,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppDesignTokens.secondaryText,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing16),
          plotsAsync.when(
            loading: () =>
                const _Section(title: 'Plots', child: AppLoadingView()),
            error: (e, _) => _Section(
                title: 'Plots',
                child: Text('Error: $e',
                    style: const TextStyle(color: Colors.red))),
            data: (plots) {
              final assignments = assignmentsAsync.valueOrNull;
              final assignmentByPlot = assignments != null
                  ? {for (var a in assignments) a.plotId: a.treatmentId}
                  : <int, int?>{};
              final assignedCount = assignments != null
                  ? plots
                      .where((p) =>
                          (assignmentByPlot[p.id] ?? p.treatmentId) != null)
                      .length
                  : null;
              return _Section(
                title: 'Plots',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${plots.length} plots',
                        style: const TextStyle(
                            fontSize: 14, color: AppDesignTokens.primaryText)),
                    if (assignedCount != null) ...[
                      const SizedBox(height: 4),
                      Text('$assignedCount assigned',
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppDesignTokens.secondaryText)),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesignTokens.spacing12),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing8),
          child,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppDesignTokens.secondaryText)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 14, color: AppDesignTokens.primaryText))),
        ],
      ),
    );
  }
}
