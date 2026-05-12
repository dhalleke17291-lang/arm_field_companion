import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_design_tokens.dart';
import '../../../domain/signals/signal_providers.dart';
import '../../trials/widgets/signal_action_sheet.dart';

class RatingBottomBar extends ConsumerWidget {
  const RatingBottomBar({
    super.key,
    required this.trialId,
    required this.sessionId,
    required this.isSaving,
    required this.editable,
    required this.canGoBack,
    required this.primaryLabel,
    required this.isVeryLast,
    required this.onSave,
    required this.onSaveAndNext,
    required this.onNavigatePrev,
    required this.onJumpToPlot,
    required this.onFlag,
  });

  final int trialId;
  final int sessionId;
  final bool isSaving;
  final bool editable;
  final bool canGoBack;
  final String primaryLabel;
  final bool isVeryLast;
  final VoidCallback onSave;
  final VoidCallback onSaveAndNext;
  final VoidCallback onNavigatePrev;
  final VoidCallback onJumpToPlot;
  final VoidCallback onFlag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openSignals = ref
            .watch(openSignalsForTrialProvider(trialId))
            .valueOrNull
            ?.where((s) => s.sessionId == sessionId)
            .toList() ??
        [];
    final hasSignals = openSignals.isNotEmpty;
    final hasCritical = openSignals.any((s) => s.severity == 'critical');

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        decoration: const BoxDecoration(
          color: AppDesignTokens.cardSurface,
          border: Border(top: BorderSide(color: AppDesignTokens.borderCrisp)),
          boxShadow: [
            BoxShadow(
              color: AppDesignTokens.shadowMedium,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed:
                          isSaving || !editable ? null : onSave,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppDesignTokens.primary,
                        side: const BorderSide(
                            color: AppDesignTokens.borderCrisp),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDesignTokens.spacing8),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed:
                          isSaving || !editable ? null : onSaveAndNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignTokens.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppDesignTokens.divider,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    primaryLabel,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    softWrap: false,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  isVeryLast
                                      ? Icons.check_circle_outline
                                      : Icons.arrow_forward,
                                  size: 18,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: canGoBack ? onNavigatePrev : null,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Prev', style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppDesignTokens.secondaryText,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onJumpToPlot,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Jump', style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppDesignTokens.secondaryText,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onFlag,
                    icon: const Icon(Icons.flag_outlined, size: 20),
                    tooltip: 'Flag plot',
                    style: IconButton.styleFrom(
                      foregroundColor: AppDesignTokens.secondaryText,
                    ),
                  ),
                  if (hasSignals) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        final signal = hasCritical
                            ? openSignals.firstWhere(
                                (s) => s.severity == 'critical')
                            : openSignals.first;
                        await showSignalActionSheet(
                          context,
                          signal: signal,
                          trialId: trialId,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppDesignTokens.warningBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: hasCritical
                                  ? AppDesignTokens.missedColor
                                  : AppDesignTokens.warningFg,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${openSignals.length} signal${openSignals.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: hasCritical
                                    ? AppDesignTokens.missedColor
                                    : AppDesignTokens.warningFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
