import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';

class AssessmentSelectorPanel extends StatelessWidget {
  const AssessmentSelectorPanel({
    super.key,
    required this.assessments,
    required this.currentAssessment,
    required this.taByLegacy,
    required this.taById,
    required this.nonRecordedAssessmentIds,
    required this.definitions,
    required this.aamMap,
    required this.assessmentScrollController,
    required this.sessionTrialAssessmentIdsByAssessmentId,
    required this.shellDescription,
    required this.assessmentDisplayLabel,
    required this.assessmentChipLabel,
    required this.onAssessmentSelected,
    this.hasGuide = false,
    this.onGuideIconTap,
  });

  final List<Assessment> assessments;
  final Assessment currentAssessment;
  final Map<int, TrialAssessment> taByLegacy;
  final Map<int, TrialAssessment> taById;
  final Set<int> nonRecordedAssessmentIds;
  final List<AssessmentDefinition> definitions;
  final Map<int, ArmAssessmentMetadataData> aamMap;
  final ScrollController assessmentScrollController;
  final Map<int, int> sessionTrialAssessmentIdsByAssessmentId;
  final String? shellDescription;
  final String Function(
    Assessment,
    Map<int, TrialAssessment>,
    Map<int, TrialAssessment>,
  ) assessmentDisplayLabel;
  final String Function(
    Assessment,
    Map<int, TrialAssessment>,
    Map<int, TrialAssessment>,
  ) assessmentChipLabel;
  final void Function(int index, Assessment assessment) onAssessmentSelected;
  final bool hasGuide;
  final VoidCallback? onGuideIconTap;

  @override
  Widget build(BuildContext context) {
    final methodHints = _buildAssessmentMethodInstructions(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAssessmentSelector(context),
        if (shellDescription != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDesignTokens.spacing16,
              0,
              AppDesignTokens.spacing16,
              6,
            ),
            child: Text(
              shellDescription!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (methodHints != null) methodHints,
      ],
    );
  }

  AssessmentDefinition? _definitionForTrialAssessment(TrialAssessment ta) {
    for (final d in definitions) {
      if (d.id == ta.assessmentDefinitionId) return d;
    }
    return null;
  }

  Widget? _buildAssessmentMethodInstructions(BuildContext context) {
    final ta = _trialAssessmentFor(currentAssessment);
    if (ta == null) return null;
    final def = _definitionForTrialAssessment(ta);
    final methodOverride = ta.methodOverride?.trim();
    final methodFromDef = def?.method?.trim();
    final methodLine = (methodOverride != null && methodOverride.isNotEmpty)
        ? methodOverride
        : (methodFromDef != null && methodFromDef.isNotEmpty
            ? methodFromDef
            : null);

    final instrOverride = ta.instructionOverride?.trim();
    final instrOverrideClean = (instrOverride != null &&
            instrOverride.isNotEmpty &&
            !instrOverride.startsWith('librarySourceId:'))
        ? instrOverride
        : null;
    final instrDef = def?.defaultInstructions?.trim();
    final instrLine = instrOverrideClean ??
        (instrDef != null && instrDef.isNotEmpty ? instrDef : null);

    if (methodLine == null && instrLine == null) return null;

    void showFull(String title, String body) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: SelectableText(body)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    Widget lineBlock(String label, String text) {
      final overflow = text.length > 120 || text.split('\n').length > 2;
      final preview =
          overflow && text.length > 120 ? '${text.substring(0, 120)}…' : text;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label: $preview',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            if (overflow)
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => showFull(label, text),
                child: const Text('More'),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDesignTokens.spacing16,
        0,
        AppDesignTokens.spacing16,
        8,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppDesignTokens.cardSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppDesignTokens.borderCrisp),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (methodLine != null) lineBlock('Method', methodLine),
              if (instrLine != null) lineBlock('Instructions', instrLine),
            ],
          ),
        ),
      ),
    );
  }

  TrialAssessment? _trialAssessmentFor(Assessment assessment) {
    final sessionTaId = sessionTrialAssessmentIdsByAssessmentId[assessment.id];
    if (sessionTaId != null) {
      final ta = taById[sessionTaId];
      if (ta != null) return ta;
    }
    return taByLegacy[assessment.id];
  }

  Widget _buildAssessmentSelector(BuildContext context) {
    if (assessments.length == 1) {
      final showIssue = nonRecordedAssessmentIds.contains(currentAssessment.id);
      return Padding(
        padding: const EdgeInsets.fromLTRB(
            AppDesignTokens.spacing16, 10, AppDesignTokens.spacing16, 6),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppDesignTokens.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppDesignTokens.spacing8),
            Text(
              assessmentDisplayLabel(currentAssessment, taByLegacy, taById),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppDesignTokens.primaryText,
              ),
            ),
            if (currentAssessment.unit != null) ...[
              const SizedBox(width: 6),
              Text(
                '· ${currentAssessment.unit}',
                style: const TextStyle(
                    fontSize: 13, color: AppDesignTokens.secondaryText),
              ),
            ],
            if (showIssue) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: AppDesignTokens.warningFg,
              ),
            ],
            if (hasGuide && onGuideIconTap != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: onGuideIconTap,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppDesignTokens.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDesignTokens.spacing16, 10, AppDesignTokens.spacing16, 6),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 32,
              child: SingleChildScrollView(
                controller: assessmentScrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var index = 0;
                        index < assessments.length;
                        index++) ...[
                      if (index > 0) const SizedBox(width: 6),
                      _buildAssessmentChip(context, index),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (hasGuide && onGuideIconTap != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onGuideIconTap,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppDesignTokens.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssessmentChip(BuildContext context, int index) {
    final assessment = assessments[index];
    final isSelected = assessment.id == currentAssessment.id;
    final label = assessmentChipLabel(assessment, taByLegacy, taById);
    final showIssueIndicator = nonRecordedAssessmentIds.contains(assessment.id);
    return GestureDetector(
      onTap: () => onAssessmentSelected(index, assessment),
      child: Container(
        height: isSelected ? 32 : 28,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 10 : 8,
          vertical: 0,
        ),
        constraints: const BoxConstraints(maxWidth: 168),
        decoration: BoxDecoration(
          color: isSelected
              ? AppDesignTokens.primary
              : AppDesignTokens.cardSurface,
          borderRadius: BorderRadius.circular(isSelected ? 16 : 14),
          border: Border.all(color: AppDesignTokens.borderCrisp),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isSelected ? 13 : 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color:
                      isSelected ? Colors.white : AppDesignTokens.secondaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showIssueIndicator) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: isSelected ? Colors.white : AppDesignTokens.warningFg,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
