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

const List<String> _assessmentMethods = [
  'Visual rating',
  'Measured',
  'Counted',
  'Weighed',
  'Calculated',
];

const List<String> _cropParts = [
  'Whole plant',
  'Leaf',
  'Stem',
  'Root',
  'Fruit',
  'Seed',
  'Canopy',
  'Other',
];

const List<String> _timingCodes = [
  'PRE',
  'POST',
  '7DAT',
  '14DAT',
  '21DAT',
  '28DAT',
  'AAPRE',
  'AAPOST',
  'At harvest',
  'Other',
];

const List<String> _dataTypes = ['numeric', 'text'];

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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${def.dataType}${def.unit != null ? ' (${def.unit})' : ''}'
                                  '${def.scaleMin != null && def.scaleMax != null ? ' · ${def.scaleMin}–${def.scaleMax}' : ''}',
                              style: const TextStyle(
                                color: AppDesignTokens.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                            if (def.timingCode != null &&
                                def.timingCode!.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: scheme.outline.withValues(alpha: 0.6)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    def.timingCode!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                          ],
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
                            '${assessment.dataType}${assessment.unit != null ? ' (${assessment.unit})' : ''}'
                                '${assessment.minValue != null && assessment.maxValue != null ? ' · ${assessment.minValue}–${assessment.maxValue}' : ''}',
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
    await showDialog(
      context: context,
      builder: (ctx) => _CustomAssessmentFormDialog(
        trial: trial,
        ref: ref,
        existing: null,
      ),
    );
  }
}

class _CustomAssessmentFormDialog extends ConsumerStatefulWidget {
  const _CustomAssessmentFormDialog({
    required this.trial,
    required this.ref,
    this.existing,
  });

  final Trial trial;
  final WidgetRef ref;
  final AssessmentDefinition? existing;

  @override
  ConsumerState<_CustomAssessmentFormDialog> createState() =>
      _CustomAssessmentFormDialogState();
}

class _CustomAssessmentFormDialogState
    extends ConsumerState<_CustomAssessmentFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _unitController;
  late TextEditingController _scaleMinController;
  late TextEditingController _scaleMaxController;
  late TextEditingController _validMinController;
  late TextEditingController _validMaxController;
  late TextEditingController _daysAfterTreatmentController;
  late TextEditingController _timingDescriptionController;
  late TextEditingController _eppoCodeController;
  String _dataType = 'numeric';
  String? _assessmentMethod;
  String? _cropPart;
  String? _timingCode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _unitController = TextEditingController(text: e?.unit ?? '');
    _scaleMinController =
        TextEditingController(text: e?.scaleMin?.toString() ?? '');
    _scaleMaxController =
        TextEditingController(text: e?.scaleMax?.toString() ?? '');
    _validMinController =
        TextEditingController(text: e?.validMin?.toString() ?? '');
    _validMaxController =
        TextEditingController(text: e?.validMax?.toString() ?? '');
    _daysAfterTreatmentController =
        TextEditingController(text: e?.daysAfterTreatment?.toString() ?? '');
    _timingDescriptionController =
        TextEditingController(text: e?.timingDescription ?? '');
    _eppoCodeController = TextEditingController(text: e?.eppoCode ?? '');
    _dataType = e?.dataType ?? 'numeric';
    _assessmentMethod = e?.assessmentMethod;
    _cropPart = e?.cropPart;
    _timingCode = e?.timingCode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _scaleMinController.dispose();
    _scaleMaxController.dispose();
    _validMinController.dispose();
    _validMaxController.dispose();
    _daysAfterTreatmentController.dispose();
    _timingDescriptionController.dispose();
    _eppoCodeController.dispose();
    super.dispose();
  }

  double? _parseDouble(TextEditingController c) {
    final s = c.text.trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  int? _parseInt(TextEditingController c) {
    final s = c.text.trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  bool get _scaleSectionHasData =>
      _parseDouble(_scaleMinController) != null ||
      _parseDouble(_scaleMaxController) != null ||
      _parseDouble(_validMinController) != null ||
      _parseDouble(_validMaxController) != null;

  bool get _timingSectionHasData =>
      _timingCode != null ||
      _parseInt(_daysAfterTreatmentController) != null ||
      _timingDescriptionController.text.trim().isNotEmpty ||
      _eppoCodeController.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final defRepo = ref.read(assessmentDefinitionRepositoryProvider);
      if (widget.existing != null) {
        await defRepo.updateDefinition(
          widget.existing!.id,
          name: name,
          dataType: _dataType,
          unit: _unitController.text.trim().isEmpty
              ? null
              : _unitController.text.trim(),
          scaleMin: _parseDouble(_scaleMinController),
          scaleMax: _parseDouble(_scaleMaxController),
          assessmentMethod: _assessmentMethod,
          cropPart: _cropPart,
          timingCode: _timingCode,
          daysAfterTreatment: _parseInt(_daysAfterTreatmentController),
          timingDescription: _timingDescriptionController.text.trim().isEmpty
              ? null
              : _timingDescriptionController.text.trim(),
          validMin: _parseDouble(_validMinController),
          validMax: _parseDouble(_validMaxController),
          eppoCode: _eppoCodeController.text.trim().isEmpty
              ? null
              : _eppoCodeController.text.trim(),
        );
        ref.invalidate(
            trialAssessmentsWithDefinitionsForTrialProvider(widget.trial.id));
      } else {
        final code = 'CUSTOM_${widget.trial.id}_${DateTime.now().millisecondsSinceEpoch}';
        final defId = await defRepo.insertCustom(
          code: code,
          name: name,
          category: 'custom',
          dataType: _dataType,
          unit: _unitController.text.trim().isEmpty
              ? null
              : _unitController.text.trim(),
          scaleMin: _parseDouble(_scaleMinController),
          scaleMax: _parseDouble(_scaleMaxController),
          assessmentMethod: _assessmentMethod,
          cropPart: _cropPart,
          timingCode: _timingCode,
          daysAfterTreatment: _parseInt(_daysAfterTreatmentController),
          timingDescription: _timingDescriptionController.text.trim().isEmpty
              ? null
              : _timingDescriptionController.text.trim(),
          validMin: _parseDouble(_validMinController),
          validMax: _parseDouble(_validMaxController),
          eppoCode: _eppoCodeController.text.trim().isEmpty
              ? null
              : _eppoCodeController.text.trim(),
        );
        await ref.read(trialAssessmentRepositoryProvider).addToTrial(
              trialId: widget.trial.id,
              assessmentDefinitionId: defId,
              displayNameOverride: name,
              selectedManually: true,
            );
      }
      ref.invalidate(
          trialAssessmentsWithDefinitionsForTrialProvider(widget.trial.id));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.existing != null ? 'Edit Assessment' : 'Add Assessment',
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Assessment Name *',
              border: OutlineInputBorder(),
            ),
            autofocus: widget.existing == null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('dt_$_dataType'),
            initialValue: _dataType,
            decoration: const InputDecoration(
              labelText: 'Assessment type',
              border: OutlineInputBorder(),
            ),
            items: _dataTypes
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _dataType = v ?? 'numeric'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _unitController,
            decoration: const InputDecoration(
              labelText: 'Unit (e.g. %, cm, score)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: ValueKey('am_$_assessmentMethod'),
            initialValue: _assessmentMethod,
            decoration: const InputDecoration(
              labelText: 'Assessment method',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('—')),
              ..._assessmentMethods.map((s) =>
                  DropdownMenuItem<String?>(value: s, child: Text(s))),
            ],
            onChanged: (v) => setState(() => _assessmentMethod = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: ValueKey('cp_$_cropPart'),
            initialValue: _cropPart,
            decoration: const InputDecoration(
              labelText: 'Crop part assessed',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('—')),
              ..._cropParts.map((s) =>
                  DropdownMenuItem<String?>(value: s, child: Text(s))),
            ],
            onChanged: (v) => setState(() => _cropPart = v),
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            title: Text(
              'Scale & validation${_scaleSectionHasData ? ' (filled)' : ''}',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
            initiallyExpanded: _scaleSectionHasData,
            children: [
              TextField(
                controller: _scaleMinController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Scale minimum',
                  hintText: 'e.g. 0',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _scaleMaxController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Scale maximum',
                  hintText: 'e.g. 10',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _validMinController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valid range minimum',
                  hintText: 'Reject values below this',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _validMaxController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valid range maximum',
                  hintText: 'Reject values above this',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Text(
                'Scale defines the rating range shown to raters. Valid range triggers a warning if exceeded.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text(
              'Timing & regulatory${_timingSectionHasData ? ' (filled)' : ''}',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
            initiallyExpanded: _timingSectionHasData,
            children: [
              DropdownButtonFormField<String?>(
                key: ValueKey('tc_$_timingCode'),
                initialValue: _timingCode,
                decoration: const InputDecoration(
                  labelText: 'Timing code',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('—')),
                  ..._timingCodes.map((s) =>
                      DropdownMenuItem<String?>(value: s, child: Text(s))),
                ],
                onChanged: (v) => setState(() => _timingCode = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _daysAfterTreatmentController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Days after treatment',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _timingDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Timing description',
                  hintText: 'e.g. 14 days after second application',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _eppoCodeController,
                decoration: const InputDecoration(
                  labelText: 'EPPO observation code',
                  hintText: 'e.g. PHYTO',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : (widget.existing != null ? 'Save' : 'Add')),
        ),
      ],
    );
  }
}
