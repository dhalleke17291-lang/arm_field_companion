import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/assessment_result_direction.dart';
import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';
import '../../../core/trial_state.dart';
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
                    fontWeight: FontWeight.w600,
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
    // Open the form dialog directly so the user always sees content.
    // "From Library" is available as a link inside the dialog.
    _showAddAssessmentDialog(context, ref);
  }

  InputDecoration _formDecoration(String hint) => InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0DDD6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0DDD6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2D5A40), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: true,
        fillColor: Colors.white,
      );

  Future<void> _showAddAssessmentDialog(
      BuildContext context, WidgetRef ref) async {
    final parentContext = context;
    final nameController = TextEditingController();
    final unitController = TextEditingController();
    final scaleMinController = TextEditingController();
    final scaleMaxController = TextEditingController();
    String? selectedType;
    String selectedResultDirection = AssessmentResultDirection.neutral;

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Add Assessment'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      AssessmentLibraryPickerDialog.show(parentContext, trial.id);
                    },
                    icon: const Icon(Icons.library_books_outlined, size: 20),
                    label: const Text('Add from library instead'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: _formDecoration('Assessment name'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    key: ValueKey(selectedType),
                    initialValue: selectedType,
                    decoration: _formDecoration('Assessment type'),
                    items: [
                      'Visual rating',
                      'Measured',
                      'Counted',
                      'Weighed',
                      'Calculated',
                    ]
                        .map((t) => DropdownMenuItem<String?>(
                            value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedType = v),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: unitController,
                    decoration: _formDecoration('Unit e.g. %, cm, kg/ha'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: scaleMinController,
                          keyboardType: TextInputType.number,
                          decoration: _formDecoration('Scale min'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: scaleMaxController,
                          keyboardType: TextInputType.number,
                          decoration: _formDecoration('Scale max'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedResultDirection,
                    decoration: _formDecoration('Result direction'),
                    items: [
                      DropdownMenuItem(
                        value: AssessmentResultDirection.neutral,
                        child: const Text('Neutral'),
                      ),
                      DropdownMenuItem(
                        value: AssessmentResultDirection.higherBetter,
                        child: const Text('Higher is better'),
                      ),
                      DropdownMenuItem(
                        value: AssessmentResultDirection.lowerBetter,
                        child: const Text('Lower is better'),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      if (v != null) selectedResultDirection = v;
                    }),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2D5A40),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                try {
                  final defRepo =
                      ref.read(assessmentDefinitionRepositoryProvider);
                  final code =
                      'CUSTOM_${trial.id}_${DateTime.now().millisecondsSinceEpoch}';
                  final scaleMin =
                      double.tryParse(scaleMinController.text.trim());
                  final scaleMax =
                      double.tryParse(scaleMaxController.text.trim());
                  final unitStr = unitController.text.trim();
                  final defId = await defRepo.insertCustom(
                    code: code,
                    name: name,
                    category: 'custom',
                    dataType: 'numeric',
                    unit: unitStr.isEmpty ? null : unitStr,
                    scaleMin: scaleMin,
                    scaleMax: scaleMax,
                    assessmentMethod: selectedType,
                    cropPart: null,
                    timingCode: null,
                    daysAfterTreatment: null,
                    timingDescription: null,
                    validMin: null,
                    validMax: null,
                    eppoCode: null,
                    resultDirection: selectedResultDirection,
                  );
                  await ref.read(trialAssessmentRepositoryProvider).addToTrial(
                        trialId: trial.id,
                        assessmentDefinitionId: defId,
                        displayNameOverride: name,
                        selectedManually: true,
                      );
                  ref.invalidate(
                      trialAssessmentsWithDefinitionsForTrialProvider(trial.id));
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text('Save failed: $e'),
                        backgroundColor:
                            Theme.of(dialogContext).colorScheme.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    unitController.dispose();
    scaleMinController.dispose();
    scaleMaxController.dispose();
  }
}

class _CustomAssessmentFormDialog extends ConsumerStatefulWidget {
  const _CustomAssessmentFormDialog({
    required this.trial,
    required this.ref,
    // ignore: unused_element_parameter
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
  String _resultDirection = AssessmentResultDirection.neutral;
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
    _resultDirection = e?.resultDirection ?? AssessmentResultDirection.neutral;
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
          resultDirection: _resultDirection,
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
          resultDirection: _resultDirection,
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

  static const _border = Color(0xFFE0DDD6);
  static const _focused = Color(0xFF2D5A40);

  InputDecoration _fieldDecoration(String hintText) => InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _focused, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: true,
        fillColor: Colors.white,
      );

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.existing != null
                        ? 'Edit Assessment'
                        : 'Add Assessment',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),
              // Scrollable fields
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: _fieldDecoration('Assessment name'),
                        autofocus: widget.existing == null,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String?>(
                        key: ValueKey('am_$_assessmentMethod'),
                        initialValue: _assessmentMethod,
                        decoration: _fieldDecoration('Assessment type'),
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('—')),
                          ..._assessmentMethods.map((s) =>
                              DropdownMenuItem<String?>(
                                  value: s, child: Text(s))),
                        ],
                        onChanged: (v) {
                          setState(() => _assessmentMethod = v);
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _unitController,
                        decoration:
                            _fieldDecoration('Unit e.g. %, cm, kg/ha'),
                        onChanged: (_) => setState(() {}),
                      ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _scaleMinController,
                                  keyboardType: TextInputType.number,
                                  decoration: _fieldDecoration('Scale min'),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _scaleMaxController,
                                  keyboardType: TextInputType.number,
                                  decoration: _fieldDecoration('Scale max'),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _resultDirection,
                            decoration: _fieldDecoration('Result direction'),
                            items: [
                              DropdownMenuItem(
                                value: AssessmentResultDirection.neutral,
                                child: const Text('Neutral'),
                              ),
                              DropdownMenuItem(
                                value: AssessmentResultDirection.higherBetter,
                                child: const Text('Higher is better'),
                              ),
                              DropdownMenuItem(
                                value: AssessmentResultDirection.lowerBetter,
                                child: const Text('Lower is better'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _resultDirection = v);
                                setModalState(() {});
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              // Save button pinned at bottom
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5A40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving ? 'Saving…' : 'Save',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
