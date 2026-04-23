import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

import '../../core/excel_column_letters.dart';
import '../../domain/models/arm_application_sheet_column.dart';
import '../../domain/models/arm_rating_value.dart';
import '../../domain/models/arm_shell_import.dart';
import '../../domain/models/arm_treatment_sheet_row.dart';

/// One Applications-sheet column to write on export ([row01To79] = R1…R79).
class ArmApplicationsSheetExportColumn {
  ArmApplicationsSheetExportColumn({
    required this.columnIndex,
    required List<String?> row01To79,
  })  : assert(row01To79.length ==
            ArmApplicationSheetColumn.kArmApplicationDescriptorRowCount),
        row01To79 = List<String?>.unmodifiable(row01To79);

  final int columnIndex;
  final List<String?> row01To79;
}

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
/// Updates the Plot Data worksheet XML inside the xlsx zip (and optionally
/// **Applications** / **Treatments**). All other parts are copied byte-for-byte
/// to avoid [excel] decode/encode corruption on other sheets.
class ArmValueInjector {
  ArmValueInjector(this.shellImport);

  final ArmShellImport shellImport;

  Future<ArmInjectionResult> inject(
    List<ArmRatingValue> values,
    String outputPath, {
    List<ArmApplicationsSheetExportColumn>? applicationColumns,
    List<ArmTreatmentSheetRow>? treatmentRows,
  }) async {
    if (outputPath == shellImport.shellFilePath) {
      throw StateError(
        'outputPath must differ from original shell path (would overwrite source).',
      );
    }

    final skippedReasons = <String>[];
    var cellsWritten = 0;

    final shellBytes = await File(shellImport.shellFilePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(shellBytes);
    final plotDataPath = _resolveWorksheetPath(archive, 'Plot Data');
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

    final updatedPlotBytes = utf8.encode(
      plotDoc.toXmlString(pretty: false),
    );

    List<int>? updatedApplicationsBytes;
    String? applicationsPath;
    if (applicationColumns != null && applicationColumns.isNotEmpty) {
      applicationsPath = _resolveWorksheetPath(archive, 'Applications');
      if (applicationsPath == null) {
        skippedReasons.add(
          'Applications sheet missing from shell — application data not written',
        );
      } else {
        final appEntry = archive.findFile(applicationsPath);
        if (appEntry == null) {
          skippedReasons.add(
            'Applications worksheet entry missing: $applicationsPath',
          );
        } else {
          final appDoc =
              XmlDocument.parse(utf8.decode(appEntry.content as List<int>));
          for (final col in applicationColumns) {
            final idx = col.columnIndex;
            if (idx < 0) continue;
            for (var r = 0; r < col.row01To79.length; r++) {
              final raw = col.row01To79[r];
              if (raw == null) continue;
              final trimmed = raw.trim();
              if (trimmed.isEmpty) continue;
              // Verbatim text (matches importer); avoid `double.toString()` drift
              // e.g. `55` → `55.0` which breaks round-trip byte equality.
              _writeCell(
                appDoc,
                r,
                idx,
                trimmed,
                false,
                ensureRow: true,
              );
              cellsWritten++;
            }
          }
          updatedApplicationsBytes =
              utf8.encode(appDoc.toXmlString(pretty: false));
        }
      }
    }

    List<int>? updatedTreatmentsBytes;
    String? treatmentsPath;
    if (treatmentRows != null && treatmentRows.isNotEmpty) {
      treatmentsPath = _resolveWorksheetPath(archive, 'Treatments');
      if (treatmentsPath == null) {
        skippedReasons.add(
          'Treatments sheet missing from shell — treatment data not written',
        );
      } else {
        final trEntry = archive.findFile(treatmentsPath);
        if (trEntry == null) {
          skippedReasons.add(
            'Treatments worksheet entry missing: $treatmentsPath',
          );
        } else {
          final trDoc =
              XmlDocument.parse(utf8.decode(trEntry.content as List<int>));
          const treatmentsDataStartRow = 2;
          for (final tr in treatmentRows) {
            final sheetRowIdx = treatmentsDataStartRow + tr.rowIndex;
            _writeCell(
              trDoc,
              sheetRowIdx,
              0,
              '${tr.trtNumber}',
              false,
              ensureRow: true,
            );
            cellsWritten++;
            void wText(int col, String? s) {
              if (s == null) return;
              final t = s.trim();
              if (t.isEmpty) return;
              _writeCell(trDoc, sheetRowIdx, col, t, false, ensureRow: true);
              cellsWritten++;
            }

            wText(1, tr.typeCode);
            wText(2, tr.treatmentName);
            final fc = _armTreatmentNumericCellText(tr.formConc);
            if (fc != null) {
              _writeCell(trDoc, sheetRowIdx, 3, fc, false, ensureRow: true);
              cellsWritten++;
            }
            wText(4, tr.formConcUnit);
            wText(5, tr.formType);
            final rt = _armTreatmentNumericCellText(tr.rate);
            if (rt != null) {
              _writeCell(trDoc, sheetRowIdx, 6, rt, false, ensureRow: true);
              cellsWritten++;
            }
            wText(7, tr.rateUnit);
          }
          updatedTreatmentsBytes =
              utf8.encode(trDoc.toXmlString(pretty: false));
        }
      }
    }

    final newArchive = Archive();
    for (final file in archive.files) {
      if (!file.isFile) continue;
      if (file.name == plotDataPath) {
        newArchive.addFile(
          ArchiveFile(file.name, updatedPlotBytes.length, updatedPlotBytes),
        );
      } else if (applicationsPath != null &&
          updatedApplicationsBytes != null &&
          file.name == applicationsPath) {
        newArchive.addFile(
          ArchiveFile(
            file.name,
            updatedApplicationsBytes.length,
            updatedApplicationsBytes,
          ),
        );
      } else if (treatmentsPath != null &&
          updatedTreatmentsBytes != null &&
          file.name == treatmentsPath) {
        newArchive.addFile(
          ArchiveFile(
            file.name,
            updatedTreatmentsBytes.length,
            updatedTreatmentsBytes,
          ),
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

  /// Resolves `xl/workbook.xml` + `xl/_rels/workbook.xml.rels` → worksheet path.
  String? _resolveWorksheetPath(Archive archive, String sheetName) {
    final wbFile = archive.findFile('xl/workbook.xml');
    if (wbFile == null) return null;
    final wbDoc = XmlDocument.parse(utf8.decode(wbFile.content as List<int>));

    XmlElement? plotSheet;
    for (final sheet in wbDoc.findAllElements('sheet')) {
      if (sheet.getAttribute('name') == sheetName) {
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
    bool isNumeric, {
    bool ensureRow = false,
  }) {
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
      if (!ensureRow) {
        debugPrint(
          'ArmValueInjector: row r="$rowNumStr" missing, skipping $cellRef',
        );
        return;
      }
      rowEl = _getOrCreateRow(sheetData, rowIdx0);
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

  XmlElement _getOrCreateRow(XmlElement sheetData, int rowIdx0) {
    final rowNumStr = '${rowIdx0 + 1}';
    for (final r in sheetData.childElements) {
      if (r.name.local == 'row' && r.getAttribute('r') == rowNumStr) {
        return r;
      }
    }
    final newRow = XmlElement(
      XmlName('row'),
      [XmlAttribute(XmlName('r'), rowNumStr)],
      [],
    );
    final children = sheetData.children;
    final targetNum = rowIdx0 + 1;
    var insertAt = children.length;
    for (var i = 0; i < children.length; i++) {
      final ch = children[i];
      if (ch is! XmlElement || ch.name.local != 'row') {
        continue;
      }
      final rn = int.tryParse(ch.getAttribute('r') ?? '');
      if (rn != null && rn > targetNum) {
        insertAt = i;
        break;
      }
    }
    children.insert(insertAt, newRow);
    return newRow;
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

String? _armTreatmentNumericCellText(double? d) {
  if (d == null) return null;
  if (d == d.roundToDouble()) return '${d.toInt()}';
  return d.toString();
}

/// 0-based column index from an Excel cell reference (e.g. `C49` → 2).
int? _columnIndexFromCellRef(String cellRef) {
  final m = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(cellRef.trim());
  if (m == null) return null;
  return columnLettersToIndexZeroBased(m.group(1)!);
}
