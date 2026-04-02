import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

import '../../domain/models/arm_rating_value.dart';
import '../../domain/models/arm_shell_import.dart';

/// Injects rating values into an existing ARM Rating Shell file (never creates a new workbook).
///
/// Uses sheet **Plot Data** (ARM-native shells).
///
/// Updates only the Plot Data worksheet XML inside the xlsx zip; all other parts
/// are copied byte-for-byte to avoid [excel] decode/encode corruption on other sheets.
class ArmValueInjector {
  ArmValueInjector(this.shellImport);

  final ArmShellImport shellImport;

  Future<File> inject(List<ArmRatingValue> values, String outputPath) async {
    assert(
      outputPath != shellImport.shellFilePath,
      'outputPath must differ from original shell path',
    );

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

      final trimmed = v.value.trim();
      final numVal = double.tryParse(trimmed);
      final isNumeric = trimmed.isNotEmpty && numVal != null;
      final cellValue = isNumeric ? numVal.toString() : v.value;
      _writeCell(
        plotDoc,
        rowIdx,
        colIdx,
        cellValue,
        isNumeric,
      );
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
    return outFile;
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

    final cell = cEl ??
        XmlElement(
          XmlName('c'),
          [XmlAttribute(XmlName('r'), cellRef)],
          [],
        );

    if (isNumeric) {
      cell.attributes.removeWhere((a) => a.name.local == 't');
    } else {
      _setOrReplaceAttribute(cell, 't', 'str');
    }

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

    if (cEl == null) {
      rowEl.children.add(cell);
    }
  }

  void _setOrReplaceAttribute(XmlElement e, String name, String value) {
    e.attributes.removeWhere((a) => a.name.local == name);
    e.attributes.add(XmlAttribute(XmlName(name), value));
  }

  // Convert 0-based column index to Excel column letter(s)
  // 0→A, 1→B, 2→C, 25→Z, 26→AA etc.
  String _colIndexToLetter(int colIdx) {
    var result = '';
    var n = colIdx + 1;
    while (n > 0) {
      n--;
      result = String.fromCharCode(65 + n % 26) + result;
      n ~/= 26;
    }
    return result;
  }

  // Build Excel cell reference e.g. C49
  String _cellRef(int colIdx, int rowIdx) =>
      '${_colIndexToLetter(colIdx)}${rowIdx + 1}';
}
