import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/export_guard.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/plot_display.dart';
import '../../core/providers.dart';
import '../../core/trial_review_invalidation.dart';
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
    invalidateTrialReviewProviders(ref, plot.trialId);
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
    invalidateTrialReviewProviders(ref, session.trialId);
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
    invalidateTrialReviewProviders(ref, trial.id);
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
    // Always watch trials list so autoDispose does not drop to zero when
    // switching scoped vs global (conditional watch caused dispose races).
    final trialsAsync = ref.watch(deletedTrialsProvider);
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
        subtitle: scoped ? 'Deleted items in this trial' : 'All deleted items',
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.spacing16,
            vertical: AppDesignTokens.spacing24,
          ),
          children: [
            _RecoveryOverviewCard(
              scoped: scoped,
              trialsAsync: scoped ? null : trialsAsync,
              sessionsAsync: sessionsAsync,
              plotsAsync: plotsAsync,
            ),
            const SizedBox(height: AppDesignTokens.spacing16),
            if (!scoped) ...[
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

class _RecoveryOverviewCard extends StatelessWidget {
  const _RecoveryOverviewCard({
    required this.scoped,
    required this.trialsAsync,
    required this.sessionsAsync,
    required this.plotsAsync,
  });

  final bool scoped;
  final AsyncValue<List<Trial>>? trialsAsync;
  final AsyncValue<List<Session>> sessionsAsync;
  final AsyncValue<List<Plot>> plotsAsync;

  @override
  Widget build(BuildContext context) {
    final trialCount = trialsAsync?.valueOrNull?.length ?? 0;
    final sessionCount = sessionsAsync.valueOrNull?.length ?? 0;
    final plotCount = plotsAsync.valueOrNull?.length ?? 0;
    final isLoading = (trialsAsync?.isLoading ?? false) ||
        sessionsAsync.isLoading ||
        plotsAsync.isLoading;
    final total = trialCount + sessionCount + plotCount;

    return AppCard(
      padding: const EdgeInsets.all(AppDesignTokens.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: total == 0
                      ? AppDesignTokens.successBg
                      : AppDesignTokens.warningBg,
                  borderRadius:
                      BorderRadius.circular(AppDesignTokens.radiusSmall),
                ),
                child: Icon(
                  total == 0
                      ? Icons.check_circle_outline
                      : Icons.restore_from_trash_outlined,
                  color: total == 0
                      ? AppDesignTokens.successFg
                      : AppDesignTokens.warningFg,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppDesignTokens.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoading
                          ? 'Checking Recovery'
                          : total == 0
                              ? 'Recovery is clear'
                              : '$total item${total == 1 ? '' : 's'} in Recovery',
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        color: AppDesignTokens.primaryText,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      scoped
                          ? 'Deleted sessions and plots from this trial appear here until restored.'
                          : 'Deleted trials, sessions, and plots stay here until restored.',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing16),
          Row(
            children: [
              if (!scoped) ...[
                Expanded(
                  child: _RecoveryMetricTile(
                    label: 'Trials',
                    value: isLoading ? '...' : '$trialCount',
                  ),
                ),
                const SizedBox(width: AppDesignTokens.spacing8),
              ],
              Expanded(
                child: _RecoveryMetricTile(
                  label: 'Sessions',
                  value: isLoading ? '...' : '$sessionCount',
                ),
              ),
              const SizedBox(width: AppDesignTokens.spacing8),
              Expanded(
                child: _RecoveryMetricTile(
                  label: 'Plots',
                  value: isLoading ? '...' : '$plotCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecoveryMetricTile extends StatelessWidget {
  const _RecoveryMetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing12,
        vertical: AppDesignTokens.spacing12,
      ),
      decoration: BoxDecoration(
        color: AppDesignTokens.bgWarm.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
        border: Border.all(color: AppDesignTokens.borderCrisp),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoverySectionHeader extends StatelessWidget {
  const _RecoverySectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppDesignTokens.primaryTint,
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
          ),
          child: Icon(icon, size: 18, color: AppDesignTokens.primary),
        ),
        const SizedBox(width: AppDesignTokens.spacing12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppDesignTokens.primaryText,
            ),
          ),
        ),
        if (count != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: count == 0
                  ? AppDesignTokens.successBg
                  : AppDesignTokens.warningBg,
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusChip),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: count == 0
                    ? AppDesignTokens.successFg
                    : AppDesignTokens.warningFg,
              ),
            ),
          ),
      ],
    );
  }
}

class _RecoveryEmptyMessage extends StatelessWidget {
  const _RecoveryEmptyMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesignTokens.spacing12),
      decoration: BoxDecoration(
        color: AppDesignTokens.bgWarm.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
        border: Border.all(color: AppDesignTokens.borderCrisp),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 20,
            color: AppDesignTokens.successFg,
          ),
          const SizedBox(width: AppDesignTokens.spacing8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppDesignTokens.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoveryLoadingMessage extends StatelessWidget {
  const _RecoveryLoadingMessage();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppDesignTokens.spacing16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _RecoveryErrorMessage extends StatelessWidget {
  const _RecoveryErrorMessage({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesignTokens.spacing12),
      decoration: BoxDecoration(
        color:
            Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
      ),
      child: Text(
        'Error: $error',
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.error,
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
          _RecoverySectionHeader(
            icon: Icons.folder_delete_outlined,
            title: 'Deleted Trials',
            count: async.valueOrNull?.length,
          ),
          const SizedBox(height: AppDesignTokens.spacing12),
          async.when(
            loading: () => const _RecoveryLoadingMessage(),
            error: (e, _) => _RecoveryErrorMessage(error: e),
            data: (trials) {
              if (trials.isEmpty) {
                return const _RecoveryEmptyMessage(
                  text: 'No deleted trials',
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
          _RecoverySectionHeader(
            icon: Icons.event_busy_outlined,
            title: 'Deleted Sessions',
            count: async.valueOrNull?.length,
          ),
          const SizedBox(height: AppDesignTokens.spacing12),
          async.when(
            loading: () => const _RecoveryLoadingMessage(),
            error: (e, _) => _RecoveryErrorMessage(error: e),
            data: (sessions) {
              if (sessions.isEmpty) {
                return const _RecoveryEmptyMessage(
                  text: 'No deleted sessions',
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
  final guard = ref.read(exportGuardProvider);
  final ran = await guard.runExclusive(() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(content: Text('Exporting recovery ZIP...')),
    );

    final user = await ref.read(currentUserProvider.future);
    final result =
        await ref.read(exportDeletedSessionRecoveryZipUsecaseProvider).execute(
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
  });
  if (!ran && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(ExportGuard.busyMessage)),
    );
  }
}

Future<void> _runDeletedTrialRecoveryExport(
  BuildContext context,
  WidgetRef ref,
  Trial trial,
) async {
  final guard = ref.read(exportGuardProvider);
  final ran = await guard.runExclusive(() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(content: Text('Exporting recovery ZIP...')),
    );

    final user = await ref.read(currentUserProvider.future);
    final result =
        await ref.read(exportDeletedTrialRecoveryZipUsecaseProvider).execute(
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
  });
  if (!ran && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(ExportGuard.busyMessage)),
    );
  }
}

class _SessionRecoveryRow extends ConsumerWidget {
  const _SessionRecoveryRow({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trialLabelAsync =
        ref.watch(recoveryTrialDisplayNameProvider(session.trialId));
    final trialLabel =
        trialLabelAsync.valueOrNull ?? 'Trial #${session.trialId}';

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
                    onPressed: () => _runSessionRestore(context, ref, session),
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
          _RecoverySectionHeader(
            icon: Icons.grid_off_outlined,
            title: 'Deleted Plots',
            count: async.valueOrNull?.length,
          ),
          const SizedBox(height: AppDesignTokens.spacing12),
          async.when(
            loading: () => const _RecoveryLoadingMessage(),
            error: (e, _) => _RecoveryErrorMessage(error: e),
            data: (plots) {
              if (plots.isEmpty) {
                return const _RecoveryEmptyMessage(
                  text: 'No deleted plots',
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
                    _PlotRecoveryRow(plot: plots[i], sameTrialPlots: plots),
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
  const _PlotRecoveryRow({
    required this.plot,
    required this.sameTrialPlots,
  });

  final Plot plot;
  final List<Plot> sameTrialPlots;

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
    final displayLabel = getDisplayPlotLabel(plot, sameTrialPlots);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayLabel,
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
