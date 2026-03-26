import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/assessment_result_direction.dart';
import 'standalone_report_data.dart';

String _cell(String? value) {
  if (value == null || value.isEmpty) return '-';
  return value;
}

String _formatMean(double v) {
  return v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
}

String _safeTreatmentLabel(String? code) {
  if (code == null || code.trim().isEmpty || code == '-') return 'Unassigned';
  return code;
}

String _capitalizeLifecycleStatus(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
}

const String _emDashPlaceholder = '—';

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
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(0.9),
              3: const pw.FlexColumnWidth(1.1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _tableHeaderCell('Date'),
                  _tableHeaderCell('Product'),
                  _tableHeaderCell('Status'),
                  _tableHeaderCell('Applied At'),
                ],
              ),
              ...data.applications.events.map((a) => pw.TableRow(
                    children: [
                      _tableCell(dateFormat.format(a.applicationDate)),
                      _tableCell(a.productName),
                      _tableCell(_capitalizeLifecycleStatus(a.status)),
                      _tableCell(
                        a.appliedAt != null
                            ? dateFormat.format(a.appliedAt!)
                            : _emDashPlaceholder,
                      ),
                    ],
                  )),
            ],
          ),
          pw.SizedBox(height: 16),

          // Seeding
          pw.Text(
            'Seeding',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          if (data.seeding == null)
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  children: [
                    _tableCell('Seeding not recorded'),
                  ],
                ),
              ],
            )
          else
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _tableHeaderCell('Field'),
                    _tableHeaderCell('Value'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _tableCell('Seeding Date'),
                    _tableCell(dateFormat.format(data.seeding!.seedingDate)),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _tableCell('Status'),
                    _tableCell(
                        _capitalizeLifecycleStatus(data.seeding!.status)),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _tableCell('Completed At'),
                    _tableCell(
                      data.seeding!.completedAt != null
                          ? dateFormat.format(data.seeding!.completedAt!)
                          : _emDashPlaceholder,
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _tableCell('Operator'),
                    _tableCell(data.seeding!.operatorName ?? _emDashPlaceholder),
                  ],
                ),
              ],
            ),
          pw.SizedBox(height: 16),

          // ── Assessment Results ──────────────────────
          if (data.ratings.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Assessment Results',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            _buildResultsTable(data.ratings),
          ],

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

  pw.Widget _buildResultsTable(List<RatingResultRow> ratings) {
    // Group by assessment name for readability
    final byAssessment = <String, List<RatingResultRow>>{};
    for (final r in ratings) {
      byAssessment.putIfAbsent(r.assessmentName, () => []).add(r);
    }

    final widgets = <pw.Widget>[];
    for (final entry in byAssessment.entries) {
      final name = entry.key;
      final rows = entry.value;
      final unit = rows.first.unit;
      final resultDirection =
          rows.first.resultDirection;
      final label = unit.isNotEmpty ? '$name ($unit)' : name;

      widgets.add(pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
        ),
      ));
      widgets.add(pw.SizedBox(height: 4));

      // Directional summary: only for numeric values
      final byTreatment = <String, List<double>>{};
      for (final r in rows) {
        final v = double.tryParse(r.value);
        if (v != null) {
          byTreatment.putIfAbsent(r.treatmentCode, () => []).add(v);
        }
      }
      if (byTreatment.isNotEmpty) {
        final means = byTreatment.map(
            (code, vals) =>
                MapEntry(code, vals.reduce((a, b) => a + b) / vals.length));
        final sorted = means.entries.toList()
            ..sort((a, b) => a.value.compareTo(b.value));
        final lowest = sorted.first;
        final highest = sorted.last;
        String bestLabel;
        String worstLabel;
        if (resultDirection == AssessmentResultDirection.higherBetter) {
          bestLabel = 'Best Treatment: ${highest.key} (mean ${_formatMean(highest.value)})';
          worstLabel = 'Lowest Treatment: ${lowest.key} (mean ${_formatMean(lowest.value)})';
        } else if (resultDirection == AssessmentResultDirection.lowerBetter) {
          bestLabel = 'Best Treatment: ${lowest.key} (mean ${_formatMean(lowest.value)})';
          worstLabel = 'Highest Treatment: ${highest.key} (mean ${_formatMean(highest.value)})';
        } else {
          bestLabel = 'Highest treatment mean: ${highest.key} (${_formatMean(highest.value)})';
          worstLabel = 'Lowest treatment mean: ${lowest.key} (${_formatMean(lowest.value)})';
        }
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Text(
            '$bestLabel · $worstLabel',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ));
      }

      // Treatment summary table: only when numeric values exist
      if (byTreatment.isNotEmpty) {
        final summaryRows = <_TreatmentSummaryRow>[];
        for (final e in byTreatment.entries) {
          final vals = e.value;
          if (vals.isEmpty) continue;
          final mean = vals.reduce((a, b) => a + b) / vals.length;
          final min = vals.reduce((a, b) => a < b ? a : b);
          final max = vals.reduce((a, b) => a > b ? a : b);
          summaryRows.add(_TreatmentSummaryRow(
            treatment: _safeTreatmentLabel(e.key),
            mean: mean,
            min: min,
            max: max,
            n: vals.length,
          ));
        }
        summaryRows.sort((a, b) => a.treatment.compareTo(b.treatment));
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FixedColumnWidth(48),
              2: const pw.FixedColumnWidth(48),
              3: const pw.FixedColumnWidth(48),
              4: const pw.FixedColumnWidth(24),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _tableHeaderCell('Treatment'),
                  _tableHeaderCell('Mean', rightAlign: true),
                  _tableHeaderCell('Min', rightAlign: true),
                  _tableHeaderCell('Max', rightAlign: true),
                  _tableHeaderCell('n', rightAlign: true),
                ],
              ),
              ...summaryRows.map((row) => pw.TableRow(
                    children: [
                      _tableCell(row.treatment),
                      _tableCell(_formatMean(row.mean), rightAlign: true),
                      _tableCell(_formatMean(row.min), rightAlign: true),
                      _tableCell(_formatMean(row.max), rightAlign: true),
                      _tableCell('${row.n}', rightAlign: true),
                    ],
                  )),
            ],
          ),
        ));
      }

      widgets.add(pw.Table(
        border: pw.TableBorder.all(
            color: PdfColors.grey400, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FixedColumnWidth(32),
          2: const pw.FlexColumnWidth(2),
          3: const pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(
                color: PdfColors.grey200),
            children: [
              _tableHeaderCell('Plot', rightAlign: false),
              _tableHeaderCell('Rep', rightAlign: true),
              _tableHeaderCell('Treatment', rightAlign: false),
              _tableHeaderCell('Value', rightAlign: true),
            ],
          ),
          ...rows.map((r) => pw.TableRow(
                children: [
                  _tableCell(r.plotId),
                  _tableCell(r.rep.toString(),
                      rightAlign: true),
                  _tableCell(r.treatmentCode),
                  _tableCell(r.value, rightAlign: true),
                ],
              )),
        ],
      ));
      widgets.add(pw.SizedBox(height: 12));
    }
    return pw.Column(children: widgets);
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

class _TreatmentSummaryRow {
  const _TreatmentSummaryRow({
    required this.treatment,
    required this.mean,
    required this.min,
    required this.max,
    required this.n,
  });
  final String treatment;
  final double mean;
  final double min;
  final double max;
  final int n;
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
