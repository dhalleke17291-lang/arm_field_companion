import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/database/app_database.dart';
import '../../core/pdf_branding.dart';
import '../../core/plot_analysis_eligibility.dart';
import '../../core/plot_display.dart';
import '../../core/ui/assessment_display_helper.dart';

/// Builds the Trial Report PDF — structured document for the regulatory
/// binder. Distinct from the Evidence Report (provenance/audit) and the
/// session grid PDF (single-session data snapshot).
///
/// Implemented sections:
/// - **§1–4** (portrait): Site summary; product/treatment table; experimental
///   design; application details (or empty-state message).
/// - **§5** (landscape, only when assessments and analyzable plots exist):
///   Assessment data tables — plot × treatment × session columns per assessment.
/// - **§6–10** (portrait): Treatment summary statistics; crop injury log;
///   field notes; completeness summary (KPI table); conclusions placeholder
///   (`[To be completed by Study Director]`).
class TrialReportPdfBuilder {
  static const _primary = PdfColor.fromInt(0xFF0E3D2F);
  static const _borderColor = PdfColor.fromInt(0xFFCCCCCC);
  static const _textSecondary = PdfColor.fromInt(0xFF555555);
  static const _headerBg = PdfColor.fromInt(0xFFF4F1EB);
  static const _rowAlt = PdfColor.fromInt(0xFFF8F8F8);

  Future<Uint8List> build({
    required Trial trial,
    required List<Plot> plots,
    required List<Treatment> treatments,
    required Map<int, List<TreatmentComponent>> componentsByTreatment,
    required List<Session> sessions,
    required List<RatingRecord> ratings,
    required List<Assessment> assessments,
    required List<TrialApplicationEvent> applications,
    required List<Assignment> assignments,
    Map<int, String>? assessmentDisplayNames,
    List<Note>? fieldNotes,
  }) async {
    final pdf = pw.Document();
    final dateFmt = DateFormat('yyyy-MM-dd');
    final dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

    final logo = await PdfBranding.loadLogo();

    final dataPlots = plots.where(isAnalyzablePlot).toList();
    // Key includes sessionId so multi-session data renders correctly.
    final ratingMap = <(int, int, int), RatingRecord>{};
    for (final r in ratings) {
      if (!r.isCurrent || r.isDeleted) continue;
      ratingMap[(r.plotPk, r.assessmentId, r.sessionId)] = r;
    }

    String displayName(Assessment a) {
      if (assessmentDisplayNames != null &&
          assessmentDisplayNames.containsKey(a.id)) {
        return assessmentDisplayNames[a.id]!;
      }
      return AssessmentDisplayHelper.legacyAssessmentDisplayName(a.name);
    }

    // Assignment map for treatment lookup
    final plotTreatment = <int, int>{};
    for (final a in assignments) {
      if (a.treatmentId != null) plotTreatment[a.plotId] = a.treatmentId!;
    }
    for (final p in dataPlots) {
      if (!plotTreatment.containsKey(p.id) && p.treatmentId != null) {
        plotTreatment[p.id] = p.treatmentId!;
      }
    }
    final treatmentById = {for (final t in treatments) t.id: t};

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (ctx) => _pageHeader(logo, trial, dateTimeFmt, ctx),
      footer: (ctx) => _pageFooter(trial, ctx),
      build: (ctx) => [
        // Title
        pw.Center(
          child: pw.Text(
            'TRIAL REPORT',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: _primary,
              letterSpacing: 2,
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            'Generated ${dateTimeFmt.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: _textSecondary),
          ),
        ),
        pw.SizedBox(height: 16),

        // Section 1: Site Summary
        _sectionTitle('1. Site Summary'),
        _siteSummary(trial, dateFmt),
        pw.SizedBox(height: 16),

        // Section 2: Product and Treatment Table
        _sectionTitle('2. Product and Treatment Table'),
        _treatmentTable(treatments, componentsByTreatment),
        pw.SizedBox(height: 16),

        // Section 3: Experimental Design
        _sectionTitle('3. Experimental Design'),
        _designSection(trial, dataPlots, plots),
        pw.SizedBox(height: 16),

        // Section 4: Application Details
        _sectionTitle('4. Application Details'),
        if (applications.isEmpty)
          pw.Text(
            'No application events recorded.',
            style: const pw.TextStyle(fontSize: 9, color: _textSecondary),
          )
        else
          ..._applicationSections(applications, treatmentById, dateFmt),
        pw.SizedBox(height: 16),

      ],
    ));

    // Section 5 on landscape pages for wide data tables.
    if (assessments.isNotEmpty && dataPlots.isNotEmpty) {
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => _pageHeader(logo, trial, dateTimeFmt, ctx),
        footer: (ctx) => _pageFooter(trial, ctx),
        build: (ctx) => [
          _sectionTitle('5. Assessment Data'),
          ..._assessmentDataTables(
            dataPlots,
            plots,
            assessments,
            sessions,
            ratingMap,
            plotTreatment,
            treatmentById,
            displayName,
          ),
        ],
      ));
    }

    // Sections 6-10 on portrait pages.
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (ctx) => _pageHeader(logo, trial, dateTimeFmt, ctx),
      footer: (ctx) => _pageFooter(trial, ctx),
      build: (ctx) => [
        // Section 6: Treatment summary statistics.
        _sectionTitle('6. Treatment Summary Statistics'),
        _treatmentSummaryStats(
            dataPlots, assessments, sessions, ratingMap,
            plotTreatment, treatmentById, displayName),
        pw.SizedBox(height: 16),

        // Section 7: Crop injury log.
        _sectionTitle('7. Crop Injury Log'),
        _cropInjuryLog(sessions, dateFmt),
        pw.SizedBox(height: 16),

        // Section 8: Field notes.
        _sectionTitle('8. Field Notes'),
        if (fieldNotes == null || fieldNotes.isEmpty)
          pw.Text('No field notes recorded.',
              style: const pw.TextStyle(fontSize: 9, color: _textSecondary))
        else
          _fieldNotesSection(fieldNotes, dateFmt),
        pw.SizedBox(height: 16),

        // Section 9: Completeness summary (text form).
        _sectionTitle('9. Completeness Summary'),
        _completenessSummary(trial, sessions, applications, dataPlots),
        pw.SizedBox(height: 16),

        // Section 10: Conclusions.
        _sectionTitle('10. Conclusions'),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _borderColor),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            '[To be completed by Study Director]',
            style: const pw.TextStyle(
              fontSize: 10,
              color: _textSecondary,
            ),
          ),
        ),
      ],
    ));

    return pdf.save();
  }

  // Section 6
  pw.Widget _treatmentSummaryStats(
    List<Plot> dataPlots,
    List<Assessment> assessments,
    List<Session> sessions,
    Map<(int, int, int), RatingRecord> ratingMap,
    Map<int, int> plotTreatment,
    Map<int, Treatment> treatmentById,
    String Function(Assessment) displayName,
  ) {
    final trtIds = treatmentById.keys.toList()..sort();
    if (trtIds.isEmpty || assessments.isEmpty) {
      return pw.Text('No treatment data.',
          style: const pw.TextStyle(fontSize: 9, color: _textSecondary));
    }
    // Per treatment × assessment: mean across all sessions.
    final rows = <List<String>>[];
    for (final tid in trtIds) {
      final trt = treatmentById[tid]!;
      for (final a in assessments) {
        final values = <double>[];
        for (final s in sessions) {
          for (final p in dataPlots) {
            if ((plotTreatment[p.id] ?? p.treatmentId) != tid) continue;
            final r = ratingMap[(p.id, a.id, s.id)];
            if (r != null && r.resultStatus == 'RECORDED' &&
                r.numericValue != null) {
              values.add(r.numericValue!);
            }
          }
        }
        if (values.isEmpty) continue;
        final mean = values.reduce((a, b) => a + b) / values.length;
        double sd = 0;
        if (values.length > 1) {
          final variance = values
              .map((v) => (v - mean) * (v - mean))
              .reduce((a, b) => a + b) / (values.length - 1);
          sd = variance > 0 ? _sqrt(variance) : 0;
        }
        final cv = mean.abs() > 0.001 ? (sd / mean.abs()) * 100 : 0.0;
        rows.add([
          trt.code,
          displayName(a),
          _fmt(mean),
          _fmt(sd),
          '${cv.toStringAsFixed(1)}%',
          '${values.length}',
        ]);
      }
    }
    return pw.TableHelper.fromTextArray(
      headers: ['Treatment', 'Assessment', 'Mean', 'SD', 'CV%', 'n'],
      data: rows,
      headerStyle: _tableHeaderStyle(),
      headerDecoration: const pw.BoxDecoration(color: _primary),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.center,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
    );
  }

  static double _sqrt(double v) {
    if (v <= 0) return 0;
    double x = v;
    for (var i = 0; i < 20; i++) {
      x = (x + v / x) / 2;
    }
    return x;
  }

  // Section 7
  pw.Widget _cropInjuryLog(List<Session> sessions, DateFormat dateFmt) {
    final rows = <List<String>>[];
    for (final s in sessions) {
      rows.add([
        s.name,
        s.sessionDateLocal,
        s.cropInjuryStatus ?? 'Not recorded',
        s.cropInjuryNotes ?? '',
      ]);
    }
    if (rows.isEmpty) {
      return pw.Text('No sessions.',
          style: const pw.TextStyle(fontSize: 9, color: _textSecondary));
    }
    return pw.TableHelper.fromTextArray(
      headers: ['Session', 'Date', 'Status', 'Notes'],
      data: rows,
      headerStyle: _tableHeaderStyle(),
      headerDecoration: const pw.BoxDecoration(color: _primary),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
    );
  }

  // Section 8
  pw.Widget _fieldNotesSection(List<Note> notes, DateFormat dateFmt) {
    final rows = notes
        .where((n) => !n.isDeleted)
        .map((n) => [
              dateFmt.format(n.createdAt),
              n.content.length > 150
                  ? '${n.content.substring(0, 150)}...'
                  : n.content,
            ])
        .toList();
    return pw.TableHelper.fromTextArray(
      headers: ['Date', 'Note'],
      data: rows,
      headerStyle: _tableHeaderStyle(),
      headerDecoration: const pw.BoxDecoration(color: _primary),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
    );
  }

  // Section 9
  pw.Widget _completenessSummary(
    Trial trial,
    List<Session> sessions,
    List<TrialApplicationEvent> applications,
    List<Plot> dataPlots,
  ) {
    final bbchCount =
        sessions.where((s) => s.cropStageBbch != null).length;
    final injuryCount =
        sessions.where((s) => s.cropInjuryStatus != null).length;
    final appliedCount =
        applications.where((a) => a.status == 'applied').length;

    final rows = <List<String>>[
      ['Sessions', '${sessions.length}'],
      ['BBCH recorded', '$bbchCount / ${sessions.length}'],
      ['Crop injury recorded', '$injuryCount / ${sessions.length}'],
      ['Data plots', '${dataPlots.length}'],
      ['Applications recorded', '$appliedCount'],
      ['GPS', trial.latitude != null ? 'Recorded' : 'Missing'],
      ['Soil texture', trial.soilTexture ?? 'Missing'],
      ['Cultivar', trial.cultivar ?? 'Missing'],
    ];
    return _kvTable(rows);
  }

  pw.Widget _pageHeader(pw.ImageProvider? logo, Trial trial,
      DateFormat fmt, pw.Context ctx) {
    if (ctx.pageNumber == 1) return pw.SizedBox.shrink();
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _primary, width: 0.5)),
      ),
      child: pw.Row(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.only(right: 10),
            child: PdfBranding.brandBlockCompact(logo),
          ),
          pw.Expanded(
            child: pw.Text(
              '${trial.name} — Trial Report',
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold, color: _primary),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pageFooter(Trial trial, pw.Context ctx) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 6),
      child: pw.Text(
        'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
        style: const pw.TextStyle(fontSize: 7, color: _textSecondary),
      ),
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const pw.BoxDecoration(
        color: _primary,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Section 1
  pw.Widget _siteSummary(Trial t, DateFormat dateFmt) {
    final rows = <List<String>>[
      ['Trial name', t.name],
      if (t.protocolNumber != null) ['Protocol', t.protocolNumber!],
      if (t.sponsor != null) ['Sponsor', t.sponsor!],
      if (t.investigatorName != null) ['Investigator', t.investigatorName!],
      if (t.crop != null) ['Crop', t.crop!],
      if (t.cultivar != null) ['Cultivar', t.cultivar!],
      if (t.location != null) ['Location', t.location!],
      if (t.fieldName != null) ['Field', t.fieldName!],
      if (t.latitude != null && t.longitude != null)
        ['GPS', '${t.latitude!.toStringAsFixed(6)}, ${t.longitude!.toStringAsFixed(6)}'],
      if (t.soilTexture != null) ['Soil texture', t.soilTexture!],
      if (t.soilPh != null) ['Soil pH', t.soilPh!.toStringAsFixed(1)],
      if (t.organicMatterPct != null)
        ['Organic matter', '${t.organicMatterPct!.toStringAsFixed(1)}%'],
      if (t.previousCrop != null) ['Previous crop', t.previousCrop!],
      if (t.tillage != null) ['Tillage', t.tillage!],
      if (t.irrigated != null) ['Irrigated', t.irrigated! ? 'Yes' : 'No'],
      if (t.season != null) ['Season', t.season!],
    ];
    return _kvTable(rows);
  }

  // Section 2
  pw.Widget _treatmentTable(
      List<Treatment> treatments, Map<int, List<TreatmentComponent>> comps) {
    final rows = <List<String>>[];
    for (final t in treatments) {
      final cs = comps[t.id] ?? [];
      if (cs.isEmpty) {
        rows.add([t.code, t.name, t.treatmentType ?? '', '', '', '']);
      } else {
        for (var i = 0; i < cs.length; i++) {
          rows.add([
            i == 0 ? t.code : '',
            i == 0 ? t.name : '',
            i == 0 ? (t.treatmentType ?? '') : '',
            cs[i].productName,
            cs[i].rate != null ? '${cs[i].rate} ${cs[i].rateUnit ?? ''}' : '',
            cs[i].formulationType ?? '',
          ]);
        }
      }
    }
    return pw.TableHelper.fromTextArray(
      headers: ['Code', 'Name', 'Type', 'Product', 'Rate', 'Formulation'],
      data: rows,
      headerStyle: _tableHeaderStyle(),
      headerDecoration: const pw.BoxDecoration(color: _primary),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
    );
  }

  // Section 3
  pw.Widget _designSection(Trial t, List<Plot> dataPlots, List<Plot> allPlots) {
    final reps = dataPlots.map((p) => p.rep).whereType<int>().toSet();
    final guards = allPlots.where((p) => p.isGuardRow).length;
    final rows = <List<String>>[
      ['Design', t.experimentalDesign ?? 'Not specified'],
      ['Data plots', '${dataPlots.length}'],
      ['Reps', reps.isEmpty ? '—' : '${reps.length}'],
      if (guards > 0) ['Guard plots', '$guards'],
      if (t.plotLengthM != null && t.plotWidthM != null)
        ['Plot dimensions', '${t.plotLengthM} m × ${t.plotWidthM} m'],
    ];
    return _kvTable(rows);
  }

  // Section 4
  List<pw.Widget> _applicationSections(
    List<TrialApplicationEvent> apps,
    Map<int, Treatment> treatmentById,
    DateFormat dateFmt,
  ) {
    return [
      for (var i = 0; i < apps.length; i++) ...[
        if (i > 0) pw.SizedBox(height: 8),
        pw.Text(
          'Application ${i + 1} — ${dateFmt.format(apps[i].applicationDate)}',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _primary,
          ),
        ),
        pw.SizedBox(height: 4),
        _kvTable([
          ['Date', dateFmt.format(apps[i].applicationDate)],
          if (apps[i].operatorName != null)
            ['Applicator', apps[i].operatorName!],
          if (apps[i].applicationMethod != null)
            ['Method', apps[i].applicationMethod!],
          if (apps[i].growthStageCode != null)
            ['Growth stage', apps[i].growthStageCode!],
          if (apps[i].productName != null)
            ['Product', apps[i].productName!],
          if (apps[i].rate != null)
            ['Rate', '${apps[i].rate} ${apps[i].rateUnit ?? ''}'],
          if (apps[i].temperature != null)
            ['Temperature', '${apps[i].temperature}°C'],
          if (apps[i].humidity != null)
            ['Humidity', '${apps[i].humidity}%'],
          if (apps[i].windSpeed != null)
            ['Wind', '${apps[i].windSpeed} km/h ${apps[i].windDirection ?? ''}'],
          if (apps[i].equipmentUsed != null)
            ['Equipment', apps[i].equipmentUsed!],
          if (apps[i].nozzleType != null) ['Nozzle', apps[i].nozzleType!],
          if (apps[i].waterVolume != null)
            ['Carrier volume', '${apps[i].waterVolume} ${apps[i].waterVolumeUnit ?? 'L/ha'}'],
          ['Status', apps[i].status],
        ]),
      ],
    ];
  }

  // Section 5
  List<pw.Widget> _assessmentDataTables(
    List<Plot> dataPlots,
    List<Plot> allPlots,
    List<Assessment> assessments,
    List<Session> sessions,
    Map<(int, int, int), RatingRecord> ratingMap,
    Map<int, int> plotTreatment,
    Map<int, Treatment> treatmentById,
    String Function(Assessment) displayName,
  ) {
    if (assessments.isEmpty || dataPlots.isEmpty) {
      return [
        pw.Text(
          'No assessment data.',
          style: const pw.TextStyle(fontSize: 9, color: _textSecondary),
        ),
      ];
    }

    // One table per assessment
    final widgets = <pw.Widget>[];
    for (final a in assessments) {
      final headers = [
        'Plot',
        'Rep',
        'Treatment',
        ...sessions.map((s) => '${s.sessionDateLocal}\n${s.name}'),
      ];
      final rows = <List<String>>[];
      for (final p in dataPlots) {
        final trtId = plotTreatment[p.id];
        final trtCode = trtId != null
            ? (treatmentById[trtId]?.code ?? '?')
            : '—';
        final row = <String>[
          getDisplayPlotLabel(p, allPlots),
          p.rep?.toString() ?? '—',
          trtCode,
        ];
        for (final s in sessions) {
          final r = ratingMap[(p.id, a.id, s.id)];
          if (r != null) {
            if (r.resultStatus == 'RECORDED') {
              row.add(r.numericValue != null
                  ? _fmt(r.numericValue!)
                  : (r.textValue ?? '—'));
            } else {
              row.add(_statusAbbrev(r.resultStatus));
            }
          } else {
            row.add('');
          }
        }
        rows.add(row);
      }

      // Treatment means row
      final meansRow = <String>['Mean', '', ''];
      for (final s in sessions) {
        final vals = <double>[];
        for (final p in dataPlots) {
          final r = ratingMap[(p.id, a.id, s.id)];
          if (r != null &&
              r.resultStatus == 'RECORDED' &&
              r.numericValue != null) {
            vals.add(r.numericValue!);
          }
        }
        if (vals.isNotEmpty) {
          final mean = vals.reduce((a, b) => a + b) / vals.length;
          meansRow.add(_fmt(mean));
        } else {
          meansRow.add('');
        }
      }
      rows.add(meansRow);

      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              displayName(a),
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _primary,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows,
              headerStyle: _tableHeaderStyle(),
              headerDecoration: const pw.BoxDecoration(color: _primary),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellAlignment: pw.Alignment.center,
              cellPadding:
                  const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              border: pw.TableBorder.all(color: _borderColor, width: 0.5),
              oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
            ),
          ],
        ),
      ));
    }
    return widgets;
  }

  // Helpers
  pw.Widget _kvTable(List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      headers: null,
      data: rows,
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(100),
        1: const pw.FlexColumnWidth(),
      },
      cellDecoration: (index, data, rowNum) {
        if (index == 0) return const pw.BoxDecoration(color: _headerBg);
        return rowNum.isOdd
            ? const pw.BoxDecoration(color: _rowAlt)
            : const pw.BoxDecoration();
      },
    );
  }

  pw.TextStyle _tableHeaderStyle() => pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      );

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  static String _statusAbbrev(String status) => switch (status) {
        'NOT_OBSERVED' => 'N/O',
        'NOT_APPLICABLE' => 'N/A',
        'MISSING_CONDITION' => 'M/C',
        'TECHNICAL_ISSUE' => 'T/I',
        'VOID' => 'VOID',
        _ => status,
      };
}
