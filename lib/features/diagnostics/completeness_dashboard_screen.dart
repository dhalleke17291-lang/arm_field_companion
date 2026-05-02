import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../../core/database/app_database.dart';
import 'trial_readiness.dart';

/// Groups readiness check codes into dashboard sections.
const _sectionGroups = <String, List<String>>{
  'Site Details': [
    'site_details_ok',
    'site_details_incomplete',
    'no_photos',
    'photos_ok',
  ],
  'Establishment': [
    'seeding_ok',
    'no_seeding',
    'seeding_pending',
  ],
  'Ratings': [
    'sessions_ok',
    'no_sessions',
    'ratings_ok',
    'no_ratings',
    'all_rated_ok',
    'unrated_plots',
    'all_assessments_complete',
    'bbch_ok',
    'bbch_missing',
    'crop_injury_ok',
    'crop_injury_missing',
  ],
  'Applications': [
    'applications_ok',
    'no_applications',
    'applications_complete_ok',
    'incomplete_application',
    'sessions_after_app_ok',
    'session_before_application',
  ],
  'Data Quality': [
    'corrections_missing_reason',
    'components_ok',
    'missing_components',
    'assessments_used_ok',
    'unused_assessment',
  ],
};

/// Trial-level completeness dashboard. Shows all readiness checks
/// grouped by category with traffic-light status at the top.
/// Accessible from the trial overview or triggered before export.
class CompletenessDashboardScreen extends ConsumerWidget {
  const CompletenessDashboardScreen({
    super.key,
    required this.trial,
  });

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(trialReadinessProvider(trial.id));

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: GradientScreenHeader(
        title: 'Trial Readiness',
        subtitle: trial.name,
        titleFontSize: 17,
      ),
      body: SafeArea(
        top: false,
        child: reportAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (report) => _buildBody(context, report),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, TrialReadinessReport report) {
    final statusColor = switch (report.status) {
      TrialReadinessStatus.ready => AppDesignTokens.successFg,
      TrialReadinessStatus.readyWithWarnings =>
        AppDesignTokens.warningFg,
      TrialReadinessStatus.notReady => const Color(0xFFCC3333),
    };
    final statusLabel = switch (report.status) {
      TrialReadinessStatus.ready => 'Ready to export',
      TrialReadinessStatus.readyWithWarnings =>
        'Ready with ${report.warningCount} ${report.warningCount == 1 ? 'warning' : 'warnings'}',
      TrialReadinessStatus.notReady =>
        '${report.blockerCount} blocker(s) — not ready',
    };

    // Group checks by section. Unmatched checks go to "Other".
    final grouped = <String, List<TrialReadinessCheck>>{};
    final matchedCodes = <String>{};
    for (final entry in _sectionGroups.entries) {
      final section = entry.key;
      final codes = entry.value.toSet();
      final matches = report.checks
          .where((c) =>
              codes.contains(c.code) ||
              codes.any((prefix) => c.code.startsWith(prefix)))
          .toList();
      if (matches.isNotEmpty) {
        grouped[section] = matches;
        matchedCodes.addAll(matches.map((c) => c.code));
      }
    }
    final unmatched =
        report.checks.where((c) => !matchedCodes.contains(c.code)).toList();
    if (unmatched.isNotEmpty) {
      grouped['Structure'] = unmatched;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing24,
      ),
      children: [
        // Traffic light
        Container(
          padding: const EdgeInsets.all(AppDesignTokens.spacing16),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.08),
            borderRadius:
                BorderRadius.circular(AppDesignTokens.radiusCard),
            border: Border.all(
                color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(
                report.status == TrialReadinessStatus.ready
                    ? Icons.check_circle
                    : report.status ==
                            TrialReadinessStatus.readyWithWarnings
                        ? Icons.warning_amber_rounded
                        : Icons.cancel,
                color: statusColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${report.passCount} passed · '
                      '${report.warningCount} ${report.warningCount == 1 ? 'warning' : 'warnings'} · '
                      '${report.blockerCount} ${report.blockerCount == 1 ? 'blocker' : 'blockers'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDesignTokens.spacing16),

        // Sections
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: AppDesignTokens.spacing8,
              bottom: AppDesignTokens.spacing4,
            ),
            child: Text(
              entry.key.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.secondaryText
                    .withValues(alpha: 0.7),
                letterSpacing: 0.8,
              ),
            ),
          ),
          ..._sectionRows(entry.value),
        ],
      ],
    );
  }

  /// Renders checks for one section:
  /// blockers and warnings flat (always visible),
  /// info and passed each in a collapsed ExpansionTile.
  List<Widget> _sectionRows(List<TrialReadinessCheck> checks) {
    final blockers = checks
        .where((c) => c.severity == TrialCheckSeverity.blocker)
        .toList();
    final warnings = checks
        .where((c) => c.severity == TrialCheckSeverity.warning)
        .toList();
    final infos = checks
        .where((c) => c.severity == TrialCheckSeverity.info)
        .toList();
    final passes = checks
        .where((c) => c.severity == TrialCheckSeverity.pass)
        .toList();

    return [
      for (final c in blockers) _CheckRow(check: c),
      for (final c in warnings) _CheckRow(check: c),
      if (infos.isNotEmpty)
        ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.info_outline,
            size: 16,
            color: AppDesignTokens.secondaryText,
          ),
          title: Text(
            '${infos.length} informational',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          children: infos.map((c) => _CheckRow(check: c)).toList(),
        ),
      if (passes.isNotEmpty)
        ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: AppDesignTokens.successFg,
          ),
          title: Text(
            '${passes.length} passed',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppDesignTokens.successFg,
            ),
          ),
          children: passes.map((c) => _CheckRow(check: c)).toList(),
        ),
    ];
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});
  final TrialReadinessCheck check;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (check.severity) {
      TrialCheckSeverity.pass => (Icons.check_circle, AppDesignTokens.successFg),
      TrialCheckSeverity.info => (Icons.info_outline, AppDesignTokens.secondaryText),
      TrialCheckSeverity.warning => (Icons.warning_amber_rounded, AppDesignTokens.warningFg),
      TrialCheckSeverity.blocker => (Icons.cancel, const Color(0xFFCC3333)),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: check.severity == TrialCheckSeverity.blocker
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
                if (check.detail != null)
                  Text(
                    check.detail!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppDesignTokens.secondaryText
                          .withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
