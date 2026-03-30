import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../domain/enums/arm_column_kind.dart';
import '../domain/models/arm_column_classification.dart';
import '../domain/models/assessment_token.dart';
import '../domain/models/parsed_arm_csv.dart';
import '../domain/models/parsed_row_check_result.dart';
import '../domain/models/unknown_pattern_flag.dart';
import '../domain/enums/import_confidence.dart';

/// ARM CSV header parsing and classification.
class ArmCsvParser {
  static const Map<String, String> _identityHeaderRoles = {
    'Plot No.': 'plotNumber',
    'trt': 'treatmentNumber',
    'reps': 'rep',
  };

  static const Map<String, String> _treatmentHeaderRoles = {
    'Trial ID': 'trialId',
    'Treatment Name': 'treatmentName',
    'Form Conc': 'formConc',
    'Form Unit': 'formUnit',
    'Form Type': 'formType',
    ' Rate': 'rate',
    'Rate Unit': 'rateUnit',
    'Appl Code': 'applCode',
    ' Type': 'type',
  };

  List<ArmColumnClassification> classifyHeaders(List<String> headers) {
    return headers
        .mapIndexed((index, header) => classifyColumn(header, index))
        .toList();
  }

  ArmColumnClassification classifyColumn(String header, int index) {
    final identityRole = _identityHeaderRoles[header];
    if (identityRole != null) {
      return ArmColumnClassification(
        header: header,
        kind: ArmColumnKind.identity,
        index: index,
        identityRole: identityRole,
      );
    }

    final treatmentRole = _treatmentHeaderRoles[header];
    if (treatmentRole != null) {
      return ArmColumnClassification(
        header: header,
        kind: ArmColumnKind.treatment,
        index: index,
        identityRole: treatmentRole,
      );
    }

    final token = tryParseAssessmentToken(header);
    if (token != null) {
      return ArmColumnClassification(
        header: header,
        kind: ArmColumnKind.assessment,
        index: index,
        assessmentToken: token,
      );
    }

    return ArmColumnClassification(
      header: header,
      kind: ArmColumnKind.unknown,
      index: index,
    );
  }

  /// ARM assessment headers are whitespace-separated (no pipe delimiters in source CSV).
  /// [rawHeader] on the token is the original [header] string (untrimmed).
  AssessmentToken? tryParseAssessmentToken(String header) {
    final trimmed = header.trim();
    if (trimmed.isEmpty) return null;

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length < 2) return null;

    final unit = parts.last;
    final armCode = parts[parts.length - 2];

    String timingCode = '';
    DateTime? ratingDate;

    if (parts.length >= 3) {
      final timingToken = parts[parts.length - 3];
      final parsed = _tryParseArmDate(timingToken);
      if (parsed != null) {
        timingCode = timingToken;
        ratingDate = parsed;
      } else {
        timingCode = '';
        ratingDate = null;
      }
    }

    if (!RegExp(r'^[A-Z]{3,10}$').hasMatch(armCode)) return null;

    return AssessmentToken(
      rawHeader: header,
      armCode: armCode,
      timingCode: timingCode,
      unit: unit,
      ratingDate: ratingDate,
    );
  }

  DateTime? _tryParseArmDate(String value) {
    final segments = value.split('-');
    if (segments.length != 3) return null;

    const monthMap = <String, int>{
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };

    final day = int.tryParse(segments[0]);
    final month = monthMap[segments[1]];
    final yearShort = int.tryParse(segments[2]);
    if (day == null || month == null || yearShort == null) return null;

    try {
      return DateTime(2000 + yearShort, month, day);
    } catch (_) {
      return null;
    }
  }

  int? _parsePlotNumber(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  String? _parseNullableCell(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  List<Map<String, String?>> _parseDataRows(
    List<List<dynamic>> rows,
    List<ArmColumnClassification> columns,
  ) {
    final result = <Map<String, String?>>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowMap = <String, String?>{};

      for (final col in columns) {
        final value = col.index < row.length ? row[col.index] : null;
        final stringValue = value?.toString();
        rowMap[col.header] = _parseNullableCell(stringValue);
      }

      final plotCol =
          columns.firstWhereOrNull((c) => c.identityRole == 'plotNumber');
      if (plotCol != null && kDebugMode) {
        debugPrint(
          'Parser row $i plotId cell: "${rowMap[plotCol.header]}"',
        );
      }

      result.add(rowMap);
    }

    return result;
  }

  List<UnknownPatternFlag> _runIntegrityChecks(
    List<Map<String, String?>> rows,
    List<ArmColumnClassification> columns,
  ) {
    final flags = <UnknownPatternFlag>[];

    final plotHeader = columns
        .firstWhere((c) => c.identityRole == 'plotNumber',
            orElse: () => throw Exception('plotNumber column missing'))
        .header;

    final treatmentHeader = columns
        .firstWhere((c) => c.identityRole == 'treatmentNumber',
            orElse: () => throw Exception('treatmentNumber column missing'))
        .header;

    final repHeader = columns
        .firstWhere((c) => c.identityRole == 'rep',
            orElse: () => throw Exception('rep column missing'))
        .header;

    final seenPlots = <int>{};

    for (final row in rows) {
      final plotRaw = row[plotHeader];
      final plot = _parsePlotNumber(plotRaw);

      if (plot == null) {
        flags.add(UnknownPatternFlag(
          type: 'missing-or-invalid-plot-number',
          severity: PatternSeverity.high,
          affectsExport: true,
          rawValue: plotRaw ?? '',
        ));
      } else {
        if (seenPlots.contains(plot)) {
          flags.add(UnknownPatternFlag(
            type: 'duplicate-plot-number',
            severity: PatternSeverity.high,
            affectsExport: true,
            rawValue: plot.toString(),
          ));
        }
        seenPlots.add(plot);
      }

      final treatmentRaw = row[treatmentHeader];
      final treatment = _parsePlotNumber(treatmentRaw);

      if (treatment == null) {
        flags.add(UnknownPatternFlag(
          type: 'missing-treatment-number',
          severity: PatternSeverity.high,
          affectsExport: true,
          rawValue: treatmentRaw ?? '',
        ));
      }

      final repRaw = row[repHeader];
      final rep = _parsePlotNumber(repRaw);

      if (rep == null) {
        flags.add(UnknownPatternFlag(
          type: 'missing-rep',
          severity: PatternSeverity.medium,
          affectsExport: true,
          rawValue: repRaw ?? '',
        ));
      }
    }

    return flags;
  }

  ParsedRowCheckResult verifyRows({
    required List<List<dynamic>> rows,
    required List<String> headers,
  }) {
    final columns = classifyHeaders(headers);
    final parsedRows = _parseDataRows(rows, columns);
    final flags = _runIntegrityChecks(parsedRows, columns);

    return ParsedRowCheckResult(
      parsedRows: parsedRows,
      flags: flags,
      rowCount: parsedRows.length,
    );
  }

  bool _detectSparseData(
    List<Map<String, String?>> rows,
    List<ArmColumnClassification> columns,
  ) {
    final assessmentHeaders = columns
        .where((c) => c.kind == ArmColumnKind.assessment)
        .map((c) => c.header)
        .toList(growable: false);

    for (final row in rows) {
      for (final header in assessmentHeaders) {
        if (row[header] == null) return true;
      }
    }

    return false;
  }

  bool _detectRepeatedAssessmentKeys(
    List<AssessmentToken> assessments,
    List<UnknownPatternFlag> flags,
  ) {
    final seen = <String>{};
    var repeated = false;

    for (final token in assessments) {
      if (!seen.add(token.assessmentKey)) {
        repeated = true;
        flags.add(UnknownPatternFlag(
          type: 'repeated-assessment-key',
          severity: PatternSeverity.high,
          affectsExport: true,
          rawValue: token.assessmentKey,
        ));
      }
    }

    return repeated;
  }

  ImportConfidence _scoreConfidence(
    List<UnknownPatternFlag> flags,
    List<ArmColumnClassification> columns,
  ) {
    final hasIdentityFields = columns.any((c) => c.identityRole == 'plotNumber') &&
        columns.any((c) => c.identityRole == 'treatmentNumber') &&
        columns.any((c) => c.identityRole == 'rep');

    if (!hasIdentityFields) return ImportConfidence.blocked;

    final hasExportBlocking = flags.any(
      (f) => f.affectsExport && f.severity == PatternSeverity.high,
    );
    if (hasExportBlocking) return ImportConfidence.blocked;

    final hasHighFlags = flags.any((f) => f.severity == PatternSeverity.high);
    if (hasHighFlags) return ImportConfidence.low;

    final hasMediumFlags = flags.any((f) => f.severity == PatternSeverity.medium);
    if (hasMediumFlags) return ImportConfidence.medium;

    final hasAnyExportConcern = flags.any((f) => f.affectsExport);
    if (hasAnyExportConcern) return ImportConfidence.medium;

    return ImportConfidence.high;
  }

  ParsedArmCsv parse({
    required List<String> headers,
    required List<List<dynamic>> rows,
    required String sourceFileName,
  }) {
    final columns = classifyHeaders(headers);
    final parsedRows = _parseDataRows(rows, columns);
    final hasIdentityColumns = columns.any((c) => c.identityRole == 'plotNumber') &&
        columns.any((c) => c.identityRole == 'treatmentNumber') &&
        columns.any((c) => c.identityRole == 'rep');
    final flags = hasIdentityColumns
        ? _runIntegrityChecks(parsedRows, columns)
        : <UnknownPatternFlag>[];
    final assessments = columns
        .where((c) => c.assessmentToken != null)
        .map((c) => c.assessmentToken!)
        .toList(growable: false);

    final hasSparseData = _detectSparseData(parsedRows, columns);
    final hasRepeatedCodes =
        _detectRepeatedAssessmentKeys(assessments, flags);
    final confidence = _scoreConfidence(flags, columns);

    return ParsedArmCsv(
      sourceFileName: sourceFileName,
      sourceRoute: 'arm_csv_v1_unvalidated',
      armVersionHint: null,
      rawHeaders: List<String>.from(headers),
      columnOrder: List<String>.from(headers),
      columns: columns,
      dataRows: parsedRows,
      assessments: assessments,
      unknownPatterns: flags,
      hasSubsamples: false,
      hasMultiApplication: false,
      hasSparseData: hasSparseData,
      hasRepeatedCodes: hasRepeatedCodes,
      importConfidence: confidence,
    );
  }
}
