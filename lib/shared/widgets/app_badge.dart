import 'package:flutter/material.dart';

import '../../core/design/app_design_tokens.dart';

/// Small pill-shaped badge for status chips and metadata tags.
/// UI only; optional icon, secondary text color.
class AppBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  const AppBadge({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing8 + 2,
        vertical: AppDesignTokens.spacing4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppDesignTokens.secondaryText),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppDesignTokens.secondaryText,
            ),
          ),
        ],
      ),
    );
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppDesignTokens.divider.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(999),
        ),
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(999),
                child: child,
              )
            : child,
      ),
    );
  }
}
