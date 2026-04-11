import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/assessment_result_direction.dart';
import '../../../core/database/app_database.dart';
import '../../../core/design/form_styles.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_draggable_modal_sheet.dart';
import '../../../core/widgets/standard_form_bottom_sheet.dart';
import '../../assessments/assessment_library.dart';
import '../../assessments/assessment_library_picker.dart';
import '../../../core/protocol_edit_blocked_exception.dart';

const List<String> _kAssessmentMethods = [
  'Visual rating',
  'Measured',
  'Counted',
  'Weighed',
  'Calculated',
];

/// Bottom sheet: add custom assessment (same behavior as legacy dialog).
Future<void> showAddCustomAssessmentSheet(
  BuildContext context,
  WidgetRef ref, {
  required Trial trial,
}) async {
  await showAppDraggableModalSheet<void>(
    context: context,
    useRootNavigator: true,
    sheetBuilder: (sheetContext, scrollController) => _AddCustomAssessmentSheetBody(
      trial: trial,
      scrollController: scrollController,
      parentContext: context,
      onClose: () {
        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      },
    ),
  );
}

class _AddCustomAssessmentSheetBody extends ConsumerStatefulWidget {
  const _AddCustomAssessmentSheetBody({
    required this.trial,
    required this.scrollController,
    required this.parentContext,
    required this.onClose,
  });

  final Trial trial;
  final ScrollController scrollController;
  final BuildContext parentContext;
  final VoidCallback onClose;

  @override
  ConsumerState<_AddCustomAssessmentSheetBody> createState() =>
      _AddCustomAssessmentSheetBodyState();
}

class _AddCustomAssessmentSheetBodyState
    extends ConsumerState<_AddCustomAssessmentSheetBody> {
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _scaleMinController;
  late final TextEditingController _scaleMaxController;
  String? _selectedType;
  String _selectedResultDirection = AssessmentResultDirection.neutral;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _unitController = TextEditingController();
    _scaleMinController = TextEditingController();
    _scaleMaxController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _scaleMinController.dispose();
    _scaleMaxController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    try {
      final defRepo = ref.read(assessmentDefinitionRepositoryProvider);
      final code =
          'CUSTOM_${widget.trial.id}_${DateTime.now().millisecondsSinceEpoch}';
      final scaleMin = double.tryParse(_scaleMinController.text.trim());
      final scaleMax = double.tryParse(_scaleMaxController.text.trim());
      final unitStr = _unitController.text.trim();
      final defId = await defRepo.insertCustom(
        code: code,
        name: name,
        category: 'custom',
        dataType: 'numeric',
        unit: unitStr.isEmpty ? null : unitStr,
        scaleMin: scaleMin,
        scaleMax: scaleMax,
        assessmentMethod: _selectedType,
        cropPart: null,
        timingCode: null,
        daysAfterTreatment: null,
        timingDescription: null,
        validMin: null,
        validMax: null,
        eppoCode: null,
        resultDirection: _selectedResultDirection,
      );
      await ref.read(trialAssessmentRepositoryProvider).addToTrial(
            trialId: widget.trial.id,
            assessmentDefinitionId: defId,
            displayNameOverride: name,
            selectedManually: true,
          );
      ref.invalidate(
          trialAssessmentsWithDefinitionsForTrialProvider(widget.trial.id));
      if (mounted) widget.onClose();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StandardFormBottomSheetLayout(
      title: 'Add Assessment',
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      body: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(
          FormStyles.formSheetHorizontalPadding,
          0,
          FormStyles.formSheetHorizontalPadding,
          FormStyles.formSheetSectionSpacing,
        ),
        children: [
          TextButton.icon(
            onPressed: () async {
              final trialId = widget.trial.id;
              final container = ProviderScope.containerOf(context);
              final pairs = await container.read(
                trialAssessmentsWithDefinitionsForTrialProvider(trialId).future,
              );
              final existing = curatedLibraryIdsFromInstructionOverrides(
                pairs.map((p) => p.$1.instructionOverride),
              );
              if (context.mounted) Navigator.of(context).pop();
              if (!widget.parentContext.mounted) return;
              final picks = await AssessmentLibraryPicker.open(
                widget.parentContext,
                libraryEntryIdsAlreadyChosen: existing,
              );
              if (picks == null || picks.isEmpty) return;
              try {
                await container
                    .read(addCuratedLibraryAssessmentsToTrialUseCaseProvider)
                    .execute(
                      trialId: trialId,
                      selections: picks,
                      skipLibraryEntryIds: existing,
                    );
                container.invalidate(
                  trialAssessmentsWithDefinitionsForTrialProvider(trialId),
                );
              } on ProtocolEditBlockedException catch (e) {
                if (!widget.parentContext.mounted) return;
                ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                  SnackBar(
                    content: Text(e.message),
                    backgroundColor:
                        Theme.of(widget.parentContext).colorScheme.error,
                  ),
                );
              } catch (e) {
                if (!widget.parentContext.mounted) return;
                ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                  SnackBar(
                    content: Text('Save failed: $e'),
                    backgroundColor:
                        Theme.of(widget.parentContext).colorScheme.error,
                  ),
                );
              }
            },
            icon: const Icon(Icons.library_books_outlined, size: 20),
            label: const Text('Add from library instead'),
          ),
          const SizedBox(height: FormStyles.formSheetFieldSpacing),
          TextFormField(
            controller: _nameController,
            decoration: FormStyles.inputDecoration(
              labelText: 'Assessment name',
            ),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: FormStyles.formSheetFieldSpacing),
          DropdownButtonFormField<String?>(
            key: ValueKey(_selectedType),
            initialValue: _selectedType,
            decoration: FormStyles.inputDecoration(
              labelText: 'Assessment type',
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('—')),
              ..._kAssessmentMethods.map(
                (t) => DropdownMenuItem<String?>(value: t, child: Text(t)),
              ),
            ],
            onChanged: (v) => setState(() => _selectedType = v),
          ),
          const SizedBox(height: FormStyles.formSheetFieldSpacing),
          TextFormField(
            controller: _unitController,
            decoration: FormStyles.inputDecoration(
              labelText: 'Unit e.g. %, cm, kg/ha',
            ),
          ),
          const SizedBox(height: FormStyles.formSheetFieldSpacing),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _scaleMinController,
                  keyboardType: TextInputType.number,
                  decoration: FormStyles.inputDecoration(
                    labelText: 'Scale min',
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (double.tryParse(v.trim()) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: FormStyles.formSheetFieldSpacing),
              Expanded(
                child: TextFormField(
                  controller: _scaleMaxController,
                  keyboardType: TextInputType.number,
                  decoration: FormStyles.inputDecoration(
                    labelText: 'Scale max',
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (double.tryParse(v.trim()) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: FormStyles.formSheetFieldSpacing),
          DropdownButtonFormField<String>(
            initialValue: _selectedResultDirection,
            decoration: FormStyles.inputDecoration(
              labelText: 'Result direction',
            ),
            items: const [
              DropdownMenuItem(
                value: AssessmentResultDirection.neutral,
                child: Text('Neutral'),
              ),
              DropdownMenuItem(
                value: AssessmentResultDirection.higherBetter,
                child: Text('Higher is better'),
              ),
              DropdownMenuItem(
                value: AssessmentResultDirection.lowerBetter,
                child: Text('Lower is better'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _selectedResultDirection = v);
            },
          ),
        ],
      ),
    );
  }
}
