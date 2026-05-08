import 'package:flutter/material.dart';

import '../../../../core/design/app_design_tokens.dart';

/// Shared card for all ten Trial Review sections.
class OverviewSectionCard extends StatelessWidget {
  const OverviewSectionCard({
    super.key,
    required this.number,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final int number;
  final String title;

  /// Optional muted one-liner describing the section's role.
  final String? subtitle;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing8,
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing4,
      ),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: AppDesignTokens.cardShadowRating,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignTokens.spacing12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$number. $title'.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
            ],
            const SizedBox(height: AppDesignTokens.spacing8),
            child,
          ],
        ),
      ),
    );
  }
}

/// Compact loading placeholder for a section card body.
class OverviewSectionLoading extends StatelessWidget {
  const OverviewSectionLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 4,
      child: LinearProgressIndicator(
        backgroundColor: AppDesignTokens.divider,
        valueColor: AlwaysStoppedAnimation<Color>(AppDesignTokens.primary),
      ),
    );
  }
}

/// Compact error row for a section card body.
class OverviewSectionError extends StatelessWidget {
  const OverviewSectionError({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Unable to load.',
      style: TextStyle(fontSize: 12, color: AppDesignTokens.secondaryText),
    );
  }
}

/// Muted key-value row used across multiple sections.
class OverviewDataRow extends StatelessWidget {
  const OverviewDataRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppDesignTokens.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: AppDesignTokens.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Status chip used across multiple sections.
class OverviewStatusChip extends StatelessWidget {
  const OverviewStatusChip({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusChip),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
