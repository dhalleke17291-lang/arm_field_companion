import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/widgets/loading_error_widgets.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';
import '../../../core/session_state.dart';
import '../../../core/trial_state.dart';
import '../../diagnostics/trial_readiness.dart';

/// Trial-level rating coverage; null when loading, error, or no plots.
String? _ratedPlotsProgressLine(
  AsyncValue<List<Plot>> plotsAsync,
  AsyncValue<int> ratedAsync,
) {
  final plots = plotsAsync.valueOrNull;
  final rated = ratedAsync.valueOrNull;
  if (plots == null || rated == null) return null;
  final dataCount = plots.where((p) => !p.isGuardRow).length;
  if (dataCount == 0) return null;
  final excluded = plots
      .where((p) => !p.isGuardRow && p.excludeFromAnalysis == true)
      .length;
  final suffix = excluded > 0 ? ' · $excluded excluded' : '';
  return 'Rated plots $rated/$dataCount$suffix';
}

/// Readiness checklist line; null when loading/error, no issues, or fully ready (line hidden).
String? _readinessSummaryLine(AsyncValue<TrialReadinessReport> readinessAsync) {
  return readinessAsync.maybeWhen(
    data: (report) {
      if (report.blockerCount > 0) {
        final n = report.blockerCount;
        return n == 1
            ? '1 blocker before ready'
            : '$n blockers before ready';
      }
      if (report.warningCount > 0) {
        final n = report.warningCount;
        return n == 1
            ? '1 warning'
            : '$n warnings';
      }
      return null;
    },
    orElse: () => null,
  );
}

String _trialStatusDisplay(String statusLower) {
  switch (statusLower) {
    case 'active':
    case 'draft':
    case 'ready':
      return 'Active';
    case 'closed':
      return 'Closed';
    case 'archived':
      return 'Archived';
    default:
      return statusLower.isNotEmpty
          ? statusLower[0].toUpperCase() + statusLower.substring(1)
          : '';
  }
}

/// Shared trial card for Custom Trials and Protocol Trials lists.
/// Restored from git d8a563e (2026-03-21 20:05) _CompactTrialRow layout.
/// Trial card: index, name, status, metadata, primary action only.
/// Guidance (Next Steps) is shown in the list header, not on cards.
class TrialCard extends ConsumerWidget {
  const TrialCard({
    super.key,
    required this.trial,
    required this.index,
    required this.totalCount,
    required this.onTap,
    required this.onQuickRate,
    this.attentionSummary,
  });

  final Trial trial;
  final int index;
  final int totalCount;
  final VoidCallback onTap;
  final VoidCallback onQuickRate;
  /// Most urgent HIGH attention line for active trials; null hides the row.
  final String? attentionSummary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final openSession = ref.watch(openSessionProvider(trial.id)).valueOrNull;
    final hasOpenFieldSession = openSession != null &&
        isSessionOpenForFieldWork(openSession);
    final displayStatus = effectiveTrialStatusForListDisplay(
      trialStatus: trial.status,
      hasOpenFieldSession: hasOpenFieldSession,
    );
    final statusLower = displayStatus.toLowerCase();
    final isActive = statusLower == 'active';
    final isDraft = statusLower == 'draft';
    final badgeFg = isActive
        ? const Color(0xFF3D7A57)
        : isDraft
            ? const Color(0xFFC97A0A)
            : const Color(0xFF2563EB);

    final cropLoc = <String>[
      if (trial.crop != null && trial.crop!.isNotEmpty) trial.crop!,
      if (trial.location != null && trial.location!.isNotEmpty) trial.location!,
    ].join(' • ');
    final hasMetadata = cropLoc.isNotEmpty;
    final indexStr = index.toString().padLeft(2, '0');
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final ratedAsync = ref.watch(ratedPlotsCountForTrialProvider(trial.id));
    final ratedProgressLine = _ratedPlotsProgressLine(plotsAsync, ratedAsync);
    final readinessAsync = ref.watch(trialReadinessProvider(trial.id));
    final readinessLine = _readinessSummaryLine(readinessAsync);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 18,
              right: 18,
              top: 14,
              bottom: 14,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        indexStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: colorScheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _ReadinessDot(readinessAsync: readinessAsync),
                    const SizedBox(width: 6),
                    if (_trialStatusDisplay(statusLower).isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _trialStatusDisplay(statusLower),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: badgeFg,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  trial.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    letterSpacing: 0.3,
                    height: 1.35,
                  ),
                ),
                if (hasMetadata) ...[
                  const SizedBox(height: 6),
                  Text(
                    cropLoc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                      height: 1.4,
                    ),
                  ),
                ],
                if (ratedProgressLine != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    ratedProgressLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.45,
                      ),
                      height: 1.35,
                    ),
                  ),
                ],
                if (readinessLine != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    readinessLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.42,
                      ),
                      height: 1.35,
                    ),
                  ),
                ],
                if (attentionSummary != null) ...[
                  const SizedBox(height: AppDesignTokens.spacing8),
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 13,
                        color: AppDesignTokens.warningFg,
                      ),
                      const SizedBox(width: AppDesignTokens.spacing4),
                      Expanded(
                        child: Text(
                          attentionSummary!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppDesignTokens.warningFg,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                _TrialQuickActions(
                    trial: trial,
                    onQuickRate: onQuickRate,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrialQuickActions extends ConsumerWidget {
  const _TrialQuickActions({
    required this.trial,
    required this.onQuickRate,
  });

  final Trial trial;
  final VoidCallback onQuickRate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openSessionAsync = ref.watch(openSessionProvider(trial.id));

    return openSessionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, __) => AppErrorHint(error: e),
      data: (openSession) {
        final hasOpenSession = openSession != null;
        if (hasOpenSession) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
              TextButton.icon(
                onPressed: onQuickRate,
                icon: const Icon(Icons.flash_on, size: 14),
                label: const Text(
                  'Quick Rate',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(left: 0, right: 8, top: 4, bottom: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Small colored dot indicating export readiness at a glance.
/// Green = ready, amber = warnings, red = blockers, hidden while loading.
class _ReadinessDot extends StatelessWidget {
  const _ReadinessDot({required this.readinessAsync});

  final AsyncValue<TrialReadinessReport> readinessAsync;

  @override
  Widget build(BuildContext context) {
    return readinessAsync.maybeWhen(
      data: (report) {
        final Color color;
        final String tooltip;
        switch (report.status) {
          case TrialReadinessStatus.notReady:
            color = AppDesignTokens.missedColor;
            tooltip = '${report.blockerCount} blocker${report.blockerCount == 1 ? '' : 's'}';
          case TrialReadinessStatus.readyWithWarnings:
            color = AppDesignTokens.flagColor;
            tooltip = '${report.warningCount} warning${report.warningCount == 1 ? '' : 's'}';
          case TrialReadinessStatus.ready:
            color = AppDesignTokens.successFg;
            tooltip = 'Export ready';
        }
        return Tooltip(
          message: tooltip,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

