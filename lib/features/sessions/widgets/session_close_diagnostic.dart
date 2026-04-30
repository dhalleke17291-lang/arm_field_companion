import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../domain/signals/signal_providers.dart';

/// Bottom-sheet content surfaced before the researcher closes a session.
///
/// Reads [openSignalsForSessionProvider] and either fires [onAllClear]
/// immediately (no signals worth surfacing) or shows the diagnostic card.
/// Nothing ever blocks close — [onProceedAnyway] is always available.
class SessionCloseDiagnostic extends ConsumerWidget {
  const SessionCloseDiagnostic({
    super.key,
    required this.sessionId,
    required this.trialId,
    required this.onAllClear,
    required this.onProceedAnyway,
  });

  final int sessionId;
  final int trialId;
  final VoidCallback onAllClear;
  final VoidCallback onProceedAnyway;

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
        final criticals =
            allSignals.where((s) => s.severity == 'critical').toList();
        final reviews =
            allSignals.where((s) => s.severity == 'review').toList();
        // Info signals are never surfaced at session close.

        final shown = [
          ...criticals.take(1),
          ...reviews.take(3),
        ];
        final hiddenCount = (criticals.length - criticals.take(1).length) +
            (reviews.length - reviews.take(3).length);

        if (shown.isEmpty) {
          return _AutoAllClear(onAllClear: onAllClear);
        }

        return _DiagnosticSheet(
          signals: shown,
          hiddenCount: hiddenCount,
          onReviewPlots: () => Navigator.of(context).pop(),
          onClose: onProceedAnyway,
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
    required this.signals,
    required this.hiddenCount,
    required this.onReviewPlots,
    required this.onClose,
  });

  final List<Signal> signals;
  final int hiddenCount;
  final VoidCallback onReviewPlots;
  final VoidCallback onClose;

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
      _ => 'Field observation',
    };
