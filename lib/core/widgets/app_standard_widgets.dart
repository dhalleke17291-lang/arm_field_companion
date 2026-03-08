import 'package:flutter/material.dart';

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
}

/// Standard section header for list-based sections (Assessments, Seeding, etc.).
/// Title on left (e.g. "3 assessments"), action on right. Same style everywhere.
class StandardSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? action;

  const StandardSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.action,
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
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
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

  const StandardEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.trailingActions,
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
            const SizedBox(height: AppUiConstants.emptyStateSpacingBeforeAction),
            FilledButton.icon(
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
