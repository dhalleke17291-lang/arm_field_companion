import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'standalone_report_data.dart';

String _cell(String? value) {
  if (value == null || value.isEmpty) return '—';
  return value;
}

/// Builds a PDF document from assembled report data.
/// Conservative layout; no ratings, derived stats, or photo embedding.
class ReportPdfBuilderService {
  ReportPdfBuilderService();

  /// Returns PDF bytes for the given report data.
  Future<Uint8List> build(StandaloneReportData data) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('yyyy-MM-dd');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'PDF Field Report',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 16),

          // Trial summary
          pw.Header(level: 1, child: pw.Text('Trial Summary')),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            children: [
              _row('Name', _cell(data.trial.name)),
              _row('Crop', _cell(data.trial.crop)),
              _row('Location', _cell(data.trial.location)),
              _row('Season', _cell(data.trial.season)),
              _row('Status', _cell(data.trial.status)),
              _row('Workspace Type', _cell(data.trial.workspaceType)),
            ],
          ),
          pw.SizedBox(height: 16),

          // Treatments
          pw.Header(level: 1, child: pw.Text('Treatments')),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _tableCell('Code'),
                  _tableCell('Name'),
                  _tableCell('Type'),
                  _tableCell('Components'),
                ],
              ),
              ...data.treatments.map((t) => pw.TableRow(
                    children: [
                      _tableCell(t.code),
                      _tableCell(t.name),
                      _tableCell(t.treatmentType),
                      _tableCell('${t.componentCount}'),
                    ],
                  )),
            ],
          ),
          pw.SizedBox(height: 16),

          // Plots
          pw.Header(level: 1, child: pw.Text('Plots')),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _tableCell('Plot ID'),
                  _tableCell('Rep'),
                  _tableCell('Treatment'),
                ],
              ),
              ...data.plots.map((p) => pw.TableRow(
                    children: [
                      _tableCell(p.plotId),
                      _tableCell(p.rep != null ? '${p.rep}' : '—'),
                      _tableCell(p.treatmentCode),
                    ],
                  )),
            ],
          ),
          pw.SizedBox(height: 16),

          // Sessions
          pw.Header(level: 1, child: pw.Text('Sessions')),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _tableCell('Name'),
                  _tableCell('Date'),
                  _tableCell('Status'),
                ],
              ),
              ...data.sessions.map((s) => pw.TableRow(
                    children: [
                      _tableCell(s.name),
                      _tableCell(s.sessionDateLocal),
                      _tableCell(s.status),
                    ],
                  )),
            ],
          ),
          pw.SizedBox(height: 16),

          // Applications
          pw.Header(level: 1, child: pw.Text('Applications')),
          pw.Paragraph(
            text: 'Count: ${data.applications.count}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _tableCell('Date'),
                  _tableCell('Product'),
                ],
              ),
              ...data.applications.events.map((a) => pw.TableRow(
                    children: [
                      _tableCell(dateFormat.format(a.applicationDate)),
                      _tableCell(a.productName),
                    ],
                  )),
            ],
          ),
          pw.SizedBox(height: 16),

          // Photos
          pw.Header(level: 1, child: pw.Text('Photos')),
          pw.Paragraph(
            text: 'Count: ${data.photoCount.count}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );

    return pdf.save();
  }
}

pw.Widget _tableCell(String? text) => pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(_cell(text), style: const pw.TextStyle(fontSize: 9)),
    );

pw.TableRow _row(String label, String value) => pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ),
      ],
    );
