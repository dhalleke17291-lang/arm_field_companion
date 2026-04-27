import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';
import 'pin_setup_screen.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final User user;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late User _user;
  late TextEditingController _nameController;
  late TextEditingController _initialsController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _nameController = TextEditingController(text: _user.displayName);
    _initialsController = TextEditingController(
      text: _user.initials ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _initialsController.dispose();
    super.dispose();
  }

  Future<void> _openPin() async {
    final fresh = await ref.read(userRepositoryProvider).getUserById(
          _user.id,
        );
    if (fresh == null || !mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PinSetupScreen(user: fresh),
      ),
    );
    final u2 = await ref.read(userRepositoryProvider).getUserById(_user.id);
    if (u2 != null && mounted) {
      setState(() => _user = u2);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Display name is required'),
          backgroundColor: AppDesignTokens.warningBg,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).updateUser(
            _user.id,
            displayName: name,
            initials: _initialsController.text,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: $e'),
            backgroundColor: AppDesignTokens.warningBg,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    return Scaffold(
      backgroundColor: AppDesignTokens.bgWarm,
      appBar: const GradientScreenHeader(title: 'Edit profile'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display name *',
                hintText: 'e.g. Jane Smith',
              ),
              textCapitalization: TextCapitalization.words,
              enabled: !_saving,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _initialsController,
              decoration: const InputDecoration(
                labelText: 'Initials (optional)',
                hintText: 'e.g. JS',
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              enabled: !_saving,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _openPin,
              style: FilledButton.styleFrom(
                backgroundColor: AppDesignTokens.cardSurface,
                foregroundColor: AppDesignTokens.primary,
                side: const BorderSide(color: AppDesignTokens.borderCrisp),
              ),
              child: Text(
                u.pinEnabled ? 'Change PIN' : 'Set PIN',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
