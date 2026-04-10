import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_design_tokens.dart';
import '../../../core/design/form_styles.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/gradient_screen_header.dart';
import '../trial_detail_screen.dart';
import 'create_standalone_trial_wizard_usecase.dart';
import 'plot_generation_engine.dart';

const _kTypeChips = ['CHK', 'HERB', 'FUNG', 'INSEC', 'PGR', 'OTHER'];

class _TreatmentRowState {
  _TreatmentRowState({
    required this.codeController,
    required this.nameController,
    this.type,
  });

  final TextEditingController codeController;
  final TextEditingController nameController;
  String? type;
}

class _AssessmentDraft {
  _AssessmentDraft({
    required this.name,
    this.unit,
    this.scaleMin,
    this.scaleMax,
    required this.dataType,
  });

  final String name;
  final String? unit;
  final double? scaleMin;
  final double? scaleMax;
  final String dataType;
}

/// Full-screen flow: new standalone trial with structure in one session.
class TrialCreationWizard extends ConsumerStatefulWidget {
  const TrialCreationWizard({super.key});

  @override
  ConsumerState<TrialCreationWizard> createState() =>
      _TrialCreationWizardState();
}

class _TrialCreationWizardState extends ConsumerState<TrialCreationWizard> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  final _nameController = TextEditingController();
  final _cropController = TextEditingController();
  final _locationController = TextEditingController();
  final _seasonController = TextEditingController();
  String _design = PlotGenerationEngine.designRcbd;

  var _treatmentCount = 4;
  late List<_TreatmentRowState> _treatmentRows;

  var _repCount = 4;

  final List<_AssessmentDraft> _assessments = [];
  bool _customAssessmentExpanded = false;
  final _customNameController = TextEditingController();
  final _customUnitController = TextEditingController(text: '%');
  final _customMinController = TextEditingController(text: '0');
  final _customMaxController = TextEditingController(text: '100');
  String _customDataType = 'numeric';

  var _submitting = false;

  static const _previewRandomSeed = 42;

  @override
  void initState() {
    super.initState();
    _seasonController.text = '${DateTime.now().year}';
    _treatmentRows = _buildTreatmentRows(_treatmentCount);
    _nameController.addListener(() => setState(() {}));
  }

  List<_TreatmentRowState> _buildTreatmentRows(int count) {
    final list = <_TreatmentRowState>[];
    for (var i = 0; i < count; i++) {
      final code = i == 0 ? 'CHK' : 'TRT${i + 1}';
      list.add(
        _TreatmentRowState(
          codeController: TextEditingController(text: code),
          nameController: TextEditingController(),
          type: i == 0 ? 'CHK' : null,
        ),
      );
    }
    return list;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _cropController.dispose();
    _locationController.dispose();
    _seasonController.dispose();
    for (final r in _treatmentRows) {
      r.codeController.dispose();
      r.nameController.dispose();
    }
    _customNameController.dispose();
    _customUnitController.dispose();
    _customMinController.dispose();
    _customMaxController.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard trial setup?'),
        content: const Text(
          'All entered information will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _onCancelPressed() async {
    if (await _confirmDiscard() && mounted) {
      Navigator.of(context).pop();
    }
  }

  String _designSubtitle(String d) {
    switch (d) {
      case PlotGenerationEngine.designRcbd:
        return 'Randomize within each rep/block';
      case PlotGenerationEngine.designCrd:
        return 'Randomize across the full trial';
      case PlotGenerationEngine.designNonRandomized:
        return 'Same treatment order every rep';
      default:
        return '';
    }
  }

  String _assignmentSummaryLine(String d) {
    switch (d) {
      case PlotGenerationEngine.designRcbd:
        return 'Randomized by block (RCBD)';
      case PlotGenerationEngine.designCrd:
        return 'Randomized across full trial (CRD)';
      case PlotGenerationEngine.designNonRandomized:
        return 'Fixed order every rep (non-randomized)';
      default:
        return d;
    }
  }

  bool get _step1Valid => _nameController.text.trim().isNotEmpty;

  bool get _step2Valid {
    if (_treatmentRows.length < 2) return false;
    return _treatmentRows.every((r) => r.codeController.text.trim().isNotEmpty);
  }

  void _setTreatmentCount(int n) {
    if (n < 2 || n > 20) return;
    setState(() {
      if (n > _treatmentRows.length) {
        for (var i = _treatmentRows.length; i < n; i++) {
          _treatmentRows.add(
            _TreatmentRowState(
              codeController: TextEditingController(text: 'TRT${i + 1}'),
              nameController: TextEditingController(),
              type: null,
            ),
          );
        }
      } else {
        for (var i = _treatmentRows.length - 1; i >= n; i--) {
          _treatmentRows[i].codeController.dispose();
          _treatmentRows[i].nameController.dispose();
          _treatmentRows.removeAt(i);
        }
      }
      _treatmentCount = n;
    });
  }

  void _addPresetAssessment({
    required String name,
    String? unit,
    required double min,
    required double max,
    required String dataType,
  }) {
    setState(() {
      _assessments.add(_AssessmentDraft(
        name: name,
        unit: unit,
        scaleMin: min,
        scaleMax: max,
        dataType: dataType,
      ));
    });
  }

  void _addCustomAssessment() {
    final name = _customNameController.text.trim();
    if (name.isEmpty) return;
    final min = double.tryParse(_customMinController.text.trim()) ?? 0;
    final max = double.tryParse(_customMaxController.text.trim()) ?? 100;
    setState(() {
      _assessments.add(_AssessmentDraft(
        name: name,
        unit: _customUnitController.text.trim().isEmpty
            ? null
            : _customUnitController.text.trim(),
        scaleMin: min,
        scaleMax: max,
        dataType: _customDataType,
      ));
      _customNameController.clear();
    });
  }

  Future<void> _submit() async {
    if (!_step1Valid || !_step2Valid || _submitting) return;
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final nav = Navigator.of(context);
    setState(() => _submitting = true);
    final userId = await ref.read(currentUserIdProvider.future);
    if (!mounted) return;
    final useCase = ref.read(createStandaloneTrialWizardUseCaseProvider);
    final treatments = _treatmentRows
        .map(
          (r) => StandaloneWizardTreatmentInput(
            code: r.codeController.text.trim(),
            name: r.nameController.text.trim().isEmpty
                ? null
                : r.nameController.text.trim(),
            treatmentType: r.type,
          ),
        )
        .toList();
    final assessmentInputs = _assessments
        .map(
          (a) => StandaloneWizardAssessmentInput(
            name: a.name,
            unit: a.unit,
            scaleMin: a.scaleMin,
            scaleMax: a.scaleMax,
            dataType: a.dataType,
          ),
        )
        .toList();

    final result = await useCase.execute(
      CreateStandaloneTrialWizardInput(
        trialName: _nameController.text.trim(),
        crop: _cropController.text,
        location: _locationController.text,
        season: _seasonController.text,
        experimentalDesign: _design,
        treatments: treatments,
        repCount: _repCount,
        assessments: assessmentInputs,
        performedByUserId: userId,
      ),
    );

    if (!mounted) return;
    setState(() => _submitting = false);
    if (!mounted) return;

    if (!result.success || result.trialId == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Could not create trial'),
          backgroundColor: errorColor,
        ),
      );
      return;
    }

    ref.invalidate(trialsStreamProvider);
    ref.invalidate(customTrialsProvider);
    ref.invalidate(trialProvider(result.trialId!));

    final trial = await ref.read(trialRepositoryProvider).getTrialById(result.trialId!);
    if (!mounted) return;
    if (trial == null) return;

    messenger.showSnackBar(
      const SnackBar(content: Text('Trial created')),
    );

    await nav.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TrialDetailScreen(trial: trial),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppDesignTokens.backgroundSurface,
        appBar: GradientScreenHeader(
          title: 'New Standalone Trial',
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _onCancelPressed,
            tooltip: 'Cancel',
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: List.generate(5, (i) {
                  final active = i == _pageIndex;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: active
                              ? AppDesignTokens.primary
                              : AppDesignTokens.borderCrisp,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _pageIndex = i),
                children: [
                  _buildStepIdentity(context),
                  _buildStepTreatments(context),
                  _buildStepPlots(context),
                  _buildStepAssessments(context),
                  _buildStepConfirm(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navRow({
    required BuildContext context,
    required bool showBack,
    required VoidCallback? onNext,
    required String nextLabel,
    bool nextEnabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (showBack)
            OutlinedButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                );
              },
              child: const Text('Back'),
            )
          else
            const SizedBox(width: 88),
          const Spacer(),
          FilledButton(
            onPressed: (nextEnabled && !_submitting) ? onNext : null,
            child: Text(nextLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIdentity(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _nameController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Trial name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cropController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Crop',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Location',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _seasonController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Season',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Study design',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.primaryText,
                    ),
              ),
              const SizedBox(height: 8),
              ...[
                PlotGenerationEngine.designRcbd,
                PlotGenerationEngine.designCrd,
                PlotGenerationEngine.designNonRandomized,
              ].map((d) {
                final selected = _design == d;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: selected
                        ? AppDesignTokens.primary.withValues(alpha: 0.12)
                        : AppDesignTokens.cardSurface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => setState(() => _design = d),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppDesignTokens.primary
                                : AppDesignTokens.borderCrisp,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppDesignTokens.primaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _designSubtitle(d),
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(width: 88),
              const Spacer(),
              FilledButton(
                onPressed: (!_step1Valid || _submitting)
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final errorColor = Theme.of(context).colorScheme.error;
                        final name = _nameController.text.trim();
                        final exists = await ref
                            .read(trialRepositoryProvider)
                            .trialNameExists(name);
                        if (!mounted) return;
                        if (exists) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'A trial named "$name" already exists. Choose another name.',
                              ),
                              backgroundColor: errorColor,
                            ),
                          );
                          return;
                        }
                        await _pageController.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      },
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepTreatments(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'How many treatments including check?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              IconButton(
                onPressed: () => _setTreatmentCount(_treatmentCount - 1),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$_treatmentCount',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              IconButton(
                onPressed: () => _setTreatmentCount(_treatmentCount + 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _treatmentRows.length,
            itemBuilder: (context, index) {
              final row = _treatmentRows[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: AppDesignTokens.cardSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppDesignTokens.borderCrisp),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Treatment ${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppDesignTokens.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: row.codeController,
                        decoration: FormStyles.inputDecoration(
                          labelText: 'Code',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: row.nameController,
                        decoration: FormStyles.inputDecoration(
                          labelText: 'Product name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _kTypeChips.map((chip) {
                          final sel = row.type == chip;
                          return FilterChip(
                            label: Text(chip),
                            selected: sel,
                            onSelected: (bool selected) {
                              setState(() {
                                row.type = selected ? chip : null;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _navRow(
          context: context,
          showBack: true,
          nextEnabled: _step2Valid,
          nextLabel: 'Next',
          onNext: () => _pageController.nextPage(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        ),
      ],
    );
  }

  Widget _buildStepPlots(BuildContext context) {
    final tCount = _treatmentRows.length;
    final total = tCount * _repCount;
    final preview = PlotGenerationEngine.generate(
      treatmentCount: tCount,
      repCount: _repCount,
      experimentalDesign: _design,
      random: Random(_previewRandomSeed),
    );
    final lines = <String>[
      '$tCount treatments × $_repCount reps = $total plots',
      'Design: $_design — ${_designSubtitle(_design)}',
      'Rep-based numbering (default)',
      '',
    ];
    for (var r = 1; r <= _repCount; r++) {
      final start = r * 100 + 1;
      final end = r * 100 + tCount;
      lines.add('Rep $r: Plot $start–$end');
    }
    lines.add('');
    lines.add('Assignment preview:');
    var idx = 0;
    for (var r = 1; r <= _repCount; r++) {
      final codes = <String>[];
      for (var p = 0; p < tCount; p++) {
        final ti = preview.treatmentIndexPerPlot[idx];
        codes.add(_treatmentRows[ti].codeController.text.trim());
        idx++;
      }
      final suffix = _design == PlotGenerationEngine.designNonRandomized
          ? 'sequential'
          : 'randomized';
      lines.add('Rep $r: ${codes.join(', ')} ($suffix)');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'How many reps?',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: _repCount > 1
                    ? () => setState(() => _repCount--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$_repCount',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              IconButton(
                onPressed: _repCount < 8
                    ? () => setState(() => _repCount++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesignTokens.cardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppDesignTokens.borderCrisp),
              ),
              child: Text(
                lines.join('\n'),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppDesignTokens.primaryText,
                ),
              ),
            ),
          ),
        ),
        _navRow(
          context: context,
          showBack: true,
          nextLabel: 'Next',
          onNext: () => _pageController.nextPage(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        ),
      ],
    );
  }

  Widget _buildStepAssessments(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Add assessments now or skip',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('% control (0–100)'),
                onPressed: () => _addPresetAssessment(
                  name: '% control',
                  unit: '%',
                  min: 0,
                  max: 100,
                  dataType: 'numeric',
                ),
              ),
              ActionChip(
                label: const Text('% injury (0–100)'),
                onPressed: () => _addPresetAssessment(
                  name: '% injury',
                  unit: '%',
                  min: 0,
                  max: 100,
                  dataType: 'numeric',
                ),
              ),
              ActionChip(
                label: const Text('Count (0–999)'),
                onPressed: () => _addPresetAssessment(
                  name: 'Count',
                  unit: 'count',
                  min: 0,
                  max: 999,
                  dataType: 'count',
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextButton(
            onPressed: () =>
                setState(() => _customAssessmentExpanded = !_customAssessmentExpanded),
            child: Text(
              _customAssessmentExpanded
                  ? 'Hide custom assessment'
                  : 'Add custom assessment',
            ),
          ),
        ),
        if (_customAssessmentExpanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _customNameController,
                  decoration: FormStyles.inputDecoration(
                    labelText: 'Assessment name',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _customUnitController,
                  decoration: FormStyles.inputDecoration(
                    labelText: 'Unit',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customMinController,
                        keyboardType: TextInputType.number,
                        decoration: FormStyles.inputDecoration(
                          labelText: 'Scale min',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _customMaxController,
                        keyboardType: TextInputType.number,
                        decoration: FormStyles.inputDecoration(
                          labelText: 'Scale max',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Numeric'),
                      selected: _customDataType == 'numeric',
                      onSelected: (bool v) {
                        if (v) setState(() => _customDataType = 'numeric');
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Count'),
                      selected: _customDataType == 'count',
                      onSelected: (bool v) {
                        if (v) setState(() => _customDataType = 'count');
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Ordinal'),
                      selected: _customDataType == 'ordinal',
                      onSelected: (bool v) {
                        if (v) setState(() => _customDataType = 'ordinal');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _addCustomAssessment,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _assessments.length,
            itemBuilder: (context, i) {
              final a = _assessments[i];
              return ListTile(
                title: Text(a.name),
                subtitle: Text('${a.dataType} · ${a.unit ?? '—'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _assessments.removeAt(i)),
                ),
              );
            },
          ),
        ),
        TextButton(
          onPressed: () => _pageController.nextPage(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
          child: const Text('Skip — add assessments later'),
        ),
        _navRow(
          context: context,
          showBack: true,
          nextLabel: 'Continue',
          onNext: () => _pageController.nextPage(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConfirm(BuildContext context) {
    final tCount = _treatmentRows.length;
    final plots = tCount * _repCount;
    const startPlot = 101;
    final endPlot = _repCount * 100 + tCount;
    final assessNames =
        _assessments.map((a) => a.name).join(', ');
    final summary = [
      'Trial: "${_nameController.text.trim()}"',
      if (_cropController.text.trim().isNotEmpty)
        'Crop: ${_cropController.text.trim()}',
      if (_locationController.text.trim().isNotEmpty)
        'Location: ${_locationController.text.trim()}',
      if (_seasonController.text.trim().isNotEmpty)
        'Season: ${_seasonController.text.trim()}',
      'Design: $_design',
      'Treatments: $tCount',
      'Reps: $_repCount',
      'Plots: $plots',
      'Numbering: Rep-based ($startPlot–$endPlot)',
      'Assignments: ${_assignmentSummaryLine(_design)}',
      if (_assessments.isNotEmpty)
        'Assessments: ${_assessments.length} ($assessNames)'
      else
        'Assessments: none',
    ].join('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesignTokens.cardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppDesignTokens.borderCrisp),
              ),
              child: Text(
                summary,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppDesignTokens.primaryText,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create Trial'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: _submitting
                  ? null
                  : () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
              child: const Text('Back'),
            ),
          ),
        ),
      ],
    );
  }
}
