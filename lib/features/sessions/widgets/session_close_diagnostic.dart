import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';
import '../../../domain/signals/signal_models.dart';
import '../../../domain/signals/signal_providers.dart';
import '../../../domain/signals/signal_repository.dart';
import '../domain/session_close_attention_summary.dart';
import '../domain/session_close_policy_result.dart';

/// Bottom-sheet content surfaced before the researcher closes a session.
///
/// Shows evidence completeness rows (Section 1), a policy warning panel when
/// needed (Section 2), and open signals (Section 3). Fires [onAllClear]
/// immediately when nothing needs attention — no signals, all plots rated,
/// weather captured, and policy cleared. [onProceedAnyway] is always
/// available; nothing ever blocks close.
class SessionCloseDiagnostic extends ConsumerWidget {
  const SessionCloseDiagnostic({
    super.key,
    required this.sessionId,
    required this.trialId,
    required this.session,
    required this.attentionSummary,
    required this.weatherCaptured,
    required this.policyDecision,
    required this.onAllClear,
    required this.onProceedAnyway,
    required this.onWeatherCapture,
  });

  final int sessionId;
  final int trialId;
  final Session session;
  final SessionCloseAttentionSummary attentionSummary;
  final bool weatherCaptured;
  final SessionClosePolicyDecision policyDecision;
  final VoidCallback onAllClear;
  final VoidCallback onProceedAnyway;
  final VoidCallback onWeatherCapture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signalsAsync = ref.watch(openSignalsForSessionProvider(sessionId));

    return signalsAsync.when(
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      // Never block close on error.
      error: (_, __) => const SizedBox.shrink(),
      data: (allSignals) {
        final criticals = allSignals
            .where((s) => s.severity == SignalSeverity.critical.dbValue)
            .toList();
        final reviews = allSignals
            .where((s) => s.severity == SignalSeverity.review.dbValue)
            .toList();
        // Info signals are never surfaced at session close.

        final shown = [...criticals.take(1), ...reviews.take(3)];
        final hidden = [...criticals.skip(1), ...reviews.skip(3)];

        final allClear = shown.isEmpty &&
            attentionSummary.unratedPlots == 0 &&
            weatherCaptured &&
            policyDecision == SessionClosePolicyDecision.proceedToClose;

        if (allClear) {
          return _AutoAllClear(onAllClear: onAllClear);
        }

        return _DiagnosticSheet(
          session: session,
          attentionSummary: attentionSummary,
          weatherCaptured: weatherCaptured,
          policyDecision: policyDecision,
          signals: shown,
          hiddenCount: hidden.length,
          onReviewPlots: () => Navigator.of(context).pop(),
          onClose: () {
            logSessionCloseDeferEvents(
              repo: ref.read(signalRepositoryProvider),
              userId: ref.read(currentUserIdProvider).valueOrNull,
              shown: shown,
              hidden: hidden,
            );
            onProceedAnyway();
          },
          onWeatherCapture: onWeatherCapture,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Internal — auto-fire all-clear after first frame
// ---------------------------------------------------------------------------

class _AutoAllClear extends StatefulWidget {
  const _AutoAllClear({required this.onAllClear});

  final VoidCallback onAllClear;

  @override
  State<_AutoAllClear> createState() => _AutoAllClearState();
}

class _AutoAllClearState extends State<_AutoAllClear> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onAllClear();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ---------------------------------------------------------------------------
// Diagnostic sheet
// ---------------------------------------------------------------------------

class _DiagnosticSheet extends StatelessWidget {
  const _DiagnosticSheet({
    required this.session,
    required this.attentionSummary,
    required this.weatherCaptured,
    required this.policyDecision,
    required this.signals,
    required this.hiddenCount,
    required this.onReviewPlots,
    required this.onClose,
    required this.onWeatherCapture,
  });

  final Session session;
  final SessionCloseAttentionSummary attentionSummary;
  final bool weatherCaptured;
  final SessionClosePolicyDecision policyDecision;
  final List<Signal> signals;
  final int hiddenCount;
  final VoidCallback onReviewPlots;
  final VoidCallback onClose;
  final VoidCallback onWeatherCapture;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Before you leave',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppDesignTokens.primaryText,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'These items were noticed during this session.',
              style: TextStyle(
                fontSize: 13,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            const SizedBox(height: 16),
            // Section 1 — Evidence rows
            _EvidenceRow(
              label: attentionSummary.unratedPlots == 0
                  ? '${attentionSummary.ratedPlots}/${attentionSummary.totalPlots} plots rated'
                  : '${attentionSummary.unratedPlots} plots unrated',
              color: attentionSummary.unratedPlots == 0
                  ? AppDesignTokens.successFg
                  : AppDesignTokens.warningFg,
              icon: attentionSummary.unratedPlots == 0
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked,
            ),
            _EvidenceRow(
              label: weatherCaptured
                  ? 'Weather captured'
                  : 'Weather not captured — add before closing',
              color: weatherCaptured
                  ? AppDesignTokens.successFg
                  : AppDesignTokens.warningFg,
              icon: weatherCaptured
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked,
              onTap: weatherCaptured ? null : onWeatherCapture,
            ),
            _EvidenceRow(
              label: session.cropStageBbch != null
                  ? 'Growth stage recorded (BBCH ${session.cropStageBbch})'
                  : 'Growth stage (BBCH) not recorded',
              color: session.cropStageBbch != null
                  ? AppDesignTokens.successFg
                  : AppDesignTokens.warningFg,
              icon: session.cropStageBbch != null
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked,
            ),
            if (attentionSummary.editedPlots > 0)
              _EvidenceRow(
                label: '${attentionSummary.editedPlots} amended',
                color: AppDesignTokens.secondaryText,
                icon: Icons.edit_outlined,
              ),
            if (attentionSummary.flaggedPlots > 0)
              _EvidenceRow(
                label: '${attentionSummary.flaggedPlots} flagged',
                color: AppDesignTokens.flagColor,
                icon: Icons.flag_outlined,
              ),
            // Section 2 — Policy warning panel
            if (policyDecision == SessionClosePolicyDecision.warnBeforeClose) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppDesignTokens.warningBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Some items need attention before closing.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppDesignTokens.warningFg,
                  ),
                ),
              ),
            ],
            // Section 3 — Signals
            if (signals.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...signals.map((s) => _SignalRow(signal: s)),
              if (hiddenCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'and $hiddenCount more — review in trial health',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReviewPlots,
                    child: const Text('Review plots'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onClose,
                    child: const Text('Close session'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Evidence row
// ---------------------------------------------------------------------------

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({
    required this.label,
    required this.color,
    required this.icon,
    this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: row);
    }
    return row;
  }
}

// ---------------------------------------------------------------------------
// Signal row
// ---------------------------------------------------------------------------

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.signal});

  final Signal signal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _sanitize(signal.consequenceText),
            style: const TextStyle(
              fontSize: 13,
              color: AppDesignTokens.primaryText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _typeLabel(signal.signalType),
            style: const TextStyle(
              fontSize: 11,
              color: AppDesignTokens.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _kJargon = ['standard deviation', 'variance', 'p-value', 'statistical'];

String _sanitize(String text) {
  final lower = text.toLowerCase();
  if (_kJargon.any(lower.contains)) {
    return 'Check this value before leaving the field.';
  }
  return text;
}

String _typeLabel(String signalType) => switch (signalType) {
      'scale_violation' => 'Scale check',
      'spatial_anomaly' => 'Spatial pattern',
      'aov_prediction' => 'Analysis risk',
      'replication_warning' => 'Replication gap',
      'causal_context_flag' => 'Timing context',
      _ => 'Field observation',
    };

Future<void> logSessionCloseDeferEvents({
  required SignalRepository repo,
  required int? userId,
  required List<Signal> shown,
  required List<Signal> hidden,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;

  for (final s in shown) {
    await repo.recordDecisionEvent(
      signalId: s.id,
      eventType: SignalDecisionEventType.defer,
      occurredAt: now,
      actorUserId: userId,
      note: 'Proceeded at session close',
    );
  }

  for (final s in hidden) {
    await repo.recordDecisionEvent(
      signalId: s.id,
      eventType: SignalDecisionEventType.defer,
      occurredAt: now,
      actorUserId: userId,
      note: 'Not shown at session close — exceeded display limit',
    );
  }
}
