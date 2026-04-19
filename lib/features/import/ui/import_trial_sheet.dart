import 'package:drift/drift.dart' hide Column;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';
import '../../arm_import/arm_import_screen.dart';
import '../../export/domain/shell_link_preview.dart';
import '../../protocol_import/protocol_import_screen.dart';

/// Bottom sheet: ARM Rating Shell, protocol CSV, or link rating sheet to a trial.
///
/// Open from the trials hub toolbar only — not duplicated inside [TrialDetailScreen].
class ImportTrialSheet extends StatelessWidget {
  const ImportTrialSheet({
    super.key,
    required this.parentContext,
  });

  final BuildContext parentContext;

  /// Presents the sheet; routes use [parentContext] after the sheet is closed.
  static Future<void> show(BuildContext parentContext) {
    return showModalBottomSheet<void>(
      context: parentContext,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ImportTrialSheet(
        parentContext: parentContext,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              icon: Icons.table_view_outlined,
              title: 'Import ARM Rating Shell',
              subtitle:
                  'Import plots, treatments, and assessments from an ARM Excel file',
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
              title: 'Import from CSV',
              subtitle:
                  'Import trial structure from a CSV file (protocol format)',
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
              title: 'Link Rating Sheet',
              subtitle:
                  'Add ARM metadata to an existing imported trial',
              onTap: () => _onLinkArmShellTap(
                    sheetContext: context,
                    parentContext: parentContext,
                    trialId: null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Returns selected trial id, or null if the dialog was dismissed.
Future<int?> _showArmLinkedTrialPickerDialog(
  BuildContext context,
  List<Trial> trials,
) {
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Choose Trial'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in trials)
              ListTile(
                title: Text(t.name),
                onTap: () => Navigator.pop(ctx, t.id),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _onLinkArmShellTap({
  required BuildContext sheetContext,
  required BuildContext parentContext,
  int? trialId,
}) async {
  final container = ProviderScope.containerOf(parentContext);
  Navigator.pop(sheetContext);

  var resolvedId = trialId;
  if (resolvedId == null) {
    final db = container.read(databaseProvider);
    final armLinked = await (db.select(db.trials)
          ..where((t) => t.isDeleted.equals(false) & t.isArmLinked.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    if (!parentContext.mounted) return;
    if (armLinked.isEmpty) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(
          content: Text('No imported trials. Import a CSV first.'),
        ),
      );
      return;
    }
    if (armLinked.length == 1) {
      resolvedId = armLinked.single.id;
    } else {
      resolvedId = await _showArmLinkedTrialPickerDialog(
        parentContext,
        armLinked,
      );
      if (resolvedId == null || !parentContext.mounted) return;
    }
  }

  final pick = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['xlsx'],
    dialogTitle: 'Select Excel Rating Sheet',
  );
  if (pick == null || pick.files.isEmpty) return;
  final path = pick.files.single.path;
  if (path == null || path.isEmpty) return;

  final uc = container.read(armShellLinkUseCaseProvider);
  final preview = await uc.preview(resolvedId, path);
  if (!parentContext.mounted) return;

  if (!preview.canApply) {
    await showDialog<void>(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Cannot Link Rating Sheet'),
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
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _ShellLinkConfirmSheet(preview: preview),
  );

  if (applyNow != true || !parentContext.mounted) return;

  final result = await uc.apply(resolvedId, path);
  if (!parentContext.mounted) return;

  if (result.success) {
    final matched = result.totalAssessmentsMatched ?? 0;
    final unmatched = result.totalAssessmentsUnmatched ?? 0;
    final total = matched + unmatched;
    final f = result.fieldsUpdated ?? result.fieldsUpdatedCount ?? 0;
    container.invalidate(trialProvider(resolvedId));
    container.invalidate(trialSetupProvider(resolvedId));
    container.invalidate(trialAssessmentsForTrialProvider(resolvedId));
    container.invalidate(trialsStreamProvider);

    ScaffoldMessenger.of(parentContext).showSnackBar(
      SnackBar(
        content: Text(
          total == 0
              ? 'Shell linked. $f field update(s).'
              : 'Shell linked for $matched of $total assessments. $f fields updated.',
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
            'Link Rating Sheet',
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
  final label = switch (c.fieldName) {
    'pestCode' => 'Pest code',
    'arm_shell_column_id' => 'Reference code',
    'arm_shell_rating_date' => 'Rating date',
    'se_name' => 'Assessment code',
    'se_description' => 'Assessment description',
    'arm_rating_type' => 'Scale type',
    _ => c.fieldName,
  };
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppDesignTokens.cardSurface,
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      child: InkWell(
        onTap: onTap,
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
                color: AppDesignTokens.primary,
              ),
              const SizedBox(width: AppDesignTokens.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppDesignTokens.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppDesignTokens.secondaryText.withValues(
                          alpha: 0.9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
