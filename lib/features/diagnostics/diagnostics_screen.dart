import 'package:flutter/material.dart';
import '../../core/widgets/gradient_screen_header.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_info.dart';
import '../../core/diagnostics/app_error.dart';
import '../../core/diagnostics/diagnostics_store.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../shared/widgets/app_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/diagnostics/reset_app_data.dart';
import 'integrity_check_result.dart';
import 'audit_log_screen.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  List<IntegrityIssue>? _integrityIssues;
  bool _integrityLoading = false;

  Future<void> _runIntegrityChecks() async {
    setState(() {
      _integrityLoading = true;
      _integrityIssues = null;
    });
    try {
      final repo = ref.read(integrityCheckRepositoryProvider);
      final issues = await repo.runChecks();
      if (mounted) setState(() => _integrityIssues = issues);
    } catch (e) {
      if (mounted) {
        setState(() => _integrityIssues = [
              IntegrityIssue(
                code: 'check_error',
                summary: 'Integrity check failed',
                count: 1,
                detail: e.toString(),
              ),
            ]);
      }
    } finally {
      if (mounted) setState(() => _integrityLoading = false);
    }
  }

  Future<void> _copyError(AppError error) async {
    await Clipboard.setData(ClipboardData(text: error.toCopyableReport()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard')),
      );
    }
  }

  Future<void> _copyAllErrors(DiagnosticsStore store) async {
    final report = store.recentErrors.map((e) => e.toCopyableReport()).join('\n---\n');
    if (report.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: report));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied ${store.recentErrors.length} error(s) to clipboard')),
      );
    }
  }

  Future<void> _exportReport(DiagnosticsStore store) async {
    final buffer = StringBuffer();
    buffer.writeln('Diagnostics Report');
    buffer.writeln('App: $kAppVersion');
    buffer.writeln('Date: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');
    buffer.writeln('Integrity: ${_integrityIssues == null ? "Not run" : _integrityIssues!.isEmpty ? "OK" : "${_integrityIssues!.length} issue(s)"}');
    if (_integrityIssues != null && _integrityIssues!.isNotEmpty) {
      for (final i in _integrityIssues!) {
        buffer.writeln('  - ${i.summary}: ${i.count}${i.detail != null ? " (${i.detail})" : ""}');
      }
    }
    buffer.writeln('');
    buffer.writeln('Recent errors: ${store.recentErrors.length}');
    if (store.recentErrors.isNotEmpty) {
      buffer.writeln(store.recentErrors.map((e) => e.toCopyableReport()).join('\n---\n'));
    }
    try {
      await Share.share(
        buffer.toString(),
        subject: 'Diagnostics report ${DateTime.now().toIso8601String().substring(0, 10)}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export opened')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showResetConfirmDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ResetConfirmDialog(
        onCancel: () => Navigator.pop(ctx),
        onConfirm: () async {
          Navigator.pop(ctx);
          await _performReset();
        },
      ),
    );
  }

  Future<void> _performReset() async {
    try {
      final db = ref.read(databaseProvider);
      final prefs = await SharedPreferences.getInstance();
      await resetAppData(db, prefs: prefs);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All app data deleted. Restarting…')),
      );
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(diagnosticsStoreProvider);
    final errors = store.recentErrors;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EB),
      appBar: GradientScreenHeader(
        title: 'Diagnostics',
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            tooltip: 'Export report',
            onPressed: () => _exportReport(store),
          ),
          if (errors.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy_all, color: Colors.white),
              tooltip: 'Copy all errors',
              onPressed: () => _copyAllErrors(store),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              tooltip: 'Clear errors',
              onPressed: () {
                store.clear();
                setState(() {});
              },
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // System Status
          AppCard(
            padding: const EdgeInsets.all(AppDesignTokens.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'System Status',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: _StatusItem(
                        icon: Icons.storage_outlined,
                        label: 'Database',
                        value: 'Ready',
                        valueColor: AppDesignTokens.primary,
                      ),
                    ),
                    Expanded(
                      child: _StatusItem(
                        icon: Icons.health_and_safety_outlined,
                        label: 'Integrity',
                        value: _integrityIssues == null
                            ? 'Run checks'
                            : _integrityIssues!.isEmpty
                                ? 'OK'
                                : 'Issues',
                        valueColor: _integrityIssues == null
                            ? AppDesignTokens.secondaryText
                            : _integrityIssues!.isEmpty
                                ? AppDesignTokens.primary
                                : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _StatusItem(
                        icon: Icons.history_outlined,
                        label: 'Audit',
                        value: 'Enabled',
                        valueColor: AppDesignTokens.primary,
                      ),
                    ),
                    Expanded(
                      child: _StatusItem(
                        icon: Icons.file_download_outlined,
                        label: 'Export',
                        value: 'Available',
                        valueColor: AppDesignTokens.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Audit log
          AppCard(
            padding: const EdgeInsets.all(AppDesignTokens.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Audit log',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'View and export the full audit history (read-only).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AuditLogScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history_outlined),
                    label: const Text('Open audit log'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const SizedBox(height: 16),
          // App info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App version',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kAppVersion,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Recent errors
          Text(
            'Recent errors',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (errors.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No errors recorded.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            )
          else
            ...errors.take(20).map((e) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      Icons.warning_amber_rounded,
                      color: theme.colorScheme.error,
                      size: 28,
                    ),
                    title: Text(
                      e.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      '${e.timestamp.toIso8601String().substring(0, 19)}${e.code != null ? ' · ${e.code}' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: 'Copy report',
                      onPressed: () => _copyError(e),
                    ),
                  ),
                )),
          const SizedBox(height: 24),

          // Integrity checks
          Text(
            'Integrity checks',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Read-only checks. No data is modified.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _integrityLoading ? null : _runIntegrityChecks,
            icon: _integrityLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.health_and_safety_outlined),
            label: Text(_integrityLoading ? 'Running...' : 'Run integrity checks'),
          ),
          if (_integrityIssues != null) ...[
            const SizedBox(height: 12),
            if (_integrityIssues!.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'No issues found.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._integrityIssues!.map((issue) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  issue.summary,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                '${issue.count}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (issue.detail != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              issue.detail!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )),
          ],
          const SizedBox(height: 24),
          // Reset App Data
          AppCard(
            padding: const EdgeInsets.all(AppDesignTokens.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Reset App Data',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This will permanently delete ALL data stored in this app.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The following will be erased:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '• All trials\n• Treatments\n• Plots\n• Sessions\n• Ratings\n• Assessments\n• Photos\n• Import history\n• Audit records',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  'This action cannot be undone.\nUse this only for development or testing.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _showResetConfirmDialog,
                  icon: const Icon(Icons.warning_amber, size: 20),
                  label: const Text('RESET APP DATA'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
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

class _ResetConfirmDialog extends StatefulWidget {
  const _ResetConfirmDialog({
    required this.onCancel,
    required this.onConfirm,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  State<_ResetConfirmDialog> createState() => _ResetConfirmDialogState();
}

class _ResetConfirmDialogState extends State<_ResetConfirmDialog> {
  static const String _confirmText = 'DELETE';
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canConfirm = _controller.text.trim() == _confirmText;
    return AlertDialog(
      title: const Text('⚠️ Delete All App Data'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You are about to permanently delete ALL data in ARM Field Companion.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 8),
            const Text(
              'This includes trials, sessions, ratings, imports, and audit history.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text('Type DELETE to confirm.'),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'DELETE',
              ),
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canConfirm ? widget.onConfirm : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: const Text('Delete All Data'),
        ),
      ],
    );
  }
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppDesignTokens.secondaryText),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
