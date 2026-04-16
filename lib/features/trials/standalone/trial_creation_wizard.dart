import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/design/app_design_tokens.dart';
import '../../../core/design/form_styles.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/gradient_screen_header.dart';
import '../../assessments/assessment_library.dart';
import '../../assessments/assessment_library_picker.dart';
import '../trial_detail_screen.dart';
import 'create_standalone_trial_wizard_usecase.dart';
import 'plot_generation_engine.dart';
import 'trial_templates.dart';

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
    this.librarySourceId,
    this.definitionCategory,
  });

  final String name;
  final String? unit;
  final double? scaleMin;
  final double? scaleMax;
  final String dataType;
  final String? librarySourceId;
  final String? definitionCategory;
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
  var _plotsPerRep = 4;
  var _guardRowsEnabled = false;
  var _guardsPerRepEnd = 1;
  final _plotLengthController = TextEditingController();
  final _plotWidthController = TextEditingController();
  final _alleyWidthController = TextEditingController();
  double? _latitude;
  double? _longitude;

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
    _plotsPerRep = _treatmentRows.length;
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

  /// The template currently applied, or null if none / blank start.
  TrialTemplate? _appliedTemplate;

  void _applyTemplate(TrialTemplate t) {
    setState(() {
      _appliedTemplate = t;

      // Treatments
      for (final r in _treatmentRows) {
        r.codeController.dispose();
        r.nameController.dispose();
      }
      _treatmentCount = t.treatments.length;
      _treatmentRows = [
        for (final tr in t.treatments)
          _TreatmentRowState(
            codeController: TextEditingController(text: tr.code),
            nameController: TextEditingController(text: tr.name),
            type: tr.type,
          ),
      ];

      // Design & plots
      _design = t.design;
      _repCount = t.reps;
      _plotsPerRep = t.treatments.length;
      _guardRowsEnabled = t.guardRowsPerEnd > 0;
      _guardsPerRepEnd = t.guardRowsPerEnd;

      // Assessments — resolve library IDs to drafts
      _assessments.clear();
      final libraryById = {
        for (final e in AssessmentLibrary.entries) e.id: e,
      };
      for (final ta in t.assessments) {
        final lib = libraryById[ta.libraryId];
        if (lib == null) continue;
        _assessments.add(
          _AssessmentDraft(
            name: lib.name,
            unit: lib.unit,
            scaleMin: lib.scaleMin,
            scaleMax: lib.scaleMax,
            dataType: lib.dataType,
            librarySourceId: lib.id,
            definitionCategory: lib.category,
          ),
        );
      }
    });
  }

  void _clearTemplate() {
    setState(() {
      _appliedTemplate = null;
      // Reset to defaults
      for (final r in _treatmentRows) {
        r.codeController.dispose();
        r.nameController.dispose();
      }
      _treatmentCount = 4;
      _treatmentRows = _buildTreatmentRows(4);
      _design = PlotGenerationEngine.designRcbd;
      _repCount = 4;
      _plotsPerRep = 4;
      _guardRowsEnabled = false;
      _guardsPerRepEnd = 1;
      _assessments.clear();
    });
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
    _plotLengthController.dispose();
    _plotWidthController.dispose();
    _alleyWidthController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentGps() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location services are disabled. Enable and try again.',
          ),
        ),
      );
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied.')),
      );
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location updated from GPS.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
    }
  }

  double? _parseOptionalDouble(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
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
      if (_design == PlotGenerationEngine.designRcbd) {
        // RCBD: snap to nearest valid multiple of new treatment count
        final tc = _treatmentRows.length;
        final reps = (_plotsPerRep / tc).ceil().clamp(1, 50 ~/ tc);
        _plotsPerRep = reps * tc;
      } else if (_plotsPerRep < _treatmentRows.length) {
        _plotsPerRep = _treatmentRows.length;
      }
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
        librarySourceId: null,
        definitionCategory: null,
      ));
    });
  }

  bool _assessmentNameExistsCaseInsensitive(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return false;
    return _assessments.any((a) => a.name.trim().toLowerCase() == n);
  }

  Future<bool> _confirmAddAssessmentDespiteDuplicateName(String name) async {
    if (!_assessmentNameExistsCaseInsensitive(name)) return true;
    if (!mounted) return false;
    final add = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assessment name'),
        content: Text(
          'An assessment named "$name" is already in your list. Add anyway?',
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
    return add == true;
  }

  Future<void> _openAssessmentLibrary() async {
    final skip = _assessments
        .map((a) => a.librarySourceId)
        .whereType<String>()
        .toSet();
    final picks = await AssessmentLibraryPicker.open(
      context,
      libraryEntryIdsAlreadyChosen: skip,
    );
    if (picks == null || picks.isEmpty) return;
    for (final e in picks) {
      if (!mounted) return;
      if (_assessmentNameExistsCaseInsensitive(e.name)) {
        final ok = await _confirmAddAssessmentDespiteDuplicateName(e.name);
        if (!ok) continue;
      }
      if (!mounted) return;
      setState(() {
        _assessments.add(
          _AssessmentDraft(
            name: e.name,
            unit: e.unit,
            scaleMin: e.scaleMin,
            scaleMax: e.scaleMax,
            dataType: e.dataType,
            librarySourceId: e.id,
            definitionCategory: e.category,
          ),
        );
      });
    }
  }

  Future<void> _addCustomAssessment() async {
    final name = _customNameController.text.trim();
    if (name.isEmpty) return;
    if (!await _confirmAddAssessmentDespiteDuplicateName(name)) return;
    if (!mounted) return;
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
        librarySourceId: null,
        definitionCategory: null,
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
            curatedLibraryEntryId: a.librarySourceId,
            definitionCategory: a.definitionCategory,
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
        plotsPerRep: _plotsPerRep,
        guardRowsPerRep: _guardRowsEnabled ? _guardsPerRepEnd : 0,
        plotLengthM: _parseOptionalDouble(_plotLengthController.text),
        plotWidthM: _parseOptionalDouble(_plotWidthController.text),
        alleyLengthM: _parseOptionalDouble(_alleyWidthController.text),
        latitude: _latitude,
        longitude: _longitude,
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
          title: 'New Custom Trial',
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _onCancelPressed,
            tooltip: 'Cancel',
          ),
        ),
        body: SafeArea(top: false, child: Column(
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
        )),
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
              // Template selector
              Text(
                'Start from template',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.primaryText,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pre-fills treatments, assessments, and design. '
                'Everything stays editable.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final t in trialTemplates)
                    _TemplateChip(
                      template: t,
                      selected: _appliedTemplate?.id == t.id,
                      onTap: () {
                        if (_appliedTemplate?.id == t.id) {
                          _clearTemplate();
                        } else {
                          _applyTemplate(t);
                        }
                      },
                    ),
                ],
              ),
              if (_appliedTemplate != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppDesignTokens.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _appliedTemplate!.icon,
                        size: 18,
                        color: AppDesignTokens.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_appliedTemplate!.name} — '
                          '${_appliedTemplate!.treatments.length} treatments, '
                          '${_appliedTemplate!.assessments.length} assessments, '
                          '${_appliedTemplate!.reps} reps ${_appliedTemplate!.design}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              // Trial identity fields
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
                      onTap: () => setState(() {
                        _design = d;
                        if (d == PlotGenerationEngine.designRcbd) {
                          // Snap to nearest valid multiple
                          final tc = _treatmentRows.length;
                          final reps = (_plotsPerRep / tc).ceil().clamp(1, 50 ~/ tc);
                          _plotsPerRep = reps * tc;
                        }
                      }),
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
                tooltip: 'Decrease treatments',
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
                tooltip: 'Increase treatments',
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

  int get _guardRowsPerRepEffective =>
      _guardRowsEnabled ? _guardsPerRepEnd : 0;

  String _formatRepLayoutLine(int rep, List<PlotLayoutRow> rowPlots) {
    final lead = <String>[];
    final data = <String>[];
    final trail = <String>[];
    var i = 0;
    while (i < rowPlots.length && rowPlots[i].isGuardRow) {
      lead.add('[G] ${rowPlots[i].plotId}');
      i++;
    }
    while (i < rowPlots.length && !rowPlots[i].isGuardRow) {
      data.add(rowPlots[i].plotId);
      i++;
    }
    while (i < rowPlots.length) {
      final p = rowPlots[i];
      if (p.isGuardRow) {
        trail.add('${p.plotId} [G]');
      }
      i++;
    }
    final segs = <String>[];
    if (lead.isNotEmpty) segs.add(lead.join(' '));
    if (data.isNotEmpty) segs.add(data.join(' '));
    if (trail.isNotEmpty) segs.add(trail.join(' '));
    return 'Rep $rep: ${segs.join(' | ')}';
  }

  List<String> _plotLayoutPreviewLines() {
    final tCount = _treatmentRows.length;
    final preview = PlotGenerationEngine.generate(
      treatmentCount: tCount,
      plotsPerRep: _plotsPerRep,
      repCount: _repCount,
      experimentalDesign: _design,
      guardRowsPerRep: _guardRowsPerRepEffective,
      random: Random(_previewRandomSeed),
    );

    final dataTotal = _plotsPerRep * _repCount;
    final guardTotal =
        _guardRowsEnabled ? _guardsPerRepEnd * 2 * _repCount : 0;
    final lines = <String>[
      '$tCount treatments × $_plotsPerRep plots per rep × $_repCount reps = '
          '$dataTotal data plots'
          '${guardTotal > 0 ? ' + $guardTotal guard plots = ${dataTotal + guardTotal} total' : ''}',
      'Design: $_design — ${_designSubtitle(_design)}',
      'Rep-based numbering (default)',
      '',
    ];

    for (var r = 1; r <= _repCount; r++) {
      final rowPlots = preview.plots.where((p) => p.rep == r).toList();
      lines.add(_formatRepLayoutLine(r, rowPlots));
    }

    lines.add('');
    lines.add('Assignment preview:');
    var idx = 0;
    for (var r = 1; r <= _repCount; r++) {
      final codes = <String>[];
      while (idx < preview.plots.length && preview.plots[idx].rep == r) {
        final p = preview.plots[idx];
        if (!p.isGuardRow) {
          final ti = preview.treatmentIndexPerPlot[idx];
          codes.add(_treatmentRows[ti].codeController.text.trim());
        }
        idx++;
      }
      final suffix = _design == PlotGenerationEngine.designNonRandomized
          ? 'sequential'
          : 'randomized';
      lines.add('Rep $r: ${codes.join(', ')} ($suffix)');
    }

    return lines;
  }

  Widget _buildStepPlots(BuildContext context) {
    final tMin = _treatmentRows.length;
    final lines = _plotLayoutPreviewLines();

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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Decrease reps',
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
                  color: AppDesignTokens.primaryText,
                ),
              ),
              IconButton(
                tooltip: 'Increase reps',
                onPressed: _repCount < 50
                    ? () => setState(() => _repCount++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
        if (_design == PlotGenerationEngine.designRcbd)
          // RCBD: plots per rep must be an even multiple of treatment count
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Plots per rep (must be multiple of $tMin treatments)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppDesignTokens.primaryText,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Decrease plots per rep',
                      onPressed: _plotsPerRep > tMin
                          ? () => setState(() => _plotsPerRep -= tMin)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$_plotsPerRep',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppDesignTokens.primaryText,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Increase plots per rep',
                      onPressed: _plotsPerRep < 50
                          ? () => setState(() => _plotsPerRep += tMin)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${_plotsPerRep ~/ tMin} per treatment — RCBD balanced',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Plots per rep (minimum: $tMin for your treatments)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.primaryText,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Decrease plots per rep',
                  onPressed: _plotsPerRep > tMin
                      ? () => setState(() => _plotsPerRep--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_plotsPerRep',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
                IconButton(
                  tooltip: 'Increase plots per rep',
                  onPressed: _plotsPerRep < 50
                      ? () => setState(() => _plotsPerRep++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Add guard rows',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.primaryText,
              ),
            ),
            value: _guardRowsEnabled,
            onChanged: (v) => setState(() => _guardRowsEnabled = v),
          ),
        ),
        if (_guardRowsEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Guards per rep end',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.primaryText,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Decrease guards',
                  onPressed: _guardsPerRepEnd > 1
                      ? () => setState(() => _guardsPerRepEnd--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_guardsPerRepEnd',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
                IconButton(
                  tooltip: 'Increase guards',
                  onPressed: _guardsPerRepEnd < 3
                      ? () => setState(() => _guardsPerRepEnd++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExpansionTile(
                  initiallyExpanded: false,
                  title: const Text(
                    'Plot dimensions (optional)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.primaryText,
                    ),
                  ),
                  children: [
                    TextField(
                      controller: _plotLengthController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: FormStyles.inputDecoration(
                        labelText: 'Plot length (meters)',
                        hintText: 'e.g. 10',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _plotWidthController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: FormStyles.inputDecoration(
                        labelText: 'Plot width (meters)',
                        hintText: 'e.g. 3',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _alleyWidthController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: FormStyles.inputDecoration(
                        labelText: 'Alley width (meters)',
                        hintText: 'e.g. 1.5',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _useCurrentGps,
                  icon: const Icon(Icons.gps_fixed, size: 18),
                  label: const Text('Use current location'),
                ),
                if (_latitude != null && _longitude != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Latitude: ${_latitude!.toStringAsFixed(6)}, '
                    'longitude: ${_longitude!.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
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
              ],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _submitting ? null : _openAssessmentLibrary,
                icon: const Icon(Icons.library_books_outlined, size: 20),
                label: const Text('Browse Library'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppDesignTokens.primary,
                  foregroundColor: AppDesignTokens.onPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Quick presets',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
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
                  onPressed: () async {
                    await _addCustomAssessment();
                  },
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
                  tooltip: 'Remove assessment',
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
    final dataPlots = _plotsPerRep * _repCount;
    final guardPlots =
        _guardRowsEnabled ? _guardsPerRepEnd * 2 * _repCount : 0;
    final totalPlots = dataPlots + guardPlots;
    const startPlot = 101;
    final slotsPerRep = _plotsPerRep + _guardRowsPerRepEffective * 2;
    final endPlot = _repCount * 100 + slotsPerRep;
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
      'Plots per rep: $_plotsPerRep',
      if (guardPlots > 0)
        'Plots: $dataPlots data + $guardPlots guard = $totalPlots total'
      else
        'Plots: $totalPlots',
      'Numbering: Rep-based ($startPlot–$endPlot per rep pattern)',
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

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final TrialTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppDesignTokens.primary.withValues(alpha: 0.12)
              : AppDesignTokens.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppDesignTokens.primary
                : AppDesignTokens.borderCrisp,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              template.icon,
              size: 16,
              color: selected
                  ? AppDesignTokens.primary
                  : AppDesignTokens.secondaryText,
            ),
            const SizedBox(width: 6),
            Text(
              template.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? AppDesignTokens.primary
                    : AppDesignTokens.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

