import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/database/app_database.dart';
import '../../core/pdf_branding.dart';
import '../../domain/signals/signal_review_projection_mapper.dart';
import '../../domain/trial_cognition/environmental_window_evaluator.dart';
import '../../domain/trial_cognition/trial_coherence_dto.dart';
import '../../domain/trial_cognition/trial_ctq_dto.dart';
import '../../domain/trial_cognition/trial_decision_summary_dto.dart';
import '../../domain/trial_cognition/trial_evidence_arc_dto.dart';
import '../../domain/trial_cognition/trial_interpretation_risk_dto.dart';
import '../../domain/trial_cognition/trial_purpose_dto.dart';
import '../derived/domain/trial_statistics.dart';

class TrialDefensibilityPdfBuilder {
  static const _green = PdfColor.fromInt(0xFF2D5A40);
  static const _greenLight = PdfColor.fromInt(0xFFE8F0EB);
  static const _amber = PdfColor.fromInt(0xFFE8A020);
  static const _amberLight = PdfColor.fromInt(0xFFFFF3DC);
  static const _red = PdfColor.fromInt(0xFFDC2626);
  static const _textPrimary = PdfColor.fromInt(0xFF1A1A1A);
  static const _textSecondary = PdfColor.fromInt(0xFF6B6B6B);
  static const _border = PdfColor.fromInt(0xFFD4D0C8);
  static const _white = PdfColors.white;

  const TrialDefensibilityPdfBuilder({
    required this.trial,
    required this.purpose,
    required this.evidenceArc,
    required this.ctq,
    required this.coherence,
    required this.interpretationRisk,
    required this.decisionSummary,
    required this.openSignals,
    required this.environmentalSummary,
    required this.assessmentStats,
    required this.amendmentCount,
    required this.generatedAt,
    required this.logo,
  });

  final Trial trial;
  final TrialPurposeDto purpose;
  final TrialEvidenceArcDto evidenceArc;
  final TrialCtqDto ctq;
  final TrialCoherenceDto coherence;
  final TrialInterpretationRiskDto interpretationRisk;
  final TrialDecisionSummaryDto decisionSummary;
  final List<Signal> openSignals;
  final EnvironmentalSeasonSummaryDto? environmentalSummary;
  final List<AssessmentStatistics> assessmentStats;
  final int amendmentCount;
  final DateTime generatedAt;
  final pw.ImageProvider? logo;

  Future<Uint8List> build() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        footer: (context) => _buildFooter(context, trial.name),
        build: (context) => [
          ..._buildCoverPage(),
          pw.NewPage(),
          _sectionHeader('1', 'Trial identity'),
          ..._buildTrialIdentity(),
          _sectionHeader('2', 'Trial purpose'),
          ..._buildTrialPurpose(),
          _sectionHeader('3', 'Design and execution'),
          ..._buildDesignAndExecution(),
          _sectionHeader('4', 'Data quality'),
          ..._buildDataQuality(),
          _sectionHeader('5', 'Treatment results'),
          ..._buildTreatmentResults(),
          _sectionHeader('6', 'Protocol alignment'),
          ..._buildProtocolAlignment(),
          _sectionHeader('7', 'Signals and decisions'),
          ..._buildSignalsAndDecisions(),
          _sectionHeader('8', 'Environmental context'),
          ..._buildEnvironmentalContext(),
          _sectionHeader('9', 'Audit trail'),
          ..._buildAuditTrail(),
        ],
      ),
    );

    return pdf.save();
  }

  static String cvTierLabel(double? cv) {
    if (cv == null) return '-';
    if (cv < 15) return 'Excellent';
    if (cv < 25) return 'Acceptable';
    if (cv < 35) return 'Caution';
    return 'High';
  }

  static bool isCheckTreatment(String code) {
    final upper = code.trim().toUpperCase();
    return upper == 'CHK' || upper == 'UTC' || upper == 'CONTROL';
  }

  pw.Widget _buildFooter(pw.Context context, String trialName) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          trialName,
          style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: 8,
            color: _textSecondary,
          ),
        ),
        pw.Text(
          'Trial Defensibility Summary',
          style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: 8,
            color: _textSecondary,
          ),
        ),
        pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: 8,
            color: _textSecondary,
          ),
        ),
      ],
    );
  }

  List<pw.Widget> _buildCoverPage() {
    return [
      pw.Center(child: PdfBranding.brandBlock(logo)),
      pw.SizedBox(height: 24),
      pw.Center(
        child: pw.Text(
          trial.name,
          style: pw.TextStyle(
            font: pw.Font.helveticaBold(),
            fontSize: 24,
            color: _green,
          ),
        ),
      ),
      pw.SizedBox(height: 6),
      if (trial.crop != null || trial.season != null)
        pw.Center(
          child: pw.Text(
            [trial.crop, trial.season].whereType<String>().join(' / '),
            style: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: 13,
              color: _textSecondary,
            ),
          ),
        ),
      pw.SizedBox(height: 4),
      pw.Center(
        child: pw.Text(
          'Generated ${DateFormat('dd MMM yyyy HH:mm').format(generatedAt)}',
          style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: 11,
            color: _textSecondary,
          ),
        ),
      ),
      pw.SizedBox(height: 24),
      pw.Divider(color: _border),
      pw.SizedBox(height: 20),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _coverField(
              'Claim being tested',
              purpose.claimBeingTested ?? 'Not stated',
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: _coverField(
              'Primary endpoint',
              purpose.primaryEndpoint ?? 'Not stated',
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Row(
        children: [
          pw.Expanded(
            child: _coverField(
              'Design',
              trial.experimentalDesign ?? 'Not stated',
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: _coverField(
              'Workspace',
              _workspaceDisplayName(trial.workspaceType),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 24),
      _buildReadinessBadge(),
      if (openSignals.isNotEmpty || _hasBlockingItems()) ...[
        pw.SizedBox(height: 12),
        _buildCoverActionItems(),
      ],
    ];
  }

  pw.Widget _coverField(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: 9,
            color: _textSecondary,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: pw.Font.helveticaBold(),
            fontSize: 12,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildReadinessBadge() {
    final ready = openSignals.isEmpty && !_hasBlockingItems();
    final bg = ready ? _greenLight : _amberLight;
    final fg = ready ? _green : _amber;
    final text = ready
        ? 'Trial is export-ready'
        : 'Trial requires attention before submission';
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: fg, width: 0.5),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 13,
          color: fg,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildCoverActionItems() {
    final items = <String>[
      if (openSignals.isNotEmpty)
        '${openSignals.length} open signal${openSignals.length == 1 ? '' : 's'} require review',
      if (ctq.ctqItems.any((f) => f.status == 'missing'))
        'Resolve missing critical-to-quality evidence',
      if (coherence.checks.any((c) => c.status == 'review_needed'))
        'Review protocol alignment checks',
    ];
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _amberLight,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _amber, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Items requiring attention',
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 10,
              color: _amber,
            ),
          ),
          pw.SizedBox(height: 4),
          for (final item in items)
            pw.Text(
              '- $item',
              style: pw.TextStyle(
                font: pw.Font.helvetica(),
                fontSize: 10,
                color: _textPrimary,
              ),
            ),
        ],
      ),
    );
  }

  bool _hasBlockingItems() {
    return coherence.checks.any((c) => c.status == 'review_needed') ||
        ctq.ctqItems.any(
          (f) =>
              f.status == 'missing' ||
              f.status == 'blocked' ||
              f.status == 'review_needed',
        );
  }

  String _workspaceDisplayName(String? type) {
    switch (type?.toLowerCase().trim()) {
      case 'standalone':
        return 'Custom';
      case 'arm':
      case 'arm-linked':
        return 'ARM-linked';
      case 'efficacy':
        return 'Efficacy';
      case 'glp':
        return 'GLP';
      case 'variety':
        return 'Variety';
      default:
        return type ?? 'Unknown';
    }
  }

  pw.Widget _sectionHeader(String number, String title) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: _green, width: 3),
        ),
      ),
      padding: const pw.EdgeInsets.only(left: 10, top: 4, bottom: 4),
      margin: const pw.EdgeInsets.only(bottom: 10, top: 16),
      child: pw.Text(
        '$number. ${title.toUpperCase()}',
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 10,
          color: _green,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  pw.Widget _dataRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: pw.Font.helvetica(),
                fontSize: 10,
                color: _textSecondary,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                font: pw.Font.helvetica(),
                fontSize: 10,
                color: _textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildTrialIdentity() {
    return [
      _dataRow('Trial name', trial.name),
      _dataRow('Workspace', _workspaceDisplayName(trial.workspaceType)),
      if (trial.crop != null) _dataRow('Crop', trial.crop!),
      if (trial.sponsor != null) _dataRow('Sponsor', trial.sponsor!),
      if (trial.protocolNumber != null)
        _dataRow('Protocol number', trial.protocolNumber!),
      if (trial.investigatorName != null)
        _dataRow('Investigator', trial.investigatorName!),
      if (trial.location != null) _dataRow('Location', trial.location!),
      if (trial.season != null) _dataRow('Season', trial.season!),
      _dataRow('Region', trial.region),
    ];
  }

  List<pw.Widget> _buildTrialPurpose() {
    return [
      if (purpose.claimBeingTested != null)
        _dataRow('Claim being tested', purpose.claimBeingTested!),
      if (purpose.primaryEndpoint != null)
        _dataRow('Primary endpoint', purpose.primaryEndpoint!),
      if (purpose.trialPurpose != null)
        _dataRow('Trial purpose', purpose.trialPurpose!),
      if (purpose.regulatoryContext != null)
        _dataRow('Regulatory context', purpose.regulatoryContext!),
      _dataRow('Provenance', _purposeProvenance()),
      if (purpose.isPartial || purpose.requiresConfirmation)
        _amberNote(
          'Intent was inferred from available data. Confirm before submission.',
        ),
    ];
  }

  String _purposeProvenance() {
    if (purpose.provenanceSummary.trim().isNotEmpty) {
      return purpose.provenanceSummary;
    }
    if (purpose.inferredPurpose != null) {
      return 'Inferred from ${purpose.inferenceSource ?? 'available evidence'}';
    }
    return 'Not confirmed';
  }

  pw.Widget _amberNote(String text) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 6),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _amberLight,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _amber, width: 0.5),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: pw.Font.helvetica(),
          fontSize: 10,
          color: _amber,
        ),
      ),
    );
  }

  List<pw.Widget> _buildDesignAndExecution() {
    return [
      pw.Text(
        'Design',
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 10,
          color: _textPrimary,
        ),
      ),
      pw.SizedBox(height: 4),
      _dataRow('Planned evidence', evidenceArc.plannedEvidenceSummary),
      _dataRow('Design type', trial.experimentalDesign ?? '-'),
      pw.SizedBox(height: 10),
      pw.Text(
        'Execution',
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 10,
          color: _textPrimary,
        ),
      ),
      pw.SizedBox(height: 4),
      _dataRow('Actual evidence', evidenceArc.actualEvidenceSummary),
      _dataRow('Evidence state', _plainLabel(evidenceArc.evidenceState)),
      if (evidenceArc.evidenceAnchors.isNotEmpty)
        _dataRow('Evidence anchors', evidenceArc.evidenceAnchors.join(', ')),
      if (evidenceArc.missingEvidenceItems.isNotEmpty)
        _dataRow(
            'Missing evidence', evidenceArc.missingEvidenceItems.join('; ')),
      if (amendmentCount > 0)
        _amberNote(
          '$amendmentCount rating amendment${amendmentCount == 1 ? '' : 's'} recorded. See audit trail section.',
        ),
    ];
  }

  List<pw.Widget> _buildDataQuality() {
    if (assessmentStats.isEmpty) {
      return [
        pw.Text(
          'No assessment data available.',
          style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: 10,
            color: _textSecondary,
          ),
        ),
      ];
    }

    return [
      pw.TableHelper.fromTextArray(
        headers: ['Assessment', 'CV', 'Variability', 'Outliers'],
        headerStyle: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 9,
          color: _white,
        ),
        headerDecoration: const pw.BoxDecoration(color: _green),
        cellStyle: pw.TextStyle(
          font: pw.Font.helvetica(),
          fontSize: 9,
          color: _textPrimary,
        ),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.center,
          2: pw.Alignment.center,
          3: pw.Alignment.center,
        },
        data: assessmentStats
            .map(
              (a) => [
                a.progress.assessmentName,
                a.trialCV != null ? '${a.trialCV!.toStringAsFixed(1)}%' : '-',
                cvTierLabel(a.trialCV),
                a.outliers != null && a.outliers!.isNotEmpty
                    ? 'Detected'
                    : 'None',
              ],
            )
            .toList(),
      ),
      if (assessmentStats.any((a) => a.trialCV != null && a.trialCV! > 35)) ...[
        pw.SizedBox(height: 8),
        _amberNote(
          'High variability in one or more assessments may limit the reliability of treatment separation conclusions.',
        ),
      ],
      if (interpretationRisk.factors.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        _dataRow(
            'Interpretation risk', _plainLabel(interpretationRisk.riskLevel)),
      ],
    ];
  }

  List<pw.Widget> _buildTreatmentResults() {
    if (assessmentStats.isEmpty) {
      return [
        pw.Text(
          'No treatment result summaries available.',
          style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: 10,
            color: _textSecondary,
          ),
        ),
      ];
    }

    final widgets = <pw.Widget>[];
    for (final a in assessmentStats) {
      widgets.addAll([
        pw.Text(
          a.progress.assessmentName,
          style: pw.TextStyle(
            font: pw.Font.helveticaBold(),
            fontSize: 10,
            color: _textPrimary,
          ),
        ),
        pw.SizedBox(height: 4),
      ]);
      if (a.treatmentMeans.isEmpty) {
        widgets.add(
          pw.Text(
            'No numeric treatment means available.',
            style: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: 9,
              color: _textSecondary,
            ),
          ),
        );
      } else {
        widgets.add(
          pw.TableHelper.fromTextArray(
            headers: ['Treatment', 'Mean', 'n', 'SD', 'Notes'],
            headerStyle: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 9,
              color: _white,
            ),
            headerDecoration: const pw.BoxDecoration(color: _green),
            cellStyle: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: 9,
              color: _textPrimary,
            ),
            data: a.treatmentMeans.map((t) {
              final outlierReps = a.outliers
                  ?.where((o) => o.treatmentCode == t.treatmentCode)
                  .map((o) => 'Rep ${o.rep}')
                  .join(', ');
              final notes = [
                if (outlierReps != null && outlierReps.isNotEmpty)
                  'Outlier: $outlierReps',
                if (isCheckTreatment(t.treatmentCode)) 'Untreated check',
              ].join(' / ');
              return [
                t.treatmentCode,
                '${t.mean.toStringAsFixed(1)} ${a.unit}'.trim(),
                '${t.n}',
                t.standardDeviation.toStringAsFixed(1),
                notes,
              ];
            }).toList(),
          ),
        );
      }
      if (a.trialCV != null && a.trialCV! > 35) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4, bottom: 8),
            child: pw.Text(
              'High variability - interpret mean separation with caution.',
              style: pw.TextStyle(
                font: pw.Font.helvetica(),
                fontSize: 9,
                color: _amber,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        );
      }
      widgets.add(pw.SizedBox(height: 12));
    }
    return widgets;
  }

  List<pw.Widget> _buildProtocolAlignment() {
    final aligned = coherence.checks.where((c) => c.status == 'aligned').length;
    final total = coherence.checks.length;
    return [
      _dataRow('Alignment summary', '$aligned of $total checks aligned'),
      pw.SizedBox(height: 8),
      if (coherence.checks.isEmpty)
        pw.Text(
          'No protocol alignment checks available.',
          style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: 10,
            color: _textSecondary,
          ),
        )
      else
        for (final check in coherence.checks) ...[
          pw.Row(
            children: [
              pw.Container(
                width: 8,
                height: 8,
                decoration: pw.BoxDecoration(
                  color: _checkColor(check.status),
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      check.label,
                      style: pw.TextStyle(
                        font: pw.Font.helvetica(),
                        fontSize: 10,
                        color: _textPrimary,
                      ),
                    ),
                    if (check.status != 'aligned' && check.reason.isNotEmpty)
                      pw.Text(
                        check.reason,
                        style: pw.TextStyle(
                          font: pw.Font.helvetica(),
                          fontSize: 9,
                          color: _textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              pw.Text(
                _checkStatusLabel(check.status),
                style: pw.TextStyle(
                  font: pw.Font.helvetica(),
                  fontSize: 9,
                  color: _checkColor(check.status),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
        ],
    ];
  }

  PdfColor _checkColor(String status) {
    switch (status) {
      case 'aligned':
        return _green;
      case 'review_needed':
        return _amber;
      case 'blocked':
        return _red;
      default:
        return _textSecondary;
    }
  }

  String _checkStatusLabel(String status) {
    switch (status) {
      case 'aligned':
        return 'Aligned';
      case 'review_needed':
        return 'Review needed';
      case 'cannot_evaluate':
        return 'Cannot evaluate';
      case 'acknowledged':
        return 'Acknowledged';
      default:
        return _plainLabel(status);
    }
  }

  List<pw.Widget> _buildSignalsAndDecisions() {
    return [
      if (openSignals.isNotEmpty) ...[
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: _amberLight,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: _amber, width: 0.5),
          ),
          child: pw.Text(
            '${openSignals.length} signal${openSignals.length == 1 ? '' : 's'} require attention before submission',
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 10,
              color: _amber,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        for (final signal in openSignals) ...[
          pw.Text(
            signalDisplayTitle(signal.signalType),
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 10,
              color: _textPrimary,
            ),
          ),
          pw.Text(
            signal.consequenceText,
            style: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: 9,
              color: _textSecondary,
            ),
          ),
          pw.Text(
            'Status: ${signalStatusLabel(signal.status)}',
            style: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: 9,
              color: _amber,
            ),
          ),
          pw.SizedBox(height: 6),
        ],
      ],
      if (openSignals.isEmpty)
        pw.Text(
          'No open signals.',
          style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: 10,
            color: _textSecondary,
          ),
        ),
      pw.SizedBox(height: 8),
      pw.Text(
        'Documented decisions',
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 10,
          color: _textPrimary,
        ),
      ),
      pw.SizedBox(height: 4),
      if (!decisionSummary.hasAnyResearcherReasoning)
        pw.Text(
          'No decisions recorded.',
          style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: 10,
            color: _textSecondary,
          ),
        )
      else ...[
        for (final decision in decisionSummary.signalDecisions)
          _decisionLine(
            'Signal ${decision.signalId}',
            decision.eventType,
            decision.note,
            decision.actorName,
            DateTime.fromMillisecondsSinceEpoch(
              decision.occurredAt,
              isUtc: true,
            ),
          ),
        for (final ack in decisionSummary.ctqAcknowledgments)
          _decisionLine(
            ack.factorKey,
            'CTQ acknowledgment',
            ack.reason,
            ack.actorName,
            ack.acknowledgedAt,
          ),
      ],
    ];
  }

  pw.Widget _decisionLine(
    String title,
    String decisionType,
    String? reasoning,
    String? actor,
    DateTime date,
  ) {
    final dateLabel = DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal());
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$title - ${_plainLabel(decisionType)}',
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 9,
              color: _textPrimary,
            ),
          ),
          pw.Text(
            [
              if (actor != null && actor.trim().isNotEmpty) actor,
              dateLabel,
            ].join(' / '),
            style: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: 8,
              color: _textSecondary,
            ),
          ),
          if (reasoning != null && reasoning.trim().isNotEmpty)
            pw.Text(
              reasoning,
              style: pw.TextStyle(
                font: pw.Font.helvetica(),
                fontSize: 9,
                color: _textPrimary,
              ),
            ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildEnvironmentalContext() {
    final summary = environmentalSummary;
    if (summary == null) {
      return [
        pw.Text(
          'Environmental evidence not available. Set trial site coordinates to enable weather tracking.',
          style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: 10,
            color: _textSecondary,
          ),
        ),
      ];
    }

    return [
      _dataRow(
        'Season precipitation',
        summary.totalPrecipitationMm != null
            ? '${summary.totalPrecipitationMm!.toStringAsFixed(1)} mm'
            : '-',
      ),
      _dataRow('Frost events', '${summary.totalFrostEvents}'),
      _dataRow(
        'Excessive rainfall events',
        '${summary.totalExcessiveRainfallEvents}',
      ),
      _dataRow(
        'Days with data',
        '${summary.daysWithData} / ${summary.daysExpected}',
      ),
      _dataRow('Confidence', _plainLabel(summary.overallConfidence)),
    ];
  }

  List<pw.Widget> _buildAuditTrail() {
    if (amendmentCount == 0) {
      return [
        pw.Text(
          'No rating amendments recorded.',
          style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: 10,
            color: _textSecondary,
          ),
        ),
      ];
    }
    return [
      _amberNote(
        '$amendmentCount rating amendment${amendmentCount == 1 ? '' : 's'} recorded. Full amendment detail is available in the Agnexis Data Screen export.',
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        'Amendment records are maintained in the trial database and available for audit on request.',
        style: pw.TextStyle(
          font: pw.Font.helvetica(),
          fontSize: 10,
          color: _textSecondary,
        ),
      ),
    ];
  }

  String _plainLabel(String value) {
    final spaced = value.replaceAll('_', ' ').trim();
    if (spaced.isEmpty) return '-';
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}
