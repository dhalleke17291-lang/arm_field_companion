import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/pdf_branding.dart';
import 'field_execution_report_data.dart';

/// Renders [FieldExecutionReportData] into a professional operational review PDF.
///
/// Pure renderer: reads only the DTO, no DB access, no providers, no stored
/// conclusions. The review verdict is report-local and derived from assembled
/// execution facts.
class FieldExecutionReportPdfBuilder {
  static const titleText = 'FIELD EXECUTION REVIEW';
  static const subtitleText =
      'Operational execution and evidence readiness summary';
  static const interpretationBoundaryText =
      'This report evaluates operational execution, evidence provenance, '
      'and review requirements. It does not determine biological efficacy, '
      'treatment ranking, or final statistical validity.';

  static const _primary = PdfBranding.primaryColor;
  static const _ink = PdfColor.fromInt(0xFF1F2933);
  static const _muted = PdfColor.fromInt(0xFF606A75);
  static const _line = PdfColor.fromInt(0xFFD7DCE0);
  static const _soft = PdfColor.fromInt(0xFFF6F7F5);
  static const _softGreen = PdfColor.fromInt(0xFFEAF2ED);
  static const _softAmber = PdfColor.fromInt(0xFFFFF6E8);
  static const _amber = PdfColor.fromInt(0xFF9A5B00);
  static const _red = PdfColor.fromInt(0xFFB42318);
  static const _white = PdfColors.white;

  Future<Uint8List> build(FieldExecutionReportData data) async {
    final pdf = pw.Document();
    final dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');
    final logo = await PdfBranding.loadLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => _pageHeader(logo, data, dateTimeFmt),
        footer: (ctx) => _pageFooter(ctx),
        build: (ctx) => [
          _reportTitle(data, dateTimeFmt),
          pw.SizedBox(height: 16),
          _sectionTitle('1. Review Verdict'),
          _reviewVerdictBlock(data),
          _sectionGap(),
          _sectionTitle('2. Session Execution Summary'),
          _sessionExecutionSummary(data),
          _sectionGap(),
          _sectionTitle('3. Evidence & Provenance'),
          _evidenceAndProvenance(data),
          _sectionGap(),
          _sectionTitle('4. Review Risks & Signals'),
          _reviewRisksAndSignals(data.signals),
          _sectionGap(),
          _sectionTitle('5. Completeness & Readiness'),
          _completenessAndReadiness(data.completeness),
          _sectionGap(),
          _sectionTitle('6. Trial Context'),
          _trialContext(data),
          _sectionGap(),
          _sectionTitle('7. Interpretation Boundary'),
          _interpretationBoundary(),
        ],
      ),
    );

    return pdf.save();
  }

  static String reviewVerdictStatusForTesting(FieldExecutionReportData data) =>
      _buildReviewVerdict(data).status;

  static String executionCoverageSentenceForTesting(
    FieldExecutionReportData data,
  ) =>
      _executionCoverageSentence(data.sessionGrid);

  static String evidenceGpsLabelForTesting(FerEvidenceRecord evidence) =>
      _gpsEvidenceLabel(evidence);

  // Page framing

  pw.Widget _pageHeader(
    pw.ImageProvider? logo,
    FieldExecutionReportData data,
    DateFormat fmt,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 7),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.6)),
      ),
      child: pw.Row(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.only(right: 10),
            child: PdfBranding.brandBlockCompact(logo),
          ),
          pw.Expanded(
            child: pw.Text(
              '${data.identity.trialName} - Field Execution Review',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
          ),
          pw.Text(
            fmt.format(data.generatedAt),
            style: const pw.TextStyle(fontSize: 7, color: _muted),
          ),
        ],
      ),
    );
  }

  pw.Widget _pageFooter(pw.Context ctx) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
        style: const pw.TextStyle(fontSize: 7, color: _muted),
      ),
    );
  }

  pw.Widget _reportTitle(FieldExecutionReportData data, DateFormat fmt) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          titleText,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: _primary,
            letterSpacing: 1.2,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          subtitleText,
          style: const pw.TextStyle(fontSize: 10, color: _muted),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'Generated ${fmt.format(data.generatedAt)}',
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ],
    );
  }

  // Section 1

  pw.Widget _reviewVerdictBlock(FieldExecutionReportData data) {
    final verdict = _buildReviewVerdict(data);
    final accent = _verdictColor(verdict.status);
    final bg = verdict.status == 'Review ready' ? _softGreen : _softAmber;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: bg,
        border: pw.Border.all(color: accent, width: 0.6),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _labelValue('Status', verdict.status, valueColor: accent),
          _labelValue('Operational readiness', verdict.operationalReadiness),
          _labelValue('Export impact', verdict.exportImpact),
          pw.SizedBox(height: 6),
          _smallHeading('Primary review concerns'),
          if (verdict.concerns.isEmpty)
            _noteText(
                'No primary review concerns identified from the assembled report data.')
          else
            ...verdict.concerns.map(_bullet),
          pw.SizedBox(height: 6),
          _smallHeading('Recommended next action'),
          pw.Text(
            verdict.nextAction,
            style: const pw.TextStyle(fontSize: 9, color: _ink),
          ),
        ],
      ),
    );
  }

  // Section 2

  pw.Widget _sessionExecutionSummary(FieldExecutionReportData data) {
    final id = data.identity;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _twoColumnRows([
          ['Trial', id.trialName],
          if (id.crop != null) ['Crop', id.crop!],
          if (id.season != null) ['Season', id.season!],
          ['Session', id.sessionName],
          ['Date', id.sessionDateLocal],
          ['Execution status', _sentenceCase(id.sessionStatus)],
          ['Rater', id.raterName ?? 'Not recorded'],
        ]),
        pw.SizedBox(height: 8),
        _statementBox(_executionCoverageSentence(data.sessionGrid)),
      ],
    );
  }

  static String _executionCoverageSentence(FerSessionGrid grid) {
    return '${grid.rated} of ${grid.dataPlotCount} planned data plots rated '
        'across ${grid.assessmentCount} assessment(s).';
  }

  // Section 3

  pw.Widget _evidenceAndProvenance(FieldExecutionReportData data) {
    final ev = data.evidenceRecord;
    final rows = [
      ['GPS-confirmed ratings', _gpsEvidenceLabel(ev)],
      [
        'Weather snapshot',
        ev.hasWeather ? 'Evidence captured' : 'Not recorded'
      ],
      [
        'Session timestamp',
        ev.hasTimestamp ? 'Evidence captured' : 'Not recorded'
      ],
      [
        'Photos attached',
        ev.photoCount == 0 ? 'Evidence not attached' : '${ev.photoCount}',
      ],
      ['Session duration', _formatDuration(ev.sessionDurationMinutes)],
      ['Rater', data.identity.raterName ?? 'Not recorded'],
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _twoColumnRows(rows),
        if (ev.photoCount > 0) ...[
          pw.SizedBox(height: 5),
          _noteText(
            'Photo IDs: ${ev.photoIds.join(", ")}. Photo binaries are not embedded in this report.',
          ),
        ],
        pw.SizedBox(height: 7),
        _noteText(
          'Source: operational capture tables. This section reflects execution evidence, not treatment efficacy.',
        ),
      ],
    );
  }

  static String _gpsEvidenceLabel(FerEvidenceRecord evidence) {
    return evidence.hasGps
        ? 'GPS evidence present'
        : 'GPS evidence not recorded';
  }

  // Section 4

  pw.Widget _reviewRisksAndSignals(FerSignalsSection signals) {
    if (signals.openSignals.isEmpty) {
      return _statementBox('No unresolved signals recorded for this session.');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final signal in signals.openSignals) ...[
          _signalCard(signal),
          pw.SizedBox(height: 7),
        ],
        _noteText('Decision history is not included in this report.'),
      ],
    );
  }

  pw.Widget _signalCard(FerSignalRow signal) {
    final accent = signal.severity.toLowerCase() == 'critical' ? _red : _amber;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line, width: 0.6),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: _white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _signalTypeLabel(signal.signalType),
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: accent,
            ),
          ),
          pw.SizedBox(height: 5),
          _labelValue('Severity', _sentenceCase(signal.severity)),
          _labelValue('Status', _sentenceCase(signal.status)),
          _labelValue('Impact', signal.consequenceText),
          _labelValue('Raised at', _fmtEpoch(signal.raisedAt)),
          _labelValue('Recoverability', _recoverabilityLabel(signal)),
        ],
      ),
    );
  }

  static String _recoverabilityLabel(FerSignalRow signal) {
    final severity = signal.severity.toLowerCase();
    final status = signal.status.toLowerCase();
    final type = signal.signalType.toLowerCase();
    if (type.contains('photo') || type.contains('evidence')) {
      return 'Recoverable before export if evidence can still be attached or documented.';
    }
    if (severity == 'critical' && status == 'open') {
      return 'Permanent constraint after capture unless corrected through documented review.';
    }
    return 'Requires review.';
  }

  // Section 5

  pw.Widget _completenessAndReadiness(FerCompletenessSection comp) {
    return _twoColumnRows([
      ['Planned data plots', '${comp.expectedPlots}'],
      ['Completed data plots', '${comp.completedPlots}'],
      ['Incomplete plots', '${comp.incompletePlots}'],
      [
        'Session closure eligibility',
        comp.canClose ? 'Satisfied' : 'Review required',
      ],
      ['Blockers', '${comp.blockerCount}'],
      ['Review items', '${comp.warningCount}'],
    ]);
  }

  // Section 6

  pw.Widget _trialContext(FieldExecutionReportData data) {
    final cognition = data.cognition;
    final protocol = data.protocolContext;
    final rows = <List<String>>[
      ['Purpose status', cognition.purposeStatusLabel],
      ['Primary endpoint', cognition.primaryEndpoint ?? 'Not recorded'],
      [
        'Missing purpose fields',
        cognition.missingIntentFieldLabels.isEmpty
            ? 'None recorded as missing'
            : cognition.missingIntentFieldLabels.join(', '),
      ],
      ['Critical-to-quality status', cognition.ctqOverallStatusLabel],
      ['ARM/protocol metadata status', _protocolMetadataStatus(protocol)],
      ['Application timing', _applicationTimingLabel(protocol)],
    ];

    final children = <pw.Widget>[
      _twoColumnRows(rows),
    ];
    if (cognition.claimBeingTested != null &&
        cognition.claimBeingTested!.isNotEmpty) {
      children
        ..add(pw.SizedBox(height: 8))
        ..add(_labelValue('Claim being tested', cognition.claimBeingTested!));
    }
    if (cognition.topCtqAttentionItems.isNotEmpty) {
      children
        ..add(pw.SizedBox(height: 8))
        ..add(_smallHeading('Review attention items'))
        ..addAll(
          cognition.topCtqAttentionItems.map(
            (item) =>
                _bullet('${item.label}: ${_neutralStatus(item.statusLabel)}'),
          ),
        );
    }
    children
      ..add(pw.SizedBox(height: 7))
      ..add(_noteText(FerCognitionSection.disclaimerText));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: children,
    );
  }

  String _protocolMetadataStatus(FerProtocolContext protocol) {
    if (protocol.isArmLinked) {
      return 'ARM protocol metadata linked to this session.';
    }
    if (protocol.isArmTrial) {
      return 'ARM protocol metadata exists for this trial; this session is not linked.';
    }
    return 'No ARM protocol metadata is currently linked to this trial.';
  }

  String _applicationTimingLabel(FerProtocolContext protocol) {
    if (protocol.missingCount > 0) {
      return 'Application timing: Not recorded for this session';
    }
    if (protocol.timingCount > 0 || protocol.unexpectedCount > 0) {
      return 'Application timing: Review required';
    }
    return 'Application timing: Not yet evaluable';
  }

  // Section 7

  pw.Widget _interpretationBoundary() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _soft,
        border: pw.Border.all(color: _line, width: 0.6),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        interpretationBoundaryText,
        style: const pw.TextStyle(fontSize: 9, color: _ink),
      ),
    );
  }

  // Verdict logic

  static _FerReviewVerdict _buildReviewVerdict(FieldExecutionReportData data) {
    final openCriticalSignals = data.signals.openSignals
        .where((s) =>
            s.severity.toLowerCase() == 'critical' &&
            s.status.toLowerCase() == 'open')
        .length;
    final concerns = <String>[];

    if (openCriticalSignals > 0) {
      concerns.add(
        '$openCriticalSignals unresolved critical signal${openCriticalSignals == 1 ? '' : 's'}',
      );
    }
    if (data.evidenceRecord.photoCount == 0) {
      concerns.add('No photo evidence attached');
    }
    if (!data.evidenceRecord.hasGps) {
      concerns.add('GPS evidence not recorded');
    }
    if (!data.evidenceRecord.hasWeather) {
      concerns.add('Weather snapshot not recorded');
    }
    if (data.cognition.missingIntentFieldLabels.isNotEmpty) {
      concerns.add('Trial purpose incomplete');
    }
    if (data.cognition.blockerCount > 0) {
      concerns.add('${data.cognition.blockerCount} CTQ blocker(s)');
    }
    if (data.cognition.reviewCount > 0 || data.cognition.warningCount > 0) {
      concerns.add('CTQ review items require attention');
    }
    if (data.completeness.incompletePlots > 0) {
      concerns.add('${data.completeness.incompletePlots} incomplete plot(s)');
    }
    if (data.completeness.blockerCount > 0) {
      concerns.add(
          '${data.completeness.blockerCount} session completeness blocker(s)');
    }

    if (openCriticalSignals > 0) {
      return _FerReviewVerdict(
        status: 'Review required before export',
        operationalReadiness: 'Partial',
        exportImpact: 'Review required before export',
        concerns: concerns,
        nextAction:
            'Review unresolved critical signals and document the researcher decision before export.',
      );
    }

    final reviewReady = data.completeness.canClose &&
        data.completeness.incompletePlots == 0 &&
        data.completeness.blockerCount == 0 &&
        data.completeness.warningCount == 0 &&
        data.cognition.blockerCount == 0 &&
        data.cognition.reviewCount == 0 &&
        data.cognition.warningCount == 0 &&
        data.cognition.missingIntentFieldLabels.isEmpty;

    if (reviewReady) {
      return _FerReviewVerdict(
        status: 'Review ready',
        operationalReadiness: 'Satisfied',
        exportImpact: 'No blocking review item identified in this report',
        concerns: concerns,
        nextAction:
            'Confirm the report contents against source records before final export.',
      );
    }

    return _FerReviewVerdict(
      status: 'Partial review required',
      operationalReadiness: 'Partial',
      exportImpact: 'Review recommended before export',
      concerns: concerns,
      nextAction:
          'Review incomplete evidence, CTQ attention items, and session completeness before export.',
    );
  }

  // Shared formatting

  pw.Widget _sectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.6)),
      ),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  pw.Widget _sectionGap() => pw.SizedBox(height: 18);

  pw.Widget _twoColumnRows(List<List<String>> rows) {
    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: 0.35),
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(150),
        1: pw.FlexColumnWidth(),
      },
      children: rows
          .map(
            (row) => pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text(
                    row[0],
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      color: _muted,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text(
                    row[1],
                    style: const pw.TextStyle(fontSize: 8.5, color: _ink),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  pw.Widget _labelValue(
    String label,
    String value, {
    PdfColor valueColor = _ink,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8.5,
                color: _muted,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 8.5, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _statementBox(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: _soft,
        border: pw.Border.all(color: _line, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9, color: _ink),
      ),
    );
  }

  pw.Widget _smallHeading(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
    );
  }

  pw.Widget _bullet(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('- ', style: const pw.TextStyle(fontSize: 9, color: _ink)),
          pw.Expanded(
            child: pw.Text(
              text,
              style: const pw.TextStyle(fontSize: 9, color: _ink),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _noteText(String text) {
    return pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 8, color: _muted),
    );
  }

  PdfColor _verdictColor(String status) {
    if (status == 'Review ready') return _primary;
    if (status == 'Review required before export') return _red;
    return _amber;
  }

  String _fmtEpoch(int epochMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true);
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }

  String _formatDuration(int? minutes) {
    if (minutes == null || minutes < 0) return 'Not available';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '$hours h' : '$hours h $mins min';
  }

  String _signalTypeLabel(String value) {
    final words = value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map(_sentenceCase)
        .toList();
    return words.isEmpty ? value : words.join(' ');
  }

  static String _sentenceCase(String value) {
    if (value.isEmpty) return value;
    final clean = value.replaceAll('_', ' ').trim();
    if (clean.isEmpty) return clean;
    return '${clean[0].toUpperCase()}${clean.substring(1).toLowerCase()}';
  }

  String _neutralStatus(String value) {
    return value == 'Missing' ? 'Not recorded' : value;
  }
}

class _FerReviewVerdict {
  const _FerReviewVerdict({
    required this.status,
    required this.operationalReadiness,
    required this.exportImpact,
    required this.concerns,
    required this.nextAction,
  });

  final String status;
  final String operationalReadiness;
  final String exportImpact;
  final List<String> concerns;
  final String nextAction;
}
