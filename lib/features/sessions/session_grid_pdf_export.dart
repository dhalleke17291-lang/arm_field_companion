import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/database/app_database.dart';
import '../../core/pdf_branding.dart';
import '../../core/plot_analysis_eligibility.dart';
import '../../core/plot_display.dart';
import '../../core/ui/assessment_display_helper.dart';

/// Builds a PDF snapshot of the session data grid.
///
/// Includes: session metadata header, full plot × assessment grid with values,
/// column statistics footer (mean, min, max), treatment summary if available.
class SessionGridPdfExport {
  SessionGridPdfExport({
    required this.trial,
    required this.session,
    required this.plots,
    required this.assessments,
    required this.ratings,
    this.assessmentDisplayNames,
    this.plotTreatmentMap,
    this.treatmentNames,
    this.completedPlots,
    this.expectedPlots,
  });

  final Trial trial;
  final Session session;
  final List<Plot> plots;
  final List<Assessment> assessments;
  final List<RatingRecord> ratings;
  final Map<int, String>? assessmentDisplayNames;
  final Map<int, int>? plotTreatmentMap;
  final Map<int, String>? treatmentNames;
  final int? completedPlots;
  final int? expectedPlots;

  static const _primaryColor = PdfBranding.primaryColor;
  static const _borderColor = PdfColor.fromInt(0xFFCCCCCC);
  static const _textSecondary = PdfBranding.textSecondary;
  static const _statsBg = PdfColor.fromInt(0xFFF5F5F5);

  Future<Uint8List> build() async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    final logo = await PdfBranding.loadLogo();

    final dataPlots = plots.where(isAnalyzablePlot).toList();

    // Rating lookup
    final ratingMap = <(int, int), RatingRecord>{};
    for (final r in ratings) {
      if (!r.isCurrent || r.isDeleted) continue;
      ratingMap[(r.plotPk, r.assessmentId)] = r;
    }

    // Column stats
    final colStats = <int, ({double mean, double min, double max, int n})>{};
    for (final a in assessments) {
      final values = <double>[];
      for (final p in dataPlots) {
        final r = ratingMap[(p.id, a.id)];
        if (r != null &&
            r.resultStatus == 'RECORDED' &&
            r.numericValue != null) {
          values.add(r.numericValue!);
        }
      }
      if (values.isNotEmpty) {
        values.sort();
        final sum = values.reduce((a, b) => a + b);
        colStats[a.id] = (
          mean: sum / values.length,
          min: values.first,
          max: values.last,
          n: values.length,
        );
      }
    }

    // Per-column CV (coefficient of variation)
    final colCv = <int, double>{};
    for (final a in assessments) {
      final s = colStats[a.id];
      if (s == null || s.n < 2 || s.mean == 0) continue;
      final vals = <double>[];
      for (final p in dataPlots) {
        final r = ratingMap[(p.id, a.id)];
        if (r != null &&
            r.resultStatus == 'RECORDED' &&
            r.numericValue != null) {
          vals.add(r.numericValue!);
        }
      }
      final sumSqDev = vals.fold<double>(
          0, (sum, v) => sum + (v - s.mean) * (v - s.mean));
      final sd = math.sqrt(sumSqDev / (vals.length - 1));
      colCv[a.id] = (sd / s.mean * 100).abs();
    }

    // Per-treatment means
    final trtMeans = <int, Map<int, double>>{};
    for (final p in dataPlots) {
      final tid = plotTreatmentMap?[p.id] ?? p.treatmentId;
      if (tid == null) continue;
      trtMeans.putIfAbsent(tid, () => {});
      for (final a in assessments) {
        final r = ratingMap[(p.id, a.id)];
        if (r != null &&
            r.resultStatus == 'RECORDED' &&
            r.numericValue != null) {
          trtMeans[tid]!.putIfAbsent(a.id, () => 0);
          trtMeans[tid]![a.id] =
              (trtMeans[tid]![a.id] ?? 0) + r.numericValue!;
        }
      }
    }
    // Count reps per treatment
    final trtCounts = <int, int>{};
    for (final p in dataPlots) {
      final tid = plotTreatmentMap?[p.id] ?? p.treatmentId;
      if (tid == null) continue;
      trtCounts[tid] = (trtCounts[tid] ?? 0) + 1;
    }
    // Convert sums to means
    for (final tid in trtMeans.keys) {
      final n = trtCounts[tid] ?? 1;
      for (final aid in trtMeans[tid]!.keys.toList()) {
        trtMeans[tid]![aid] = trtMeans[tid]![aid]! / n;
      }
    }

    // Assessment display names
    String displayName(Assessment a) {
      if (assessmentDisplayNames != null &&
          assessmentDisplayNames!.containsKey(a.id)) {
        return assessmentDisplayNames![a.id]!;
      }
      return AssessmentDisplayHelper.legacyAssessmentDisplayName(a.name);
    }

    // Treatment label for a plot
    String? treatmentLabel(Plot p) {
      final tid = plotTreatmentMap?[p.id] ?? p.treatmentId;
      if (tid == null) return null;
      return treatmentNames?[tid] ?? 'TRT $tid';
    }

    // Build table data
    final headers = [
      'Plot',
      if (plotTreatmentMap != null && plotTreatmentMap!.isNotEmpty) 'Treatment',
      if (dataPlots.any((p) => p.rep != null)) 'Rep',
      ...assessments.map(displayName),
    ];
    final hasTreatment =
        plotTreatmentMap != null && plotTreatmentMap!.isNotEmpty;
    final hasRep = dataPlots.any((p) => p.rep != null);

    final rows = <List<String>>[];
    for (final p in dataPlots) {
      final row = <String>[
        getDisplayPlotLabel(p, plots),
        if (hasTreatment) (treatmentLabel(p) ?? '-'),
        if (hasRep) (p.rep?.toString() ?? '-'),
      ];
      for (final a in assessments) {
        final r = ratingMap[(p.id, a.id)];
        if (r == null) {
          row.add('-');
        } else if (r.resultStatus == 'VOID') {
          row.add('VOID');
        } else if (r.resultStatus != 'RECORDED') {
          row.add(_statusAbbrev(r.resultStatus));
        } else {
          row.add(r.numericValue != null
              ? _fmt(r.numericValue!)
              : (r.textValue ?? '-'));
        }
      }
      rows.add(row);
    }

    // Stats row
    final statsRow = <String>[
      'Stats',
      if (hasTreatment) '',
      if (hasRep) '',
      ...assessments.map((a) {
        final s = colStats[a.id];
        if (s == null) return '';
        final cv = colCv[a.id];
        final cvStr = cv != null ? '\nCV ${cv.toStringAsFixed(1)}% (total)' : '';
        return 'Mean ${_fmt(s.mean)}\nRange ${_fmt(s.min)}–${_fmt(s.max)}  n=${s.n}$cvStr';
      }),
    ];

    // Determine column widths — fixed for metadata cols, flex for assessments
    final metaCols = 1 + (hasTreatment ? 1 : 0) + (hasRep ? 1 : 0);
    // Use landscape if many columns
    final useLandscape = headers.length > 6;
    final pageFormat = useLandscape
        ? PdfPageFormat.a4.landscape
        : PdfPageFormat.a4;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildHeader(
          logo: logo,
          dateFormat: dateFormat,
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _textSecondary),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            context: context,
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: _primaryColor),
            headerAlignment: pw.Alignment.center,
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellAlignment: pw.Alignment.center,
            cellHeight: 18,
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            border: pw.TableBorder.all(color: _borderColor, width: 0.5),
            columnWidths: {
              for (var i = 0; i < headers.length; i++)
                i: i == 0
                    ? const pw.FixedColumnWidth(45)
                    : (i < metaCols
                        ? const pw.FixedColumnWidth(65)
                        : const pw.FlexColumnWidth()),
            },
          ),
          // Stats footer row
          if (colStats.isNotEmpty) ...[
            pw.TableHelper.fromTextArray(
              context: context,
              headers: null,
              data: [statsRow],
              cellStyle: const pw.TextStyle(
                fontSize: 6.0,
                color: PdfColors.grey600,
              ),
              cellAlignment: pw.Alignment.center,
              cellHeight: 28,
              cellPadding:
                  const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              border: pw.TableBorder.all(color: _borderColor, width: 0.5),
              cellDecoration: (_, __, ___) =>
                  const pw.BoxDecoration(color: _statsBg),
              columnWidths: {
                for (var i = 0; i < headers.length; i++)
                  i: i == 0
                      ? const pw.FixedColumnWidth(45)
                      : (i < metaCols
                          ? const pw.FixedColumnWidth(65)
                          : const pw.FlexColumnWidth()),
              },
            ),
          ],
          // Treatment means section
          if (hasTreatment && trtMeans.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Treatment Means',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: [
                'Treatment',
                ...assessments.map(displayName),
              ],
              data: (trtMeans.keys.toList()..sort()).map((tid) {
                  final label = treatmentNames?[tid] ?? 'TRT $tid';
                  return [
                    label,
                    ...assessments.map((a) {
                      final mean = trtMeans[tid]?[a.id];
                      return mean != null ? _fmt(mean) : '-';
                    }),
                  ];
                }).toList(),
              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: _primaryColor),
              headerAlignment: pw.Alignment.center,
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellAlignment: pw.Alignment.center,
              cellHeight: 18,
              cellPadding:
                  const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              border: pw.TableBorder.all(color: _borderColor, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(80),
                for (var i = 1; i <= assessments.length; i++)
                  i: const pw.FlexColumnWidth(),
              },
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader({
    pw.ImageProvider? logo,
    required DateFormat dateFormat,
  }) {
    final completeness = (expectedPlots != null && expectedPlots! > 0)
        ? '$completedPlots / $expectedPlots plots complete'
        : null;

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _primaryColor)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.only(right: 14),
            child: PdfBranding.brandBlock(logo),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  trial.name,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${session.name}  ·  ${session.sessionDateLocal}',
                  style: const pw.TextStyle(fontSize: 10, color: _textSecondary),
                ),
                if (session.raterName != null)
                  pw.Text(
                    'Rater: ${session.raterName}',
                    style:
                        const pw.TextStyle(fontSize: 9, color: _textSecondary),
                  ),
                if (completeness != null)
                  pw.Text(
                    completeness,
                    style:
                        const pw.TextStyle(fontSize: 9, color: _textSecondary),
                  ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Session Grid Export',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _textSecondary,
                ),
              ),
              pw.Text(
                dateFormat.format(DateTime.now()),
                style: const pw.TextStyle(fontSize: 8, color: _textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _statusAbbrev(String status) => switch (status) {
        'NOT_OBSERVED' => 'N/O',
        'NOT_APPLICABLE' => 'N/A',
        'MISSING_CONDITION' => 'M/C',
        'TECHNICAL_ISSUE' => 'T/I',
        _ => status,
      };

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}
