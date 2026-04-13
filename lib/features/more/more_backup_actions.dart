import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../backup/backup_models.dart';
import '../backup/backup_password_dialog.dart';
import '../backup/backup_reminder_store.dart';

Future<void> showBackupProgressDialog(
  BuildContext context,
  String message,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppDesignTokens.cardSurface,
        content: Row(
          children: [
            const CircularProgressIndicator(color: AppDesignTokens.primary),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppDesignTokens.primaryText),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> runBackupFlow(BuildContext context, WidgetRef ref) async {
  final pwd = await showBackupPasswordDialog(context, isBackup: true);
  if (pwd == null || !context.mounted) return;

  final status = ValueNotifier<String>('Preparing database...');
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ValueListenableBuilder<String>(
      valueListenable: status,
      builder: (ctx, message, __) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppDesignTokens.cardSurface,
          content: Row(
            children: [
              const CircularProgressIndicator(color: AppDesignTokens.primary),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: AppDesignTokens.primaryText),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 50));
  try {
    final file = await ref.read(backupServiceProvider).createBackup(
      pwd,
      onProgress: (s) => status.value = s,
    );
    if (context.mounted) nav.pop();
    if (context.mounted) {
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/octet-stream')],
        text: 'Agnexis encrypted backup',
      );
      // Record backup timestamp for reminder system.
      final prefs = await SharedPreferences.getInstance();
      await BackupReminderStore(prefs).recordBackupCompleted();
    }
  } catch (e) {
    if (context.mounted) nav.pop();
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppDesignTokens.cardSurface,
          title: const Text(
            'Backup Failed',
            style: TextStyle(color: AppDesignTokens.primaryText),
          ),
          content: Text(
            e.toString(),
            style: const TextStyle(color: AppDesignTokens.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'OK',
                style: TextStyle(color: AppDesignTokens.primary),
              ),
            ),
          ],
        ),
      );
    }
  } finally {
    status.dispose();
  }
}

Future<void> runRestoreFlow(BuildContext context, WidgetRef ref) async {
  final pick = await FilePicker.platform.pickFiles(type: FileType.any);
  // Tested manually — cancel returns cleanly (no restore, no DB access).
  if (pick == null || pick.files.isEmpty) return;
  if (!context.mounted) return;
  final path = pick.files.single.path;
  if (path == null) return;
  if (!path.toLowerCase().endsWith('.agnexis')) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDesignTokens.cardSurface,
        title: const Text(
          'Invalid File',
          style: TextStyle(color: AppDesignTokens.primaryText),
        ),
        content: const Text(
          'Please select an Agnexis backup file (.agnexis)',
          style: TextStyle(color: AppDesignTokens.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'OK',
              style: TextStyle(color: AppDesignTokens.primary),
            ),
          ),
        ],
      ),
    );
    return;
  }

  final pwd = await showBackupPasswordDialog(context, isBackup: false);
  if (pwd == null || !context.mounted) return;

  final nav = Navigator.of(context, rootNavigator: true);
  await showBackupProgressDialog(context, 'Validating backup...');
  BackupMeta meta;
  try {
    meta = await ref
        .read(restoreServiceProvider)
        .validateBackup(File(path), pwd);
  } catch (e) {
    if (context.mounted) nav.pop();
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppDesignTokens.cardSurface,
          title: const Text(
            'Restore Failed',
            style: TextStyle(color: AppDesignTokens.primaryText),
          ),
          content: Text(
            e.toString(),
            style: const TextStyle(color: AppDesignTokens.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'OK',
                style: TextStyle(color: AppDesignTokens.primary),
              ),
            ),
          ],
        ),
      );
    }
    return;
  }
  if (context.mounted) nav.pop();

  final fmt = DateFormat.yMMMd().add_jm();
  final localDate = fmt.format(meta.backupDate.toLocal());
  if (!context.mounted) return;
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppDesignTokens.cardSurface,
      title: const Text(
        'Restore from Backup?',
        style: TextStyle(color: AppDesignTokens.primaryText),
      ),
      content: Text(
        'Backup date: $localDate\n'
        'Schema version: ${meta.schemaVersion}\n'
        'Trials: ${meta.trialCount}\n'
        'Photos: ${meta.photoCount}\n\n'
        'This will REPLACE ALL current data.\n'
        'A safety snapshot of your current data will be saved first.\n\n'
        'Linked rating sheets were preserved in the backup but may need to be re-linked.',
        style: const TextStyle(color: AppDesignTokens.secondaryText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppDesignTokens.primary),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppDesignTokens.primary,
            foregroundColor: AppDesignTokens.onPrimary,
          ),
          child: const Text('Restore'),
        ),
      ],
    ),
  );
  if (confirm != true || !context.mounted) return;

  await showBackupProgressDialog(context, 'Restoring data...');
  try {
    final restored =
        await ref.read(restoreServiceProvider).restore(File(path), pwd);
    if (!restored) return;
    if (context.mounted) nav.pop();
    if (!context.mounted) return;
    // Post-restore: [databaseProvider] holds a closed [AppDatabase]. Show ONLY this
    // dialog — block back so the shell cannot rebuild and watch DB providers.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppDesignTokens.cardSurface,
          title: const Text(
            'Restore Complete',
            style: TextStyle(color: AppDesignTokens.primaryText),
          ),
          content: Text(
            Platform.isAndroid
                ? 'All data has been restored. The app will now close. Please reopen it.'
                : 'All data has been restored. Please close and reopen the app.',
            style: const TextStyle(color: AppDesignTokens.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (Platform.isAndroid) {
                  SystemNavigator.pop();
                }
                Navigator.of(ctx).pop();
              },
              child: const Text(
                'OK',
                style: TextStyle(color: AppDesignTokens.primary),
              ),
            ),
          ],
        ),
      ),
    );
  } catch (e) {
    if (context.mounted) nav.pop();
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppDesignTokens.cardSurface,
          title: const Text(
            'Restore Failed',
            style: TextStyle(color: AppDesignTokens.primaryText),
          ),
          content: Text(
            '${e.toString()}\n\nA safety snapshot may be available in your documents folder.',
            style: const TextStyle(color: AppDesignTokens.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'OK',
                style: TextStyle(color: AppDesignTokens.primary),
              ),
            ),
          ],
        ),
      );
    }
  }
}
