import 'package:flutter/material.dart';

import '../../core/design/app_design_tokens.dart';

/// Password entry for backup (confirm) or restore (single field).
Future<String?> showBackupPasswordDialog(
  BuildContext context, {
  required bool isBackup,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _BackupPasswordDialogBody(isBackup: isBackup),
  );
}

class _BackupPasswordDialogBody extends StatefulWidget {
  const _BackupPasswordDialogBody({required this.isBackup});

  final bool isBackup;

  @override
  State<_BackupPasswordDialogBody> createState() =>
      _BackupPasswordDialogBodyState();
}

class _BackupPasswordDialogBodyState extends State<_BackupPasswordDialogBody> {
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;

  @override
  void dispose() {
    _pw1.dispose();
    _pw2.dispose();
    super.dispose();
  }

  void _submit() {
    final p1 = _pw1.text;
    if (p1.isEmpty) {
      setState(() => _error = 'Password cannot be empty');
      return;
    }
    if (p1.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (widget.isBackup) {
      if (p1 != _pw2.text) {
        setState(() => _error = 'Passwords do not match');
        return;
      }
    }
    Navigator.of(context).pop(p1);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppDesignTokens.cardSurface,
      title: Text(
        widget.isBackup ? 'Backup Password' : 'Restore Password',
        style: const TextStyle(color: AppDesignTokens.primaryText),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _pw1,
              obscureText: _obscure1,
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle:
                    const TextStyle(color: AppDesignTokens.secondaryText),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppDesignTokens.divider),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppDesignTokens.primary),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure1 ? Icons.visibility : Icons.visibility_off,
                    color: AppDesignTokens.iconSubtle,
                  ),
                  onPressed: () => setState(() => _obscure1 = !_obscure1),
                ),
              ),
            ),
            if (widget.isBackup) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _pw2,
                obscureText: _obscure2,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  labelStyle:
                      const TextStyle(color: AppDesignTokens.secondaryText),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppDesignTokens.divider),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppDesignTokens.primary),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure2 ? Icons.visibility : Icons.visibility_off,
                      color: AppDesignTokens.iconSubtle,
                    ),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppDesignTokens.warningFg,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppDesignTokens.primary),
          ),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppDesignTokens.primary,
            foregroundColor: AppDesignTokens.onPrimary,
          ),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
