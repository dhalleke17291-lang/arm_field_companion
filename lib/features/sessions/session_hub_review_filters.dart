import 'package:flutter/material.dart';

import '../../core/design/app_design_tokens.dart';

/// Compact horizontal filter strip shown above the session summary grid.
/// Shows rep chips (if reps exist), then Unrated/Issues/Edited/Flagged pills,
/// then a Reset pill when any filter is active.
///
/// All filter state lives in the caller; this widget is pure presentation.
class HubReviewFilterStrip extends StatelessWidget {
  const HubReviewFilterStrip({
    super.key,
    required this.reps,
    required this.repFilter,
    required this.unratedOnly,
    required this.issuesOnly,
    required this.editedOnly,
    required this.flaggedOnly,
    required this.anyActive,
    required this.onRepSelected,
    required this.onUnratedToggle,
    required this.onIssuesToggle,
    required this.onEditedToggle,
    required this.onFlaggedToggle,
    required this.onReset,
  });

  final List<int> reps;
  final int? repFilter;
  final bool unratedOnly;
  final bool issuesOnly;
  final bool editedOnly;
  final bool flaggedOnly;
  final bool anyActive;
  final void Function(int rep) onRepSelected;
  final VoidCallback onUnratedToggle;
  final VoidCallback onIssuesToggle;
  final VoidCallback onEditedToggle;
  final VoidCallback onFlaggedToggle;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppDesignTokens.borderCrisp),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Rep chips — only shown when trial has reps
            for (final rep in reps) ...[
              _FilterPill(
                label: 'Rep $rep',
                selected: repFilter == rep,
                onTap: () => onRepSelected(rep),
              ),
              const SizedBox(width: 6),
            ],
            if (reps.isNotEmpty) ...[
              Container(
                width: 1,
                height: 16,
                color: AppDesignTokens.borderCrisp,
              ),
              const SizedBox(width: 6),
            ],
            // Status filter pills
            _FilterPill(
              label: 'Unrated',
              selected: unratedOnly,
              onTap: onUnratedToggle,
            ),
            const SizedBox(width: 6),
            _FilterPill(
              label: 'Issues',
              selected: issuesOnly,
              onTap: onIssuesToggle,
            ),
            const SizedBox(width: 6),
            _FilterPill(
              label: 'Edited',
              selected: editedOnly,
              onTap: onEditedToggle,
            ),
            const SizedBox(width: 6),
            _FilterPill(
              label: 'Flagged',
              selected: flaggedOnly,
              onTap: onFlaggedToggle,
            ),
            // Reset pill — only visible when any filter is active
            if (anyActive) ...[
              const SizedBox(width: 10),
              Container(
                width: 1,
                height: 16,
                color: AppDesignTokens.borderCrisp,
              ),
              const SizedBox(width: 6),
              _FilterPill(
                label: 'Reset',
                selected: false,
                onTap: onReset,
                isReset: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact toggle pill used in [HubReviewFilterStrip].
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isReset = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isReset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? AppDesignTokens.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppDesignTokens.primary.withValues(alpha: 0.5)
                : AppDesignTokens.borderCrisp,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected
                ? AppDesignTokens.primary
                : isReset
                    ? scheme.onSurfaceVariant
                    : scheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
