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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: scheme.outlineVariant,
            ),
            const SizedBox(height: AppDesignTokens.spacing16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ) ??
                  const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppDesignTokens.spacing8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ) ??
                  TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
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
