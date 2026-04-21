import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/pdf_branding.dart';
import 'evidence_report_data.dart';

/// Renders the Field Evidence Report PDF from assembled [EvidenceReportData].
class EvidenceReportPdfBuilder {
  static const _primary = PdfBranding.primaryColor;
  static const _accent = PdfColor.fromInt(0xFF2E7D52);
  static const _headerBg = PdfColor.fromInt(0xFFF4F1EB);
  static const _borderColor = PdfColor.fromInt(0xFFCCCCCC);
  static const _textSecondary = PdfColor.fromInt(0xFF555555);
  static const _alertRed = PdfColor.fromInt(0xFFCC3333);
  static const _successGreen = PdfColor.fromInt(0xFF2E7D32);
  static const _warningAmber = PdfColor.fromInt(0xFFE65100);
  static const _rowAlt = PdfColor.fromInt(0xFFF8F8F8);

  Future<Uint8List> build(EvidenceReportData data) async {
    final pdf = pw.Document();
    final dateFmt = DateFormat('yyyy-MM-dd');
    final dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

    final logo = await PdfBranding.loadLogo();

    const pageFormat = PdfPageFormat.a4;

    pdf.addPage(pw.MultiPage(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(28),
      header: (_) => _pageHeader(logo, data, dateTimeFmt),
      footer: (ctx) => _pageFooter(ctx),
      build: (ctx) => [
        // Title
        pw.Center(
          child: pw.Text(
            'FIELD EVIDENCE REPORT',
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
            'Generated ${dateTimeFmt.format(data.generatedAt)} · Agnexis v${data.appVersion}',
            style: const pw.TextStyle(fontSize: 8, color: _textSecondary),
          ),
        ),
        pw.SizedBox(height: 16),

        // ── EVIDENCE COMPLETENESS SCORE ──
        _sectionTitle('Evidence Completeness Score'),
        _completenessScoreSection(data.completenessScore),
        pw.SizedBox(height: 16),

        // ── 1. TRIAL IDENTITY ──
        _sectionTitle('1. Trial Identity'),
        _trialIdentitySection(data.identity, dateFmt),
        pw.SizedBox(height: 16),

        // ── 2. PROTOCOL TIMELINE ──
        _sectionTitle('2. Protocol Timeline'),
        _timelineSection(data.timeline, dateTimeFmt),
        pw.SizedBox(height: 16),

        // ── 3. TREATMENTS ──
        _sectionTitle('3. Treatment Table'),
        _treatmentSection(data.treatments),
        pw.SizedBox(height: 16),

        // ── 4. SEEDING ──
        if (data.seeding != null) ...[
          _sectionTitle('4. Seeding Evidence'),
          _seedingSection(data.seeding!, dateFmt, dateTimeFmt),
          pw.SizedBox(height: 16),
        ],

        // ── 5. APPLICATIONS ──
        if (data.applications.isNotEmpty) ...[
          _sectionTitle('5. Application Evidence'),
          _applicationSection(data.applications, dateFmt),
          pw.SizedBox(height: 16),
        ],

        // ── 6. SESSION EVIDENCE MATRIX ──
        _sectionTitle('6. Session Evidence Matrix'),
        _sessionMatrixSection(data.sessions, dateTimeFmt),
        pw.SizedBox(height: 16),

        // ── 7. DATA INTEGRITY ──
        _sectionTitle('7. Data Integrity Evidence'),
        _dataIntegritySection(data.integrity),
        pw.SizedBox(height: 16),

        // ── 8. TIMESTAMP DISTRIBUTIONS ──
        if (data.integrity.sessionTimestampDistributions.isNotEmpty) ...[
          _sectionTitle('8. Timestamp Distribution'),
          _timestampDistributionSection(
              data.integrity.sessionTimestampDistributions),
          pw.SizedBox(height: 16),
        ],

        // ── 9. AMENDMENT & CORRECTION LOG ──
        if (data.integrity.amendments.isNotEmpty ||
            data.integrity.corrections.isNotEmpty) ...[
          _sectionTitle('9. Amendment & Correction Log'),
          _amendmentSection(data.integrity, dateTimeFmt),
          pw.SizedBox(height: 16),
        ],

        // ── 10. OUTLIER DOCUMENTATION ──
        if (data.outliers.isNotEmpty) ...[
          _sectionTitle('10. Outlier Documentation'),
          _outlierSection(data.outliers),
          pw.SizedBox(height: 16),
        ],

        // ── 11. DEVICE & RATER CERTIFICATION ──
        _sectionTitle('11. Device & Rater Certification'),
        _deviceRaterSection(data.integrity),
        pw.SizedBox(height: 16),

        // ── WEATHER EVIDENCE ──
        if (data.sessions.any((s) => s.weather?.hasData == true)) ...[
          _sectionTitle('12. Weather Evidence'),
          _weatherSection(data.sessions),
          pw.SizedBox(height: 16),
        ],

        // ── PHOTO EVIDENCE ──
        if (data.photos.isNotEmpty) ...[
          _sectionTitle('13. Photo Evidence'),
          _photoSection(data.photos, dateTimeFmt),
          pw.SizedBox(height: 16),
        ],
      ],
    ));

    return pdf.save();
  }

  pw.Widget _pageHeader(
    pw.ImageProvider? logo,
    EvidenceReportData data,
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
              '${data.identity.name} — Field Evidence Report',
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

  // ── COMPLETENESS SCORE ──
  pw.Widget _completenessScoreSection(EvidenceCompletenessScore score) {
    final pct = score.percentage.round();
    final color = pct >= 80
        ? _successGreen
        : (pct >= 50 ? _warningAmber : _alertRed);

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                '$pct / 100',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Text(
                  'Evidence Completeness Score',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _primary,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          // Score bar
          pw.ClipRRect(
            horizontalRadius: 3,
            verticalRadius: 3,
            child: pw.Container(
              height: 8,
              child: pw.Stack(
                children: [
                  pw.Container(
                    color: const PdfColor.fromInt(0xFFE0E0E0),
                  ),
                  pw.Container(
                    width: (pct / 100) * 500, // approximate
                    color: color,
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          for (final c in score.components)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 130,
                    child: pw.Text(c.name,
                        style: const pw.TextStyle(fontSize: 8)),
                  ),
                  pw.SizedBox(
                    width: 40,
                    child: pw.Text(
                      '${c.score}/${c.maxScore}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: c.score == c.maxScore
                            ? _successGreen
                            : (c.score > 0 ? _warningAmber : _alertRed),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(c.detail,
                        style: const pw.TextStyle(
                            fontSize: 7, color: _textSecondary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── TRIAL IDENTITY ──
  pw.Widget _trialIdentitySection(
      EvidenceTrialIdentity id, DateFormat dateFmt) {
    final rows = <List<String>>[
      ['Trial name', id.name],
      if (id.protocolNumber != null) ['Protocol number', id.protocolNumber!],
      if (id.sponsor != null) ['Sponsor', id.sponsor!],
      if (id.investigatorName != null)
        ['Investigator', id.investigatorName!],
      if (id.cooperatorName != null) ['Cooperator', id.cooperatorName!],
      if (id.crop != null) ['Crop', id.crop!],
      if (id.location != null) ['Location', id.location!],
      if (id.season != null) ['Season', id.season!],
      if (id.fieldName != null) ['Field', id.fieldName!],
      if (id.county != null || id.stateProvince != null || id.country != null)
        [
          'Region',
          [id.county, id.stateProvince, id.country]
              .whereType<String>()
              .join(', ')
        ],
      if (id.latitude != null && id.longitude != null)
        [
          'GPS',
          '${id.latitude!.toStringAsFixed(6)}, '
              '${id.longitude!.toStringAsFixed(6)}'
        ],
      if (id.soilSeries != null || id.soilTexture != null)
        [
          'Soil',
          [id.soilSeries, id.soilTexture].whereType<String>().join(' — ')
        ],
      if (id.experimentalDesign != null) ['Design', id.experimentalDesign!],
      if (id.plotCount != null) ['Plots', '${id.plotCount}'],
      if (id.treatmentCount != null)
        ['Treatments', '${id.treatmentCount}'],
      if (id.repCount != null) ['Reps', '${id.repCount}'],
      if (id.createdAt != null)
        ['Created', dateFmt.format(id.createdAt!)],
      ['Status', id.status],
      ['Workspace', id.workspaceType],
    ];

    return _keyValueTable(rows);
  }

  // ── TIMELINE ──
  pw.Widget _timelineSection(List<TimelineEvent> events, DateFormat fmt) {
    if (events.isEmpty) {
      return pw.Text('No timeline events.',
          style: const pw.TextStyle(fontSize: 9, color: _textSecondary));
    }
    return pw.TableHelper.fromTextArray(
      headers: ['Date', 'Time', 'Event', 'Detail'],
      data: events
          .map((e) => [
                DateFormat('yyyy-MM-dd').format(e.date),
                DateFormat('HH:mm').format(e.date),
                e.label,
                e.detail ?? '',
              ])
          .toList(),
      headerStyle: _tableHeaderStyle(),
      headerDecoration: const pw.BoxDecoration(color: _primary),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(65),
        1: const pw.FixedColumnWidth(35),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1),
      },
      oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
    );
  }

  // ── TREATMENTS ──
  pw.Widget _treatmentSection(List<EvidenceTreatment> treatments) {
    final rows = <List<String>>[];
    for (final t in treatments) {
      if (t.components.isEmpty) {
        rows.add([t.code, t.name, t.treatmentType ?? '', '', '', '']);
      } else {
        for (var i = 0; i < t.components.length; i++) {
          final c = t.components[i];
          rows.add([
            i == 0 ? t.code : '',
            i == 0 ? t.name : '',
            i == 0 ? (t.treatmentType ?? '') : '',
            c.productName,
            c.rate != null ? '${c.rate} ${c.rateUnit ?? ''}' : '',
            c.formulationType ?? '',
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
      columnWidths: {
        0: const pw.FixedColumnWidth(40),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FixedColumnWidth(40),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FixedColumnWidth(60),
        5: const pw.FixedColumnWidth(60),
      },
      oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
    );
  }

  // ── SEEDING ──
  pw.Widget _seedingSection(
      EvidenceSeeding s, DateFormat dateFmt, DateFormat dateTimeFmt) {
    final rows = <List<String>>[
      ['Seeding date', dateFmt.format(s.seedingDate)],
      if (s.variety != null) ['Variety', s.variety!],
      if (s.seedLotNumber != null) ['Seed lot', s.seedLotNumber!],
      if (s.seedingRate != null)
        ['Rate', '${s.seedingRate} ${s.seedingRateUnit ?? ''}'],
      if (s.plantingMethod != null) ['Method', s.plantingMethod!],
      if (s.operatorName != null) ['Operator', s.operatorName!],
      if (s.completedAt != null)
        ['Completed', dateTimeFmt.format(s.completedAt!)],
      if (s.emergenceDate != null)
        ['Emergence', dateFmt.format(s.emergenceDate!)],
      if (s.status != null) ['Status', s.status!],
    ];
    return _keyValueTable(rows);
  }

  // ── APPLICATIONS ──
  pw.Widget _applicationSection(
      List<EvidenceApplication> apps, DateFormat dateFmt) {
    final rows = apps
        .map((a) => [
              dateFmt.format(a.applicationDate),
              a.productName ?? '-',
              a.treatmentCode ?? '-',
              a.rate != null ? '${a.rate} ${a.rateUnit ?? ''}' : '-',
              a.applicationMethod ?? '-',
              a.operatorName ?? '-',
              _appWeather(a),
              a.status ?? '-',
            ])
        .toList();

    return pw.TableHelper.fromTextArray(
      headers: [
        'Date',
        'Product',
        'Treatment',
        'Rate',
        'Method',
        'Operator',
        'Weather',
        'Status'
      ],
      data: rows,
      headerStyle: _tableHeaderStyle(),
      headerDecoration: const pw.BoxDecoration(color: _primary),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
    );
  }

  String _appWeather(EvidenceApplication a) {
    final parts = <String>[];
    if (a.temperature != null) parts.add('${a.temperature}°C');
    if (a.humidity != null) parts.add('${a.humidity}% RH');
    if (a.windSpeed != null) parts.add('${a.windSpeed} km/h');
    return parts.isEmpty ? '-' : parts.join(', ');
  }

  // ── SESSION MATRIX ──
  pw.Widget _sessionMatrixSection(
      List<EvidenceSession> sessions, DateFormat fmt) {
    final rows = sessions
        .map((s) => [
              s.name,
              s.sessionDateLocal,
              s.raterName ?? '-',
              s.startedAt != null ? DateFormat('HH:mm').format(s.startedAt!) : '-',
              s.endedAt != null ? DateFormat('HH:mm').format(s.endedAt!) : '-',
              _sessionDuration(s),
              '${s.plotsRated}',
              '${s.plotsEdited}',
              '${s.assessmentCount}',
              s.cropStageBbch?.toString() ?? '-',
              s.status,
            ])
        .toList();

    return pw.TableHelper.fromTextArray(
      headers: [
        'Session',
        'Date',
        'Rater',
        'Start',
        'End',
        'Duration',
        'Plots',
        'Edited',
        'Assess.',
        'BBCH',
        'Status'
      ],
      data: rows,
      headerStyle: _tableHeaderStyle(),
      headerDecoration: const pw.BoxDecoration(color: _primary),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellAlignment: pw.Alignment.center,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
    );
  }

  String _sessionDuration(EvidenceSession s) {
    if (s.startedAt == null || s.endedAt == null) return '-';
    final mins = s.endedAt!.difference(s.startedAt!).inMinutes;
    if (mins < 60) return '${mins}m';
    return '${mins ~/ 60}h ${mins % 60}m';
  }

  // ── DATA INTEGRITY ──
  pw.Widget _dataIntegritySection(EvidenceDataIntegrity di) {
    final statusRows = di.statusCounts.entries
        .map((e) => [e.key, '${e.value}'])
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _keyValueTable([
          ['Total ratings', '${di.totalRatings}'],
          [
            'With GPS coordinates',
            '${di.ratingsWithGps} (${_pct(di.ratingsWithGps, di.totalRatings)}%)'
          ],
          [
            'With confidence level',
            '${di.ratingsWithConfidence} (${_pct(di.ratingsWithConfidence, di.totalRatings)}%)'
          ],
          [
            'With timestamp',
            '${di.ratingsWithTimestamp} (${_pct(di.ratingsWithTimestamp, di.totalRatings)}%)'
          ],
          ['Amendments', '${di.amendments.length}'],
          ['Corrections', '${di.corrections.length}'],
        ]),
        pw.SizedBox(height: 8),
        pw.Text('Value status distribution:',
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: ['Status', 'Count'],
          data: statusRows,
          headerStyle: _tableHeaderStyle(),
          headerDecoration: const pw.BoxDecoration(color: _primary),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          border: pw.TableBorder.all(color: _borderColor, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FixedColumnWidth(60),
          },
          oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
        ),
      ],
    );
  }

  // ── TIMESTAMP DISTRIBUTION ──
  pw.Widget _timestampDistributionSection(
      List<SessionTimestampDistribution> dists) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Timestamp distribution shows when ratings were collected within '
          'each session. Evenly distributed timestamps indicate authentic '
          'field collection. Clustered timestamps may indicate batch entry.',
          style: const pw.TextStyle(fontSize: 8, color: _textSecondary),
        ),
        pw.SizedBox(height: 6),
        for (final d in dists) ...[
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _borderColor),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${d.sessionName} — ${d.sessionDate}',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'First: ${d.firstRatingTime ?? "-"} · '
                  'Last: ${d.lastRatingTime ?? "-"} · '
                  'Duration: ${d.durationMinutes} min · '
                  'Ratings: ${d.ratingCount}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                if (d.ratingCount > 0 && d.durationMinutes > 0) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Average pace: ${(d.durationMinutes / d.ratingCount * 60).toStringAsFixed(1)} sec/rating',
                    style:
                        const pw.TextStyle(fontSize: 8, color: _textSecondary),
                  ),
                ],
                // Simple text-based distribution (5 time buckets)
                if (d.ratingTimesMinutesFromStart.isNotEmpty &&
                    d.durationMinutes > 0) ...[
                  pw.SizedBox(height: 4),
                  _textHistogram(d),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  pw.Widget _textHistogram(SessionTimestampDistribution d) {
    // Divide into 5 buckets
    const bucketCount = 5;
    final bucketSize =
        (d.durationMinutes / bucketCount).ceil().clamp(1, 999999);
    final buckets = List.filled(bucketCount, 0);
    for (final m in d.ratingTimesMinutesFromStart) {
      final idx = (m / bucketSize).floor().clamp(0, bucketCount - 1);
      buckets[idx]++;
    }
    final maxBucket = buckets.reduce((a, b) => a > b ? a : b);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Distribution (${bucketSize}min buckets):',
            style: const pw.TextStyle(fontSize: 7, color: _textSecondary)),
        pw.SizedBox(height: 2),
        for (var i = 0; i < bucketCount; i++)
          pw.Row(
            children: [
              pw.SizedBox(
                width: 50,
                child: pw.Text(
                  '${i * bucketSize}-${(i + 1) * bucketSize}m',
                  style: const pw.TextStyle(fontSize: 7),
                ),
              ),
              pw.Container(
                width: maxBucket > 0
                    ? (buckets[i] / maxBucket) * 200
                    : 0,
                height: 6,
                color: _accent,
              ),
              pw.SizedBox(width: 4),
              pw.Text('${buckets[i]}',
                  style: const pw.TextStyle(fontSize: 7)),
            ],
          ),
      ],
    );
  }

  // ── AMENDMENTS ──
  pw.Widget _amendmentSection(EvidenceDataIntegrity di, DateFormat fmt) {
    final widgets = <pw.Widget>[];

    if (di.amendments.isNotEmpty) {
      widgets.add(pw.Text(
        'Amendments (${di.amendments.length}):',
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ));
      widgets.add(pw.SizedBox(height: 4));
      widgets.add(pw.TableHelper.fromTextArray(
        headers: [
          'Plot',
          'Assessment',
          'Session',
          'Original',
          'New',
          'Reason',
          'By',
          'When'
        ],
        data: di.amendments
            .map((a) => [
                  a.plotLabel,
                  a.assessmentName,
                  a.sessionName,
                  a.originalValue ?? '-',
                  a.newValue ?? '-',
                  a.reason ?? '-',
                  a.amendedBy ?? '-',
                  a.amendedAt != null ? fmt.format(a.amendedAt!) : '-',
                ])
            .toList(),
        headerStyle: _tableHeaderStyle(),
        headerDecoration: const pw.BoxDecoration(color: _primary),
        cellStyle: const pw.TextStyle(fontSize: 7),
        cellAlignment: pw.Alignment.centerLeft,
        cellPadding:
            const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        border: pw.TableBorder.all(color: _borderColor, width: 0.5),
        oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
      ));
    }

    if (di.corrections.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(pw.Text(
        'Corrections (${di.corrections.length}):',
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ));
      widgets.add(pw.SizedBox(height: 4));
      widgets.add(pw.TableHelper.fromTextArray(
        headers: [
          'Plot',
          'Session',
          'Old value',
          'New value',
          'Status change',
          'Reason',
          'When'
        ],
        data: di.corrections
            .map((c) => [
                  c.plotLabel,
                  c.sessionName,
                  c.oldValue ?? '-',
                  c.newValue ?? '-',
                  c.oldStatus != c.newStatus
                      ? '${c.oldStatus ?? ""} → ${c.newStatus ?? ""}'
                      : '-',
                  c.reason ?? '-',
                  c.correctedAt != null ? fmt.format(c.correctedAt!) : '-',
                ])
            .toList(),
        headerStyle: _tableHeaderStyle(),
        headerDecoration: const pw.BoxDecoration(color: _primary),
        cellStyle: const pw.TextStyle(fontSize: 7),
        cellAlignment: pw.Alignment.centerLeft,
        cellPadding:
            const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        border: pw.TableBorder.all(color: _borderColor, width: 0.5),
        oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
      ));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }

  // ── OUTLIERS ──
  pw.Widget _outlierSection(List<EvidenceOutlier> outliers) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '${outliers.length} value(s) flagged as >2 SD from treatment mean.',
          style: const pw.TextStyle(fontSize: 8, color: _textSecondary),
        ),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: [
            'Plot',
            'Treatment',
            'Rep',
            'Assessment',
            'Value',
            'Trt Mean',
            'SD',
            'Confidence',
            'Amended'
          ],
          data: outliers
              .map((o) => [
                    o.plotLabel,
                    o.treatmentCode,
                    o.rep?.toString() ?? '-',
                    o.assessmentName,
                    o.value.toStringAsFixed(1),
                    o.treatmentMean.toStringAsFixed(1),
                    '${o.sdFromMean.toStringAsFixed(1)}σ',
                    o.confidence ?? '-',
                    o.wasAmended ? 'Yes' : 'No',
                  ])
              .toList(),
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
    );
  }

  // ── DEVICE & RATER ──
  pw.Widget _deviceRaterSection(EvidenceDataIntegrity di) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Devices used:',
            style:
                pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        if (di.deviceSummaries.isEmpty)
          pw.Text('No device information recorded.',
              style: const pw.TextStyle(fontSize: 8, color: _textSecondary))
        else
          pw.TableHelper.fromTextArray(
            headers: ['Device', 'Ratings', 'Sessions'],
            data: di.deviceSummaries
                .map((d) => [
                      d.deviceInfo,
                      '${d.ratingCount}',
                      d.sessionNames.join(', '),
                    ])
                .toList(),
            headerStyle: _tableHeaderStyle(),
            headerDecoration: const pw.BoxDecoration(color: _primary),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            border: pw.TableBorder.all(color: _borderColor, width: 0.5),
            oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
          ),
        pw.SizedBox(height: 10),
        pw.Text('Raters:',
            style:
                pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: ['Rater', 'Ratings', 'Sessions'],
          data: di.raterSummaries
              .map((r) => [
                    r.name,
                    '${r.ratingCount}',
                    r.sessionNames.join(', '),
                  ])
              .toList(),
          headerStyle: _tableHeaderStyle(),
          headerDecoration: const pw.BoxDecoration(color: _primary),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          border: pw.TableBorder.all(color: _borderColor, width: 0.5),
          oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
        ),
      ],
    );
  }

  // ── WEATHER ──
  pw.Widget _weatherSection(List<EvidenceSession> sessions) {
    final sessionsWithWeather =
        sessions.where((s) => s.weather?.hasData == true).toList();

    return pw.TableHelper.fromTextArray(
      headers: [
        'Session',
        'Date',
        'Temp',
        'Humidity',
        'Wind',
        'Direction',
        'Cloud',
        'Precip.',
        'Soil',
        'Source'
      ],
      data: sessionsWithWeather
          .map((s) {
            final w = s.weather!;
            return [
              s.name,
              s.sessionDateLocal,
              w.temperature != null
                  ? '${w.temperature}°${w.temperatureUnit ?? 'C'}'
                  : '-',
              w.humidity != null ? '${w.humidity}%' : '-',
              w.windSpeed != null
                  ? '${w.windSpeed} ${w.windSpeedUnit ?? 'km/h'}'
                  : '-',
              w.windDirection ?? '-',
              w.cloudCover ?? '-',
              w.precipitation ?? '-',
              w.soilCondition ?? '-',
              w.source ?? '-',
            ];
          })
          .toList(),
      headerStyle: _tableHeaderStyle(),
      headerDecoration: const pw.BoxDecoration(color: _primary),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellAlignment: pw.Alignment.center,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
    );
  }

  // ── PHOTOS ──
  pw.Widget _photoSection(List<EvidencePhoto> photos, DateFormat fmt) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '${photos.length} photo(s) attached to this trial.',
          style: const pw.TextStyle(fontSize: 8, color: _textSecondary),
        ),
        pw.SizedBox(height: 8),
        // Photo grid — 2 per row with metadata
        pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final photo in photos)
              pw.Container(
                width: 250,
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _borderColor),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Thumbnail or placeholder
                    if (photo.imageBytes != null)
                      pw.ClipRRect(
                        horizontalRadius: 2,
                        verticalRadius: 2,
                        child: pw.Image(
                          pw.MemoryImage(
                              photo.imageBytes! is Uint8List
                                  ? photo.imageBytes! as Uint8List
                                  : Uint8List.fromList(photo.imageBytes!)),
                          width: 242,
                          height: 160,
                          fit: pw.BoxFit.cover,
                        ),
                      )
                    else
                      pw.Container(
                        width: 242,
                        height: 160,
                        color: _rowAlt,
                        alignment: pw.Alignment.center,
                        child: pw.Text('Photo not available',
                            style: const pw.TextStyle(
                                fontSize: 8, color: _textSecondary)),
                      ),
                    pw.SizedBox(height: 4),
                    // Metadata
                    pw.Text(
                      '${photo.plotLabel} · ${photo.sessionName}',
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      '${photo.sessionDate} · '
                      '${DateFormat('HH:mm').format(photo.createdAt)}',
                      style:
                          const pw.TextStyle(fontSize: 7, color: _textSecondary),
                    ),
                    if (photo.caption != null && photo.caption!.isNotEmpty)
                      pw.Text(
                        photo.caption!,
                        style: const pw.TextStyle(
                            fontSize: 7, color: _textSecondary),
                        maxLines: 2,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ── Helpers ──
  pw.Widget _keyValueTable(List<List<String>> rows) {
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

  pw.TextStyle _tableHeaderStyle() {
    return pw.TextStyle(
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
  }

  String _pct(int part, int total) =>
      total > 0 ? (part / total * 100).round().toString() : '0';
}
