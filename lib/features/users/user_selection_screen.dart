import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/current_user.dart';
import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../shell/main_shell_screen.dart';
import 'add_user_screen.dart';
import 'edit_profile_screen.dart';

/// Field profile switcher used for execution attribution.
class UserSelectionScreen extends ConsumerWidget {
  const UserSelectionScreen({super.key, this.popOnSelect = false});

  final bool popOnSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(activeUsersProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.bgWarm,
      appBar: const GradientScreenHeader(
        title: 'Current User',
        subtitle: 'Used for session, rating, edit, and export attribution',
      ),
      body: SafeArea(
        top: false,
        child: usersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (users) => users.isEmpty
              ? _buildEmpty(context, ref)
              : _buildList(context, ref, users),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(AppDesignTokens.spacing24),
          decoration: BoxDecoration(
            color: AppDesignTokens.cardSurface,
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
            border: Border.all(color: AppDesignTokens.borderCrisp),
            boxShadow: AppDesignTokens.cardShadow,
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppDesignTokens.primaryTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.person_add_alt_1_outlined,
                  size: 34,
                  color: AppDesignTokens.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Create the first field profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Users keep sessions, ratings, corrections, and backups attributed to the right person.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: AppDesignTokens.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openAddUser(context, ref),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Field Profile'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<User> users) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _UserSelectionIntroCard(userCount: users.length),
        const SizedBox(height: AppDesignTokens.spacing16),
        Container(
          decoration: BoxDecoration(
            color: AppDesignTokens.cardSurface,
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
            border: Border.all(color: AppDesignTokens.borderCrisp),
            boxShadow: AppDesignTokens.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < users.length; i++) ...[
                if (i > 0) const _UserDivider(),
                _UserRow(
                  user: users[i],
                  onTap: () => _selectUser(context, ref, users[i]),
                  onLongPress: () => _openEditProfile(context, ref, users[i]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppDesignTokens.spacing16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _openAddUser(context, ref),
            icon: const Icon(Icons.person_add),
            label: const Text('Add Field Profile'),
          ),
        ),
        const SizedBox(height: AppDesignTokens.spacing8),
        const Text(
          'Tip: long-press a field profile to edit its name or initials.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppDesignTokens.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _UserSelectionIntroCard extends StatelessWidget {
  const _UserSelectionIntroCard({required this.userCount});

  final int userCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDesignTokens.spacing16),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: AppDesignTokens.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppDesignTokens.primaryTint,
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
            ),
            child: const Icon(
              Icons.badge_outlined,
              color: AppDesignTokens.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppDesignTokens.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$userCount active user${userCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select the person currently using the app.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.onTap,
    required this.onLongPress,
  });

  final User user;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  String get _initials {
    if (user.initials?.trim().isNotEmpty == true) {
      return user.initials!.trim().toUpperCase();
    }
    if (user.displayName.trim().isNotEmpty) {
      return user.displayName.trim().substring(0, 1).toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing16,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppDesignTokens.successBg,
                    borderRadius:
                        BorderRadius.circular(AppDesignTokens.radiusLarge),
                  ),
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppDesignTokens.spacing12),
                Expanded(
                  child: Text(
                    user.displayName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.primaryText,
                    ),
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppDesignTokens.emptyBadgeBg.withValues(alpha: 0.7),
                    borderRadius:
                        BorderRadius.circular(AppDesignTokens.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    color: AppDesignTokens.secondaryText,
                    size: 22,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UserDivider extends StatelessWidget {
  const _UserDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 80,
      color: AppDesignTokens.divider,
    );
  }
}

/// Shown when no current_user_id is set. User taps to select or adds a new user.
extension _UserSelectionActions on UserSelectionScreen {
  Future<void> _openEditProfile(
    BuildContext context,
    WidgetRef ref,
    User user,
  ) async {
    final u = await ref.read(userRepositoryProvider).getUserById(user.id);
    if (u == null || !context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(user: u),
      ),
    );
    ref.invalidate(activeUsersProvider);
  }

  /// Returns `true` if the user may proceed with the profile switch, `false` to stay.
  Future<bool> _warnOpenSessionsOrAllowProceed(
      BuildContext context, WidgetRef ref) async {
    final currentId = await getCurrentUserId();
    if (currentId == null) return true;

    final sessionRepo = ref.read(sessionRepositoryProvider);
    final openSessions = await sessionRepo.getOpenSessionsForUser(currentId);
    if (openSessions.isEmpty) return true;

    if (!context.mounted) return false;

    final trialRepo = ref.read(trialRepositoryProvider);
    final trialNames = <String>[];
    for (final s in openSessions) {
      final trial = await trialRepo.getTrialById(s.trialId);
      if (trial != null) trialNames.add(trial.name);
    }
    final namesText =
        trialNames.isNotEmpty ? trialNames.join(', ') : 'an active trial';

    if (!context.mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Session In Progress'),
        content: Text(
          'Close your open session in $namesText before switching profiles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _selectUser(
    BuildContext context,
    WidgetRef ref,
    User user,
  ) async {
    if (!await _warnOpenSessionsOrAllowProceed(context, ref)) return;
    final fresh = await ref.read(userRepositoryProvider).getUserById(
              user.id,
            ) ??
        user;
    if (!context.mounted) return;
    await setCurrentUserId(fresh.id);
    ref.invalidate(currentUserIdProvider);
    ref.invalidate(currentUserProvider);
    if (!context.mounted) return;
    if (popOnSelect) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MainShellScreen(),
        ),
      );
    }
  }

  Future<void> _openAddUser(BuildContext context, WidgetRef ref) async {
    final userId = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const AddUserScreen()),
    );
    if (userId != null && context.mounted) {
      if (!await _warnOpenSessionsOrAllowProceed(context, ref)) return;
      await setCurrentUserId(userId);
      ref.invalidate(currentUserIdProvider);
      ref.invalidate(currentUserProvider);
      if (!context.mounted) return;
      if (popOnSelect) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShellScreen()),
        );
      }
    }
  }
}
