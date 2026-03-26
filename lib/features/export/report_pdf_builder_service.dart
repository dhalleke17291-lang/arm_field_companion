import 'package:flutter/services.dart';
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

/// ASCII hyphen for missing PDF values (Helvetica Unicode limitations).
const String _emDashPlaceholder = '-';

/// Builds a PDF document from assembled report data.
/// Profile-aware layout; research profile is fully implemented.
class ReportPdfBuilderService {
  ReportPdfBuilderService();

  /// Swap this path in one line to change the report header logo asset.
  static const _kLogoAssetPath = 'assets/Branding/splash_logo.png';

  static const _kPrimaryColor = PdfColor.fromInt(0xFF0E3D2F);
  static const _kAccentColor = PdfColor.fromInt(0xFF2E7D52);
  static const _kHeaderBg = PdfColor.fromInt(0xFFF4F1EB);
  static const _kBorderColor = PdfColor.fromInt(0xFFCCCCCC);
  static const _kTextSecondary = PdfColor.fromInt(0xFF555555);

  static const _kFontSizeDisplay = 24.0;
  static const _kFontSizeH1 = 16.0;
  static const _kFontSizeH2 = 13.0;
  static const _kFontSizeBody = 10.0;
  static const _kFontSizeSmall = 9.0;
  static const _kFontSizeCaption = 8.0;

  static const _kSpaceXS = 4.0;
  static const _kSpaceSM = 8.0;
  static const _kSpaceMD = 16.0;
  static const _kSpaceLG = 24.0;

  /// Returns PDF bytes for the given report data.
  Future<Uint8List> build(
    StandaloneReportData data, {
    ReportProfile profile = ReportProfile.research,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('yyyy-MM-dd');
    pw.ImageProvider? logo;
    try {
      final logoBytes = await rootBundle.load(_kLogoAssetPath);
      logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {
      logo = null;
    }

    switch (profile) {
      case ReportProfile.research:
        _buildResearch(pdf, data, logo, dateFormat);
        break;
      case ReportProfile.fieldSummary:
        _buildStubPage(pdf, 'Field Summary');
        break;
      case ReportProfile.interim:
        _buildStubPage(pdf, 'Interim / Progress');
        break;
      case ReportProfile.glpAudit:
        _buildStubPage(pdf, 'GLP Audit');
        break;
      case ReportProfile.cooperator:
        _buildStubPage(pdf, 'Cooperator Report');
        break;
    }

    return pdf.save();
  }

  // TODO: implement in future pass
  void _buildStubPage(pw.Document pdf, String name) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (context) => pw.Center(
          child: pw.Text(
            '$name report - not yet implemented',
            style: const pw.TextStyle(fontSize: 16),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ),
    );
  }

  void _buildResearch(
    pw.Document pdf,
    StandaloneReportData data,
    pw.ImageProvider? logo,
    DateFormat dateFormat,
  ) {
    final t = data.trial;
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 48),
        header: (ctx) => _pageHeader(data, ctx),
        footer: (ctx) => _pageFooter(data, ctx, dateFormat),
        build: (ctx) {
          return [
            ..._buildCover(data, logo, dateFormat),
            pw.NewPage(),
            ..._buildSiteDescriptionSection(t),
            pw.SizedBox(height: _kSpaceMD),
            ..._buildTreatmentsSection(data),
            pw.SizedBox(height: _kSpaceMD),
            ..._buildPlotLayoutSection(data),
            pw.SizedBox(height: _kSpaceMD),
            ..._buildSeedingSection(data, dateFormat),
            pw.SizedBox(height: _kSpaceMD),
            ..._buildApplicationsSection(data, dateFormat),
            pw.SizedBox(height: _kSpaceMD),
            ..._buildSessionsSection(data),
            pw.SizedBox(height: _kSpaceMD),
            ..._buildAssessmentSection(data),
            pw.SizedBox(height: _kSpaceMD),
            ..._buildPhotosSection(data),
          ];
        },
      ),
    );
  }

  List<pw.Widget> _buildCover(
    StandaloneReportData data,
    pw.ImageProvider? logo,
    DateFormat dateFormat,
  ) {
    final t = data.trial;
    final generated = dateFormat.format(DateTime.now());
    return [
      if (logo != null)
        pw.Image(logo, width: 120)
      else
        pw.Text(
          'ARM Field Companion',
          style: pw.TextStyle(
            fontSize: _kFontSizeBody,
            fontWeight: pw.FontWeight.bold,
            color: _kPrimaryColor,
          ),
        ),
      pw.SizedBox(height: _kSpaceMD),
      pw.Text(
        'FIELD TRIAL REPORT',
        style: pw.TextStyle(
          fontSize: _kFontSizeDisplay,
          fontWeight: pw.FontWeight.bold,
          color: _kPrimaryColor,
        ),
      ),
      pw.Text(
        t.name,
        style: const pw.TextStyle(
          fontSize: _kFontSizeH1,
          color: _kTextSecondary,
        ),
      ),
      pw.Container(
        height: 1.5,
        color: _kPrimaryColor,
        margin: const pw.EdgeInsets.only(top: 4, bottom: 4),
      ),
      pw.SizedBox(height: _kSpaceSM),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _kvRow('Protocol Number', t.protocolNumber),
                _kvRow('Sponsor', t.sponsor),
                _kvRow('Investigator', t.investigatorName),
                _kvRow('Cooperator', t.cooperatorName),
                _kvRow('Site ID', t.siteId),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _kvRow('Season', t.season),
                _kvRow('Crop', t.crop),
                _kvRow('Status', _capitalizeLifecycleStatus(_cell(t.status))),
                _kvRow(
                  'Workspace Type',
                  _capitalizeLifecycleStatus(_cell(t.workspaceType)),
                ),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: _kSpaceLG),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Generated: $generated',
          style: const pw.TextStyle(
            fontSize: _kFontSizeCaption,
            color: _kTextSecondary,
          ),
        ),
      ),
    ];
  }

  List<pw.Widget> _buildSiteDescriptionSection(TrialReportSummary t) {
    final widgets = <pw.Widget>[
      _sectionHeader('Site Description'),
    ];

    final locationRows = <pw.Widget>[];
    void addLoc(String label, String? v) {
      final w = _kvRowIfHasValue(label, v);
      if (w != null) locationRows.add(w);
    }

    addLoc('Field Name', t.fieldName);
    addLoc('Location', t.location);
    addLoc('County', t.county);
    addLoc('State / Province', t.stateProvince);
    addLoc('Country', t.country);
    if (t.latitude != null && t.longitude != null) {
      locationRows
          .add(_kvRow('GPS Coordinates', '${t.latitude}, ${t.longitude}'));
    }
    if (t.elevationM != null) {
      locationRows.add(_kvRow('Elevation', '${t.elevationM} m'));
    }

    widgets.add(pw.Text(
      'Location',
      style: pw.TextStyle(
        fontSize: _kFontSizeH2,
        fontWeight: pw.FontWeight.bold,
        color: _kPrimaryColor,
      ),
    ));
    widgets.add(
      locationRows.isEmpty
          ? _italicNote('Not recorded')
          : pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: locationRows,
            ),
    );

    widgets.add(pw.SizedBox(height: _kSpaceSM));

    final conditionRows = <pw.Widget>[];
    void addCond(String label, String? v) {
      final w = _kvRowIfHasValue(label, v);
      if (w != null) conditionRows.add(w);
    }

    addCond('Previous Crop', t.previousCrop);
    addCond('Tillage', t.tillage);
    if (t.irrigated != null) {
      conditionRows.add(_kvRow('Irrigated', t.irrigated! ? 'Yes' : 'No'));
    }
    addCond('Soil Series', t.soilSeries);
    addCond('Soil Texture', t.soilTexture);
    if (t.organicMatterPct != null) {
      conditionRows
          .add(_kvRow('Organic Matter', '${t.organicMatterPct}%'));
    }
    if (t.soilPh != null) {
      conditionRows.add(_kvRow('Soil pH', '${t.soilPh}'));
    }

    widgets.add(pw.Text(
      'Site Conditions',
      style: pw.TextStyle(
        fontSize: _kFontSizeH2,
        fontWeight: pw.FontWeight.bold,
        color: _kPrimaryColor,
      ),
    ));
    widgets.add(
      conditionRows.isEmpty
          ? _italicNote('Not recorded')
          : pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: conditionRows,
            ),
    );

    widgets.add(pw.SizedBox(height: _kSpaceSM));

    final plotRows = <pw.Widget>[];
    void addPlot(String label, String? v) {
      final w = _kvRowIfHasValue(label, v);
      if (w != null) plotRows.add(w);
    }

    addPlot('Experimental Design', t.experimentalDesign);
    if (t.plotLengthM != null && t.plotWidthM != null) {
      plotRows.add(_kvRow(
        'Plot Size',
        '${t.plotLengthM} x ${t.plotWidthM} m',
      ));
    }
    if (t.plotRows != null) {
      plotRows.add(_kvRow('Plot Rows', '${t.plotRows}'));
    }
    addPlot('Plot Dimensions', t.plotDimensions);

    widgets.add(pw.Text(
      'Plot Layout',
      style: pw.TextStyle(
        fontSize: _kFontSizeH2,
        fontWeight: pw.FontWeight.bold,
        color: _kPrimaryColor,
      ),
    ));
    widgets.add(
      plotRows.isEmpty
          ? _italicNote('Not recorded')
          : pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: plotRows,
            ),
    );

    return widgets;
  }

  List<pw.Widget> _buildTreatmentsSection(StandaloneReportData data) {
    final widgets = <pw.Widget>[_sectionHeader('Treatments')];
    for (var ti = 0; ti < data.treatments.length; ti++) {
      final tr = data.treatments[ti];
      widgets.add(
        pw.Container(
          color: _kAccentColor,
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            '${tr.code} - ${tr.name}',
            style: pw.TextStyle(
              fontSize: _kFontSizeBody,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
      );
      if (tr.components.isEmpty) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.all(_kSpaceSM),
            child: _italicNote('No components recorded'),
          ),
        );
      } else {
        widgets.add(
          pw.Table(
            border: pw.TableBorder.all(color: _kBorderColor, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(0.8),
              5: const pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _kHeaderBg),
                children: [
                  _tableHeaderCell('Product'),
                  _tableHeaderCell('Rate'),
                  _tableHeaderCell('Unit'),
                  _tableHeaderCell('Formulation'),
                  _tableHeaderCell('AI%', rightAlign: true),
                  _tableHeaderCell('Timing'),
                ],
              ),
              ...tr.components.asMap().entries.map((e) {
                final i = e.key;
                final c = e.value;
                final bg = i.isEven ? PdfColors.white : PdfColors.grey100;
                final aiStr = c.activeIngredientPct != null
                    ? '${c.activeIngredientPct}%'
                    : '-';
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    _tableCell(c.productName),
                    _tableCell(c.rate),
                    _tableCell(c.rateUnit),
                    _tableCell(c.formulationType),
                    _tableCell(aiStr, rightAlign: true),
                    _tableCell(c.applicationTiming),
                  ],
                );
              }),
            ],
          ),
        );
      }
      if (ti < data.treatments.length - 1) {
        widgets.add(pw.SizedBox(height: _kSpaceSM));
      }
    }
    return widgets;
  }

  List<pw.Widget> _buildPlotLayoutSection(StandaloneReportData data) {
    final sorted = List<PlotReportSummary>.from(data.plots)
      ..sort((a, b) {
        final ai = a.plotSortIndex ?? 999999;
        final bi = b.plotSortIndex ?? 999999;
        final c = ai.compareTo(bi);
        if (c != 0) return c;
        return a.plotId.compareTo(b.plotId);
      });

    return [
      _sectionHeader('Plot Layout'),
      pw.Table(
        border: pw.TableBorder.all(color: _kBorderColor, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(0.5),
          2: const pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _kHeaderBg),
            children: [
              _tableHeaderCell('Plot ID'),
              _tableHeaderCell('Rep', rightAlign: true),
              _tableHeaderCell('Treatment'),
            ],
          ),
          ...sorted.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value;
            final bg = i.isEven ? PdfColors.white : _kHeaderBg;
            return pw.TableRow(
              decoration: pw.BoxDecoration(color: bg),
              children: [
                _tableCell(p.plotId),
                _tableCell(p.rep != null ? '${p.rep}' : '-', rightAlign: true),
                _tableCell(p.treatmentCode),
              ],
            );
          }),
        ],
      ),
    ];
  }

  List<pw.Widget> _buildSeedingSection(
    StandaloneReportData data,
    DateFormat dateFormat,
  ) {
    final s = data.seeding;
    final widgets = <pw.Widget>[_sectionHeader('Seeding')];
    if (s == null) {
      widgets.add(_italicNote('Seeding not recorded'));
      return widgets;
    }

    final rows = <pw.Widget>[
      _kvRowIfHasValue('Seeding Date', dateFormat.format(s.seedingDate))!,
      _kvRow('Status', _capitalizeLifecycleStatus(s.status)),
    ];
    if (s.completedAt != null) {
      rows.add(_kvRow('Completed At', dateFormat.format(s.completedAt!)));
    }
    final op = _kvRowIfHasValue('Operator', s.operatorName);
    if (op != null) rows.add(op);
    final v = _kvRowIfHasValue('Variety', s.variety);
    if (v != null) rows.add(v);
    final lot = _kvRowIfHasValue('Seed Lot', s.seedLotNumber);
    if (lot != null) rows.add(lot);
    if (s.seedingRate != null) {
      final ru = s.seedingRateUnit ?? '';
      rows.add(_kvRow(
        'Seeding Rate',
        '${s.seedingRate} $ru'.trim(),
      ));
    }
    final pm = _kvRowIfHasValue('Planting Method', s.plantingMethod);
    if (pm != null) rows.add(pm);
    if (s.emergenceDate != null) {
      rows.add(_kvRow('Emergence Date', dateFormat.format(s.emergenceDate!)));
    }

    widgets.add(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rows,
      ),
    );
    return widgets;
  }

  List<pw.Widget> _buildApplicationsSection(
    StandaloneReportData data,
    DateFormat dateFormat,
  ) {
    final widgets = <pw.Widget>[_sectionHeader('Applications')];
    final ev = data.applications.events;
    if (ev.isEmpty) {
      widgets.add(_italicNote('No applications recorded'));
      return widgets;
    }
    final applied = ev.where((e) => e.status.toLowerCase() == 'applied').length;
    final pending = ev.where((e) => e.status.toLowerCase() == 'pending').length;
    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: _kSpaceSM),
        child: pw.Text(
          '${data.applications.count} application(s) - $applied applied, $pending pending',
          style: const pw.TextStyle(fontSize: _kFontSizeBody, color: _kTextSecondary),
        ),
      ),
    );
    widgets.add(
      pw.Table(
        border: pw.TableBorder.all(color: _kBorderColor, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(2),
          2: const pw.FlexColumnWidth(1),
          3: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _kHeaderBg),
            children: [
              _tableHeaderCell('Date'),
              _tableHeaderCell('Product'),
              _tableHeaderCell('Status'),
              _tableHeaderCell('Applied At'),
            ],
          ),
          ...ev.map((a) => pw.TableRow(
                children: [
                  _tableCell(dateFormat.format(a.applicationDate)),
                  _tableCell(a.productName),
                  _applicationStatusCell(a.status),
                  _tableCell(
                    a.appliedAt != null
                        ? dateFormat.format(a.appliedAt!)
                        : _emDashPlaceholder,
                  ),
                ],
              )),
        ],
      ),
    );
    return widgets;
  }

  pw.Widget _applicationStatusCell(String status) {
    final cap = _capitalizeLifecycleStatus(status);
    final isApplied = status.toLowerCase() == 'applied';
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        cap,
        style: pw.TextStyle(
          fontSize: _kFontSizeBody,
          color: isApplied ? _kAccentColor : _kTextSecondary,
          fontStyle:
              isApplied ? pw.FontStyle.normal : pw.FontStyle.italic,
        ),
      ),
    );
  }

  List<pw.Widget> _buildSessionsSection(StandaloneReportData data) {
    final widgets = <pw.Widget>[_sectionHeader('Sessions')];
    if (data.sessions.isEmpty) {
      widgets.add(_italicNote('No sessions recorded'));
      return widgets;
    }
    widgets.add(
      pw.Table(
        border: pw.TableBorder.all(color: _kBorderColor, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _kHeaderBg),
            children: [
              _tableHeaderCell('Name'),
              _tableHeaderCell('Date'),
              _tableHeaderCell('Status'),
            ],
          ),
          ...data.sessions.map(
            (s) => pw.TableRow(
              children: [
                _tableCell(s.name),
                _tableCell(s.sessionDateLocal),
                _sessionStatusCell(s.status),
              ],
            ),
          ),
        ],
      ),
    );
    return widgets;
  }

  pw.Widget _sessionStatusCell(String status) {
    final open = status.toLowerCase() != 'closed';
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        status,
        style: pw.TextStyle(
          fontSize: _kFontSizeBody,
          color: open ? _kTextSecondary : PdfColors.black,
          fontStyle: open ? pw.FontStyle.italic : pw.FontStyle.normal,
        ),
      ),
    );
  }

  List<pw.Widget> _buildAssessmentSection(StandaloneReportData data) {
    final w = <pw.Widget>[
      _sectionHeader('Assessment Results'),
    ];
    if (data.ratings.isEmpty) {
      w.add(_italicNote('No assessment results recorded'));
    } else {
      w.add(_buildResultsTable(data.ratings));
    }
    return w;
  }

  List<pw.Widget> _buildPhotosSection(StandaloneReportData data) {
    final c = data.photoCount.count;
    return [
      _sectionHeader('Photos'),
      pw.Text(
        'Photos captured: $c',
        style: const pw.TextStyle(fontSize: _kFontSizeBody),
      ),
      if (c == 0) _italicNote('No photos recorded'),
      pw.SizedBox(height: _kSpaceSM),
      pw.Text(
        'Note: Photo embedding available in a future report version',
        style: pw.TextStyle(
          fontSize: _kFontSizeCaption,
          color: _kTextSecondary,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    ];
  }

  pw.Widget _italicNote(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: _kFontSizeBody,
          fontStyle: pw.FontStyle.italic,
          color: _kTextSecondary,
        ),
      ),
    );
  }

  pw.Widget _pageHeader(StandaloneReportData data, pw.Context context) {
    if (context.pageNumber == 1) {
      return pw.SizedBox();
    }
    final pageOf = '${context.pagesCount}';
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                data.trial.name,
                style: const pw.TextStyle(
                  fontSize: _kFontSizeCaption,
                  color: _kTextSecondary,
                ),
              ),
            ),
            pw.Text(
              'Page ${context.pageNumber} of $pageOf',
              style: const pw.TextStyle(
                fontSize: _kFontSizeCaption,
                color: _kTextSecondary,
              ),
            ),
          ],
        ),
        pw.Container(height: 1, color: _kPrimaryColor),
      ],
    );
  }

  pw.Widget _pageFooter(
    StandaloneReportData data,
    pw.Context context,
    DateFormat dateFormat,
  ) {
    final today = dateFormat.format(DateTime.now());
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(height: 1, color: _kBorderColor),
        pw.SizedBox(height: _kSpaceXS),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated: $today',
              style: const pw.TextStyle(
                fontSize: _kFontSizeCaption,
                color: _kTextSecondary,
              ),
            ),
            pw.Text(
              'ARM Field Companion',
              style: const pw.TextStyle(
                fontSize: _kFontSizeCaption,
                color: _kTextSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _sectionHeader(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          decoration: const pw.BoxDecoration(
            color: _kHeaderBg,
            border: pw.Border(
              left: pw.BorderSide(color: _kPrimaryColor, width: 3),
            ),
          ),
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: _kFontSizeH1,
              fontWeight: pw.FontWeight.bold,
              color: _kPrimaryColor,
            ),
          ),
        ),
        pw.SizedBox(height: _kSpaceSM),
      ],
    );
  }

  pw.Widget _kvRow(String label, String? value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: _kFontSizeSmall,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              _cell(value),
              style: const pw.TextStyle(fontSize: _kFontSizeSmall),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget? _kvRowIfHasValue(String label, String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return _kvRow(label, value);
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

// ignore: unused_element
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
