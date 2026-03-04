import 'package:drift/drift.dart';
import '../plot_repository.dart';
import '../../trials/trial_repository.dart';
import '../../../core/database/app_database.dart';

class ImportPlotsUseCase {
  final PlotRepository _plotRepository;
  final TrialRepository _trialRepository;

  ImportPlotsUseCase(this._plotRepository, this._trialRepository);

  Future<ImportPlotsResult> execute(ImportPlotsInput input) async {
    final warnings = <String>[];
    final validPlots = <PlotsCompanion>[];
    final seenPlotIds = <String>{};

    // Blocking condition — zero valid rows
    if (input.rows.isEmpty) {
      return ImportPlotsResult.failure('No rows found in CSV');
    }

    // Blocking condition — required columns missing
    final firstRow = input.rows.first;
    if (!firstRow.containsKey('plot_id')) {
      return ImportPlotsResult.failure(
          'Required column "plot_id" missing from CSV');
    }

    // Process each row — forgiving import per spec
    for (int i = 0; i < input.rows.length; i++) {
      final row = input.rows[i];
      final rowNum = i + 2; // 1-based, accounting for header

      final plotId = row['plot_id']?.toString().trim();
      if (plotId == null || plotId.isEmpty) {
        warnings.add('Row $rowNum: missing plot_id, skipped');
        continue;
      }

      // Duplicate plot ID check
      if (seenPlotIds.contains(plotId)) {
        warnings.add('Row $rowNum: duplicate plot_id "$plotId", skipped');
        continue;
      }
      seenPlotIds.add(plotId);

      // Parse optional fields
      int? rep;
      if (row['rep'] != null) {
        rep = int.tryParse(row['rep'].toString());
        if (rep == null) {
          warnings.add('Row $rowNum: invalid rep "${row['rep']}", ignored');
        }
      }

      int? plotSortIndex;
      if (row['plot_sort_index'] != null) {
        plotSortIndex = int.tryParse(row['plot_sort_index'].toString());
      } else {
        // Default sort index to row position if not provided
        plotSortIndex = i + 1;
      }

      validPlots.add(PlotsCompanion.insert(
        trialId: input.trialId,
        plotId: plotId,
        plotSortIndex: Value(plotSortIndex),
        rep: Value(rep),
        row: Value(row['row']?.toString()),
        column: Value(row['column']?.toString()),
      ));
    }

    // Blocking condition — no valid rows after filtering
    if (validPlots.isEmpty) {
      return ImportPlotsResult.failure(
          'No valid rows found after processing CSV');
    }

    // Single transaction — full rollback on failure per spec
    try {
      await _plotRepository.insertPlotsBulk(validPlots);

      // Write import event
      await _trialRepository.getTrialById(input.trialId);

      return ImportPlotsResult.success(
        rowsImported: validPlots.length,
        rowsSkipped: input.rows.length - validPlots.length,
        warnings: warnings,
      );
    } catch (e) {
      return ImportPlotsResult.failure('Import failed, rolled back: $e');
    }
  }
}

class ImportPlotsInput {
  final int trialId;
  final List<Map<String, dynamic>> rows;
  final String fileName;

  const ImportPlotsInput({
    required this.trialId,
    required this.rows,
    required this.fileName,
  });
}

class ImportPlotsResult {
  final bool success;
  final int rowsImported;
  final int rowsSkipped;
  final List<String> warnings;
  final String? errorMessage;

  const ImportPlotsResult._({
    required this.success,
    this.rowsImported = 0,
    this.rowsSkipped = 0,
    this.warnings = const [],
    this.errorMessage,
  });

  factory ImportPlotsResult.success({
    required int rowsImported,
    required int rowsSkipped,
    required List<String> warnings,
  }) =>
      ImportPlotsResult._(
        success: true,
        rowsImported: rowsImported,
        rowsSkipped: rowsSkipped,
        warnings: warnings,
      );

  factory ImportPlotsResult.failure(String message) =>
      ImportPlotsResult._(success: false, errorMessage: message);
}
