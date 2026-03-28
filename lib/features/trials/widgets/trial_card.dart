import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';
import '../../../core/session_state.dart';
import '../../../core/trial_state.dart';

String _trialStatusDisplay(String statusLower) {
  switch (statusLower) {
    case 'active':
      return 'Active';
    case 'draft':
      return 'Draft';
    case 'closed':
    case 'archived':
      return 'Ready';
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
    required this.onContinueSession,
    required this.onQuickRate,
    this.attentionSummary,
  });

  final Trial trial;
  final int index;
  final int totalCount;
  final VoidCallback onTap;
  final void Function(Session session) onContinueSession;
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
                    onContinueSession: onContinueSession,
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
    required this.onContinueSession,
    required this.onQuickRate,
  });

  final Trial trial;
  final void Function(Session session) onContinueSession;
  final VoidCallback onQuickRate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openSessionAsync = ref.watch(openSessionProvider(trial.id));

    return openSessionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (openSession) {
        final hasOpenSession = openSession != null;
        final colorScheme = Theme.of(context).colorScheme;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasOpenSession)
              TextButton(
                onPressed: () => onContinueSession(openSession),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  padding: const EdgeInsets.only(left: 0, right: 8, top: 4, bottom: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Continue Session',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.primary,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            if (!hasOpenSession)
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

