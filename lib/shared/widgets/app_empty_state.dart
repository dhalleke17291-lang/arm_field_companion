import 'package:flutter/material.dart';

import '../../core/design/app_design_tokens.dart';

/// Empty state widget: centered layout, icon in circular tinted container,
/// title, subtitle, optional action. UI only; no business logic.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDesignTokens.spacing16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppDesignTokens.spacing24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
