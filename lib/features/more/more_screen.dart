import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/connectivity/google_drive_backup_provider.dart';
import '../../core/connectivity/onedrive_backup_provider.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../backup/backup_audit_preferences.dart';
import '../backup/backup_passphrase_store.dart';
import '../backup/backup_reminder_store.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../recovery/recovery_screen.dart';
import '../users/user_selection_screen.dart';
import 'more_backup_actions.dart';

void _openUserSelection(BuildContext context) {
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute<void>(
      builder: (_) => const UserSelectionScreen(),
    ),
    (route) => false,
  );
}

/// Threshold for "stale backup" — nudge the user with a muted amber chip.
const int _kStaleBackupDays = 7;

/// More tab: settings-style layout (account, diagnostics, backup).
class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  BackupReminderStore? _backupStore;
  BackupAuditPreferences? _auditPrefs;
  final _passphraseStore = BackupPassphraseStore();
  bool _hasCachedPassphrase = false;
  bool _isDriveConnected = false;
  String? _driveEmail;
  bool _isOneDriveConnected = false;
  String? _oneDriveEmail;

  @override
  void initState() {
    super.initState();
    _loadStores();
    _refreshPassphraseState();
    _refreshDriveState();
    _refreshOneDriveState();
  }

  Future<void> _loadStores() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _backupStore = BackupReminderStore(prefs);
      _auditPrefs = BackupAuditPreferences(prefs);
    });
  }

  Future<void> _refreshPassphraseState() async {
    final has = await _passphraseStore.hasCached();
    if (mounted) setState(() => _hasCachedPassphrase = has);
  }

  Future<void> _refreshAfterBackup() async {
    await _loadStores();
    await _refreshPassphraseState();
  }

  Future<void> _refreshDriveState() async {
    final provider = GoogleDriveBackupProvider.instance;
    final connected = await provider.isAuthenticated;
    if (!connected) {
      await provider.signInSilently();
    }
    final email = provider.connectedEmail;
    if (mounted) {
      setState(() {
        _isDriveConnected = provider.connectedEmail != null;
        _driveEmail = email;
      });
    }
  }

  Future<void> _refreshOneDriveState() async {
    final provider = OneDriveBackupProvider.instance;
    final connected = await provider.isAuthenticated;
    if (mounted) {
      setState(() {
        _isOneDriveConnected = connected;
        _oneDriveEmail = provider.connectedEmail;
      });
    }
  }

  Future<void> _onOneDriveTap() async {
    final provider = OneDriveBackupProvider.instance;
    if (!_isOneDriveConnected) {
      final ok = await provider.authenticate();
      if (!mounted) return;
      if (ok) {
        await _refreshOneDriveState();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OneDrive connected!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sign-in failed: ${provider.lastAuthError ?? "cancelled"}',
              ),
            ),
          );
        }
      }
      return;
    }

    if (!mounted) return;
    final action = await showModalBottomSheet<_DriveAction>(
      context: context,
      backgroundColor: AppDesignTokens.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined,
                  color: AppDesignTokens.primary),
              title: const Text('Upload backup to OneDrive',
                  style: TextStyle(color: AppDesignTokens.primaryText)),
              onTap: () => Navigator.pop(ctx, _DriveAction.upload),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined,
                  color: AppDesignTokens.primary),
              title: const Text('Restore from OneDrive',
                  style: TextStyle(color: AppDesignTokens.primaryText)),
              onTap: () => Navigator.pop(ctx, _DriveAction.restore),
            ),
            ListTile(
              leading: const Icon(Icons.logout,
                  color: AppDesignTokens.secondaryText),
              title: const Text('Disconnect OneDrive',
                  style: TextStyle(color: AppDesignTokens.secondaryText)),
              onTap: () => Navigator.pop(ctx, _DriveAction.signOut),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    switch (action) {
      case _DriveAction.upload:
        await runOneDriveBackupFlow(context, ref);
        await _refreshOneDriveState();
      case _DriveAction.restore:
        await runOneDriveRestoreFlow(context, ref);
      case _DriveAction.signOut:
        await provider.signOut();
        await _refreshOneDriveState();
    }
  }

  Future<void> _onDriveTap() async {
    final provider = GoogleDriveBackupProvider.instance;
    if (!_isDriveConnected) {
      final ok = await provider.authenticate();
      if (!mounted) return;
      if (ok) {
        await _refreshDriveState();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sign-in failed: ${provider.lastAuthError ?? "cancelled"}',
              ),
            ),
          );
        }
      }
      return;
    }

    if (!mounted) return;
    final action = await showModalBottomSheet<_DriveAction>(
      context: context,
      backgroundColor: AppDesignTokens.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined,
                  color: AppDesignTokens.primary),
              title: const Text('Upload backup to Drive',
                  style: TextStyle(color: AppDesignTokens.primaryText)),
              onTap: () => Navigator.pop(ctx, _DriveAction.upload),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined,
                  color: AppDesignTokens.primary),
              title: const Text('Restore from Drive',
                  style: TextStyle(color: AppDesignTokens.primaryText)),
              onTap: () => Navigator.pop(ctx, _DriveAction.restore),
            ),
            ListTile(
              leading: const Icon(Icons.logout,
                  color: AppDesignTokens.secondaryText),
              title: const Text('Disconnect Google Drive',
                  style: TextStyle(color: AppDesignTokens.secondaryText)),
              onTap: () => Navigator.pop(ctx, _DriveAction.signOut),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    switch (action) {
      case _DriveAction.upload:
        await runCloudBackupFlow(context, ref);
        await _refreshDriveState();
      case _DriveAction.restore:
        await runCloudRestoreFlow(context, ref);
      case _DriveAction.signOut:
        await provider.signOut();
        await _refreshDriveState();
    }
  }

  Future<void> _forgetPassphrase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDesignTokens.cardSurface,
        title: const Text(
          'Forget saved passphrase?',
          style: TextStyle(color: AppDesignTokens.primaryText),
        ),
        content: const Text(
          'Next backup will ask you to enter a passphrase again.',
          style: TextStyle(color: AppDesignTokens.secondaryText),
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
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _passphraseStore.clear();
    await _refreshPassphraseState();
  }

  Future<void> _showBackupReminderModePicker() async {
    final store = _backupStore;
    if (store == null) return;
    final current = store.mode;
    final selected = await showDialog<BackupReminderMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Backup Reminder'),
        children: BackupReminderMode.values.map((mode) {
          final isSelected = mode == current;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, mode),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color: isSelected
                      ? AppDesignTokens.primary
                      : AppDesignTokens.iconSubtle,
                ),
                const SizedBox(width: 12),
                Text(
                  backupReminderModeLabel(mode),
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (selected != null && mounted) {
      await store.setMode(selected);
      setState(() {});
    }
  }

  List<Widget> _backupReminderRows() {
    final s = _backupStore;
    if (s == null) return [];
    return [
      _MoreRow(
        icon: Icons.notifications_outlined,
        title: 'Backup Reminder',
        subtitle: Text(
          backupReminderModeLabel(s.mode),
          style: const TextStyle(
            fontSize: 13,
            color: AppDesignTokens.secondaryText,
          ),
        ),
        onTap: _showBackupReminderModePicker,
      ),
      const Divider(height: 1, indent: 70),
    ];
  }

  Widget _backupSubtitleWithStatus() {
    final store = _backupStore;
    final last = store?.lastBackupTime;
    final ageDays =
        last == null ? null : DateTime.now().difference(last).inDays;
    final isStale = store != null &&
        (last == null || (ageDays != null && ageDays >= _kStaleBackupDays));
    final lastLabel = store?.lastBackupLabel ?? 'Never';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Create an encrypted backup file to save or share',
          style: TextStyle(
            fontSize: 13,
            color: AppDesignTokens.secondaryText,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'Last backup: $lastLabel',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isStale
                    ? AppDesignTokens.warningFg
                    : AppDesignTokens.secondaryText.withValues(alpha: 0.85),
              ),
            ),
            if (isStale) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppDesignTokens.warningBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  last == null ? 'No backup yet' : 'Back up now',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppDesignTokens.warningFg,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: const GradientScreenHeader(
        title: 'More',
        leading: SizedBox(width: 48),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          children: [
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppDesignTokens.borderCrisp),
              ),
              color: AppDesignTokens.cardSurface,
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  userAsync.when(
                    loading: () => _MoreRow(
                      icon: Icons.person_outline_rounded,
                      title: 'Change User',
                      subtitle: const Text(
                        'Select or add a user',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppDesignTokens.secondaryText,
                        ),
                      ),
                      onTap: () => _openUserSelection(context),
                    ),
                    error: (_, __) => _MoreRow(
                      icon: Icons.person_add_outlined,
                      title: 'Select User',
                      subtitle: const Text(
                        'Sign in to use the app',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppDesignTokens.secondaryText,
                        ),
                      ),
                      onTap: () => _openUserSelection(context),
                    ),
                    data: (user) => _MoreRow(
                      icon: Icons.person_outline_rounded,
                      title: 'Change User',
                      subtitle: Text(
                        user != null
                            ? 'Signed in as ${user.displayName}'
                            : 'Select or add a user',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppDesignTokens.secondaryText,
                        ),
                      ),
                      onTap: () => _openUserSelection(context),
                    ),
                  ),
                  const Divider(height: 1, indent: 70),
                ],
              ),
            ),
            const _MoreSectionHeader('Data & Diagnostics'),
            const SizedBox(height: 8),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppDesignTokens.borderCrisp),
              ),
              color: AppDesignTokens.cardSurface,
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MoreRow(
                    icon: Icons.analytics_outlined,
                    title: 'Diagnostics',
                    subtitle: const Text(
                      'Integrity, audit log, derived data',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const DiagnosticsScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 70),
                  _MoreRow(
                    icon: Icons.restore_from_trash_outlined,
                    title: 'Recovery',
                    subtitle: const Text(
                      'View deleted trials, sessions and plots',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const RecoveryScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const _MoreSectionHeader('Backup'),
            const SizedBox(height: 8),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppDesignTokens.borderCrisp),
              ),
              color: AppDesignTokens.cardSurface,
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MoreRow(
                    icon: Icons.backup_outlined,
                    title: 'Backup',
                    subtitle: _backupSubtitleWithStatus(),
                    onTap: () async {
                      await runBackupFlow(context, ref);
                      if (!mounted) return;
                      await _refreshAfterBackup();
                    },
                  ),
                  const Divider(height: 1, indent: 70),
                  ..._backupReminderRows(),
                  _MoreRow(
                    icon: Icons.restore_outlined,
                    title: 'Restore from Backup',
                    subtitle: const Text(
                      'Replace all data from a backup file',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                    onTap: () => runRestoreFlow(context, ref),
                  ),
                  const Divider(height: 1, indent: 70),
                  _MoreRow(
                    icon: Icons.cloud_outlined,
                    title: 'Google Drive',
                    subtitle: Text(
                      _isDriveConnected
                          ? 'Connected${_driveEmail != null ? " as $_driveEmail" : ""}'
                          : 'Back up to Google Drive',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                    onTap: () => _onDriveTap(),
                  ),
                  const Divider(height: 1, indent: 70),
                  _MoreRow(
                    icon: Icons.cloud_outlined,
                    title: 'OneDrive',
                    subtitle: Text(
                      _isOneDriveConnected
                          ? 'Connected${_oneDriveEmail != null ? " as $_oneDriveEmail" : ""}'
                          : 'Back up to Microsoft OneDrive',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                    onTap: () => _onOneDriveTap(),
                  ),
                  if (_auditPrefs != null || _hasCachedPassphrase)
                    const Divider(height: 1, indent: 70),
                  if (_auditPrefs case final audit?) ...[
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      title: const Text(
                        'Clear audit log after backup',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppDesignTokens.primaryText,
                        ),
                      ),
                      subtitle: const Text(
                        'When enabled, a successful encrypted backup removes audit history from this device only. '
                        'The full history remains inside the .agnexis file. Leave off to keep the log on device.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: AppDesignTokens.secondaryText,
                        ),
                      ),
                      value: audit.clearAuditLogAfterSuccessfulBackup,
                      activeThumbColor: AppDesignTokens.onPrimary,
                      activeTrackColor: AppDesignTokens.primary,
                      onChanged: (next) async {
                        await audit.setClearAuditLogAfterSuccessfulBackup(next);
                        if (mounted) setState(() {});
                      },
                    ),
                    if (_hasCachedPassphrase)
                      const Divider(height: 1, indent: 70),
                  ],
                  if (_hasCachedPassphrase)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgetPassphrase,
                          style: TextButton.styleFrom(
                            foregroundColor: AppDesignTokens.warningFg,
                          ),
                          child: const Text(
                            'Forget saved passphrase',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreSectionHeader extends StatelessWidget {
  const _MoreSectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: AppDesignTokens.secondaryText,
        ),
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppDesignTokens.primaryTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: AppDesignTokens.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppDesignTokens.primaryText,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    subtitle!,
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppDesignTokens.iconSubtle,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

enum _DriveAction { upload, restore, signOut }
