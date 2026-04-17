import 'package:flutter/material.dart';

import '../../core/design/app_design_tokens.dart';

/// Result of the password dialog.
class BackupPasswordResult {
  const BackupPasswordResult({
    required this.passphrase,
    required this.savePassphrase,
  });

  final String passphrase;

  /// True when the user ticked "Save for next time". Only meaningful on
  /// backup flows; always false on restore (we don't offer save there).
  final bool savePassphrase;
}

/// Password entry for backup (confirm) or restore (single field).
///
/// [showSaveCheckbox] — when true on a backup flow, renders a
/// "Save for next time" checkbox (default on). Callers only pass true
/// the first time the user backs up; once a passphrase is cached and
/// the opt-in persisted, the dialog is skipped entirely.
///
/// [helperMessage] — optional. Shown above the password field. Used
/// on restore when a cached passphrase just failed to decrypt the file,
/// so the user sees *why* they're being asked to type something now.
Future<BackupPasswordResult?> showBackupPasswordDialog(
  BuildContext context, {
  required bool isBackup,
  bool showSaveCheckbox = false,
  String? helperMessage,
}) {
  return showDialog<BackupPasswordResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _BackupPasswordDialogBody(
      isBackup: isBackup,
      showSaveCheckbox: showSaveCheckbox,
      helperMessage: helperMessage,
    ),
  );
}

class _BackupPasswordDialogBody extends StatefulWidget {
  const _BackupPasswordDialogBody({
    required this.isBackup,
    required this.showSaveCheckbox,
    this.helperMessage,
  });

  final bool isBackup;
  final bool showSaveCheckbox;
  final String? helperMessage;

  @override
  State<_BackupPasswordDialogBody> createState() =>
      _BackupPasswordDialogBodyState();
}

class _BackupPasswordDialogBodyState extends State<_BackupPasswordDialogBody> {
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _savePassphrase = true;
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
    Navigator.of(context).pop(BackupPasswordResult(
      passphrase: p1,
      savePassphrase: widget.showSaveCheckbox && _savePassphrase,
    ));
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
            if (widget.helperMessage != null) ...[
              Text(
                widget.helperMessage!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
              const SizedBox(height: 12),
            ],
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
            if (widget.showSaveCheckbox) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: () =>
                    setState(() => _savePassphrase = !_savePassphrase),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _savePassphrase,
                        onChanged: (v) =>
                            setState(() => _savePassphrase = v ?? false),
                        activeColor: AppDesignTokens.primary,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Save for next time',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppDesignTokens.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 34),
                child: Text(
                  'Stored securely in the device keychain',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppDesignTokens.secondaryText,
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
