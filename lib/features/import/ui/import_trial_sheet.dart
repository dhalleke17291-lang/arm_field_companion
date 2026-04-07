import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';
import '../../arm_import/arm_import_screen.dart';
import '../../export/domain/shell_link_preview.dart';
import '../../protocol_import/protocol_import_screen.dart';

/// Bottom sheet: choose ARM CSV, Protocol CSV, or (trial context) shell link.
class ImportTrialSheet extends StatelessWidget {
  const ImportTrialSheet({
    super.key,
    required this.parentContext,
    this.trialId,
  });

  final BuildContext parentContext;

  /// When non-null, "Link ARM Rating Shell" is enabled for this trial.
  final int? trialId;

  /// Presents the sheet; routes use [parentContext] after the sheet is closed.
  static Future<void> show(
    BuildContext parentContext, {
    int? trialId,
  }) {
    return showModalBottomSheet<void>(
      context: parentContext,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ImportTrialSheet(
        parentContext: parentContext,
        trialId: trialId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasTrial = trialId != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDesignTokens.spacing16,
          AppDesignTokens.spacing12,
          AppDesignTokens.spacing16,
          AppDesignTokens.spacing24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppDesignTokens.spacing16),
                decoration: BoxDecoration(
                  color: AppDesignTokens.borderCrisp,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Import Trial',
              style: AppDesignTokens.bodyCrispStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppDesignTokens.primaryText,
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing16),
            _ImportOptionTile(
              icon: Icons.table_chart_outlined,
              title: 'Import from ARM (CSV)',
              subtitle: 'Use an ARM export CSV for ARM-linked trials',
              onTap: () {
                Navigator.pop(context);
                Navigator.push<void>(
                  parentContext,
                  MaterialPageRoute<void>(
                    builder: (_) => const ArmImportScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: AppDesignTokens.spacing8),
            _ImportOptionTile(
              icon: Icons.file_download_outlined,
              title: 'Import Protocol (CSV)',
              subtitle: 'Use the AgQuest protocol CSV format',
              onTap: () {
                Navigator.pop(context);
                Navigator.push<void>(
                  parentContext,
                  MaterialPageRoute<void>(
                    builder: (_) => const ProtocolImportScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: AppDesignTokens.spacing8),
            _ImportOptionTile(
              icon: Icons.link_outlined,
              title: 'Link ARM Rating Shell',
              subtitle: hasTrial
                  ? 'Enrich trial metadata from ARM shell'
                  : 'Store an empty ARM shell for export back to ARM',
              enabled: hasTrial,
              trailingBadge: hasTrial ? null : 'Coming soon',
              onTap: hasTrial
                  ? () => _onLinkArmShellTap(
                        sheetContext: context,
                        parentContext: parentContext,
                        trialId: trialId!,
                      )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _onLinkArmShellTap({
  required BuildContext sheetContext,
  required BuildContext parentContext,
  required int trialId,
}) async {
  final container = ProviderScope.containerOf(parentContext);
  Navigator.pop(sheetContext);

  final pick = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['xlsx'],
    dialogTitle: 'Select ARM Rating Shell',
  );
  if (pick == null || pick.files.isEmpty) return;
  final path = pick.files.single.path;
  if (path == null || path.isEmpty) return;

  final uc = container.read(armShellLinkUseCaseProvider);
  final preview = await uc.preview(trialId, path);
  if (!parentContext.mounted) return;

  if (!preview.canApply) {
    await showDialog<void>(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Cannot Link Shell'),
        content: SingleChildScrollView(
          child: Text(
            preview.blockerSummary.isEmpty
                ? 'Link blocked.'
                : preview.blockerSummary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    return;
  }

  final applyNow = await showModalBottomSheet<bool>(
    context: parentContext,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _ShellLinkConfirmSheet(preview: preview),
  );

  if (applyNow != true || !parentContext.mounted) return;

  final result = await uc.apply(trialId, path);
  if (!parentContext.mounted) return;

  if (result.success) {
    final n = result.fieldsUpdatedCount ?? 0;
    container.invalidate(trialProvider(trialId));
    container.invalidate(trialSetupProvider(trialId));
    container.invalidate(trialAssessmentsForTrialProvider(trialId));
    container.invalidate(trialsStreamProvider);

    ScaffoldMessenger.of(parentContext).showSnackBar(
      SnackBar(
        content: Text(
          n == 0
              ? 'Shell linked. No field changes were needed.'
              : 'Shell linked. Updated $n field change(s).',
        ),
      ),
    );
  } else {
    final scheme = Theme.of(parentContext).colorScheme;
    ScaffoldMessenger.of(parentContext).showSnackBar(
      SnackBar(
        content: Text(result.errorMessage ?? 'Link failed'),
        backgroundColor: scheme.error,
      ),
    );
  }
}

class _ShellLinkConfirmSheet extends StatelessWidget {
  const _ShellLinkConfirmSheet({required this.preview});

  final ShellLinkPreview preview;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final warnings = preview.issues
        .where((i) => i.severity == ShellLinkIssueSeverity.warn)
        .toList();

    final changeLines = <String>[
      for (final c in preview.trialFieldChanges)
        _trialChangeLine(c),
      for (final c in preview.assessmentFieldChanges)
        _assessmentChangeLine(c),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Link ARM Rating Shell',
            style: AppDesignTokens.headingStyle(
              fontSize: 17,
              color: AppDesignTokens.primaryText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Shell title',
            style: AppDesignTokens.bodyCrispStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            preview.shellTitle.isEmpty ? '—' : preview.shellTitle,
            style: AppDesignTokens.bodyStyle(
              color: AppDesignTokens.primaryText,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Fields to update',
            style: AppDesignTokens.bodyCrispStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.35,
            ),
            child: SingleChildScrollView(
              child: changeLines.isEmpty
                  ? Text(
                      'No trial or assessment field changes.',
                      style: AppDesignTokens.bodyStyle(
                        color: AppDesignTokens.secondaryText,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in changeLines)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '· $line',
                              style: AppDesignTokens.bodyStyle(
                                fontSize: 14,
                                color: AppDesignTokens.primaryText,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Warnings',
              style: AppDesignTokens.bodyCrispStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.warningFg,
              ),
            ),
            const SizedBox(height: 6),
            for (final w in warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '· ${w.message}',
                  style: AppDesignTokens.bodyStyle(
                    fontSize: 13,
                    color: AppDesignTokens.warningFg,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _trialChangeLine(ShellTrialFieldChange c) {
  final label = _trialFieldLabel(c.fieldName);
  if (c.isFillEmpty) {
    return '$label: set to "${c.newValue}"';
  }
  return '$label: "${c.oldValue}" → "${c.newValue}"';
}

String _assessmentChangeLine(ShellAssessmentFieldChange c) {
  final label = c.fieldName == 'pestCode'
      ? 'Pest code'
      : 'Shell column index';
  if (c.isFillEmpty) {
    return 'Assessment ${c.trialAssessmentId} ($label): set to "${c.newValue}"';
  }
  return 'Assessment ${c.trialAssessmentId} ($label): "${c.oldValue ?? '—'}" → "${c.newValue}"';
}

String _trialFieldLabel(String fieldName) {
  switch (fieldName) {
    case 'name':
      return 'Trial name';
    case 'protocolNumber':
      return 'Protocol number';
    case 'cooperatorName':
      return 'Cooperator';
    case 'crop':
      return 'Crop';
    default:
      return fieldName;
  }
}

class _ImportOptionTile extends StatelessWidget {
  const _ImportOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
    this.trailingBadge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final String? trailingBadge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? AppDesignTokens.cardSurface
          : AppDesignTokens.cardSurface.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.spacing12,
            vertical: AppDesignTokens.spacing12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 24,
                color: enabled
                    ? AppDesignTokens.primary
                    : AppDesignTokens.secondaryText,
              ),
              const SizedBox(width: AppDesignTokens.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? AppDesignTokens.primaryText
                            : AppDesignTokens.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppDesignTokens.secondaryText.withValues(
                          alpha: enabled ? 0.9 : 0.65,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingBadge != null) ...[
                const SizedBox(width: 8),
                Text(
                  trailingBadge!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
