import 'package:flutter/material.dart';

import '../trial_state.dart';

/// App-wide UI standards for consistent look and behavior.
/// Use these so similar elements (section headers, empty states, etc.) look the same across screens.
class AppUiConstants {
  AppUiConstants._();

  /// Section header: horizontal padding
  static const double sectionHeaderPaddingH = 12;

  /// Section header: vertical padding (compact)
  static const double sectionHeaderPaddingV = 8;

  /// Empty state: icon size
  static const double emptyStateIconSize = 56;

  /// Empty state: space between icon and title
  static const double emptyStateSpacingAfterIcon = 12;

  /// Empty state: space between title and subtitle
  static const double emptyStateSpacingAfterTitle = 8;

  /// Empty state: space before primary action button
  static const double emptyStateSpacingBeforeAction = 20;

  /// Card list: horizontal padding
  static const double listPaddingH = 8;

  /// Card list: vertical padding
  static const double listPaddingV = 6;

  /// Primary action button: vertical padding (compact)
  static const double primaryButtonPaddingV = 12;

  /// Lock notice: horizontal padding (under section headers, in lock rows)
  static const double lockNoticePaddingH = 12;

  /// Lock notice: vertical padding (space above/below the message line)
  static const double lockNoticePaddingV = 4;

  /// Lock notice: space above when shown under a section header
  static const double lockNoticeSpacingAbove = 0;

  /// Lock notice: space below when shown under a section header
  static const double lockNoticeSpacingBelow = 6;

  /// Section-level Add button: icon size (use in [StandardSectionAddButton]).
  static const double sectionAddIconSize = 18;

  /// Section-level Add button: label.
  static const String sectionAddLabel = 'Add';
}

/// Standard section header for list-based sections (Assessments, Seeding, etc.).
/// Title on left (e.g. "3 assessments"), action on right. Same style everywhere.
class StandardSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? action;

  /// Optional chip or badge (e.g. ProtocolLockChip) shown between title and action.
  final Widget? trailingIndicator;

  const StandardSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.action,
    this.trailingIndicator,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppUiConstants.sectionHeaderPaddingH,
        vertical: AppUiConstants.sectionHeaderPaddingV,
      ),
      color: scheme.primaryContainer,
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: scheme.primary,
                letterSpacing: 0.15,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailingIndicator != null) ...[
            trailingIndicator!,
            const SizedBox(width: 8),
          ],
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Standard Add action for [StandardSectionHeader].action.
/// Use this for section-level "Add" so placement and style stay consistent.
/// When [onPressed] is null the button is disabled; set [disabledTooltip] to explain why (e.g. protocol lock).
class StandardSectionAddButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? disabledTooltip;

  const StandardSectionAddButton({
    super.key,
    this.onPressed,
    this.disabledTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final widget = TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: AppUiConstants.sectionAddIconSize),
      label: const Text(AppUiConstants.sectionAddLabel),
    );
    if (onPressed == null &&
        disabledTooltip != null &&
        disabledTooltip!.isNotEmpty) {
      return Tooltip(message: disabledTooltip!, child: widget);
    }
    return widget;
  }
}

Widget _wrapTooltipWhenDisabled(
    {required String? tooltip, required Widget child}) {
  if (tooltip == null || tooltip.isEmpty) return child;
  return Tooltip(message: tooltip, child: child);
}

/// Standard empty state: icon, title, one-line subtitle, primary action.
/// Same layout and spacing across Seeding, Assessments, Treatments, Applications, Plots, Sessions.
class StandardEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onAction;

  /// Optional icon for the primary action button (default: Icons.add).
  final IconData? actionIcon;

  /// Optional widgets below the primary button (e.g. secondary actions for Plots).
  final List<Widget>? trailingActions;

  /// When [onAction] is null, show this tooltip on the disabled button so users understand why before tapping.
  final String? disabledTooltipMessage;

  const StandardEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.trailingActions,
    this.disabledTooltipMessage,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AppUiConstants.emptyStateIconSize,
              color: scheme.primary,
            ),
            const SizedBox(height: AppUiConstants.emptyStateSpacingAfterIcon),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppUiConstants.emptyStateSpacingAfterTitle),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(
                height: AppUiConstants.emptyStateSpacingBeforeAction),
            _wrapTooltipWhenDisabled(
              tooltip: onAction == null ? disabledTooltipMessage : null,
              child: FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.add, size: 20),
                label: Text(actionLabel),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: AppUiConstants.primaryButtonPaddingV,
                  ),
                ),
              ),
            ),
            if (trailingActions != null && trailingActions!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...trailingActions!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Standard label: value row for detail cards (Plot Detail, record details, etc.).
/// Same padding and text styles app-wide.
class StandardDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const StandardDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: 10),
          ],
          SizedBox(
            width: icon != null ? 100 : 120,
            child: Text(
              label,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline lock explanation text. Use under section headers, in empty states, or in
/// lock rows (e.g. Treatments) so the lock reason is visible before the user taps.
/// One consistent style: compact, subtle, same padding and color everywhere.
class ProtocolLockNotice extends StatelessWidget {
  final String message;

  const ProtocolLockNotice({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppUiConstants.lockNoticePaddingH,
        AppUiConstants.lockNoticePaddingV,
        AppUiConstants.lockNoticePaddingH,
        AppUiConstants.lockNoticeSpacingBelow,
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// Source/state label for operational entries (seeding, applications).
/// Use one consistent badge for: Prefilled from Protocol, Manual, Recorded.
/// Compact and professional; same styling everywhere.
enum OperationalSource {
  prefilledFromProtocol,
  manual,
  recorded,
}

class OperationalSourceBadge extends StatelessWidget {
  final OperationalSource source;

  const OperationalSourceBadge({super.key, required this.source});

  static const String _prefilledLabel = 'Prefilled from Protocol';
  static const String _manualLabel = 'Manual';
  static const String _recordedLabel = 'Recorded';

  String get _label {
    switch (source) {
      case OperationalSource.prefilledFromProtocol:
        return _prefilledLabel;
      case OperationalSource.manual:
        return _manualLabel;
      case OperationalSource.recorded:
        return _recordedLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Compact chip showing protocol lock state: "Editable" or "Locked".
/// Optional [status] enables tooltip with [getProtocolLockMessage] when locked.
class ProtocolLockChip extends StatelessWidget {
  final bool isLocked;
  final String? status;

  const ProtocolLockChip({
    super.key,
    required this.isLocked,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = getProtocolLockLabel(status);
    final tooltip =
        isLocked && status != null && getProtocolLockMessage(status).isNotEmpty
            ? getProtocolLockMessage(status)
            : null;
    Widget chip = Material(
      color:
          isLocked ? scheme.surfaceContainerHighest : scheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLocked ? Icons.lock : Icons.lock_open,
              size: 14,
              color: isLocked ? scheme.onSurfaceVariant : scheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isLocked ? scheme.onSurfaceVariant : scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
    if (tooltip != null) {
      chip = Tooltip(message: tooltip, child: chip);
    }
    return chip;
  }
}
