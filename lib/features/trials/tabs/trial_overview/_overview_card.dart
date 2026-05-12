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
        AppDesignTokens.spacing12,
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing8,
      ),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: AppDesignTokens.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primaryTint,
                    borderRadius:
                        BorderRadius.circular(AppDesignTokens.radiusSmall),
                    border: Border.all(
                      color: AppDesignTokens.primary.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Text(
                    '$number',
                    style: AppDesignTokens.compactActionLabelStyle.copyWith(
                      fontSize: 12,
                      height: 1,
                      color: AppDesignTokens.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppDesignTokens.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppDesignTokens.headingStyle(
                          fontSize: 14,
                          color: AppDesignTokens.primaryText,
                        ).copyWith(height: 1.2),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: AppDesignTokens.bodyCrispStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppDesignTokens.secondaryText,
                          ).copyWith(height: 1.35),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 1,
              color: AppDesignTokens.borderCrisp,
            ),
            const SizedBox(height: 12),
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
      height: 5,
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
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        color: AppDesignTokens.secondaryText,
      ),
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
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 136,
            child: Text(
              label,
              style: AppDesignTokens.bodyCrispStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppDesignTokens.secondaryText,
              ).copyWith(height: 1.3),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppDesignTokens.headingStyle(
                fontSize: 13,
                color: AppDesignTokens.primaryText,
              ).copyWith(height: 1.3),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusChip),
      ),
      child: Text(
        label,
        style: AppDesignTokens.compactActionLabelStyle.copyWith(
          height: 1.15,
          color: fg,
        ),
      ),
    );
  }
}
