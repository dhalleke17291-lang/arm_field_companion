import 'package:flutter/material.dart';
import '../../core/widgets/gradient_screen_header.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_info.dart';
import '../../core/export_guard.dart';
import '../../core/diagnostics/app_error.dart';
import '../../core/diagnostics/diagnostics_store.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../shared/widgets/app_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/diagnostics/reset_app_data.dart';
import 'integrity_check_result.dart';
import 'scan_rcbd_layouts_usecase.dart';
import 'audit_log_screen.dart';
import 'edited_items_screen.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  List<IntegrityIssue>? _integrityIssues;
  bool _integrityLoading = false;

  RcbdLayoutScanReport? _rcbdScanReport;
  bool _rcbdScanLoading = false;
  String? _rcbdScanError;

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

  Future<void> _runRcbdScan() async {
    setState(() {
      _rcbdScanLoading = true;
      _rcbdScanReport = null;
      _rcbdScanError = null;
    });
    try {
      final useCase = ref.read(scanRcbdLayoutsUseCaseProvider);
      final report = await useCase.execute();
      if (mounted) setState(() => _rcbdScanReport = report);
    } catch (e) {
      if (mounted) setState(() => _rcbdScanError = e.toString());
    } finally {
      if (mounted) setState(() => _rcbdScanLoading = false);
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
    final report =
        store.recentErrors.map((e) => e.toCopyableReport()).join('\n---\n');
    if (report.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: report));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Copied ${store.recentErrors.length} error(s) to clipboard')),
      );
    }
  }

  Future<void> _exportReport(DiagnosticsStore store) async {
    final guard = ref.read(exportGuardProvider);
    final ran = await guard.runExclusive(() async {
      final buffer = StringBuffer();
      buffer.writeln('Diagnostics Report');
      buffer.writeln('App: $kAppVersion');
      buffer.writeln('Date: ${DateTime.now().toIso8601String()}');
      buffer.writeln('');
      buffer.writeln(
          'Integrity: ${_integrityIssues == null ? "Not run" : _integrityIssues!.isEmpty ? "OK" : "${_integrityIssues!.length} issue(s)"}');
      if (_integrityIssues != null && _integrityIssues!.isNotEmpty) {
        for (final i in _integrityIssues!) {
          buffer.writeln(
              '  - ${i.summary}: ${i.count}${i.detail != null ? " (${i.detail})" : ""}');
        }
      }
      buffer.writeln('');
      buffer.writeln('Recent errors: ${store.recentErrors.length}');
      if (store.recentErrors.isNotEmpty) {
        buffer.writeln(store.recentErrors
            .map((e) => e.toCopyableReport())
            .join('\n---\n'));
      }
      try {
        await Share.share(
          buffer.toString(),
          subject:
              'Diagnostics report ${DateTime.now().toIso8601String().substring(0, 10)}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export opened')),
          );
        }
      } catch (e) {
        if (mounted) {
          final scheme = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Export failed — please try again. If the problem persists, check trial data for missing or incomplete records.',
                style: TextStyle(color: scheme.onError),
              ),
              backgroundColor: scheme.error,
            ),
          );
        }
      }
    });
    if (!ran && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(ExportGuard.busyMessage)),
      );
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
        subtitle: 'Health checks, audit records, and support tools',
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
      body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _SupportSnapshotCard(
                errorCount: errors.length,
                onExportReport: () => _exportReport(store),
              ),
              const _DiagnosticsSectionHeader(
                'Checks',
                subtitle: 'Read-only tools for unusual data or export problems',
              ),
              AppCard(
                padding: const EdgeInsets.all(AppDesignTokens.spacing16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Data consistency check',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Looks for missing, duplicate, or inconsistent records. Use when export, review, or app behavior seems off.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _integrityLoading ? null : _runIntegrityChecks,
                        icon: _integrityLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.health_and_safety_outlined),
                        label: Text(_integrityLoading
                            ? 'Checking data...'
                            : 'Check data consistency'),
                      ),
                    ),
                    if (_integrityIssues != null) ...[
                      const SizedBox(height: 12),
                      _IntegrityResultList(issues: _integrityIssues!),
                    ],
                  ],
                ),
              ),
              const _DiagnosticsSectionHeader(
                'Investigate',
                subtitle: 'Open the existing review screens for record history',
              ),
              AppCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DiagnosticsActionRow(
                      icon: Icons.history_outlined,
                      title: 'Audit log',
                      subtitle:
                          'Full activity history, including deleted and restored items',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const AuditLogScreen(),
                          ),
                        );
                      },
                    ),
                    const _DiagnosticsDivider(),
                    _DiagnosticsActionRow(
                      icon: Icons.edit_note_outlined,
                      title: 'Edited items',
                      subtitle: 'Review amended and corrected data',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const EditedItemsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (errors.isNotEmpty) ...[
                const _DiagnosticsSectionHeader(
                  'Recent Errors',
                  subtitle: 'Shown only for the current app session history',
                ),
                AppCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DiagnosticsActionRow(
                        icon: Icons.copy_all,
                        title: 'Copy recent errors',
                        subtitle:
                            'Copy ${errors.length} error${errors.length == 1 ? '' : 's'} to clipboard',
                        onTap: () => _copyAllErrors(store),
                      ),
                      const _DiagnosticsDivider(),
                      _DiagnosticsActionRow(
                        icon: Icons.delete_sweep_outlined,
                        title: 'Clear recent errors',
                        subtitle:
                            'Remove the local error list from this screen',
                        destructive: true,
                        onTap: () {
                          store.clear();
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...errors.take(20).map(
                      (e) => AppCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          leading: Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.error,
                            size: 26,
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
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            tooltip: 'Copy report',
                            onPressed: () => _copyError(e),
                          ),
                        ),
                      ),
                    ),
              ],
              const _DiagnosticsSectionHeader(
                'Advanced',
                subtitle:
                    'Specialized layout checks and destructive maintenance',
              ),

              // RCBD layout audit — read-only scan of standalone RCBD trials
              AppCard(
                padding: const EdgeInsets.all(AppDesignTokens.spacing16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'RCBD layout audit',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Scans custom RCBD trials for duplicate reps, canonical reps, '
                      'or heavy vertical stripes. Read-only.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _rcbdScanLoading ? null : _runRcbdScan,
                        icon: _rcbdScanLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.science_outlined),
                        label: Text(_rcbdScanLoading
                            ? 'Scanning...'
                            : 'Audit RCBD layouts'),
                      ),
                    ),
                  ],
                ),
              ),
              if (_rcbdScanError != null) ...[
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Scan failed: $_rcbdScanError',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
              if (_rcbdScanReport != null) ...[
                const SizedBox(height: 12),
                if (_rcbdScanReport!.isClean)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.check,
                              color: AppDesignTokens.successFg),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _rcbdScanReport!.trialsScanned == 0
                                  ? 'No custom RCBD trials to scan.'
                                  : 'No issues found across '
                                      '${_rcbdScanReport!.trialsScanned} '
                                      'custom RCBD trial${_rcbdScanReport!.trialsScanned == 1 ? '' : 's'}.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      () {
                        final total = _rcbdScanReport!.affectedTrials.length;
                        final scanned = _rcbdScanReport!.trialsScanned;
                        final hardCount = _rcbdScanReport!.affectedTrials
                            .where((a) => a.hasHardViolations)
                            .length;
                        if (hardCount > 0) {
                          return '$hardCount of $scanned trial${scanned == 1 ? '' : 's'} '
                              'with invalid layout. $total total flagged.';
                        }
                        return '$total of $scanned trial${scanned == 1 ? '' : 's'} '
                            'with spatial concerns (all layouts valid).';
                      }(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  ..._rcbdScanReport!.affectedTrials.map(
                    (audit) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: audit.hasHardViolations
                              ? AppDesignTokens.missedColor
                                  .withValues(alpha: 0.4)
                              : AppDesignTokens.warningBorder,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  audit.hasHardViolations
                                      ? Icons.error_outline
                                      : Icons.info_outline,
                                  size: 20,
                                  color: audit.hasHardViolations
                                      ? AppDesignTokens.missedColor
                                      : AppDesignTokens.warningFg,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        audit.trialName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        audit.hasHardViolations
                                            ? 'Layout invalid — must regenerate'
                                            : 'Spatial concern — valid layout',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: audit.hasHardViolations
                                              ? AppDesignTokens.missedColor
                                              : AppDesignTokens.warningFg,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (audit.report.hardViolations.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              for (final v in audit.report.hardViolations)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 28, top: 2),
                                  child: Text(
                                    '\u2022 $v',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppDesignTokens.missedColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                            if (audit.report.softViolations.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              for (final v in audit.report.softViolations)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 28, top: 2),
                                  child: Text(
                                    '\u2022 $v',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppDesignTokens.secondaryText,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),

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
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This will permanently delete ALL data stored in this app.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The following will be erased:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.8),
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
                        fontWeight: FontWeight.w400,
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
          )),
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
              'You are about to permanently delete ALL data in Agnexis.',
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

class _SupportSnapshotCard extends StatelessWidget {
  const _SupportSnapshotCard({
    required this.errorCount,
    required this.onExportReport,
  });

  final int errorCount;
  final VoidCallback onExportReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppDesignTokens.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Support snapshot',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use this when troubleshooting, sharing app state, or preparing details for support.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatusTile(
                  icon: Icons.error_outline,
                  label: 'Recent errors',
                  value: errorCount == 0 ? 'None' : '$errorCount',
                  valueColor: errorCount == 0
                      ? AppDesignTokens.successFg
                      : theme.colorScheme.error,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: _StatusTile(
                  icon: Icons.info_outline,
                  label: 'App version',
                  value: kAppVersion,
                  valueColor: AppDesignTokens.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onExportReport,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export support report'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesignTokens.bgWarm.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
        border: Border.all(color: AppDesignTokens.borderCrisp),
      ),
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
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsSectionHeader extends StatelessWidget {
  const _DiagnosticsSectionHeader(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
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

class _DiagnosticsActionRow extends StatelessWidget {
  const _DiagnosticsActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : AppDesignTokens.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing16,
          vertical: 15,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius:
                    BorderRadius.circular(AppDesignTokens.radiusSmall),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: destructive
                          ? Theme.of(context).colorScheme.error
                          : AppDesignTokens.primaryText,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.chevron_right,
              color: AppDesignTokens.secondaryText,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticsDivider extends StatelessWidget {
  const _DiagnosticsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 72,
      color: AppDesignTokens.divider,
    );
  }
}

class _IntegrityResultList extends StatelessWidget {
  const _IntegrityResultList({required this.issues});

  final List<IntegrityIssue> issues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (issues.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppDesignTokens.successBg.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppDesignTokens.successFg,
              size: 20,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No data health issues found.',
                style: TextStyle(
                  color: AppDesignTokens.successFg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: issues.map(
        (issue) {
          final colors = _IntegrityIssueColors.forSeverity(
            issue.severity,
            theme,
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius:
                    BorderRadius.circular(AppDesignTokens.radiusSmall),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        issue.severity == IntegritySeverity.error
                            ? Icons.error_outline
                            : Icons.info_outline,
                        size: 20,
                        color: colors.foreground,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          issue.summary,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: colors.title,
                          ),
                        ),
                      ),
                      Text(
                        '${issue.count}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (issue.detail != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      issue.detail!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ).toList(),
    );
  }
}

class _IntegrityIssueColors {
  const _IntegrityIssueColors({
    required this.background,
    required this.border,
    required this.foreground,
    required this.title,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final Color title;

  static _IntegrityIssueColors forSeverity(
    IntegritySeverity severity,
    ThemeData theme,
  ) {
    return switch (severity) {
      IntegritySeverity.error => _IntegrityIssueColors(
          background: theme.colorScheme.errorContainer.withValues(alpha: 0.42),
          border: theme.colorScheme.error.withValues(alpha: 0.35),
          foreground: theme.colorScheme.error,
          title: AppDesignTokens.primaryText,
        ),
      IntegritySeverity.warning => const _IntegrityIssueColors(
          background: AppDesignTokens.warningBg,
          border: AppDesignTokens.warningBorder,
          foreground: AppDesignTokens.warningFg,
          title: AppDesignTokens.primaryText,
        ),
      IntegritySeverity.informational => _IntegrityIssueColors(
          background: AppDesignTokens.emptyBadgeBg.withValues(alpha: 0.7),
          border: AppDesignTokens.borderCrisp,
          foreground: AppDesignTokens.secondaryText,
          title: AppDesignTokens.primaryText,
        ),
    };
  }
}
