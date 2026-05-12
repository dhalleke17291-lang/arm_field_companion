import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/design/form_styles.dart';
import '../../../core/providers.dart';
import '../../../domain/trial_cognition/mode_c_revelation_model.dart';
import '../../../domain/trial_cognition/regulatory_context_value.dart';
import '../../../shared/layout/responsive_layout.dart';

/// Opens the Mode C intent revelation sheet for [trial].
/// Resolves the current purpose, current user, ARM status, and (for standalone
/// trials) the active assessment list before showing. Nothing is fetched
/// inside the sheet widget itself.
Future<void> showTrialIntentSheet(
  BuildContext context,
  WidgetRef ref, {
  required Trial trial,
}) async {
  final purposeRepo = ref.read(trialPurposeRepositoryProvider);
  final existingFuture = purposeRepo.getCurrentTrialPurpose(trial.id);
  final userFuture = ref.read(currentUserProvider.future);
  // ARM status lives in arm_trial_metadata, not on the Trial row.
  final armMetaFuture =
      ref.read(armTrialMetadataStreamProvider(trial.id).future);

  final existing = await existingFuture;
  final user = await userFuture;
  final armMeta = await armMetaFuture;
  final isArmTrial = armMeta?.isArmLinked ?? false;

  // For standalone trials, load the active assessment list for Q6/Q7.
  // ARM trials skip Q6/Q7 — no fetch needed.
  List<(TrialAssessment, AssessmentDefinition)> activeAssessments = const [];
  if (!isArmTrial) {
    final allPairs = await ref
        .read(trialAssessmentsWithDefinitionsForTrialProvider(trial.id).future);
    activeAssessments = [for (final p in allPairs) if (p.$1.isActive) p];
  }

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: false,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppDesignTokens.cardSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (ctx) {
      final rl = ResponsiveLayout.of(ctx);
      final maxW = rl.modalSheetMaxWidth;
      final sheet = _TrialIntentSheet(
        trial: trial,
        existing: existing,
        capturedBy: user?.displayName,
        isArmTrial: isArmTrial,
        activeAssessments: activeAssessments,
      );
      if (maxW.isInfinite) return sheet;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: sheet,
        ),
      );
    },
  );
}

// Maps each question key index → the existing text answer from the DB row.
// Index 1 (trial_purpose_context) maps to trial_purpose for backward-compat
// text preservation. The picker's initial selection is loaded separately
// from regulatoryContext in _TrialIntentSheetState.initState.
String? _existingAnswer(TrialPurpose? p, int index) {
  if (p == null) return null;
  return switch (ModeCQuestionKeys.all[index]) {
    ModeCQuestionKeys.claimBeingTested => p.claimBeingTested,
    ModeCQuestionKeys.trialPurposeContext => p.trialPurpose,
    ModeCQuestionKeys.primaryEndpoint => p.primaryEndpoint,
    ModeCQuestionKeys.treatmentRoles => p.treatmentRoleSummary,
    ModeCQuestionKeys.knownInterpretationFactors =>
      p.knownInterpretationFactors,
    _ => null,
  };
}

class _TrialIntentSheet extends ConsumerStatefulWidget {
  const _TrialIntentSheet({
    required this.trial,
    required this.existing,
    required this.capturedBy,
    required this.isArmTrial,
    required this.activeAssessments,
  });

  final Trial trial;
  final TrialPurpose? existing;
  final String? capturedBy;

  /// True when the trial has ARM shell metadata. Q6/Q7 are skipped for ARM trials.
  final bool isArmTrial;

  /// Active trial assessments for Q6 (planned DAT per assessment).
  /// Empty for ARM trials and standalone trials with no active assessments.
  final List<(TrialAssessment, AssessmentDefinition)> activeAssessments;

  @override
  ConsumerState<_TrialIntentSheet> createState() => _TrialIntentSheetState();
}

class _TrialIntentSheetState extends ConsumerState<_TrialIntentSheet> {
  // ARM trials: 5 questions. Standalone with assessments: 7 (adds Q6 DAT + Q7 window).
  late final int _totalQuestions;

  late final PageController _pageController;
  late final List<TextEditingController> _controllers; // indices 0–4
  late final List<bool> _hadExisting;

  /// Structured commercial context selection — maps to regulatory_context column.
  String? _selectedRegulatoryContext;

  /// Q6: planned DAT controllers keyed by TrialAssessment.id.
  late final Map<int, TextEditingController> _plannedDatControllers;

  /// Q7: acceptable timing deviation in ±days.
  late final TextEditingController _windowController;

  var _pageIndex = 0;
  var _submitting = false;

  // Whether Q6/Q7 pages are active for this session.
  bool get _hasProtocolPages =>
      !widget.isArmTrial && widget.activeAssessments.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _totalQuestions = _hasProtocolPages ? 7 : 5;
    _pageController = PageController();
    _controllers = List.generate(
      5,
      (i) => TextEditingController(
        text: _existingAnswer(widget.existing, i) ?? '',
      ),
    );
    _hadExisting = List.generate(
      5,
      (i) => (_existingAnswer(widget.existing, i) ?? '').isNotEmpty,
    );
    _selectedRegulatoryContext = widget.existing?.regulatoryContext;

    // Q6: parse existing plannedDatByAssessment JSON to pre-fill controllers.
    Map<String, dynamic> existingDat = {};
    final rawDat = widget.existing?.plannedDatByAssessment;
    if (rawDat != null && rawDat.isNotEmpty) {
      try {
        existingDat = jsonDecode(rawDat) as Map<String, dynamic>;
      } catch (_) {}
    }
    _plannedDatControllers = {
      for (final p in widget.activeAssessments)
        p.$1.id: TextEditingController(
          text: existingDat[p.$1.id.toString()]?.toString() ?? '',
        ),
    };

    // Q7: pre-fill from existing protocolTimingWindow.
    _windowController = TextEditingController(
      text: widget.existing?.protocolTimingWindow?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final c in _plannedDatControllers.values) {
      c.dispose();
    }
    _windowController.dispose();
    super.dispose();
  }

  Future<void> _writeEvent({
    required int questionIndex,
    required String answerState,
    int? trialPurposeId,
  }) async {
    final key = ModeCQuestionKeys.all[questionIndex];
    final text = _controllers[questionIndex].text.trim();
    await ref.read(intentRevelationEventRepositoryProvider).addIntentRevelationEvent(
          trialId: widget.trial.id,
          trialPurposeId: trialPurposeId,
          touchpoint: ModeCTouchpoints.manualOverview,
          questionKey: key,
          questionText: kModeCQuestionText[key]!,
          answerValue: text.isEmpty ? null : text,
          answerState: answerState,
          source: 'field_researcher_input',
          capturedBy: widget.capturedBy,
        );
  }

  Future<void> _onSave(int questionIndex) async {
    final state = _hadExisting[questionIndex]
        ? IntentAnswerState.revised
        : IntentAnswerState.captured;
    await _writeEvent(questionIndex: questionIndex, answerState: state);
    _advancePage();
  }

  Future<void> _onSkip(int questionIndex) async {
    await _writeEvent(
        questionIndex: questionIndex,
        answerState: IntentAnswerState.skipped);
    _advancePage();
  }

  void _advancePage() {
    final next = _pageIndex + 1;
    setState(() => _pageIndex = next);
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
    );
  }

  void _goBack() {
    if (_pageIndex == 0) {
      Navigator.of(context).pop();
      return;
    }
    final prev = _pageIndex - 1;
    setState(() => _pageIndex = prev);
    _pageController.animateToPage(
      prev,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
    );
  }

  String? _buildPlannedDatJson() {
    final map = <String, int>{};
    for (final p in widget.activeAssessments) {
      final val =
          int.tryParse(_plannedDatControllers[p.$1.id]?.text.trim() ?? '');
      if (val != null) map[p.$1.id.toString()] = val;
    }
    return map.isEmpty ? null : jsonEncode(map);
  }

  int? _parseWindow() =>
      int.tryParse(_windowController.text.trim());

  Future<void> _onConfirm() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final purposeRepo = ref.read(trialPurposeRepositoryProvider);

      String? fieldText(int i) {
        final s = _controllers[i].text.trim();
        return s.isEmpty ? null : s;
      }

      final plannedDatJson = _hasProtocolPages ? _buildPlannedDatJson() : null;
      final window = _hasProtocolPages ? _parseWindow() : null;

      final effectiveSourceMode =
          widget.existing?.sourceMode == TrialPurposeSourceMode.armStructure
              ? TrialPurposeSourceMode.armStructure
              : TrialPurposeSourceMode.manualRevelation;

      final companion = TrialPurposesCompanion.insert(
        trialId: widget.trial.id,
        claimBeingTested: Value(fieldText(0)),
        trialPurpose: Value(fieldText(1)),
        regulatoryContext: Value(_selectedRegulatoryContext),
        primaryEndpoint: Value(fieldText(2)),
        treatmentRoleSummary: Value(fieldText(3)),
        knownInterpretationFactors: Value(fieldText(4)),
        sourceMode: Value(effectiveSourceMode),
        plannedDatByAssessment: Value(plannedDatJson),
        protocolTimingWindow: Value(window),
      );

      final int newId;
      if (widget.existing == null) {
        newId = await purposeRepo.createInitialTrialPurpose(
          trialId: widget.trial.id,
          claimBeingTested: fieldText(0),
          trialPurpose: fieldText(1),
          regulatoryContext: _selectedRegulatoryContext,
          primaryEndpoint: fieldText(2),
          treatmentRoleSummary: fieldText(3),
          knownInterpretationFactors: fieldText(4),
          sourceMode: TrialPurposeSourceMode.manualRevelation,
          plannedDatByAssessment: plannedDatJson,
          protocolTimingWindow: window,
        );
      } else {
        newId = await purposeRepo.createNewTrialPurposeVersion(
          widget.existing!,
          companion,
        );
      }

      await purposeRepo.confirmTrialPurpose(newId,
          confirmedBy: widget.capturedBy);

      await ref
          .read(ctqFactorDefinitionRepositoryProvider)
          .seedDefaultCtqFactorsForPurpose(
            trialId: widget.trial.id,
            trialPurposeId: newId,
          );

      ref.invalidate(trialPurposeProvider(widget.trial.id));

      for (var i = 0; i < 5; i++) {
        if (_controllers[i].text.trim().isNotEmpty) {
          await _writeEvent(
            questionIndex: i,
            answerState: IntentAnswerState.confirmed,
            trialPurposeId: newId,
          );
        }
      }

      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: screenHeight * 0.88,
        child: Column(
          children: [
            _DragHandle(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < 5; i++)
                    if (i == 1)
                      _PickerQuestionPage(
                        questionIndex: i,
                        totalQuestions: _totalQuestions,
                        selectedValue: _selectedRegulatoryContext,
                        onSelect: (key) {
                          setState(() => _selectedRegulatoryContext = key);
                        },
                        onNext: () => _onSave(i),
                        onSkip: () => _onSkip(i),
                        onBack: _goBack,
                      )
                    else
                      _QuestionPage(
                        questionIndex: i,
                        totalQuestions: _totalQuestions,
                        controller: _controllers[i],
                        onSave: () => _onSave(i),
                        onSkip: () => _onSkip(i),
                        onBack: _goBack,
                        isFirst: i == 0,
                      ),
                  if (_hasProtocolPages) ...[
                    _PlannedDatPage(
                      questionIndex: 5,
                      totalQuestions: _totalQuestions,
                      assessmentPairs: widget.activeAssessments,
                      controllers: _plannedDatControllers,
                      onNext: _advancePage,
                      onSkip: _advancePage,
                      onBack: _goBack,
                    ),
                    _TimingWindowPage(
                      questionIndex: 6,
                      totalQuestions: _totalQuestions,
                      controller: _windowController,
                      onNext: _advancePage,
                      onSkip: _advancePage,
                      onBack: _goBack,
                    ),
                  ],
                  _ReviewPage(
                    controllers: _controllers,
                    selectedRegulatoryContext: _selectedRegulatoryContext,
                    plannedDatJson: _hasProtocolPages
                        ? _buildPlannedDatJson()
                        : null,
                    assessmentPairs: widget.activeAssessments,
                    protocolWindow: _hasProtocolPages ? _parseWindow() : null,
                    onBack: _goBack,
                    onConfirm: _submitting ? null : _onConfirm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: AppDesignTokens.spacing8),
        decoration: BoxDecoration(
          color: AppDesignTokens.dragHandle,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ── Picker question page (commercial context) ─────────────────────────────────

class _PickerQuestionPage extends StatelessWidget {
  const _PickerQuestionPage({
    required this.questionIndex,
    required this.totalQuestions,
    required this.selectedValue,
    required this.onSelect,
    required this.onNext,
    required this.onSkip,
    required this.onBack,
  });

  final int questionIndex;
  final int totalQuestions;
  final String? selectedValue;
  final ValueChanged<String> onSelect;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  bool get _isRequired =>
      ModeCQuestionKeys.required.contains(ModeCQuestionKeys.all[questionIndex]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FormStyles.formSheetHorizontalPadding,
            AppDesignTokens.spacing8,
            FormStyles.formSheetHorizontalPadding,
            0,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Back',
                color: AppDesignTokens.secondaryText,
              ),
              const SizedBox(width: 4),
              Text(
                '${questionIndex + 1} of $totalQuestions',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppDesignTokens.secondaryText,
                ),
              ),
              if (_isRequired) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.emptyBadgeBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'REQUIRED',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: AppDesignTokens.secondaryText,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              FormStyles.formSheetHorizontalPadding,
              AppDesignTokens.spacing16,
              FormStyles.formSheetHorizontalPadding,
              AppDesignTokens.spacing16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What is the purpose of this trial?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.primaryText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppDesignTokens.spacing16),
                for (final key in RegulatoryContextValue.all) ...[
                  _ContextOptionTile(
                    label: RegulatoryContextValue.labels[key]!,
                    selected: selectedValue == key,
                    onTap: () => onSelect(key),
                  ),
                  const SizedBox(height: AppDesignTokens.spacing8),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FormStyles.formSheetHorizontalPadding,
            AppDesignTokens.spacing12,
            FormStyles.formSheetHorizontalPadding,
            AppDesignTokens.spacing16,
          ),
          child: Row(
            children: [
              TextButton(
                onPressed: onSkip,
                child: const Text('Skip'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onNext,
                child: const Text('Next →'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContextOptionTile extends StatelessWidget {
  const _ContextOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? AppDesignTokens.primary : AppDesignTokens.divider;
    final bg = selected
        ? AppDesignTokens.primary.withValues(alpha: 0.06)
        : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: selected ? 1.5 : 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: selected
                      ? AppDesignTokens.primaryText
                      : AppDesignTokens.secondaryText,
                  fontWeight:
                      selected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check,
                size: 16,
                color: AppDesignTokens.primary,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Free-text question page ───────────────────────────────────────────────────

class _QuestionPage extends StatelessWidget {
  const _QuestionPage({
    required this.questionIndex,
    required this.totalQuestions,
    required this.controller,
    required this.onSave,
    required this.onSkip,
    required this.onBack,
    required this.isFirst,
  });

  final int questionIndex;
  final int totalQuestions;
  final TextEditingController controller;
  final VoidCallback onSave;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final bool isFirst;

  bool get _isRequired =>
      ModeCQuestionKeys.required.contains(ModeCQuestionKeys.all[questionIndex]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final key = ModeCQuestionKeys.all[questionIndex];
    final questionText = kModeCQuestionText[key]!;
    final isLast = questionIndex == totalQuestions - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FormStyles.formSheetHorizontalPadding,
            AppDesignTokens.spacing8,
            FormStyles.formSheetHorizontalPadding,
            0,
          ),
          child: Row(
            children: [
              if (!isFirst)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Back',
                  color: AppDesignTokens.secondaryText,
                ),
              if (!isFirst) const SizedBox(width: 4),
              Text(
                '${questionIndex + 1} of $totalQuestions',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppDesignTokens.secondaryText,
                ),
              ),
              if (_isRequired) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.emptyBadgeBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'REQUIRED',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: AppDesignTokens.secondaryText,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              FormStyles.formSheetHorizontalPadding,
              AppDesignTokens.spacing16,
              FormStyles.formSheetHorizontalPadding,
              AppDesignTokens.spacing16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  questionText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.primaryText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppDesignTokens.spacing16),
                TextField(
                  controller: controller,
                  minLines: 4,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: FormStyles.inputDecoration(
                    hintText: questionIndex == 0
                        ? 'e.g. Compare herbicide treatments against the untreated check for weed control.'
                        : 'Type your answer here…',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                if (questionIndex == 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'It shows how well the treatments separate, and what the baseline comparison is.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppDesignTokens.secondaryText,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FormStyles.formSheetHorizontalPadding,
            AppDesignTokens.spacing12,
            FormStyles.formSheetHorizontalPadding,
            AppDesignTokens.spacing16,
          ),
          child: Row(
            children: [
              TextButton(
                onPressed: onSkip,
                child: const Text('Skip'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onSave,
                child: Text(isLast ? 'Review →' : 'Next →'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Planned DAT per assessment (Q6) ──────────────────────────────────────────

class _PlannedDatPage extends StatelessWidget {
  const _PlannedDatPage({
    required this.questionIndex,
    required this.totalQuestions,
    required this.assessmentPairs,
    required this.controllers,
    required this.onNext,
    required this.onSkip,
    required this.onBack,
  });

  final int questionIndex;
  final int totalQuestions;
  final List<(TrialAssessment, AssessmentDefinition)> assessmentPairs;
  final Map<int, TextEditingController> controllers;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FormStyles.formSheetHorizontalPadding,
            AppDesignTokens.spacing8,
            FormStyles.formSheetHorizontalPadding,
            0,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Back',
                color: AppDesignTokens.secondaryText,
              ),
              const SizedBox(width: 4),
              Text(
                '${questionIndex + 1} of $totalQuestions',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: AppDesignTokens.secondaryText),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              FormStyles.formSheetHorizontalPadding,
              AppDesignTokens.spacing16,
              FormStyles.formSheetHorizontalPadding,
              AppDesignTokens.spacing16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'When is each assessment planned to be rated? (days after treatment)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.primaryText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppDesignTokens.spacing4),
                Text(
                  'Enter the planned days after the last application for each assessment.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppDesignTokens.secondaryText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppDesignTokens.spacing16),
                for (final p in assessmentPairs) ...[
                  _AssessmentDatRow(
                    name: p.$1.displayNameOverride ?? p.$2.name,
                    controller: controllers[p.$1.id]!,
                  ),
                  const SizedBox(height: AppDesignTokens.spacing12),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FormStyles.formSheetHorizontalPadding,
            AppDesignTokens.spacing12,
            FormStyles.formSheetHorizontalPadding,
            AppDesignTokens.spacing16,
          ),
          child: Row(
            children: [
              TextButton(onPressed: onSkip, child: const Text('Skip')),
              const Spacer(),
              FilledButton(onPressed: onNext, child: const Text('Next →')),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssessmentDatRow extends StatelessWidget {
  const _AssessmentDatRow({
    required this.name,
    required this.controller,
  });

  final String name;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            name,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppDesignTokens.primaryText),
          ),
        ),
        const SizedBox(width: AppDesignTokens.spacing12),
        SizedBox(
          width: 72,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: FormStyles.inputDecoration(hintText: 'DAT'),
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

// ── Timing window (Q7) ────────────────────────────────────────────────────────

class _TimingWindowPage extends StatelessWidget {
  const _TimingWindowPage({
    required this.questionIndex,
    required this.totalQuestions,
    required this.controller,
    required this.onNext,
    required this.onSkip,
    required this.onBack,
  });

  final int questionIndex;
  final int totalQuestions;
  final TextEditingController controller;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FormStyles.formSheetHorizontalPadding,
            AppDesignTokens.spacing8,
            FormStyles.formSheetHorizontalPadding,
            0,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Back',
                color: AppDesignTokens.secondaryText,
              ),
              const SizedBox(width: 4),
              Text(
                '${questionIndex + 1} of $totalQuestions',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: AppDesignTokens.secondaryText),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              FormStyles.formSheetHorizontalPadding,
              AppDesignTokens.spacing16,
              FormStyles.formSheetHorizontalPadding,
              AppDesignTokens.spacing16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How many days of deviation from the planned date is acceptable?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.primaryText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppDesignTokens.spacing4),
                Text(
                  'Sessions rated within ±N days of the planned date will not be flagged as deviations.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppDesignTokens.secondaryText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppDesignTokens.spacing16),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: FormStyles.inputDecoration(hintText: '±days'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FormStyles.formSheetHorizontalPadding,
            AppDesignTokens.spacing12,
            FormStyles.formSheetHorizontalPadding,
            AppDesignTokens.spacing16,
          ),
          child: Row(
            children: [
              TextButton(onPressed: onSkip, child: const Text('Skip')),
              const Spacer(),
              FilledButton(onPressed: onNext, child: const Text('Next →')),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Review page ───────────────────────────────────────────────────────────────

class _ReviewPage extends StatelessWidget {
  const _ReviewPage({
    required this.controllers,
    required this.selectedRegulatoryContext,
    required this.plannedDatJson,
    required this.assessmentPairs,
    required this.protocolWindow,
    required this.onBack,
    required this.onConfirm,
  });

  final List<TextEditingController> controllers;

  /// Structured commercial context key from the picker (may be null if skipped).
  final String? selectedRegulatoryContext;

  /// JSON string from Q6, or null if ARM trial / skipped.
  final String? plannedDatJson;

  /// Active assessment pairs passed from Q6 (for computing configured count).
  final List<(TrialAssessment, AssessmentDefinition)> assessmentPairs;

  /// Parsed window from Q7, or null if ARM trial / skipped.
  final int? protocolWindow;

  final VoidCallback onBack;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FormStyles.formSheetHorizontalPadding,
            AppDesignTokens.spacing16,
            FormStyles.formSheetHorizontalPadding,
            AppDesignTokens.spacing8,
          ),
          child: Text(
            'Review answers',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              FormStyles.formSheetHorizontalPadding,
              AppDesignTokens.spacing8,
              FormStyles.formSheetHorizontalPadding,
              AppDesignTokens.spacing16,
            ),
            itemCount: ModeCQuestionKeys.all.length +
                (assessmentPairs.isNotEmpty ? 1 : 0),
            separatorBuilder: (_, __) =>
                const Divider(height: AppDesignTokens.spacing24),
            itemBuilder: (_, i) {
              // Protocol timing summary row (Q6/Q7) — appended after Q1–Q5.
              if (i == ModeCQuestionKeys.all.length) {
                final configuredCount = plannedDatJson == null
                    ? 0
                    : (jsonDecode(plannedDatJson!) as Map).length;
                final datSummary = configuredCount == 0
                    ? '— skipped'
                    : '$configuredCount of ${assessmentPairs.length} assessments configured';
                final windowSummary = protocolWindow == null
                    ? '— skipped'
                    : '±$protocolWindow days';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Protocol timing',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppDesignTokens.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Planned DAT: $datSummary',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: configuredCount == 0
                            ? AppDesignTokens.secondaryText
                            : AppDesignTokens.primaryText,
                        fontStyle: configuredCount == 0
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Deviation window: $windowSummary',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: protocolWindow == null
                            ? AppDesignTokens.secondaryText
                            : AppDesignTokens.primaryText,
                        fontStyle: protocolWindow == null
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ],
                );
              }

              // Index 1 is the commercial context picker — display the
              // selected label as its own row, not the free-text trial_purpose.
              if (i == 1) {
                final label = selectedRegulatoryContext != null
                    ? RegulatoryContextValue.labels[selectedRegulatoryContext]
                    : null;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What is the purpose of this trial?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppDesignTokens.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label ?? '— skipped',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: label == null
                            ? AppDesignTokens.secondaryText
                            : AppDesignTokens.primaryText,
                        fontStyle: label == null
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ],
                );
              }

              final key = ModeCQuestionKeys.all[i];
              final answer = controllers[i].text.trim();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kModeCQuestionText[key]!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppDesignTokens.secondaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    answer.isEmpty ? '— skipped' : answer,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: answer.isEmpty
                          ? AppDesignTokens.secondaryText
                          : AppDesignTokens.primaryText,
                      fontStyle: answer.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FormStyles.formSheetHorizontalPadding,
            AppDesignTokens.spacing12,
            FormStyles.formSheetHorizontalPadding,
            AppDesignTokens.spacing16,
          ),
          child: Row(
            children: [
              TextButton(
                onPressed: onBack,
                child: const Text('Back'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onConfirm,
                child: const Text('Confirm intent'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
