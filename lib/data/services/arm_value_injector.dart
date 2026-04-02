import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/arm_rating_value.dart';
import '../../domain/models/arm_shell_import.dart';

/// Injects rating values into an existing ARM Rating Shell file (never creates a new workbook).
///
/// Uses sheet **Plot Data** (ARM-native shells).
class ArmValueInjector {
  ArmValueInjector(this.shellImport);

  final ArmShellImport shellImport;

  Future<File> inject(List<ArmRatingValue> values, String outputPath) async {
    assert(
      outputPath != shellImport.shellFilePath,
      'outputPath must differ from original shell path',
    );

    final bytes = await File(shellImport.shellFilePath).readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheets = excel.sheets;
    final sheet = sheets['Plot Data'];
    if (sheet == null) {
      throw StateError(
        'Plot Data sheet missing from shell file',
      );
    }

    final plotRowMap = <int, int>{
      for (final r in shellImport.plotRows) r.plotNumber: r.rowIndex,
    };
    final Map<String, int> columnMap;
    if (shellImport.assessmentColumns.isNotEmpty) {
      columnMap = {
        for (final c in shellImport.assessmentColumns)
          c.armColumnId: c.columnIndex,
      };
    } else {
      columnMap = {
        for (final v in values)
          v.armColumnId:
              v.armColumnId.codeUnitAt(0) - 'A'.codeUnitAt(0),
      };
    }

    for (final v in values) {
      final rowIdx = plotRowMap[v.plotNumber];
      final colIdx = columnMap[v.armColumnId];
      if (rowIdx == null) {
        debugPrint(
          'ArmValueInjector: plotNumber ${v.plotNumber} not in shell, skipping',
        );
        continue;
      }
      if (colIdx == null) {
        debugPrint(
          'ArmValueInjector: armColumnId ${v.armColumnId} not in shell, skipping',
        );
        continue;
      }
      assert(
        rowIdx >= 48,
        'Write blocked: rowIdx $rowIdx is in ARM descriptor zone (< 48)',
      );
      assert(
        colIdx >= 2,
        'Write blocked: colIdx $colIdx targets col A or B',
      );

      final numericValue = double.tryParse(v.value.trim());
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: rowIdx),
        numericValue != null
            ? DoubleCellValue(numericValue)
            : TextCellValue(v.value),
      );
    }

    final encoded = excel.encode();
    if (encoded == null) {
      throw StateError('excel.encode() returned null');
    }
    final outFile = File(outputPath);
    await outFile.writeAsBytes(encoded);
    return outFile;
  }
}
