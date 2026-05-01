import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/export_guard.dart';
import '../../core/providers.dart';
import '../export/field_execution_report_pdf_builder.dart';

/// Single policy for session ARM XML export menu/actions (closed sessions only).
bool isSessionXmlExportAvailable(Session session) => session.endedAt != null;

const String _sessionCsvExportFailedSnack =
    'Export failed — please try again. If the problem persists, check trial data for missing or incomplete records.';

const String _sessionXmlExportFailedSnack =
    'XML export failed — please try again. If the problem persists, check session data for missing or incomplete records.';

/// CSV export with shared guard, dialogs, share sheet, diagnostics, and snackbars.
Future<void> runSessionCsvExport(
  BuildContext context,
  WidgetRef ref, {
  required Trial trial,
  required Session session,
}) async {
  final guard = ref.read(exportGuardProvider);
  final ran = await guard.runExclusive(() async {
    final usecase = ref.read(exportSessionCsvUsecaseProvider);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exporting...')),
      );

      final currentUser = await ref.read(currentUserProvider.future);
      final result = await usecase.exportSessionToCsv(
        sessionId: session.id,
        trialId: trial.id,
        trialName: trial.name,
        sessionName: session.name,
        sessionDateLocal: session.sessionDateLocal,
        sessionRaterName: session.raterName,
        exportedByDisplayName: currentUser?.displayName,
        isSessionClosed: session.endedAt != null,
        requireSessionClosed: false,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      if (!result.success) {
        ref.read(diagnosticsStoreProvider).recordError(
              result.errorMessage ?? 'Unknown error',
              code: 'export_failed',
            );
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Export Failed'),
            content: SelectableText(result.errorMessage ?? 'Unknown error'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Export Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${result.rowCount} ratings exported'),
              if (result.auditFilePath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Session audit events exported (separate file).',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (result.warningMessage != null) ...[
                const SizedBox(height: AppDesignTokens.spacing8),
                Text(
                  result.warningMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text('Saved to:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SelectableText(
                result.filePath!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final files = [XFile(result.filePath!)];
                if (result.auditFilePath != null) {
                  files.add(XFile(result.auditFilePath!));
                }
                final box = context.findRenderObject() as RenderBox?;
                await Share.shareXFiles(
                  files,
                  subject: '${trial.name} - ${session.name} Export',
                  sharePositionOrigin: box == null
                      ? const Rect.fromLTWH(0, 0, 100, 100)
                      : box.localToGlobal(Offset.zero) & box.size,
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (context.mounted) {
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _sessionCsvExportFailedSnack,
              style: TextStyle(color: scheme.onError),
            ),
            backgroundColor: scheme.error,
          ),
        );
      }
    }
  });
  if (!ran && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(ExportGuard.busyMessage)),
    );
  }
}

/// ARM XML export; no-op when [session] is still open ([isSessionXmlExportAvailable] false).
Future<void> runSessionArmXmlExport(
  BuildContext context,
  WidgetRef ref, {
  required Trial trial,
  required Session session,
}) async {
  if (!isSessionXmlExportAvailable(session)) return;

  final guard = ref.read(exportGuardProvider);
  final ran = await guard.runExclusive(() async {
    final usecase = ref.read(exportSessionArmXmlUsecaseProvider);
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exporting XML...')),
      );
      final currentUser = await ref.read(currentUserProvider.future);
      final result = await usecase.exportSessionToArmXml(
        sessionId: session.id,
        trialId: trial.id,
        trialName: trial.name,
        sessionName: session.name,
        sessionDateLocal: session.sessionDateLocal,
        sessionRaterName: session.raterName,
        exportedByDisplayName: currentUser?.displayName,
        isSessionClosed: session.endedAt != null,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      if (!result.success) {
        ref.read(diagnosticsStoreProvider).recordError(
              result.errorMessage ?? 'Unknown error',
              code: 'arm_xml_export_failed',
            );
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('XML Export Failed'),
            content: SelectableText(result.errorMessage ?? 'Unknown error'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('XML Export Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Session exported as structured XML.'),
              const SizedBox(height: 8),
              const Text('Saved to:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SelectableText(
                result.filePath!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final box = context.findRenderObject() as RenderBox?;
                await Share.shareXFiles(
                  [XFile(result.filePath!)],
                  subject: '${trial.name} - ${session.name} XML Export',
                  sharePositionOrigin: box == null
                      ? const Rect.fromLTWH(0, 0, 100, 100)
                      : box.localToGlobal(Offset.zero) & box.size,
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (context.mounted) {
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _sessionXmlExportFailedSnack,
              style: TextStyle(color: scheme.onError),
            ),
            backgroundColor: scheme.error,
          ),
        );
      }
    }
  });
  if (!ran && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(ExportGuard.busyMessage)),
    );
  }
}

/// Assembles and shares a Field Execution Report PDF for the given session.
Future<void> runFieldExecutionReportExport(
  BuildContext context,
  WidgetRef ref, {
  required Trial trial,
  required Session session,
}) async {
  final guard = ref.read(exportGuardProvider);
  final ran = await guard.runExclusive(() async {
    final assemblyService =
        ref.read(fieldExecutionReportAssemblyServiceProvider);
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating report...')),
      );

      final data = await assemblyService.assembleForSession(
        trial: trial,
        session: session,
      );
      final bytes = await FieldExecutionReportPdfBuilder().build(data);

      final dir = await getTemporaryDirectory();
      final sanitizedName = session.name.replaceAll(RegExp(r'[^\w\-]'), '_');
      final file = File('${dir.path}/fer_$sanitizedName.pdf');
      await file.writeAsBytes(bytes);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Report Ready'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Field Execution Report generated.'),
              const SizedBox(height: AppDesignTokens.spacing8),
              const Text('Saved to:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SelectableText(
                file.path,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final box = context.findRenderObject() as RenderBox?;
                await Share.shareXFiles(
                  [XFile(file.path)],
                  subject:
                      '${trial.name} — ${session.name} Field Execution Report',
                  sharePositionOrigin: box == null
                      ? const Rect.fromLTWH(0, 0, 100, 100)
                      : box.localToGlobal(Offset.zero) & box.size,
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (context.mounted) {
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Report generation failed — please try again.',
              style: TextStyle(color: scheme.onError),
            ),
            backgroundColor: scheme.error,
          ),
        );
      }
    }
  });
  if (!ran && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(ExportGuard.busyMessage)),
    );
  }
}
