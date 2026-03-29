import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../domain/enums/arm_column_kind.dart';
import '../domain/models/arm_column_classification.dart';
import '../domain/models/import_snapshot_payload.dart';
import '../domain/models/parsed_arm_csv.dart';

String _computeChecksum(String rawCsv) {
  final bytes = utf8.encode(rawCsv);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

/// Builds a serializable snapshot from [ParsedArmCsv] (no persistence).
class ArmImportSnapshotService {
  ImportSnapshotPayload buildSnapshot({
    required ParsedArmCsv parsed,
    required String sourceFile,
    required String rawCsv,
  }) {
    final rawFileChecksum = _computeChecksum(rawCsv);

    final columns = parsed.columns;

    final identityColumns = columns
        .where((c) => c.kind == ArmColumnKind.identity)
        .map((c) => c.header)
        .toList(growable: false);

    final assessmentTokens = parsed.assessments.map((a) {
      return <String, dynamic>{
        'rawHeader': a.rawHeader,
        'armCode': a.armCode,
        'timingCode': a.timingCode,
        'unit': a.unit,
        'ratingDate': a.ratingDate?.toUtc().toIso8601String(),
        'assessmentKey': a.assessmentKey,
      };
    }).toList(growable: false);

    final treatmentTokens = columns
        .where((c) => c.kind == ArmColumnKind.treatment)
        .map((c) => <String, dynamic>{
              'header': c.header,
              'role': c.identityRole ?? '',
            })
        .toList(growable: false);

    final plotHeader = _headerForRole(columns, 'plotNumber');
    final treatmentHeader = _headerForRole(columns, 'treatmentNumber');
    final repHeader = _headerForRole(columns, 'rep');

    final plotTokens = <Map<String, dynamic>>[];
    final seenPlotKeys = <String>{};

    if (plotHeader != null && treatmentHeader != null && repHeader != null) {
      for (final row in parsed.dataRows) {
        final plotRaw = row[plotHeader];
        final trtRaw = row[treatmentHeader];
        final repRaw = row[repHeader];
        if (plotRaw == null || trtRaw == null || repRaw == null) continue;

        final plotKey = plotRaw;
        if (seenPlotKeys.contains(plotKey)) continue;
        seenPlotKeys.add(plotKey);

        plotTokens.add(<String, dynamic>{
          'plotNumber': plotRaw,
          'treatmentNumber': trtRaw,
          'rep': repRaw,
        });
      }
    }

    final unknownPatterns = parsed.unknownPatterns.map((f) {
      return <String, dynamic>{
        'type': f.type,
        'severity': f.severity.name,
        'affectsExport': f.affectsExport,
        'rawValue': f.rawValue,
      };
    }).toList(growable: false);

    final treatmentNumberHeader = _headerForRole(columns, 'treatmentNumber');
    final uniqueTreatments = <String>{};
    if (treatmentNumberHeader != null) {
      for (final row in parsed.dataRows) {
        final v = row[treatmentNumberHeader];
        if (v != null && v.trim().isNotEmpty) {
          uniqueTreatments.add(v.trim());
        }
      }
    }

    return ImportSnapshotPayload(
      sourceFile: sourceFile,
      sourceRoute: parsed.sourceRoute,
      armVersion: parsed.armVersionHint,
      rawHeaders: List<String>.from(parsed.rawHeaders),
      columnOrder: List<String>.from(parsed.columnOrder),
      rowTypePatterns: const [],
      plotCount: plotTokens.length,
      treatmentCount: uniqueTreatments.length,
      assessmentCount: parsed.assessments.length,
      identityColumns: identityColumns,
      assessmentTokens: assessmentTokens,
      treatmentTokens: treatmentTokens,
      plotTokens: plotTokens,
      unknownPatterns: unknownPatterns,
      hasSubsamples: parsed.hasSubsamples,
      hasMultiApplication: parsed.hasMultiApplication,
      hasSparseData: parsed.hasSparseData,
      hasRepeatedCodes: parsed.hasRepeatedCodes,
      rawFileChecksum: rawFileChecksum,
    );
  }

  String? _headerForRole(
    List<ArmColumnClassification> columns,
    String role,
  ) {
    for (final c in columns) {
      if (c.identityRole == role) return c.header;
    }
    return null;
  }
}
