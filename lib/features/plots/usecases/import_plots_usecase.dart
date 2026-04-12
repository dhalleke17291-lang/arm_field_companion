import 'package:drift/drift.dart';
import '../plot_repository.dart';
import '../../trials/trial_repository.dart';
import '../../../core/database/app_database.dart';
import '../../../core/protocol_edit_blocked_exception.dart';
import '../../../core/trial_state.dart';

/// Charter PART 16: Import status categories for transparency.
enum ImportStatusCategory {
  matchedSuccessfully,
  autoHandled,
  needsUserReview,
  mustFixBeforeImport,
}

/// Result of the Import Review step (Charter PART 16).
class ImportReviewResult {
  final int matchedSuccessfullyCount;
  final List<String> autoHandledMessages;
  final List<String> needsUserReviewItems;
  final List<String> mustFixErrors;
  final List<Map<String, dynamic>>? normalizedRows;

  const ImportReviewResult({
    required this.matchedSuccessfullyCount,
    this.autoHandledMessages = const [],
    this.needsUserReviewItems = const [],
    this.mustFixErrors = const [],
    this.normalizedRows,
  });

  bool get canProceed =>
      mustFixErrors.isEmpty &&
      normalizedRows != null &&
      normalizedRows!.isNotEmpty;
}

class ImportPlotsUseCase {
  ImportPlotsUseCase(
    this._db,
    this._plotRepository,
    this._trialRepository,
  );

  final AppDatabase _db;
  final PlotRepository _plotRepository;
  final TrialRepository _trialRepository;

  /// Optional column aliases for plot_id (Charter: auto-handled mapping).
  static const Map<String, String> _plotIdAliases = {
    'plot_id': 'plot_id',
    'plot': 'plot_id',
    'Plot': 'plot_id',
    'Plot ID': 'plot_id',
    'plot id': 'plot_id',
  };

  /// Structural scan + mapping + validation. Returns review for user approval.
  ImportReviewResult analyzeForImport(ImportPlotsInput input) {
    final autoHandled = <String>[];
    final mustFix = <String>[];
    final needsReview = <String>[];

    if (input.rows.isEmpty) {
      mustFix.add('No rows found in CSV');
      return ImportReviewResult(
        matchedSuccessfullyCount: 0,
        mustFixErrors: mustFix,
      );
    }

    final firstRow = input.rows.first;
    final headers = firstRow.keys.map((k) => k.toString().trim()).toList();
    String? plotIdHeader;
    for (final h in headers) {
      final canonical = _plotIdAliases[h];
      if (canonical != null) {
        if (plotIdHeader != null) {
          needsReview.add(
              "Multiple columns may map to plot_id: '$plotIdHeader' and '$h'. Confirm which to use.");
        }
        plotIdHeader ??= h;
      }
    }
    if (plotIdHeader == null) {
      mustFix.add(
          "Required column 'plot_id' (or alias: Plot, plot) missing from CSV");
      return ImportReviewResult(
        matchedSuccessfullyCount: 0,
        mustFixErrors: mustFix,
      );
    }
    if (plotIdHeader != 'plot_id') {
      autoHandled.add("Column '$plotIdHeader' mapped to plot_id");
    }

    final normalizedRows = <Map<String, dynamic>>[];
    final seenPlotIds = <String>{};
    int matchedCount = 0;

    for (int i = 0; i < input.rows.length; i++) {
      final row = input.rows[i];
      final rowNum = i + 2;
      final plotIdVal = row[plotIdHeader]?.toString().trim() ?? '';
      final normalized = <String, dynamic>{
        'plot_id': plotIdVal,
        'rep': row['rep'],
        'row': row['row'],
        'column': row['column'],
        'plot_sort_index': row['plot_sort_index'],
      };

      final plotId = plotIdVal.isEmpty ? null : plotIdVal;
      if (plotId == null || plotId.isEmpty) {
        mustFix.add('Row $rowNum: missing plot_id');
        continue;
      }
      if (seenPlotIds.contains(plotId)) {
        mustFix.add('Row $rowNum: duplicate plot_id "$plotId"');
        continue;
      }
      seenPlotIds.add(plotId);

      if (row['rep'] != null) {
        final repVal = int.tryParse(row['rep'].toString());
        if (repVal == null) {
          autoHandled.add('Row $rowNum: invalid rep "${row['rep']}", ignored');
        }
      }
      normalizedRows.add(normalized);
      matchedCount++;
    }

    if (matchedCount == 0 && mustFix.isEmpty) {
      mustFix.add('No valid rows to import after validation');
    }

    return ImportReviewResult(
      matchedSuccessfullyCount: matchedCount,
      autoHandledMessages: autoHandled,
      needsUserReviewItems: needsReview,
      mustFixErrors: mustFix,
      normalizedRows:
          mustFix.isEmpty && matchedCount > 0 ? normalizedRows : null,
    );
  }

  /// Protocol Model Integration — run after user approval. Uses rows from review (canonical keys).
  Future<ImportPlotsResult> execute(ImportPlotsInput input) async {
    final trial = await _trialRepository.getTrialById(input.trialId);
    if (trial == null) {
      return ImportPlotsResult.failure('Trial not found.');
    }
    final hasData = await trialHasAnySessionData(_db, input.trialId);
    if (!canEditTrialStructure(trial, hasSessionData: hasData)) {
      return ImportPlotsResult.failure(
        structureEditBlockedMessage(trial, hasSessionData: hasData),
      );
    }

    final warnings = <String>[];
    final validPlots = <PlotsCompanion>[];
    final seenPlotIds = <String>{};

    if (input.rows.isEmpty) {
      return ImportPlotsResult.failure('No rows found in CSV');
    }

    final firstRow = input.rows.first;
    if (!firstRow.containsKey('plot_id')) {
      return ImportPlotsResult.failure(
          'Required column "plot_id" missing from CSV');
    }

    for (int i = 0; i < input.rows.length; i++) {
      final row = input.rows[i];
      final rowNum = i + 2;

      final plotId = row['plot_id']?.toString().trim();
      if (plotId == null || plotId.isEmpty) {
        warnings.add('Row $rowNum: missing plot_id, skipped');
        continue;
      }
      if (seenPlotIds.contains(plotId)) {
        warnings.add('Row $rowNum: duplicate plot_id "$plotId", skipped');
        continue;
      }
      seenPlotIds.add(plotId);

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

    if (validPlots.isEmpty) {
      return ImportPlotsResult.failure(
          'No valid rows found after processing CSV');
    }

    try {
      await _plotRepository.insertPlotsBulk(validPlots);

      return ImportPlotsResult.success(
        rowsImported: validPlots.length,
        rowsSkipped: input.rows.length - validPlots.length,
        warnings: warnings,
      );
    } on ProtocolEditBlockedException catch (e) {
      return ImportPlotsResult.failure(e.message);
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
