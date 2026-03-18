import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../../shared/widgets/app_card.dart';

String _deletedMetadataLine(DateTime? deletedAt, String? deletedBy) {
  final datePart = deletedAt != null
      ? DateFormat('MMM d, yyyy').format(deletedAt.toLocal())
      : 'Unknown date';
  final byPart = (deletedBy != null && deletedBy.trim().isNotEmpty)
      ? deletedBy.trim()
      : 'Unknown';
  return 'Deleted $datePart • $byPart';
}

const _kSectionHeadingStyle = TextStyle(
  fontWeight: FontWeight.w600,
  fontSize: 15,
  color: AppDesignTokens.primaryText,
);

const _kEmptyStateStyle = TextStyle(
  fontSize: 13,
  color: AppDesignTokens.secondaryText,
);

Future<void> _runPlotRestore(
  BuildContext context,
  WidgetRef ref,
  Plot plot,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    const SnackBar(content: Text('Restoring plot...')),
  );

  final user = await ref.read(currentUserProvider.future);
  final result = await ref.read(plotRepositoryProvider).restorePlot(
        plot.id,
        restoredBy: user?.displayName,
        restoredByUserId: user?.id,
      );

  if (!context.mounted) return;
  messenger.clearSnackBars();

  if (result.success) {
    ref.invalidate(deletedPlotsProvider);
    ref.invalidate(deletedPlotsForTrialRecoveryProvider(plot.trialId));
    ref.invalidate(plotsForTrialProvider(plot.trialId));
    messenger.showSnackBar(
      const SnackBar(content: Text('Plot restored')),
    );
    return;
  }

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cannot Restore Plot'),
      content: SelectableText(result.errorMessage ?? 'Restore failed.'),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<void> _runSessionRestore(
  BuildContext context,
  WidgetRef ref,
  Session session,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    const SnackBar(content: Text('Restoring session...')),
  );

  final user = await ref.read(currentUserProvider.future);
  final result = await ref.read(sessionRepositoryProvider).restoreSession(
        session.id,
        restoredBy: user?.displayName,
        restoredByUserId: user?.id,
      );

  if (!context.mounted) return;
  messenger.clearSnackBars();

  if (result.success) {
    ref.invalidate(deletedSessionsProvider);
    ref.invalidate(deletedSessionsForTrialRecoveryProvider(session.trialId));
    ref.invalidate(sessionsForTrialProvider(session.trialId));
    messenger.showSnackBar(
      const SnackBar(content: Text('Session restored')),
    );
    return;
  }

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cannot Restore Session'),
      content: SelectableText(result.errorMessage ?? 'Restore failed.'),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<void> _runTrialRestore(
  BuildContext context,
  WidgetRef ref,
  Trial trial,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    const SnackBar(content: Text('Restoring trial...')),
  );

  final user = await ref.read(currentUserProvider.future);
  final result = await ref.read(trialRepositoryProvider).restoreTrial(
        trial.id,
        restoredBy: user?.displayName,
        restoredByUserId: user?.id,
      );

  if (!context.mounted) return;
  messenger.clearSnackBars();

  if (result.success) {
    ref.invalidate(deletedTrialsProvider);
    ref.invalidate(deletedSessionsProvider);
    ref.invalidate(deletedPlotsProvider);
    ref.invalidate(deletedSessionsForTrialRecoveryProvider(trial.id));
    ref.invalidate(deletedPlotsForTrialRecoveryProvider(trial.id));
    ref.invalidate(trialsStreamProvider);
    ref.invalidate(sessionsForTrialProvider(trial.id));
    ref.invalidate(plotsForTrialProvider(trial.id));
    ref.invalidate(trialProvider(trial.id));
    ref.invalidate(trialSetupProvider(trial.id));
    messenger.showSnackBar(
      const SnackBar(content: Text('Trial restored')),
    );
    return;
  }

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cannot Restore Trial'),
      content: SelectableText(result.errorMessage ?? 'Restore failed.'),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

String? _trialCropLocationSubtitle(Trial t) {
  final parts = <String>[];
  if (t.crop != null && t.crop!.trim().isNotEmpty) {
    parts.add(t.crop!.trim());
  }
  if (t.location != null && t.location!.trim().isNotEmpty) {
    parts.add(t.location!.trim());
  }
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

/// Read-only list of soft-deleted trials, sessions, and plots (Recovery).
///
/// When [trialId] is null, lists all deleted trials, sessions, and plots.
/// When [trialId] is set, lists only deleted sessions and plots for that trial.
class RecoveryScreen extends ConsumerWidget {
  const RecoveryScreen({super.key, this.trialId});

  final int? trialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trialId;
    final scoped = t != null;
    final trialsAsync = scoped ? null : ref.watch(deletedTrialsProvider);
    final sessionsAsync = t == null
        ? ref.watch(deletedSessionsProvider)
        : ref.watch(deletedSessionsForTrialRecoveryProvider(t));
    final plotsAsync = t == null
        ? ref.watch(deletedPlotsProvider)
        : ref.watch(deletedPlotsForTrialRecoveryProvider(t));

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: GradientScreenHeader(
        title: 'Recovery',
        subtitle: scoped
            ? 'Deleted items in this trial'
            : 'All deleted items',
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.spacing16,
            vertical: AppDesignTokens.spacing24,
          ),
          children: [
            if (!scoped && trialsAsync != null) ...[
              _DeletedTrialsSection(async: trialsAsync),
              const SizedBox(height: AppDesignTokens.spacing16),
            ],
            _DeletedSessionsSection(async: sessionsAsync),
            const SizedBox(height: AppDesignTokens.spacing16),
            _DeletedPlotsSection(async: plotsAsync),
          ],
        ),
      ),
    );
  }
}

class _DeletedTrialsSection extends StatelessWidget {
  const _DeletedTrialsSection({required this.async});

  final AsyncValue<List<Trial>> async;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDesignTokens.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Deleted Trials', style: _kSectionHeadingStyle),
          const SizedBox(height: AppDesignTokens.spacing12),
          async.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDesignTokens.spacing16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => Text(
              'Error: $e',
              style: const TextStyle(
                fontSize: 13,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            data: (trials) {
              if (trials.isEmpty) {
                return const Text(
                  'No deleted trials',
                  style: _kEmptyStateStyle,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < trials.length; i++) ...[
                    if (i > 0) ...[
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppDesignTokens.borderCrisp,
                      ),
                      const SizedBox(height: AppDesignTokens.spacing12),
                    ],
                    _TrialRecoveryRow(trial: trials[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TrialRecoveryRow extends ConsumerWidget {
  const _TrialRecoveryRow({required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = _trialCropLocationSubtitle(trial);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trial.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              if (sub != null) ...[
                const SizedBox(height: 4),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                _deletedMetadataLine(trial.deletedAt, trial.deletedBy),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'Restores this deleted trial and its deleted data',
              child: TextButton.icon(
                onPressed: () => _runTrialRestore(context, ref, trial),
                icon: const Icon(
                  Icons.restore_outlined,
                  size: 18,
                  color: AppDesignTokens.primary,
                ),
                label: const Text(
                  'Restore',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppDesignTokens.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            Tooltip(
              message: 'Exports deleted trial data for analysis',
              child: TextButton.icon(
                onPressed: () =>
                    _runDeletedTrialRecoveryExport(context, ref, trial),
                icon: const Icon(
                  Icons.download_outlined,
                  size: 18,
                  color: AppDesignTokens.primary,
                ),
                label: const Text(
                  'Export (Recovery)',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppDesignTokens.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeletedSessionsSection extends StatelessWidget {
  const _DeletedSessionsSection({required this.async});

  final AsyncValue<List<Session>> async;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDesignTokens.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Deleted Sessions', style: _kSectionHeadingStyle),
          const SizedBox(height: AppDesignTokens.spacing12),
          async.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDesignTokens.spacing16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => Text(
              'Error: $e',
              style: const TextStyle(
                fontSize: 13,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            data: (sessions) {
              if (sessions.isEmpty) {
                return const Text(
                  'No deleted sessions',
                  style: _kEmptyStateStyle,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < sessions.length; i++) ...[
                    if (i > 0) ...[
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppDesignTokens.borderCrisp,
                      ),
                      const SizedBox(height: AppDesignTokens.spacing12),
                    ],
                    _SessionRecoveryRow(session: sessions[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _runDeletedSessionRecoveryExport(
  BuildContext context,
  WidgetRef ref,
  Session session,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    const SnackBar(content: Text('Exporting recovery ZIP...')),
  );

  final user = await ref.read(currentUserProvider.future);
  final result = await ref
      .read(exportDeletedSessionRecoveryZipUsecaseProvider)
      .execute(
        sessionId: session.id,
        exportedByDisplayName: user?.displayName,
      );

  if (!context.mounted) return;
  messenger.clearSnackBars();

  if (!result.success ||
      result.filePath == null ||
      result.filePath!.isEmpty) {
    ref.read(diagnosticsStoreProvider).recordError(
          result.errorMessage ?? 'Recovery export failed',
          code: 'recovery_export_failed',
        );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Failed'),
        content: SelectableText(
          result.errorMessage ?? 'Recovery export failed.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Recovery Export Ready'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deleted-session Recovery ZIP is ready for analysis or review. '
            'This file is not for standard operational re-import.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          const Text(
            'Saved to:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          SelectableText(
            result.filePath!,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () async {
            Navigator.pop(ctx);
            final box = context.findRenderObject() as RenderBox?;
            await Share.shareXFiles(
              [XFile(result.filePath!)],
              subject: 'Recovery export — ${session.name}',
              sharePositionOrigin: box == null
                  ? const Rect.fromLTWH(0, 0, 100, 100)
                  : box.localToGlobal(Offset.zero) & box.size,
            );
          },
          icon: const Icon(Icons.share),
          label: const Text('Share'),
        ),
      ],
    ),
  );
}

Future<void> _runDeletedTrialRecoveryExport(
  BuildContext context,
  WidgetRef ref,
  Trial trial,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    const SnackBar(content: Text('Exporting recovery ZIP...')),
  );

  final user = await ref.read(currentUserProvider.future);
  final result = await ref
      .read(exportDeletedTrialRecoveryZipUsecaseProvider)
      .execute(
        trialId: trial.id,
        exportedByDisplayName: user?.displayName,
      );

  if (!context.mounted) return;
  messenger.clearSnackBars();

  if (!result.success ||
      result.filePath == null ||
      result.filePath!.isEmpty) {
    ref.read(diagnosticsStoreProvider).recordError(
          result.errorMessage ?? 'Recovery export failed',
          code: 'recovery_trial_export_failed',
        );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Failed'),
        content: SelectableText(
          result.errorMessage ?? 'Recovery export failed.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Recovery Export Ready'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deleted-trial Recovery ZIP is ready for analysis or review. '
            'This file is not for standard operational re-import.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          const Text(
            'Saved to:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          SelectableText(
            result.filePath!,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () async {
            Navigator.pop(ctx);
            final box = context.findRenderObject() as RenderBox?;
            await Share.shareXFiles(
              [XFile(result.filePath!)],
              subject: 'Recovery export — ${trial.name}',
              sharePositionOrigin: box == null
                  ? const Rect.fromLTWH(0, 0, 100, 100)
                  : box.localToGlobal(Offset.zero) & box.size,
            );
          },
          icon: const Icon(Icons.share),
          label: const Text('Share'),
        ),
      ],
    ),
  );
}

class _SessionRecoveryRow extends ConsumerWidget {
  const _SessionRecoveryRow({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trialLabelAsync =
        ref.watch(recoveryTrialDisplayNameProvider(session.trialId));
    final trialLabel = trialLabelAsync.valueOrNull ?? 'Trial #${session.trialId}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppDesignTokens.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$trialLabel • ${session.sessionDateLocal}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _deletedMetadataLine(session.deletedAt, session.deletedBy),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Restores this deleted session and its rating data',
                  child: TextButton.icon(
                    onPressed: () =>
                        _runSessionRestore(context, ref, session),
                    icon: const Icon(
                      Icons.restore_outlined,
                      size: 18,
                      color: AppDesignTokens.primary,
                    ),
                    label: const Text(
                      'Restore',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppDesignTokens.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Exports deleted session data for analysis',
                  child: TextButton.icon(
                    onPressed: () =>
                        _runDeletedSessionRecoveryExport(context, ref, session),
                    icon: const Icon(
                      Icons.download_outlined,
                      size: 18,
                      color: AppDesignTokens.primary,
                    ),
                    label: const Text(
                      'Export (Recovery)',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppDesignTokens.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _DeletedPlotsSection extends StatelessWidget {
  const _DeletedPlotsSection({required this.async});

  final AsyncValue<List<Plot>> async;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDesignTokens.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Deleted Plots', style: _kSectionHeadingStyle),
          const SizedBox(height: AppDesignTokens.spacing12),
          async.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDesignTokens.spacing16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => Text(
              'Error: $e',
              style: const TextStyle(
                fontSize: 13,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            data: (plots) {
              if (plots.isEmpty) {
                return const Text(
                  'No deleted plots',
                  style: _kEmptyStateStyle,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < plots.length; i++) ...[
                    if (i > 0) ...[
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppDesignTokens.borderCrisp,
                      ),
                      const SizedBox(height: AppDesignTokens.spacing12),
                    ],
                    _PlotRecoveryRow(plot: plots[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlotRecoveryRow extends ConsumerWidget {
  const _PlotRecoveryRow({required this.plot});

  final Plot plot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trialLabelAsync =
        ref.watch(recoveryTrialDisplayNameProvider(plot.trialId));
    final trialLabel = trialLabelAsync.valueOrNull ?? 'Trial #${plot.trialId}';
    final repPart = plot.rep != null ? 'Rep ${plot.rep}' : null;
    final secondary = [
      if (repPart != null) repPart,
      trialLabel,
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plot.plotId,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                secondary,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _deletedMetadataLine(plot.deletedAt, plot.deletedBy),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
            ],
          ),
        ),
        Tooltip(
          message: 'Restores this deleted plot to the active trial layout',
          child: TextButton.icon(
            onPressed: () => _runPlotRestore(context, ref, plot),
            icon: const Icon(
              Icons.restore_outlined,
              size: 18,
              color: AppDesignTokens.primary,
            ),
            label: const Text(
              'Restore',
              style: TextStyle(
                fontSize: 13,
                color: AppDesignTokens.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }
}
