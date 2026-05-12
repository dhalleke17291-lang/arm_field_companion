import 'package:flutter/material.dart';

import '../../../core/design/app_design_tokens.dart';
import '../../../core/plot_sort.dart';
import '../../../core/session_walk_order_store.dart';

class WalkOrderBar extends StatelessWidget {
  const WalkOrderBar({
    super.key,
    required this.walkOrderMode,
    required this.onTap,
  });

  final WalkOrderMode walkOrderMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppDesignTokens.cardSurface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.spacing16,
            vertical: 8,
          ),
          decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: AppDesignTokens.borderCrisp)),
          ),
          child: Row(
            children: [
              Icon(Icons.directions_walk,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Walk order: ',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              Text(
                SessionWalkOrderStore.labelForMode(walkOrderMode),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
