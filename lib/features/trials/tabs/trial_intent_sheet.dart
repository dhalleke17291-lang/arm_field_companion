import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/design/form_styles.dart';
import '../../../core/providers.dart';
import '../../../domain/trial_cognition/mode_c_revelation_model.dart';

/// Opens the Mode C intent revelation sheet for [trial].
/// Resolves the current purpose and current user before showing.
Future<void> showTrialIntentSheet(
  BuildContext context,
  WidgetRef ref, {
  required Trial trial,
}) async {
  final purposeRepo = ref.read(trialPurposeRepositoryProvider);
  final existing = await purposeRepo.getCurrentTrialPurpose(trial.id);
  final user = await ref.read(currentUserProvider.future);
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppDesignTokens.cardSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (ctx) => _TrialIntentSheet(
      trial: trial,
      existing: existing,
      capturedBy: user?.displayName,
    ),
  );
}

// Maps each question key index → the existing answer from the DB row.
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
  });

  final Trial trial;
  final TrialPurpose? existing;
  final String? capturedBy;

  @override
  ConsumerState<_TrialIntentSheet> createState() => _TrialIntentSheetState();
}

class _TrialIntentSheetState extends ConsumerState<_TrialIntentSheet> {
  static const int _totalQuestions = 5;

  late final PageController _pageController;
  late final List<TextEditingController> _controllers;
  late final List<bool> _hadExisting;
  var _pageIndex = 0;
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _controllers = List.generate(
      _totalQuestions,
      (i) => TextEditingController(
        text: _existingAnswer(widget.existing, i) ?? '',
      ),
    );
    _hadExisting = List.generate(
      _totalQuestions,
      (i) => (_existingAnswer(widget.existing, i) ?? '').isNotEmpty,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
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

  Future<void> _onConfirm() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final purposeRepo = ref.read(trialPurposeRepositoryProvider);

      String? fieldText(int i) {
        final s = _controllers[i].text.trim();
        return s.isEmpty ? null : s;
      }

      final companion = TrialPurposesCompanion.insert(
        trialId: widget.trial.id,
        claimBeingTested: Value(fieldText(0)),
        trialPurpose: Value(fieldText(1)),
        primaryEndpoint: Value(fieldText(2)),
        treatmentRoleSummary: Value(fieldText(3)),
        knownInterpretationFactors: Value(fieldText(4)),
        sourceMode: const Value(TrialPurposeSourceMode.manualRevelation),
      );

      final int newId;
      if (widget.existing == null) {
        newId = await purposeRepo.createInitialTrialPurpose(
          trialId: widget.trial.id,
          claimBeingTested: fieldText(0),
          trialPurpose: fieldText(1),
          primaryEndpoint: fieldText(2),
          treatmentRoleSummary: fieldText(3),
          knownInterpretationFactors: fieldText(4),
          sourceMode: TrialPurposeSourceMode.manualRevelation,
        );
      } else {
        newId = await purposeRepo.createNewTrialPurposeVersion(
          widget.existing!,
          companion,
        );
      }

      await purposeRepo.confirmTrialPurpose(newId, confirmedBy: widget.capturedBy);

      await ref.read(ctqFactorDefinitionRepositoryProvider)
          .seedDefaultCtqFactorsForPurpose(
        trialId: widget.trial.id,
        trialPurposeId: newId,
      );

      ref.invalidate(trialPurposeProvider(widget.trial.id));
      ref.invalidate(trialEvidenceArcProvider(widget.trial.id));
      ref.invalidate(trialCriticalToQualityProvider(widget.trial.id));

      for (var i = 0; i < _totalQuestions; i++) {
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
                  for (var i = 0; i < _totalQuestions; i++)
                    _QuestionPage(
                      questionIndex: i,
                      totalQuestions: _totalQuestions,
                      controller: _controllers[i],
                      onSave: () => _onSave(i),
                      onSkip: () => _onSkip(i),
                      onBack: _goBack,
                      isFirst: i == 0,
                    ),
                  _ReviewPage(
                    controllers: _controllers,
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

class _ReviewPage extends StatelessWidget {
  const _ReviewPage({
    required this.controllers,
    required this.onBack,
    required this.onConfirm,
  });

  final List<TextEditingController> controllers;
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
            itemCount: ModeCQuestionKeys.all.length,
            separatorBuilder: (_, __) =>
                const Divider(height: AppDesignTokens.spacing24),
            itemBuilder: (_, i) {
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
