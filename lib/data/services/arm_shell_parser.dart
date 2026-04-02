import 'dart:io';

import 'package:excel/excel.dart';

import '../../domain/models/arm_column_map.dart';
import '../../domain/models/arm_plot_row.dart';
import '../../domain/models/arm_shell_import.dart';

/// Reads an ARM Excel Rating Shell and extracts trial metadata, columns, and plot rows.
///
/// Supports sheet name **Ratings** (app export) or **Plot Data** (legacy / ARM-native).
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
          columnLetter: _colIndexToLetter(colIdx),
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

  String _colIndexToLetter(int colIdx) {
    return String.fromCharCode('A'.codeUnitAt(0) + colIdx);
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
