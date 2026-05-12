part of '../trial_detail_screen.dart';

class TrialReadinessSheet extends ConsumerWidget {
  const TrialReadinessSheet({
    super.key,
    required this.trialId,
    required this.report,
    required this.showExportAnyway,
    required this.onExport,
    required this.onClose,
  });

  final int trialId;
  final TrialReadinessReport report;
  final bool showExportAnyway;
  final VoidCallback onExport;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final readinessCodes = report.checks.map((c) => c.code).toSet();
    final diagnosticExtras = ref
        .watch(trialDiagnosticsProvider(trialId))
        .where(
          (f) =>
              f.source != DiagnosticSource.readiness &&
              !readinessCodes.contains(f.code),
        )
        .toList();
    final exportSnapshot =
        ref.watch(trialExportDiagnosticsSnapshotProvider(trialId));

    List<ReadinessCheckRow> rowsForSeverity(UnifiedSeverity severity) {
      final fromReport = report.checks
          .where((c) => mapTrialCheckSeverity(c.severity) == severity)
          .map((c) => ReadinessCheckRow(check: c))
          .toList();
      final fromDiag = diagnosticExtras
          .where((f) => mapFindingDiagnosticSeverity(f.severity) == severity)
          .map((f) => ReadinessCheckRow.fromFinding(f))
          .toList();
      return [...fromReport, ...fromDiag];
    }

    final blockers = rowsForSeverity(UnifiedSeverity.blocker);
    final warnings = rowsForSeverity(UnifiedSeverity.warning);
    final infos = rowsForSeverity(UnifiedSeverity.info);
    final passes = report.checks
        .where(
          (c) => mapTrialCheckSeverity(c.severity) == UnifiedSeverity.pass,
        )
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Trial readiness',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (diagnosticExtras.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  exportSnapshot != null
                      ? 'From last trial export attempt — ${exportSnapshot.attemptLabel} · Recorded ${DateFormat.yMMMd().add_jm().format(exportSnapshot.publishedAt.toLocal())}. Run export again for current status.'
                      : 'From last trial export attempt',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  shrinkWrap: true,
                  children: [
                    ...blockers,
                    ...warnings,
                    ...infos,
                    if (passes.isNotEmpty)
                      ExpansionTile(
                        initiallyExpanded: false,
                        title: Text(
                          'Show ${passes.length} passed checks',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        children: passes
                            .map((c) => ReadinessCheckRow(check: c))
                            .toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (showExportAnyway) ...[
                FilledButton(
                  onPressed: onExport,
                  child: const Text('Export anyway'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: onClose,
                  child: const Text('Cancel'),
                ),
              ] else ...[
                FilledButton.tonal(
                  onPressed: onClose,
                  child: const Text('Close'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class ReadinessCheckRow extends StatelessWidget {
  const ReadinessCheckRow({
    super.key,
    required this.check,
    // Reserved for readiness rows that need a source hint; callers use default today.
    // ignore: unused_element_parameter
    this.source,
  })  : _findingSeverity = null,
        _message = null,
        _findingDetail = null,
        _findingSource = null;

  factory ReadinessCheckRow.fromFinding(DiagnosticFinding f) {
    return ReadinessCheckRow._finding(
      severity: _mapDiagnosticSeverity(f.severity),
      message: f.message,
      detail: f.detail,
      findingSource: f.source,
    );
  }

  const ReadinessCheckRow._finding({
    required UnifiedSeverity severity,
    required String message,
    String? detail,
    required DiagnosticSource findingSource,
  })  : check = null,
        source = null,
        _findingSeverity = severity,
        _message = message,
        _findingDetail = detail,
        _findingSource = findingSource;

  final TrialReadinessCheck? check;
  final DiagnosticSource? source;
  final UnifiedSeverity? _findingSeverity;
  final String? _message;
  final String? _findingDetail;
  final DiagnosticSource? _findingSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unified = check != null
        ? mapTrialCheckSeverity(check!.severity)
        : _findingSeverity!;
    final label = check?.label ?? _message!;
    final detailText = check?.detail ?? _findingDetail;
    final hintSource = check != null ? source : _findingSource;
    IconData icon;
    Color color;
    switch (unified) {
      case UnifiedSeverity.blocker:
        icon = Icons.close;
        color = scheme.error;
        break;
      case UnifiedSeverity.warning:
        icon = Icons.warning_amber_outlined;
        color = AppDesignTokens.warningFg;
        break;
      case UnifiedSeverity.pass:
        icon = Icons.check;
        color = AppDesignTokens.successFg;
        break;
      case UnifiedSeverity.info:
        icon = Icons.info_outline;
        color = AppDesignTokens.primary;
        break;
    }
    final hintText = hintSource != null &&
            hintSource != DiagnosticSource.readiness &&
            _sourceLabel(hintSource).isNotEmpty
        ? _sourceLabel(hintSource)
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (detailText != null && detailText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detailText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hintText != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                hintText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
