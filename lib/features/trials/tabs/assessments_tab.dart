import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';
import '../../../core/trial_state.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/loading_error_widgets.dart';
import '../../../core/widgets/app_standard_widgets.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../assessment_library_picker_dialog.dart';

/// Assessments tab for trial detail: library + custom assessments list.
class AssessmentsTab extends ConsumerWidget {
  const AssessmentsTab({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync =
        ref.watch(trialAssessmentsWithDefinitionsForTrialProvider(trial.id));
    final legacyAsync = ref.watch(assessmentsForTrialProvider(trial.id));

    if (libraryAsync.isLoading && legacyAsync.isLoading) {
      return const AppLoadingView();
    }
    return libraryAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, st) => AppErrorView(
        error: e,
        stackTrace: st,
        onRetry: () => ref.invalidate(
            trialAssessmentsWithDefinitionsForTrialProvider(trial.id)),
      ),
      data: (libraryList) => legacyAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, st) => AppErrorView(
          error: e,
          stackTrace: st,
          onRetry: () => ref.invalidate(assessmentsForTrialProvider(trial.id)),
        ),
        data: (legacyList) =>
            _buildAssessmentsContent(context, ref, libraryList, legacyList),
      ),
    );
  }

  Widget _buildAssessmentsContent(
    BuildContext context,
    WidgetRef ref,
    List<(TrialAssessment, AssessmentDefinition)> libraryList,
    List<Assessment> legacyList,
  ) {
    final locked = isProtocolLocked(trial.status);
    final total = libraryList.length + legacyList.length;
    if (total == 0) {
      final button = FilledButton(
        onPressed:
            locked ? null : () => _showAddAssessmentOptions(context, ref),
        child: const Text('Add Assessment'),
      );
      return AppEmptyState(
        icon: Icons.assessment,
        title: 'No Assessments Yet',
        subtitle: locked
            ? getProtocolLockMessage(trial.status)
            : 'Add from library or create a custom assessment.',
        action: locked && getProtocolLockMessage(trial.status).isNotEmpty
            ? Tooltip(
                message: getProtocolLockMessage(trial.status), child: button)
            : button,
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.spacing16,
            vertical: 10,
          ),
          decoration: const BoxDecoration(
            color: AppDesignTokens.sectionHeaderBg,
            border:
                Border(bottom: BorderSide(color: AppDesignTokens.borderCrisp)),
          ),
          child: Row(
            children: [
              const Icon(Icons.assessment_outlined,
                  size: 16, color: AppDesignTokens.primary),
              const SizedBox(width: AppDesignTokens.spacing8),
              Expanded(
                child: Text(
                  total == 1 ? '1 assessment' : '$total assessments',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppDesignTokens.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ProtocolLockChip(isLocked: locked, status: trial.status),
              const SizedBox(width: 8),
              Tooltip(
                message: locked
                    ? getProtocolLockMessage(trial.status)
                    : 'Add assessment',
                child: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: locked
                      ? null
                      : () => _showAddAssessmentOptions(context, ref),
                ),
              ),
            ],
          ),
        ),
        if (locked)
          ProtocolLockNotice(message: getProtocolLockMessage(trial.status)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              if (libraryList.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4, bottom: 6),
                  child: Text(
                    'From library',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ...libraryList.map((pair) {
                  final ta = pair.$1;
                  final def = pair.$2;
                  final name = ta.displayNameOverride ?? def.name;
                  return Container(
                    margin:
                        const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.cardSurface,
                      borderRadius:
                          BorderRadius.circular(AppDesignTokens.radiusCard),
                      border: Border.all(color: AppDesignTokens.borderCrisp),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDesignTokens.spacing16,
                        vertical: AppDesignTokens.spacing8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(AppDesignTokens.spacing8),
                        decoration: BoxDecoration(
                          color: AppDesignTokens.sectionHeaderBg,
                          borderRadius: BorderRadius.circular(
                              AppDesignTokens.radiusXSmall),
                        ),
                        child: const Icon(Icons.analytics_outlined,
                            size: 20, color: AppDesignTokens.primary),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppDesignTokens.primaryText,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${def.dataType}${def.unit != null ? ' (${def.unit})' : ''}',
                          style: const TextStyle(
                            color: AppDesignTokens.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      trailing: ta.isActive
                          ? const Icon(Icons.check_circle_outline,
                              size: 20, color: AppDesignTokens.primary)
                          : const Icon(Icons.chevron_right,
                              size: 20, color: AppDesignTokens.iconSubtle),
                    ),
                  );
                }),
              ],
              if (legacyList.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 16, bottom: 6),
                  child: Text(
                    'Custom',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ...legacyList.map((assessment) => Container(
                      margin: const EdgeInsets.only(
                          bottom: AppDesignTokens.spacing8),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.cardSurface,
                        borderRadius:
                            BorderRadius.circular(AppDesignTokens.radiusCard),
                        border: Border.all(color: AppDesignTokens.borderCrisp),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppDesignTokens.spacing16,
                          vertical: AppDesignTokens.spacing8,
                        ),
                        leading: Container(
                          padding:
                              const EdgeInsets.all(AppDesignTokens.spacing8),
                          decoration: BoxDecoration(
                            color: AppDesignTokens.sectionHeaderBg,
                            borderRadius: BorderRadius.circular(
                                AppDesignTokens.radiusXSmall),
                          ),
                          child: const Icon(Icons.analytics_outlined,
                              size: 20, color: AppDesignTokens.primary),
                        ),
                        title: Text(
                          assessment.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppDesignTokens.primaryText,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${assessment.dataType}${assessment.unit != null ? ' (${assessment.unit})' : ''}',
                            style: const TextStyle(
                              color: AppDesignTokens.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        trailing: assessment.isActive
                            ? const Icon(Icons.check_circle_outline,
                                size: 20, color: AppDesignTokens.primary)
                            : const Icon(Icons.chevron_right,
                                size: 20, color: AppDesignTokens.iconSubtle),
                      ),
                    )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showAddAssessmentOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppDesignTokens.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDesignTokens.radiusLarge),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin:
                    const EdgeInsets.only(bottom: AppDesignTokens.spacing16),
                decoration: BoxDecoration(
                  color: AppDesignTokens.dragHandle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding:
                    EdgeInsets.only(left: 20, bottom: AppDesignTokens.spacing8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add Assessment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.primaryText,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primaryTint,
                    borderRadius:
                        BorderRadius.circular(AppDesignTokens.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.library_books_outlined,
                    color: AppDesignTokens.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'From Library',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                ),
                subtitle: const Text(
                  'Choose from standard templates',
                  style: TextStyle(
                      fontSize: 12, color: AppDesignTokens.secondaryText),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  AssessmentLibraryPickerDialog.show(context, trial.id);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primaryTint,
                    borderRadius:
                        BorderRadius.circular(AppDesignTokens.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: AppDesignTokens.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Custom Assessment',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                ),
                subtitle: const Text(
                  'Create your own assessment',
                  style: TextStyle(
                      fontSize: 12, color: AppDesignTokens.secondaryText),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showAddAssessmentDialog(context, ref);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddAssessmentDialog(
      BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final unitController = TextEditingController();
    final minController = TextEditingController();
    final maxController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AppDialog(
        title: 'Add Assessment',
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Assessment Name *',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: unitController,
              decoration: const InputDecoration(
                labelText: 'Unit (e.g. %, cm, score)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min Value',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: maxController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Value',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              final db = ref.read(databaseProvider);
              await db.into(db.assessments).insert(
                    AssessmentsCompanion.insert(
                      trialId: trial.id,
                      name: nameController.text.trim(),
                      unit: drift.Value(unitController.text.isEmpty
                          ? null
                          : unitController.text),
                      minValue:
                          drift.Value(double.tryParse(minController.text)),
                      maxValue:
                          drift.Value(double.tryParse(maxController.text)),
                    ),
                  );

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
