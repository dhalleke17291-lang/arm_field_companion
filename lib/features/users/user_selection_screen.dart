import 'package:flutter/material.dart';
import '../../core/widgets/gradient_screen_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/current_user.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../shell/main_shell_screen.dart';
import 'add_user_screen.dart';

/// Shown when no current_user_id is set. User taps to select or adds a new user.
class UserSelectionScreen extends ConsumerWidget {
  const UserSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(activeUsersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EB),
      appBar: const GradientScreenHeader(title: 'Select User'),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (users) => users.isEmpty
            ? _buildEmpty(context, ref)
            : _buildList(context, ref, users),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddUser(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text(
              'No users yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a user to get started.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _openAddUser(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add User'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<User> users) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                (user.initials?.isNotEmpty == true)
                    ? user.initials!.toUpperCase()
                    : user.displayName.isNotEmpty
                        ? user.displayName.substring(0, 1).toUpperCase()
                        : '?',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(user.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: user.initials?.isNotEmpty == true
                ? Text(user.initials!)
                : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectUser(context, ref, user.id),
          ),
        );
      },
    );
  }

  Future<void> _selectUser(BuildContext context, WidgetRef ref, int userId) async {
    await setCurrentUserId(userId);
    ref.invalidate(currentUserIdProvider);
    ref.invalidate(currentUserProvider);
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShellScreen()),
    );
  }

  Future<void> _openAddUser(BuildContext context, WidgetRef ref) async {
    final userId = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const AddUserScreen()),
    );
    if (userId != null && context.mounted) {
      await setCurrentUserId(userId);
      ref.invalidate(currentUserIdProvider);
      ref.invalidate(currentUserProvider);
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShellScreen()),
      );
    }
  }
}
