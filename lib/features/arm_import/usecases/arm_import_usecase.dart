import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../trials/trial_repository.dart';
import '../data/arm_csv_parser.dart';
import '../data/arm_import_persistence_repository.dart';
import '../data/arm_import_report_builder.dart';
import '../data/arm_import_snapshot_service.dart';
import '../data/compatibility_profile_builder.dart';
import '../domain/results/arm_import_result.dart';

/// Orchestrates ARM CSV import: parse → snapshot/profile/report → persist (metadata only in this step).
class ArmImportUseCase {
  ArmImportUseCase(
    this._db,
    this._trialRepository,
    this._parser,
    this._snapshotService,
    this._profileBuilder,
    this._persistence,
    this._reportBuilder,
  );

  final AppDatabase _db;
  final TrialRepository _trialRepository;
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

String _trialNameFromSourceFile(String sourceFileName) {
  final base = p.basename(sourceFileName.trim());
  if (base.isEmpty) return 'ARM import';
  final dot = base.lastIndexOf('.');
  if (dot <= 0) return base;
  return base.substring(0, dot);
}
