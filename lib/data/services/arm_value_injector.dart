import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

import '../../core/excel_column_letters.dart';
import '../../domain/models/arm_rating_value.dart';
import '../../domain/models/arm_shell_import.dart';

/// Result of an injection operation.
class ArmInjectionResult {
  final File file;
  final int cellsWritten;
  final List<String> skippedReasons;

  ArmInjectionResult({
    required this.file,
    required this.cellsWritten,
    this.skippedReasons = const [],
  });

  bool get hasSkips => skippedReasons.isNotEmpty;
}

/// Injects rating values into an existing ARM Rating Shell file (never creates a new workbook).
///
/// Uses sheet **Plot Data** (ARM-native shells).
///
/// Updates only the Plot Data worksheet XML inside the xlsx zip; all other parts
/// are copied byte-for-byte to avoid [excel] decode/encode corruption on other sheets.
class ArmValueInjector {
  ArmValueInjector(this.shellImport);

  final ArmShellImport shellImport;

  Future<ArmInjectionResult> inject(List<ArmRatingValue> values, String outputPath) async {
    if (outputPath == shellImport.shellFilePath) {
      throw StateError(
        'outputPath must differ from original shell path (would overwrite source).',
      );
    }

    final skippedReasons = <String>[];
    var cellsWritten = 0;

    final shellBytes = await File(shellImport.shellFilePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(shellBytes);
    final plotDataPath = _resolvePlotDataWorksheetPath(archive);
    if (plotDataPath == null) {
      throw StateError(
        'Plot Data sheet missing from shell file',
      );
    }
    final plotEntry = archive.findFile(plotDataPath);
    if (plotEntry == null) {
      throw StateError('Worksheet entry missing: $plotDataPath');
    }

    final plotXml = utf8.decode(plotEntry.content as List<int>);
    final plotDoc = XmlDocument.parse(plotXml);
    final worksheets = plotDoc.findAllElements('worksheet').toList();
    if (worksheets.isEmpty) {
      throw StateError('worksheet root missing in Plot Data XML');
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
      columnMap = {};
      for (final v in values) {
        final idx = columnLettersToIndexZeroBased(v.armColumnId);
        if (idx != null) {
          columnMap[v.armColumnId] = idx;
        }
      }
    }

    for (final v in values) {
      final rowIdx = plotRowMap[v.plotNumber];
      final colIdx = columnMap[v.armColumnId];
      if (rowIdx == null) {
        skippedReasons.add(
          'Plot ${v.plotNumber} not found in shell — skipped',
        );
        continue;
      }
      if (colIdx == null) {
        skippedReasons.add(
          'Column ${v.armColumnId} not found in shell — skipped',
        );
        continue;
      }
      if (rowIdx < 48 || colIdx < 2) {
        skippedReasons.add(
          'Plot ${v.plotNumber} column ${v.armColumnId}: bounds violation '
          '(row=$rowIdx col=$colIdx) — skipped',
        );
        continue;
      }

      final trimmed = v.value.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final numVal = double.tryParse(trimmed);
      final isNumeric = numVal != null;
      final cellValue = isNumeric ? numVal.toString() : v.value;
      _writeCell(
        plotDoc,
        rowIdx,
        colIdx,
        cellValue,
        isNumeric,
      );
      cellsWritten++;
    }

    final updatedBytes = utf8.encode(
      plotDoc.toXmlString(pretty: false),
    );

    final newArchive = Archive();
    for (final file in archive.files) {
      if (!file.isFile) continue;
      if (file.name == plotDataPath) {
        newArchive.addFile(
          ArchiveFile(file.name, updatedBytes.length, updatedBytes),
        );
      } else {
        final content = List<int>.from(file.content as List<int>);
        newArchive.addFile(ArchiveFile(file.name, content.length, content));
      }
    }

    final encoded = ZipEncoder().encode(newArchive);
    if (encoded == null) {
      throw StateError('zip encode returned null');
    }
    final outFile = File(outputPath);
    await outFile.writeAsBytes(encoded);
    return ArmInjectionResult(
      file: outFile,
      cellsWritten: cellsWritten,
      skippedReasons: skippedReasons,
    );
  }

  /// Resolves `xl/workbook.xml` + `xl/_rels/workbook.xml.rels` → Plot Data worksheet path.
  String? _resolvePlotDataWorksheetPath(Archive archive) {
    final wbFile = archive.findFile('xl/workbook.xml');
    if (wbFile == null) return null;
    final wbDoc = XmlDocument.parse(utf8.decode(wbFile.content as List<int>));

    XmlElement? plotSheet;
    for (final sheet in wbDoc.findAllElements('sheet')) {
      if (sheet.getAttribute('name') == 'Plot Data') {
        plotSheet = sheet;
        break;
      }
    }
    if (plotSheet == null) return null;

    String? rid;
    for (final a in plotSheet.attributes) {
      if (a.name.local == 'id' && a.name.prefix == 'r') {
        rid = a.value;
        break;
      }
    }
    if (rid == null) return null;

    final relsFile = archive.findFile('xl/_rels/workbook.xml.rels');
    if (relsFile == null) return null;
    final relsDoc =
        XmlDocument.parse(utf8.decode(relsFile.content as List<int>));

    for (final rel in relsDoc.findAllElements('Relationship')) {
      if (rel.getAttribute('Id') == rid) {
        final target = rel.getAttribute('Target');
        if (target == null) return null;
        final t = target.replaceAll('\\', '/');
        if (t.startsWith('xl/')) return t;
        return 'xl/$t';
      }
    }
    return null;
  }

  void _writeCell(
    XmlDocument doc,
    int rowIdx0,
    int colIdx,
    String value,
    bool isNumeric,
  ) {
    if (value.trim().isEmpty) {
      return;
    }

    final rowNumStr = '${rowIdx0 + 1}';
    final cellRef = _cellRef(colIdx, rowIdx0);

    final sheetDataList = doc.findAllElements('sheetData').toList();
    if (sheetDataList.isEmpty) {
      debugPrint('ArmValueInjector: sheetData missing, skipping $cellRef');
      return;
    }
    final sheetData = sheetDataList.first;

    XmlElement? rowEl;
    for (final r in sheetData.childElements) {
      if (r.name.local == 'row' && r.getAttribute('r') == rowNumStr) {
        rowEl = r;
        break;
      }
    }
    if (rowEl == null) {
      debugPrint(
        'ArmValueInjector: row r="$rowNumStr" missing, skipping $cellRef',
      );
      return;
    }

    XmlElement? cEl;
    for (final c in rowEl.childElements) {
      if (c.name.local == 'c' && c.getAttribute('r') == cellRef) {
        cEl = c;
        break;
      }
    }

    if (cEl != null) {
      _setCellTypeAndValue(cEl, value, isNumeric);
      return;
    }

    final newCell = XmlElement(
      XmlName('c'),
      [
        XmlAttribute(XmlName('r'), cellRef),
        XmlAttribute(
          XmlName('t'),
          isNumeric ? 'n' : 'str',
        ),
      ],
      [
        XmlElement(XmlName('v'), [], [XmlText(value)]),
      ],
    );
    _insertCellInRowColumnOrder(rowEl, newCell, colIdx);
  }

  void _setCellTypeAndValue(
    XmlElement cell,
    String value,
    bool isNumeric,
  ) {
    _setOrReplaceAttribute(cell, 't', isNumeric ? 'n' : 'str');

    XmlElement? vEl;
    for (final ch in cell.childElements) {
      if (ch.name.local == 'v') {
        vEl = ch;
        break;
      }
    }
    if (vEl != null) {
      vEl.children.clear();
      vEl.children.add(XmlText(value));
    } else {
      cell.children.add(
        XmlElement(XmlName('v'), [], [XmlText(value)]),
      );
    }
  }

  /// Inserts [cell] among [rowEl]'s `<c>` children so column order is ascending.
  void _insertCellInRowColumnOrder(
    XmlElement rowEl,
    XmlElement cell,
    int targetColIdx,
  ) {
    final children = rowEl.children;
    var insertAt = 0;
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      if (child is! XmlElement || child.name.local != 'c') {
        insertAt = i + 1;
        continue;
      }
      final r = child.getAttribute('r');
      final otherCol = r != null ? _columnIndexFromCellRef(r) : null;
      if (otherCol == null) {
        insertAt = i + 1;
        continue;
      }
      if (otherCol > targetColIdx) {
        children.insert(i, cell);
        return;
      }
      insertAt = i + 1;
    }
    children.insert(insertAt, cell);
  }

  void _setOrReplaceAttribute(XmlElement e, String name, String value) {
    e.attributes.removeWhere((a) => a.name.local == name);
    e.attributes.add(XmlAttribute(XmlName(name), value));
  }

  // Build Excel cell reference e.g. C49
  String _cellRef(int colIdx, int rowIdx) =>
      '${columnIndexToLettersZeroBased(colIdx)}${rowIdx + 1}';
}

/// 0-based column index from an Excel cell reference (e.g. `C49` → 2).
int? _columnIndexFromCellRef(String cellRef) {
  final m = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(cellRef.trim());
  if (m == null) return null;
  return columnLettersToIndexZeroBased(m.group(1)!);
}
