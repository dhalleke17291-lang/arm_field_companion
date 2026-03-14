import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../users/user_selection_screen.dart';

void _openUserSelection(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => const UserSelectionScreen(),
    ),
  );
}

/// More tab: Change user and Diagnostics. Elegant, minimal.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: const GradientScreenHeader(title: 'More'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.spacing16,
            vertical: AppDesignTokens.spacing24,
          ),
          children: [
            userAsync.when(
              loading: () => _buildActionCard(
                context,
                icon: Icons.person_outline_rounded,
                title: 'Change User',
                subtitle: 'Select or add a user',
                onTap: () => _openUserSelection(context),
              ),
              error: (_, __) => _buildActionCard(
                context,
                icon: Icons.person_add_outlined,
                title: 'Select User',
                subtitle: 'Sign in to use the app',
                onTap: () => _openUserSelection(context),
              ),
              data: (user) => _buildActionCard(
                context,
                icon: Icons.person_outline_rounded,
                title: 'Change User',
                subtitle: user != null
                    ? 'Signed in as ${user.displayName}'
                    : 'Select or add a user',
                onTap: () => _openUserSelection(context),
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing12),
            _buildActionCard(
              context,
              icon: Icons.analytics_outlined,
              title: 'Diagnostics',
              subtitle: 'Integrity, audit log, derived data',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const DiagnosticsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppDesignTokens.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppDesignTokens.spacing16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
            border: Border.all(color: AppDesignTokens.borderCrisp),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppDesignTokens.primaryTint,
                  borderRadius:
                      BorderRadius.circular(AppDesignTokens.radiusSmall),
                ),
                child: Icon(icon, size: 24, color: AppDesignTokens.primary),
              ),
              const SizedBox(width: AppDesignTokens.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppDesignTokens.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: AppDesignTokens.iconSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
