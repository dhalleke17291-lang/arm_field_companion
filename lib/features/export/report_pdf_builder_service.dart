import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'standalone_report_data.dart';

String _cell(String? value) {
  if (value == null || value.isEmpty) return '-';
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
          pw.Text(
            'PDF Field Report',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 20),

          // Trial summary
          pw.Text(
            'Trial Summary',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
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
          pw.Text(
            'Treatments',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
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
                  _tableHeaderCell('Code'),
                  _tableHeaderCell('Name'),
                  _tableHeaderCell('Type'),
                  _tableHeaderCell('Components', rightAlign: true),
                ],
              ),
              ...data.treatments.map((t) => pw.TableRow(
                    children: [
                      _tableCell(t.code),
                      _tableCell(t.name),
                      _tableCell(t.treatmentType),
                      _tableCell('${t.componentCount}', rightAlign: true),
                    ],
                  )),
            ],
          ),
          pw.SizedBox(height: 16),

          // Plots
          pw.Text(
            'Plots',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
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
                  _tableHeaderCell('Plot ID'),
                  _tableHeaderCell('Rep', rightAlign: true),
                  _tableHeaderCell('Treatment'),
                ],
              ),
              ...data.plots.map((p) => pw.TableRow(
                    children: [
                      _tableCell(p.plotId),
                      _tableCell(p.rep != null ? '${p.rep}' : '-', rightAlign: true),
                      _tableCell(p.treatmentCode),
                    ],
                  )),
            ],
          ),
          pw.SizedBox(height: 16),

          // Sessions
          pw.Text(
            'Sessions',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
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
                  _tableHeaderCell('Name'),
                  _tableHeaderCell('Date'),
                  _tableHeaderCell('Status'),
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
          pw.Text(
            'Applications',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Paragraph(
            text: 'Count: ${data.applications.count}',
            style: const pw.TextStyle(fontSize: 11),
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
                  _tableHeaderCell('Date'),
                  _tableHeaderCell('Product'),
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
          pw.Text(
            'Photos',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Paragraph(
            text: 'Count: ${data.photoCount.count}',
            style: const pw.TextStyle(fontSize: 11),
          ),
        ],
      ),
    );

    return pdf.save();
  }
}

pw.Widget _tableHeaderCell(String text, {bool rightAlign = false}) {
  final child = pw.Text(
    text,
    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
  );
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: rightAlign
        ? pw.Align(alignment: pw.Alignment.centerRight, child: child)
        : child,
  );
}

pw.Widget _tableCell(String? text, {bool rightAlign = false}) {
  const style = pw.TextStyle(fontSize: 10);
  final child = pw.Text(_cell(text), style: style, softWrap: true);
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: rightAlign
        ? pw.Align(
            alignment: pw.Alignment.centerRight,
            child: child,
          )
        : child,
  );
}

pw.TableRow _row(String label, String value) => pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
