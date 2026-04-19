import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      appBar: const GradientScreenHeader(
        title: 'More',
        leading: SizedBox(width: 48),
      ),
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
            const SizedBox(height: AppDesignTokens.spacing12),
            _buildActionCard(
              context,
              icon: Icons.restore_from_trash_outlined,
              title: 'Recovery',
              subtitle: 'View deleted trials, sessions and plots',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const RecoveryScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: AppDesignTokens.spacing12),
            _BackupActionCard(onTap: () => runBackupFlow(context, ref)),
            // Forget-passphrase lives inside the card when a passphrase is
            // cached; the card renders it conditionally.
            const SizedBox(height: AppDesignTokens.spacing12),
            _BackupReminderCard(),
            const SizedBox(height: AppDesignTokens.spacing12),
            const _BackupAuditClearPrefCard(),
            const SizedBox(height: AppDesignTokens.spacing12),
            _buildActionCard(
              context,
              icon: Icons.restore_outlined,
              title: 'Restore from Backup',
              subtitle: 'Replace all data from a backup file',
              onTap: () => runRestoreFlow(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildActionCard(
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
                color: AppDesignTokens.shadowLight,
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

/// Threshold for "stale backup" — nudge the user with a muted amber chip.
const int _kStaleBackupDays = 7;

/// Backup action card — tap to back up. Shows last-backup age inline so
/// the user sees status where they'd act, without scrolling to the
/// reminder card below.
class _BackupActionCard extends StatefulWidget {
  const _BackupActionCard({required this.onTap});

  /// Expected to be async — the card awaits the future and refreshes its
  /// state (last-backup timestamp, cached-passphrase indicator) when done.
  final Future<void> Function() onTap;

  @override
  State<_BackupActionCard> createState() => _BackupActionCardState();
}

class _BackupActionCardState extends State<_BackupActionCard> {
  BackupReminderStore? _store;
  final _passphraseStore = BackupPassphraseStore();
  bool _hasCachedPassphrase = false;

  @override
  void initState() {
    super.initState();
    _loadStore();
    _refreshPassphraseState();
  }

  Future<void> _loadStore() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _store = BackupReminderStore(prefs));
  }

  Future<void> _refreshPassphraseState() async {
    final has = await _passphraseStore.hasCached();
    if (mounted) setState(() => _hasCachedPassphrase = has);
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

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final last = store?.lastBackupTime;
    final ageDays =
        last == null ? null : DateTime.now().difference(last).inDays;
    final isStale = store != null &&
        (last == null || (ageDays != null && ageDays >= _kStaleBackupDays));
    final lastLabel = store?.lastBackupLabel ?? 'Never';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppDesignTokens.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          ),
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          child: InkWell(
            onTap: () async {
              await widget.onTap();
              if (!mounted) return;
              await _loadStore();
              await _refreshPassphraseState();
            },
            child: Container(
              padding: const EdgeInsets.all(AppDesignTokens.spacing16),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(AppDesignTokens.radiusCard),
                border: Border.all(color: AppDesignTokens.borderCrisp),
                boxShadow: const [
                  BoxShadow(
                    color: AppDesignTokens.shadowLight,
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
                child: const Icon(
                  Icons.backup_outlined,
                  size: 24,
                  color: AppDesignTokens.primary,
                ),
              ),
              const SizedBox(width: AppDesignTokens.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Backup',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppDesignTokens.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
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
                                : AppDesignTokens.secondaryText
                                    .withValues(alpha: 0.85),
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
                              last == null
                                  ? 'No backup yet'
                                  : 'Back up now',
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
        ),
        if (_hasCachedPassphrase)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _forgetPassphrase,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor:
                    AppDesignTokens.secondaryText.withValues(alpha: 0.85),
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
      ],
    );
  }
}

/// Backup reminder settings card — lets user choose when to be reminded.
class _BackupReminderCard extends StatefulWidget {
  @override
  State<_BackupReminderCard> createState() => _BackupReminderCardState();
}

class _BackupReminderCardState extends State<_BackupReminderCard> {
  BackupReminderStore? _store;

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _store = BackupReminderStore(prefs));
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (store == null) return const SizedBox.shrink();

    final mode = store.mode;
    final lastLabel = store.lastBackupLabel;

    return Material(
      color: AppDesignTokens.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: _showModePicker,
        child: Container(
          padding: const EdgeInsets.all(AppDesignTokens.spacing16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
            border: Border.all(color: AppDesignTokens.borderCrisp),
            boxShadow: const [
              BoxShadow(
                color: AppDesignTokens.shadowLight,
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
                child: const Icon(Icons.notifications_outlined,
                    size: 24, color: AppDesignTokens.primary),
              ),
              const SizedBox(width: AppDesignTokens.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Backup Reminder',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppDesignTokens.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${backupReminderModeLabel(mode)} · Last backup: $lastLabel',
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

  Future<void> _showModePicker() async {
    final store = _store;
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
}

/// User opt-in: clear [audit_events] on device after successful backup (manual or auto).
class _BackupAuditClearPrefCard extends StatefulWidget {
  const _BackupAuditClearPrefCard();

  @override
  State<_BackupAuditClearPrefCard> createState() =>
      _BackupAuditClearPrefCardState();
}

class _BackupAuditClearPrefCardState extends State<_BackupAuditClearPrefCard> {
  BackupAuditPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _prefs = BackupAuditPreferences(p));
  }

  @override
  Widget build(BuildContext context) {
    final store = _prefs;
    if (store == null) {
      return const SizedBox(height: 8);
    }
    final value = store.clearAuditLogAfterSuccessfulBackup;
    return Material(
      color: AppDesignTokens.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          border: Border.all(color: AppDesignTokens.borderCrisp),
          boxShadow: const [
            BoxShadow(
              color: AppDesignTokens.shadowLight,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.spacing16,
            vertical: AppDesignTokens.spacing8,
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
          value: value,
          activeThumbColor: AppDesignTokens.onPrimary,
          activeTrackColor: AppDesignTokens.primary,
          onChanged: (next) async {
            await store.setClearAuditLogAfterSuccessfulBackup(next);
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }
}
