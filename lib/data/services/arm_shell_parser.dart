import 'dart:io';

import 'package:excel/excel.dart';

import '../../core/excel_column_letters.dart';
import '../../domain/models/arm_column_map.dart';
import '../../domain/models/arm_plot_row.dart';
import '../../domain/models/arm_shell_import.dart';

/// Reads an ARM Excel Rating Shell and extracts trial metadata, columns, and plot rows.
///
/// Only the **Plot Data** sheet is implemented; a **Ratings** sheet name is not read.
///
/// ARM Rating Shell layout contract (ARM 2025/2026):
/// Sheet: "Plot Data" (exact name)
///
/// Metadata:
///   r=1,c=2: Trial title
///   r=2,c=2: Trial ID
///   r=3,c=2: Cooperator
///   r=4,c=2: Crop
///
/// Assessment columns (c=2 onward, until empty ID cell):
///   r=7:  ARM Column ID (identity anchor)
///   r=15: Rating date
///   r=17: SE Name
///   r=20: Rating type
///   r=21: Rating unit
///   r=29: Crop stage major
///   r=41: Rating timing
///   r=46: Num subsamples
///
/// Plot data:
///   Marker: "041TRT" in c=0 (scanned from r=7 downward)
///   Data rows: headerRow+1 onward
///   c=0: Treatment number (int)
///   c=1: Plot number (int)
///   Block number: derived as plotNumber ~/ 100
///
/// If ARM changes this layout, update the row indices above
/// and the corresponding constants in parse().
///
/// Row and column indices are **0-based** ([CellIndex.indexByColumnRow]).
class ArmShellParser {
  ArmShellParser(this.shellFilePath);

  final String shellFilePath;

  Future<ArmShellImport> parse() async {
    final bytes = await File(shellFilePath).readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheets = excel.sheets;
    final sheet = sheets['Plot Data'];
    if (sheet == null) {
      throw ArgumentError(
        'Rating shell sheet not found — expected "Plot Data" (ARM Rating Shell format).',
      );
    }

    final title = _cellString(sheet, 1, 2) ?? '';
    final trialId = _cellString(sheet, 2, 2) ?? '';
    final cooperator = _cellString(sheet, 3, 2);
    final crop = _cellString(sheet, 4, 2);

    final assessmentColumns = <ArmColumnMap>[];
    final colLimit = sheet.maxColumns > 0 ? sheet.maxColumns : 512;
    for (var colIdx = 2; colIdx < colLimit; colIdx++) {
      final rawId = _cellString(sheet, 7, colIdx);
      if (rawId == null || rawId.trim().isEmpty) {
        break;
      }
      final armColumnId = rawId.trim();
      final subs = _cellString(sheet, 46, colIdx);
      assessmentColumns.add(
        ArmColumnMap(
          armColumnId: armColumnId,
          columnLetter: columnIndexToLettersZeroBased(colIdx),
          columnIndex: colIdx,
          ratingDate: _cellString(sheet, 15, colIdx),
          seName: _cellString(sheet, 17, colIdx),
          ratingType: _cellString(sheet, 20, colIdx),
          ratingUnit: _cellString(sheet, 21, colIdx),
          cropStageMaj: _cellString(sheet, 29, colIdx),
          ratingTiming: _cellString(sheet, 41, colIdx),
          numSubsamples: int.tryParse((subs ?? '').trim()),
        ),
      );
    }

    var headerRowIdx = -1;
    for (var rowIdx = 7; rowIdx < sheet.maxRows; rowIdx++) {
      final cell = _cellString(sheet, rowIdx, 0);
      if (cell != null && cell.trim() == '041TRT') {
        headerRowIdx = rowIdx;
        break;
      }
    }
    if (headerRowIdx < 0) {
      throw ArgumentError(
        'ARM Rating Shell invalid: 041TRT header row not found. '
        'Verify this file was exported from ARM.',
      );
    }

    final plotRows = <ArmPlotRow>[];
    for (var rowIdx = headerRowIdx + 1; rowIdx < sheet.maxRows; rowIdx++) {
      final trt = _cellInt(sheet, rowIdx, 0);
      if (trt == null) {
        break;
      }
      final plot = _cellInt(sheet, rowIdx, 1);
      if (plot == null) {
        break;
      }
      plotRows.add(
        ArmPlotRow(
          trtNumber: trt,
          plotNumber: plot,
          blockNumber: plot ~/ 100,
          rowIndex: rowIdx,
        ),
      );
    }

    return ArmShellImport(
      title: title,
      trialId: trialId,
      cooperator: cooperator,
      crop: crop,
      assessmentColumns: assessmentColumns,
      plotRows: plotRows,
      shellFilePath: shellFilePath,
    );
  }

  String? _cellString(Sheet sheet, int rowIdx, int colIdx) {
    final val = sheet
        .cell(
          CellIndex.indexByColumnRow(
            columnIndex: colIdx,
            rowIndex: rowIdx,
          ),
        )
        .value;
    return switch (val) {
      TextCellValue(:final value) => _excelTextSpanString(value),
      IntCellValue(:final value) => value.toString(),
      DoubleCellValue(:final value) => value.toString(),
      BoolCellValue(:final value) => value.toString(),
      null => null,
      _ => val.toString(),
    };
  }

  String _excelTextSpanString(TextSpan span) {
    final t = span.text;
    if (t != null && t.isNotEmpty) {
      return t;
    }
    final children = span.children;
    if (children != null && children.isNotEmpty) {
      return children.map(_excelTextSpanString).join();
    }
    return '';
  }

  int? _cellInt(Sheet sheet, int rowIdx, int colIdx) {
    final val = sheet
        .cell(
          CellIndex.indexByColumnRow(
            columnIndex: colIdx,
            rowIndex: rowIdx,
          ),
        )
        .value;
    return switch (val) {
      IntCellValue(:final value) => value,
      DoubleCellValue(:final value) => value.toInt(),
      TextCellValue(:final value) => int.tryParse(_excelTextSpanString(value).trim()),
      _ => null,
    };
  }
}
