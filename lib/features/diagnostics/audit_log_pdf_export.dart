import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/app_info.dart';
import '../../core/config/app_info.dart';
import '../../core/database/app_database.dart';

/// Read-only PDF export of [AuditEvent] rows (suitable for sharing/archival;
/// harder to casually edit than CSV).
class AuditLogPdfExport {
  AuditLogPdfExport({
    required this.events,
    this.scopeDescription,
  });

  final List<AuditEvent> events;
  /// e.g. "All trials" or "Trial #12 only"
  final String? scopeDescription;

  static final _dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  static const _primary = PdfColor.fromInt(0xFF2D5A40);
  static const _muted = PdfColor.fromInt(0xFF6B7280);
  static const _border = PdfColor.fromInt(0xFFE5E7EB);

  Future<Uint8List> build() async {
    final doc = pw.Document();
    final exportedAt = DateTime.now().toUtc();
    final scope = scopeDescription ?? 'All trials';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              AppInfo.appName,
              style: pw.TextStyle(
                fontSize: 9,
                color: _primary,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Audit log export',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Scope: $scope · Events: ${events.length} · Exported (UTC): ${_dateFmt.format(exportedAt)} · App v$kAppVersion',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
            pw.Divider(color: _border, thickness: 0.5),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Divider(color: _border, thickness: 0.5),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Read-only export for review and records. Prefer the encrypted backup (.agnexis) for full data restoration.',
                    style: const pw.TextStyle(fontSize: 7, color: _muted),
                  ),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7, color: _muted),
                ),
              ],
            ),
          ],
        ),
        build: (ctx) => [
          ...events.map(_eventBlock),
        ],
      ),
    );

    return await doc.save();
  }


  pw.Widget _eventBlock(AuditEvent e) {
    final ids = <String>[
      if (e.trialId != null) 'trial ${e.trialId}',
      if (e.sessionId != null) 'session ${e.sessionId}',
      if (e.plotPk != null) 'plot ${e.plotPk}',
    ].join(' · ');

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            e.eventType,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _primary,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            '${_dateFmt.format(e.createdAt.toUtc())} UTC'
            '${e.performedBy != null && e.performedBy!.isNotEmpty ? ' · ${e.performedBy}' : ''}'
            '${ids.isNotEmpty ? ' · $ids' : ''}',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            e.description,
            style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.2),
          ),
          if (e.metadata != null && e.metadata!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Metadata: ${e.metadata}',
              style: const pw.TextStyle(fontSize: 7, color: _muted),
            ),
          ],
        ],
      ),
    );
  }
}
