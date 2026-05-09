import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/connectivity/google_drive_backup_provider.dart';
import '../../core/connectivity/onedrive_backup_provider.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../backup/backup_passphrase_store.dart';
import '../backup/backup_reminder_store.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../recovery/recovery_screen.dart';
import '../users/user_selection_screen.dart';
import 'more_backup_actions.dart';

void _openUserSelection(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => const UserSelectionScreen(popOnSelect: true),
    ),
  );
}

/// Threshold for "stale backup" — nudge the user with a muted amber chip.
const int _kStaleBackupDays = 7;

/// More tab: settings-style layout (field user, diagnostics, backup).
class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  BackupReminderStore? _backupStore;
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
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
        subtitle: 'Field user, recovery, and backup settings',
        leading: SizedBox(width: 48),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 18),
          children: [
            _MoreCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  userAsync.when(
                    loading: () => _MoreRow(
                      icon: Icons.person_outline_rounded,
                      title: 'Current User',
                      subtitle: const Text(
                        'Used for session and rating attribution',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppDesignTokens.secondaryText,
                        ),
                      ),
                      onTap: () => _openUserSelection(context),
                      prominent: true,
                    ),
                    error: (_, __) => _MoreRow(
                      icon: Icons.person_add_outlined,
                      title: 'Current User',
                      subtitle: const Text(
                        'Choose a field profile to attribute work',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppDesignTokens.secondaryText,
                        ),
                      ),
                      onTap: () => _openUserSelection(context),
                      prominent: true,
                    ),
                    data: (user) => _MoreRow(
                      icon: Icons.person_outline_rounded,
                      title: 'Current User',
                      subtitle: Text(
                        user != null
                            ? 'Using app as ${user.displayName}'
                            : 'Choose a field profile to attribute work',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppDesignTokens.secondaryText,
                        ),
                      ),
                      onTap: () => _openUserSelection(context),
                      prominent: true,
                      statusChip: user != null
                          ? const _StatusChip(
                              label: 'Current',
                              color: AppDesignTokens.successFg,
                              backgroundColor: AppDesignTokens.successBg,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const _MoreSectionHeader(
              'Data & Diagnostics',
              subtitle: 'Support tools, activity review, and recovery',
            ),
            _MoreCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MoreRow(
                    icon: Icons.analytics_outlined,
                    title: 'Diagnostics',
                    subtitle: const Text(
                      'Support report, checks and app errors',
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
                  const _MoreDivider(),
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
            const _MoreSectionHeader(
              'Backup',
              subtitle: 'Protect field data before device or app changes',
            ),
            _MoreCard(
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
                    prominent: true,
                  ),
                  const _MoreDivider(),
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
                  const _MoreDivider(),
                  const _MoreGroupLabel('Cloud destinations'),
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
                    statusChip: _isDriveConnected
                        ? const _StatusChip(
                            label: 'Connected',
                            color: AppDesignTokens.successFg,
                            backgroundColor: AppDesignTokens.successBg,
                          )
                        : const _StatusChip(
                            label: 'Not set up',
                            color: AppDesignTokens.secondaryText,
                            backgroundColor: AppDesignTokens.emptyBadgeBg,
                          ),
                  ),
                  const _MoreDivider(),
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
                    statusChip: _isOneDriveConnected
                        ? const _StatusChip(
                            label: 'Connected',
                            color: AppDesignTokens.successFg,
                            backgroundColor: AppDesignTokens.successBg,
                          )
                        : const _StatusChip(
                            label: 'Not set up',
                            color: AppDesignTokens.secondaryText,
                            backgroundColor: AppDesignTokens.emptyBadgeBg,
                          ),
                  ),
                  if (_hasCachedPassphrase) const _MoreDivider(),
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
  const _MoreSectionHeader(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: AppDesignTokens.primary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                height: 1.25,
                color: AppDesignTokens.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoreCard extends StatelessWidget {
  const _MoreCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: AppDesignTokens.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _MoreGroupLabel extends StatelessWidget {
  const _MoreGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 2),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppDesignTokens.secondaryText,
        ),
      ),
    );
  }
}

class _MoreDivider extends StatelessWidget {
  const _MoreDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 76,
      color: AppDesignTokens.divider,
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.statusChip,
    this.prominent = false,
  });

  final IconData icon;
  final String title;
  final Widget? subtitle;
  final VoidCallback? onTap;
  final Widget? statusChip;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: 18,
          vertical: prominent ? 18 : 15,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: prominent ? 48 : 44,
              height: prominent ? 48 : 44,
              decoration: BoxDecoration(
                color: prominent
                    ? AppDesignTokens.sectionHeaderBg
                    : AppDesignTokens.primaryTint,
                borderRadius:
                    BorderRadius.circular(AppDesignTokens.radiusSmall),
                border: Border.all(
                  color: AppDesignTokens.primary.withValues(alpha: 0.08),
                ),
              ),
              child: Icon(
                icon,
                color: AppDesignTokens.primary,
                size: prominent ? 23 : 21,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: prominent ? 17 : 15.5,
                      fontWeight: prominent ? FontWeight.w700 : FontWeight.w600,
                      color: AppDesignTokens.primaryText,
                      height: 1.15,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 5),
                    subtitle!,
                  ],
                  if (statusChip != null) ...[
                    const SizedBox(height: 8),
                    statusChip!,
                  ],
                ],
              ),
            ),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppDesignTokens.emptyBadgeBg.withValues(alpha: 0.65),
                borderRadius:
                    BorderRadius.circular(AppDesignTokens.radiusXSmall),
              ),
              child: const Icon(
                Icons.chevron_right,
                color: AppDesignTokens.secondaryText,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusChip),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          height: 1.1,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

enum _DriveAction { upload, restore, signOut }
