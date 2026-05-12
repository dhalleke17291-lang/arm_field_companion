import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/assessment_result_direction.dart';
import '../../../core/database/app_database.dart';
import '../../../core/design/form_styles.dart';
import '../../../core/ui/assessment_display_helper.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_draggable_modal_sheet.dart';
import '../../../core/widgets/standard_form_bottom_sheet.dart';
import '../../assessments/assessment_library.dart';
import '../../assessments/assessment_library_picker.dart';
import '../assessment_library_system_map.dart';
import '../../../core/protocol_edit_blocked_exception.dart';

/// Normalized display names already on the trial (library + unlinked legacy).
///
/// Unit 5c: pass the [aamByTaId] map so [AssessmentDisplayHelper.compactName]
/// can read the per-column ARM duplicate fields (seDescription / seName) from
/// [ArmAssessmentMetadata] first and keep the TA columns only as fallback.
Set<String> _existingTrialAssessmentNamesNormalized({
  required List<(TrialAssessment, AssessmentDefinition)> pairs,
  required List<Assessment> legacy,
  Map<int, ArmAssessmentMetadataData> aamByTaId =
      const <int, ArmAssessmentMetadataData>{},
}) {
  final linkedLegacyIds =
      pairs.map((e) => e.$1.legacyAssessmentId).whereType<int>().toSet();
  final out = <String>{};
  for (final p in pairs) {
    out.add(
      AssessmentDisplayHelper.compactName(
        p.$1,
        def: p.$2,
        aam: aamByTaId[p.$1.id],
      ).trim().toLowerCase(),
    );
  }
  for (final a in legacy) {
    if (linkedLegacyIds.contains(a.id)) continue;
    out.add(
      AssessmentDisplayHelper.legacyAssessmentDisplayName(a.name)
          .trim()
          .toLowerCase(),
    );
  }
  return out;
}

Future<Set<String>> _loadExistingTrialAssessmentNamesNormalizedForTrial(
  int trialId, {
  required Future<List<(TrialAssessment, AssessmentDefinition)>> pairsFuture,
  required Future<List<Assessment>> legacyFuture,
  Future<Map<int, ArmAssessmentMetadataData>>? aamMapFuture,
}) async {
  return _existingTrialAssessmentNamesNormalized(
    pairs: await pairsFuture,
    legacy: await legacyFuture,
    aamByTaId: aamMapFuture == null ? const {} : await aamMapFuture,
  );
}

Future<bool> _confirmDuplicateAssessmentNames(
  BuildContext context, {
  required List<String> displayNames,
}) async {
  if (displayNames.isEmpty) return true;
  final unique = displayNames.toSet().toList()..sort();
  final preview = unique.take(3).join(', ');
  final suffix = unique.length > 3 ? '…' : '';
  final message = unique.length == 1
      ? 'An assessment named \'${unique.first}\' already exists on this trial. Add anyway?'
      : '${unique.length} selected assessments already exist on this trial ($preview$suffix). Add anyway?';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Duplicate name'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Add anyway'),
        ),
      ],
    ),
  );
  return ok == true;
}

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
    sheetBuilder: (sheetContext, scrollController) =>
        _AddCustomAssessmentSheetBody(
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
    final existing = await _loadExistingTrialAssessmentNamesNormalizedForTrial(
      widget.trial.id,
      pairsFuture: ref.read(
        trialAssessmentsWithDefinitionsForTrialProvider(widget.trial.id).future,
      ),
      legacyFuture:
          ref.read(assessmentsForTrialProvider(widget.trial.id).future),
      aamMapFuture: ref.read(
        armAssessmentMetadataMapForTrialProvider(widget.trial.id).future,
      ),
    );
    if (existing.contains(name.toLowerCase()) && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Duplicate name'),
          content: Text(
            'An assessment named \'$name\' already exists on this trial. Add anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    try {
      final defRepo = ref.read(assessmentDefinitionRepositoryProvider);
      final code =
          'CUSTOM_${widget.trial.id}_${DateTime.now().millisecondsSinceEpoch}';
      final scaleMin = double.tryParse(_scaleMinController.text.trim());
      final scaleMax = double.tryParse(_scaleMaxController.text.trim());
      final unitStr = _unitController.text.trim();
      final unit = unitStr.isEmpty ? null : unitStr;
      final systemCode = canonicalSystemAssessmentCode(
        name: name,
        dataType: 'numeric',
        unit: unit,
        scaleMin: scaleMin,
        scaleMax: scaleMax,
        category: 'custom',
      );
      final systemDef =
          systemCode == null ? null : await defRepo.getByCode(systemCode);
      final defId = systemDef?.id ??
          await defRepo.insertCustom(
            code: code,
            name: name,
            category: 'custom',
            dataType: 'numeric',
            unit: unit,
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
              final namesExisting =
                  await _loadExistingTrialAssessmentNamesNormalizedForTrial(
                trialId,
                pairsFuture: container.read(
                  trialAssessmentsWithDefinitionsForTrialProvider(trialId)
                      .future,
                ),
                legacyFuture:
                    container.read(assessmentsForTrialProvider(trialId).future),
                aamMapFuture: container.read(
                  armAssessmentMetadataMapForTrialProvider(trialId).future,
                ),
              );
              final dupLabels = picks
                  .map((e) => e.name.trim())
                  .where((n) => namesExisting.contains(n.toLowerCase()))
                  .toList();
              if (dupLabels.isNotEmpty) {
                if (!widget.parentContext.mounted) return;
                final proceed = await _confirmDuplicateAssessmentNames(
                  widget.parentContext,
                  displayNames: dupLabels,
                );
                if (!proceed) return;
              }
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
                    if (double.tryParse(v.trim()) == null) {
                      return 'Invalid number';
                    }
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
                    if (double.tryParse(v.trim()) == null) {
                      return 'Invalid number';
                    }
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
