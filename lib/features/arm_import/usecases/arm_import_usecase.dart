import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../../data/repositories/treatment_repository.dart';
import '../../trials/trial_repository.dart';
import '../data/arm_csv_parser.dart';
import '../data/arm_import_persistence_repository.dart';
import '../data/arm_import_report_builder.dart';
import '../data/arm_import_snapshot_service.dart';
import '../data/compatibility_profile_builder.dart';
import '../domain/models/arm_column_classification.dart';
import '../domain/models/parsed_arm_csv.dart';
import '../domain/results/arm_import_result.dart';

/// Orchestrates ARM CSV import: parse → snapshot/profile/report → persist (metadata only in this step).
class ArmImportUseCase {
  ArmImportUseCase(
    this._db,
    this._trialRepository,
    this._treatmentRepository,
    this._parser,
    this._snapshotService,
    this._profileBuilder,
    this._persistence,
    this._reportBuilder,
  );

  final AppDatabase _db;
  final TrialRepository _trialRepository;
  final TreatmentRepository _treatmentRepository;
  final ArmCsvParser _parser;
  final ArmImportSnapshotService _snapshotService;
  final CompatibilityProfileBuilder _profileBuilder;
  final ArmImportPersistenceRepository _persistence;
  final ArmImportReportBuilder _reportBuilder;

  /// Imports from raw [content] (full CSV text). [sourceFileName] is stored on snapshot / trial ARM fields.
  Future<ArmImportResult> execute(
    String content, {
    required String sourceFileName,
  }) async {
    try {
      if (content.isEmpty) {
        return ArmImportResult.failure('Import file is empty or invalid.');
      }

      List<List<dynamic>> table;
      try {
        table = const CsvToListConverter(eol: '\n').convert(content);
      } catch (_) {
        return ArmImportResult.failure('Import file is empty or invalid.');
      }

      if (table.isEmpty || table.first.isEmpty) {
        return ArmImportResult.failure('Import file is empty or invalid.');
      }

      final headers = table.first.map((c) => c.toString()).toList();
      final dataRows = table.skip(1).toList();

      final parsed = _parser.parse(
        headers: headers,
        rows: dataRows,
        sourceFileName: sourceFileName,
      );

      final snapshotPayload = _snapshotService.buildSnapshot(
        parsed: parsed,
        sourceFile: sourceFileName,
        rawCsv: content,
      );

      final profilePayload = _profileBuilder.build(
        parsed: parsed,
        snapshot: snapshotPayload,
      );

      final report = _reportBuilder.build(parsed);

      final trialName = _trialNameFromSourceFile(sourceFileName);

      late int trialId;

      await _db.transaction(() async {
        trialId = await _trialRepository.createTrial(
          name: trialName,
          workspaceType: 'efficacy',
        );

        final treatments = _collectUniqueTreatments(parsed);
        final treatmentCodeToId = <String, int>{};
        for (final treatment in treatments) {
          final id = await _treatmentRepository.insertTreatment(
            trialId: trialId,
            code: treatment.code,
            name: treatment.name,
            treatmentType: treatment.treatmentType,
          );
          treatmentCodeToId[treatment.code] = id;
        }
        assert(treatmentCodeToId.length == treatments.length);

        final snapshotId = await _persistence.insertImportSnapshot(
          snapshotPayload,
          trialId: trialId,
        );

        await _persistence.insertCompatibilityProfile(
          profilePayload,
          trialId: trialId,
          snapshotId: snapshotId,
        );

        await _persistence.markTrialAsArmLinked(
          trialId: trialId,
          sourceFile: sourceFileName,
          armVersion: snapshotPayload.armVersion,
        );
      });

      return ArmImportResult.success(
        trialId: trialId,
        confidence: parsed.importConfidence,
        warnings: report.warnings,
        unknownPatterns: parsed.unknownPatterns,
      );
    } on DuplicateTrialException catch (e) {
      return ArmImportResult.failure('ARM import failed: $e');
    } catch (e) {
      return ArmImportResult.failure('ARM import failed: $e');
    }
  }
}

String? _findHeaderByRole(
  List<ArmColumnClassification> columns,
  String role,
) {
  for (final c in columns) {
    if (c.identityRole == role) return c.header;
  }
  return null;
}

List<_ArmTreatmentRow> _collectUniqueTreatments(ParsedArmCsv parsed) {
  final trtHeader = _findHeaderByRole(parsed.columns, 'treatmentNumber');
  if (trtHeader == null) return [];

  final nameHeader = _findHeaderByRole(parsed.columns, 'treatmentName');
  final typeHeader = _findHeaderByRole(parsed.columns, 'type');

  final seen = <String>{};
  final result = <_ArmTreatmentRow>[];

  for (final row in parsed.dataRows) {
    final raw = row[trtHeader];
    if (raw == null || raw.trim().isEmpty) continue;
    final code = raw.trim();
    if (seen.contains(code)) continue;
    seen.add(code);

    final String name;
    if (nameHeader != null) {
      final n = row[nameHeader];
      if (n != null && n.trim().isNotEmpty) {
        name = n.trim();
      } else {
        name = 'Treatment $code';
      }
    } else {
      name = 'Treatment $code';
    }

    String? treatmentType;
    if (typeHeader != null) {
      final t = row[typeHeader];
      if (t != null && t.trim().isNotEmpty) {
        treatmentType = t.trim();
      }
    }

    result.add(_ArmTreatmentRow(
      code: code,
      name: name,
      treatmentType: treatmentType,
    ));
  }

  return result;
}

class _ArmTreatmentRow {
  const _ArmTreatmentRow({
    required this.code,
    required this.name,
    this.treatmentType,
  });

  final String code;
  final String name;
  final String? treatmentType;
}

String _trialNameFromSourceFile(String sourceFileName) {
  final base = p.basename(sourceFileName.trim());
  if (base.isEmpty) return 'ARM import';
  final dot = base.lastIndexOf('.');
  if (dot <= 0) return base;
  return base.substring(0, dot);
}
