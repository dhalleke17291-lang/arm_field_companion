import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/pdf_branding.dart';
import 'field_execution_report_data.dart';

/// Renders [FieldExecutionReportData] into a PDF byte array.
///
/// Pure renderer: reads only the DTO, no DB access, no providers, no
/// interpretation. All seven sections are rendered; empty sections show
/// neutral placeholder text rather than being omitted.
class FieldExecutionReportPdfBuilder {
  static const _primary = PdfBranding.primaryColor;
  static const _headerBg = PdfColor.fromInt(0xFFF4F1EB);
  static const _borderColor = PdfColor.fromInt(0xFFCCCCCC);
  static const _textSecondary = PdfColor.fromInt(0xFF555555);
  static const _rowAlt = PdfColor.fromInt(0xFFF8F8F8);

  Future<Uint8List> build(FieldExecutionReportData data) async {
    final pdf = pw.Document();
    final dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

    final logo = await PdfBranding.loadLogo();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (_) => _pageHeader(logo, data, dateTimeFmt),
      footer: (ctx) => _pageFooter(ctx),
      build: (ctx) => [
        // Title
        pw.Center(
          child: pw.Text(
            'FIELD EXECUTION REPORT',
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
            'Generated ${dateTimeFmt.format(data.generatedAt)}',
            style: const pw.TextStyle(fontSize: 8, color: _textSecondary),
          ),
        ),
        pw.SizedBox(height: 16),

        // ── 1. TRIAL & SESSION IDENTITY ──
        _sectionTitle('1. Trial & Session Identity'),
        _identitySection(data.identity),
        pw.SizedBox(height: 16),

        // ── 2. PROTOCOL CONTEXT ──
        _sectionTitle('2. Protocol Context'),
        _protocolSection(data.protocolContext),
        pw.SizedBox(height: 16),

        // ── 3. SESSION GRID ──
        _sectionTitle('3. Session Grid'),
        _sessionGridSection(data.sessionGrid),
        pw.SizedBox(height: 16),

        // ── 4. EVIDENCE RECORD ──
        _sectionTitle('4. Evidence Record'),
        _evidenceSection(data.evidenceRecord),
        pw.SizedBox(height: 16),

        // ── 5. SIGNALS ──
        _sectionTitle('5. Signals'),
        _signalsSection(data.signals),
        pw.SizedBox(height: 16),

        // ── 6. COMPLETENESS ──
        _sectionTitle('6. Completeness'),
        _completenessSection(data.completeness),
        pw.SizedBox(height: 16),

        // ── 7. EXECUTION STATEMENT ──
        _sectionTitle('7. Execution Statement'),
        _executionStatementSection(data.executionStatement),
      ],
    ));

    return pdf.save();
  }

  // ── Page header / footer ──────────────────────────────────────────────────

  pw.Widget _pageHeader(
    pw.ImageProvider? logo,
    FieldExecutionReportData data,
    DateFormat fmt,
  ) {
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
              '${data.identity.trialName} — Field Execution Report',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _primary,
              ),
            ),
          ),
          pw.Text(
            fmt.format(data.generatedAt),
            style: const pw.TextStyle(fontSize: 7, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  pw.Widget _pageFooter(pw.Context ctx) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 6),
      child: pw.Text(
        'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
        style: const pw.TextStyle(fontSize: 7, color: _textSecondary),
      ),
    );
  }

  // ── Section 1: Identity ───────────────────────────────────────────────────

  pw.Widget _identitySection(FerIdentity id) {
    return _keyValueTable([
      ['Trial', id.trialName],
      if (id.protocolNumber != null) ['Protocol', id.protocolNumber!],
      if (id.crop != null) ['Crop', id.crop!],
      if (id.location != null) ['Location', id.location!],
      if (id.season != null) ['Season', id.season!],
      ['Session', id.sessionName],
      ['Date', id.sessionDateLocal],
      ['Status', id.sessionStatus],
      if (id.raterName != null) ['Rater', id.raterName!],
    ]);
  }

  // ── Section 2: Protocol context ───────────────────────────────────────────

  pw.Widget _protocolSection(FerProtocolContext ctx) {
    if (!ctx.isArmTrial) {
      return _noteText('No ARM protocol metadata recorded for this trial.');
    }

    final rows = <pw.Widget>[
      _keyValueTable([
        ['ARM-linked session', ctx.isArmLinked ? 'Yes' : 'No'],
        ['Protocol divergences', '${ctx.totalCount}'],
        if (ctx.timingCount > 0) ['  Timing', '${ctx.timingCount}'],
        if (ctx.missingCount > 0) ['  Missing', '${ctx.missingCount}'],
        if (ctx.unexpectedCount > 0) ['  Unexpected', '${ctx.unexpectedCount}'],
      ]),
    ];

    if (ctx.divergences.isEmpty) {
      rows.add(pw.SizedBox(height: 6));
      rows.add(_noteText('No protocol divergences recorded for this session.'));
    } else {
      rows.add(pw.SizedBox(height: 8));
      rows.add(pw.TableHelper.fromTextArray(
        headers: ['Type', 'Delta days', 'Planned DAT', 'Actual DAT'],
        data: ctx.divergences
            .map((d) => [
                  _divergenceLabel(d.type),
                  d.deltaDays != null ? '${d.deltaDays}' : '-',
                  d.plannedDat != null ? '${d.plannedDat}' : '-',
                  d.actualDat != null ? '${d.actualDat}' : '-',
                ])
            .toList(),
        headerStyle: _headerStyle(),
        headerDecoration: const pw.BoxDecoration(color: _primary),
        cellStyle: const pw.TextStyle(fontSize: 8),
        cellAlignment: pw.Alignment.centerLeft,
        cellPadding:
            const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        border: pw.TableBorder.all(color: _borderColor, width: 0.5),
        oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
      ));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rows,
    );
  }

  String _divergenceLabel(FerDivergenceType type) {
    switch (type) {
      case FerDivergenceType.timing:
        return 'Timing';
      case FerDivergenceType.missing:
        return 'Missing';
      case FerDivergenceType.unexpected:
        return 'Unexpected';
    }
  }

  // ── Section 3: Session grid ───────────────────────────────────────────────

  pw.Widget _sessionGridSection(FerSessionGrid grid) {
    return _keyValueTable([
      ['Data plots', '${grid.dataPlotCount}'],
      ['Assessments', '${grid.assessmentCount}'],
      ['Rated', '${grid.rated}'],
      ['Unrated', '${grid.unrated}'],
      ['With issues', '${grid.withIssues}'],
      ['Edited', '${grid.edited}'],
      ['Flagged', '${grid.flagged}'],
    ]);
  }

  // ── Section 4: Evidence record ────────────────────────────────────────────

  pw.Widget _evidenceSection(FerEvidenceRecord ev) {
    final rows = <pw.Widget>[
      _keyValueTable([
        ['Photos', '${ev.photoCount}'],
        ['GPS coordinates', ev.hasGps ? 'Present' : 'Not recorded'],
        ['Weather snapshot', ev.hasWeather ? 'Present' : 'Not recorded'],
        ['Session timestamp', ev.hasTimestamp ? 'Present' : 'Not recorded'],
      ]),
    ];

    if (ev.photoCount > 0) {
      rows.add(pw.SizedBox(height: 4));
      rows.add(_noteText(
          'Photo IDs: ${ev.photoIds.join(", ")}. '
          'Photo binaries are not embedded in this report.'));
    }

    rows.add(pw.SizedBox(height: 4));
    rows.add(_noteText(
        'Source: operational tables (photos, weather snapshots, ratings). '
        'The evidence_anchors audit table is not read by this report.'));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rows,
    );
  }

  // ── Section 5: Signals ────────────────────────────────────────────────────

  pw.Widget _signalsSection(FerSignalsSection signals) {
    final widgets = <pw.Widget>[];

    if (signals.openSignals.isEmpty) {
      widgets.add(
          _noteText('No unresolved signals recorded for this session.'));
    } else {
      widgets.add(pw.TableHelper.fromTextArray(
        headers: ['Type', 'Severity', 'Status', 'Consequence', 'Raised at'],
        data: signals.openSignals
            .map((s) => [
                  s.signalType,
                  s.severity,
                  s.status,
                  s.consequenceText,
                  _fmtEpoch(s.raisedAt),
                ])
            .toList(),
        headerStyle: _headerStyle(),
        headerDecoration: const pw.BoxDecoration(color: _primary),
        cellStyle: const pw.TextStyle(fontSize: 8),
        cellAlignment: pw.Alignment.centerLeft,
        cellPadding:
            const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        border: pw.TableBorder.all(color: _borderColor, width: 0.5),
        columnWidths: {
          0: const pw.FixedColumnWidth(80),
          1: const pw.FixedColumnWidth(55),
          2: const pw.FixedColumnWidth(65),
          3: const pw.FlexColumnWidth(),
          4: const pw.FixedColumnWidth(80),
        },
        oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
      ));
    }

    widgets.add(pw.SizedBox(height: 4));
    widgets
        .add(_noteText('Decision history is not included in this report.'));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }

  String _fmtEpoch(int epochMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true);
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }

  // ── Section 6: Completeness ───────────────────────────────────────────────

  pw.Widget _completenessSection(FerCompletenessSection comp) {
    return _keyValueTable([
      ['Expected plots', '${comp.expectedPlots}'],
      ['Completed plots', '${comp.completedPlots}'],
      ['Incomplete plots', '${comp.incompletePlots}'],
      ['Can close', comp.canClose ? 'Yes' : 'No'],
      ['Blockers', '${comp.blockerCount}'],
      ['Warnings', '${comp.warningCount}'],
    ]);
  }

  // ── Section 7: Execution statement ───────────────────────────────────────

  pw.Widget _executionStatementSection(String statement) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: _rowAlt,
      ),
      child: pw.Text(
        statement,
        style: const pw.TextStyle(fontSize: 9),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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

  pw.Widget _keyValueTable(List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      headers: null,
      data: rows,
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(110),
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

  pw.Widget _noteText(String text) {
    return pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 8, color: _textSecondary),
    );
  }

  pw.TextStyle _headerStyle() {
    return pw.TextStyle(
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
  }
}
