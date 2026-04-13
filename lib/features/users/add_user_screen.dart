import 'package:flutter/material.dart';
import '../../core/widgets/gradient_screen_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

/// Minimal add-user flow: display name (required), initials (optional).
/// role_key defaults to technician; not exposed in UI.
class AddUserScreen extends ConsumerStatefulWidget {
  const AddUserScreen({super.key});

  @override
  ConsumerState<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends ConsumerState<AddUserScreen> {
  final _nameController = TextEditingController();
  final _initialsController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _initialsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name is required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(userRepositoryProvider);
      final user = await repo.createUser(
        displayName: name,
        initials: _initialsController.text.trim().isEmpty
            ? null
            : _initialsController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, user.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create user: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EB),
      appBar: const GradientScreenHeader(title: 'Add User'),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save and continue'),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
