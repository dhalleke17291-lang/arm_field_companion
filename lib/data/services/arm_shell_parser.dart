import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:xml/xml.dart';

import '../../core/excel_column_letters.dart';
import '../../domain/models/arm_application_sheet_column.dart';
import '../../domain/models/arm_column_map.dart';
import '../../domain/models/arm_plot_row.dart';
import '../../domain/models/arm_shell_import.dart';
import '../../domain/models/arm_treatment_sheet_row.dart';

/// Arguments for isolate parse ([compute]).
class ArmShellParseParams {
  const ArmShellParseParams({
    required this.bytes,
    required this.shellFilePath,
  });

  final List<int> bytes;
  final String shellFilePath;
}

/// Top-level for [compute] — parse shell XML directly, no `excel` package.
ArmShellImport parseArmShellBytes(ArmShellParseParams p) {
  final archive = ZipDecoder().decodeBytes(p.bytes);

  // --- Shared strings ---
  final strings = <String>[];
  final ssFile = archive.findFile('xl/sharedStrings.xml');
  if (ssFile != null) {
    final ssDoc = XmlDocument.parse(utf8.decode(ssFile.content as List<int>));
    for (final si in ssDoc.findAllElements('si')) {
      // <si><t>text</t></si> or <si><r><t>part</t></r>...</si>
      final tElem = si.findElements('t').firstOrNull;
      if (tElem != null) {
        strings.add(tElem.innerText);
      } else {
        // Rich text: concatenate all <r><t>...</t></r> segments
        final buf = StringBuffer();
        for (final r in si.findElements('r')) {
          final rt = r.findElements('t').firstOrNull;
          if (rt != null) buf.write(rt.innerText);
        }
        strings.add(buf.toString());
      }
    }
  }

  // --- Find Plot Data worksheet path ---
  final plotDataPath = _resolveSheetPath(archive, 'Plot Data');
  if (plotDataPath == null) {
    throw ArgumentError(
      'Rating sheet not found — expected "Plot Data" (Excel rating sheet format).',
    );
  }
  final plotEntry = archive.findFile(plotDataPath);
  if (plotEntry == null) {
    throw ArgumentError('Plot Data worksheet file missing: $plotDataPath');
  }
  final plotDoc =
      XmlDocument.parse(utf8.decode(plotEntry.content as List<int>));

  final plotCells = _cellMapFromWorksheetXml(plotDoc, strings);

  // --- Helper to read a cell ---
  String? cell(int row, int col) => plotCells[(row, col)];
  int? cellInt(int row, int col) => _cellIntFrom(plotCells, row, col);

  // --- Metadata ---
  final title = cell(1, 2) ?? '';
  final trialId = cell(2, 2) ?? '';
  final cooperator = cell(3, 2);
  final crop = cell(4, 2);

  final assessmentColumns = _parseAssessmentColumnsFromCells(cell);
  final plotRows = _parsePlotRowsFromCells(cell, cellInt);

  // --- Treatments sheet (optional; legacy shells without it still parse) ---
  //
  // Best-effort: any parse failure on the Treatments sheet yields an
  // empty list rather than aborting the whole import. The existing
  // Plot Data-derived treatment path (TRT column → bare Treatments rows)
  // remains the authoritative structural source; the Treatments sheet
  // only enriches it with product / rate / formulation values.
  List<ArmTreatmentSheetRow> treatmentSheetRows = const [];
  try {
    treatmentSheetRows = _parseTreatmentsSheet(archive, strings);
  } catch (_) {
    treatmentSheetRows = const [];
  }

  List<ArmApplicationSheetColumn> applicationSheetColumns = const [];
  try {
    applicationSheetColumns = _parseApplicationsSheet(archive, strings);
  } catch (_) {
    applicationSheetColumns = const [];
  }

  String? commentsSheetText;
  try {
    commentsSheetText = _parseCommentsSheet(archive, strings);
  } catch (_) {
    commentsSheetText = null;
  }

  var subsampleAssessmentColumns = <ArmColumnMap>[];
  var subsamplePlotRows = <ArmPlotRow>[];
  try {
    final subPath = _resolveSheetPath(archive, 'Subsample Plot Data');
    if (subPath != null) {
      final subEntry = archive.findFile(subPath);
      if (subEntry != null) {
        final subDoc =
            XmlDocument.parse(utf8.decode(subEntry.content as List<int>));
        final subCells = _cellMapFromWorksheetXml(subDoc, strings);
        String? sCell(int r, int c) => subCells[(r, c)];
        int? sCellInt(int r, int c) => _cellIntFrom(subCells, r, c);
        subsampleAssessmentColumns = _parseAssessmentColumnsFromCells(sCell);
        subsamplePlotRows = _parsePlotRowsFromCells(sCell, sCellInt);
      }
    }
  } catch (_) {
    subsampleAssessmentColumns = const [];
    subsamplePlotRows = const [];
  }

  return ArmShellImport(
    title: title,
    trialId: trialId,
    cooperator: cooperator,
    crop: crop,
    assessmentColumns: assessmentColumns,
    plotRows: plotRows,
    treatmentSheetRows: treatmentSheetRows,
    applicationSheetColumns: applicationSheetColumns,
    commentsSheetText: commentsSheetText,
    subsampleAssessmentColumns: subsampleAssessmentColumns,
    subsamplePlotRows: subsamplePlotRows,
    shellFilePath: p.shellFilePath,
  );
}

/// Reads the optional **Treatments** sheet (sheet 7 in ARM 2026.0 shells).
///
/// Layout: two header rows (`R1`: `Trt`/blank/`Treatment`/`Form`/…,
/// `R2`: `No.`/`Type`/`Name`/`Conc`/`Unit`/`Type`/`Rate`/`Unit`), then
/// one data row per treatment starting at R3 (0-based row index 2).
///
/// Returns an empty list if the sheet is missing, the worksheet file is
/// unreadable, or no data row has a valid Trt No.
List<ArmTreatmentSheetRow> _parseTreatmentsSheet(
  Archive archive,
  List<String> sharedStrings,
) {
  final path = _resolveSheetPath(archive, 'Treatments');
  if (path == null) return const [];
  final entry = archive.findFile(path);
  if (entry == null) return const [];

  final doc = XmlDocument.parse(utf8.decode(entry.content as List<int>));

  final cells = <(int, int), String>{};
  for (final row in doc.findAllElements('row')) {
    final rowNum = int.tryParse(row.getAttribute('r') ?? '');
    if (rowNum == null) continue;
    final rowIdx = rowNum - 1;
    for (final c in row.findElements('c')) {
      final ref = c.getAttribute('r');
      if (ref == null) continue;
      final colIdx = _colIdxFromRef(ref);
      if (colIdx == null) continue;
      final val = _cellValue(c, sharedStrings);
      if (val != null) cells[(rowIdx, colIdx)] = val;
    }
  }

  String? cell(int row, int col) {
    final v = cells[(row, col)];
    if (v == null) return null;
    final trimmed = v.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? cellDouble(int row, int col) {
    final s = cell(row, col);
    if (s == null) return null;
    return double.tryParse(s);
  }

  // Data rows start at the third sheet row (0-based index 2), because the
  // first two rows are the two-line header. Stop at the first row with a
  // blank or non-integer Trt No.
  final rows = <ArmTreatmentSheetRow>[];
  const dataStartRow = 2;
  // 256 is a defensive upper bound — ARM trials cap well below this.
  for (var rowIdx = dataStartRow; rowIdx < dataStartRow + 256; rowIdx++) {
    final rawTrt = cell(rowIdx, 0);
    if (rawTrt == null) break;
    final trt = int.tryParse(rawTrt);
    if (trt == null) break;

    rows.add(
      ArmTreatmentSheetRow(
        trtNumber: trt,
        rowIndex: rowIdx - dataStartRow,
        typeCode: cell(rowIdx, 1),
        treatmentName: cell(rowIdx, 2),
        formConc: cellDouble(rowIdx, 3),
        formConcUnit: cell(rowIdx, 4),
        formType: cell(rowIdx, 5),
        rate: cellDouble(rowIdx, 6),
        rateUnit: cell(rowIdx, 7),
      ),
    );
  }

  return rows;
}

/// Reads the optional **Applications** sheet (79 descriptor rows × application
/// columns from C onward). Stops after two consecutive columns with no
/// non-empty cells in any descriptor row.
List<ArmApplicationSheetColumn> _parseApplicationsSheet(
  Archive archive,
  List<String> sharedStrings,
) {
  final path = _resolveSheetPath(archive, 'Applications');
  if (path == null) return const [];
  final entry = archive.findFile(path);
  if (entry == null) return const [];

  final doc = XmlDocument.parse(utf8.decode(entry.content as List<int>));

  final cells = <(int, int), String>{};
  for (final row in doc.findAllElements('row')) {
    final rowNum = int.tryParse(row.getAttribute('r') ?? '');
    if (rowNum == null) continue;
    final rowIdx = rowNum - 1;
    for (final c in row.findElements('c')) {
      final ref = c.getAttribute('r');
      if (ref == null) continue;
      final colIdx = _colIdxFromRef(ref);
      if (colIdx == null) continue;
      final val = _cellValue(c, sharedStrings);
      if (val != null) cells[(rowIdx, colIdx)] = val;
    }
  }

  String? cell(int row, int col) {
    final v = cells[(row, col)];
    if (v == null) return null;
    final trimmed = v.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  const descriptorRows = ArmApplicationSheetColumn.kArmApplicationDescriptorRowCount;
  var consecutiveAllEmpty = 0;
  final columns = <ArmApplicationSheetColumn>[];
  for (var colIdx = 2; colIdx < 512; colIdx++) {
    var anyNonEmpty = false;
    final rowVals = <String?>[];
    for (var r = 0; r < descriptorRows; r++) {
      final v = cell(r, colIdx);
      rowVals.add(v);
      if (v != null) anyNonEmpty = true;
    }
    if (!anyNonEmpty) {
      consecutiveAllEmpty++;
      if (consecutiveAllEmpty >= 2) break;
      continue;
    }
    consecutiveAllEmpty = 0;
    columns.add(
      ArmApplicationSheetColumn(
        columnIndex: colIdx,
        row01To79: rowVals,
      ),
    );
  }

  return columns;
}

/// Optional **Comments** sheet (`ECM` in column A, free text in column B).
String? _parseCommentsSheet(Archive archive, List<String> sharedStrings) {
  final path = _resolveSheetPath(archive, 'Comments');
  if (path == null) return null;
  final entry = archive.findFile(path);
  if (entry == null) return null;

  final doc = XmlDocument.parse(utf8.decode(entry.content as List<int>));
  final cells = <(int, int), String>{};
  for (final row in doc.findAllElements('row')) {
    final rowNum = int.tryParse(row.getAttribute('r') ?? '');
    if (rowNum == null) continue;
    final rowIdx = rowNum - 1;
    for (final c in row.findElements('c')) {
      final ref = c.getAttribute('r');
      if (ref == null) continue;
      final colIdx = _colIdxFromRef(ref);
      if (colIdx == null) continue;
      final val = _cellValue(c, sharedStrings);
      if (val != null) cells[(rowIdx, colIdx)] = val;
    }
  }

  String? cell(int row, int col) {
    final v = cells[(row, col)];
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  for (var r = 0; r < 64; r++) {
    final code = cell(r, 0);
    if (code != null && code.toUpperCase() == 'ECM') {
      return cell(r, 1);
    }
  }
  return null;
}

/// Reads an ARM Excel Rating Shell and extracts trial metadata, columns, and plot rows.
///
/// Parses the xlsx ZIP directly — only reads the Plot Data worksheet XML
/// and shared strings. Does NOT use the `excel` package (which decodes all
/// sheets including formula-heavy ones that can hang).
///
/// ARM Rating Shell layout contract (ARM 2025/2026):
/// Sheet: "Plot Data" (exact name)
///
/// Optional sheet: **Applications** — 79 descriptor rows (Excel rows 1–79,
/// 0-based `0…78`) × application columns from **C** onward; see
/// `_parseApplicationsSheet` and `test/fixtures/arm_shells/README.md`.
///
/// Optional sheet: **Comments** — single `ECM` row with free text in column B;
/// see `_parseCommentsSheet`.
///
/// Optional sheet: **Subsample Plot Data** — same `001EID`…`041TRT` layout as
/// Plot Data; parsed into [ArmShellImport.subsampleAssessmentColumns] and
/// [ArmShellImport.subsamplePlotRows] (best-effort when the sheet is missing or
/// invalid).
///
/// Assessment columns (c=2 onward, until empty ID cell on the `001EID` row).
/// The `001EID` descriptor row is detected from column A (falls back to **0-based
/// row 7** / Excel row 8). **Subsample Plot Data** uses the same row offsets
/// from that anchor (ARM may place `001EID` on row 1 in that sheet).
/// Full Plot Data descriptor block **0-based rows 8–46** (Excel rows 9–47,
/// `001EID`…`040ENS`) is read into [ArmColumnMap]; see
/// `test/fixtures/arm_shells/README.md`.
///
/// Highlights:
///   r=7:  ARM Column ID
///   r=9:  `003EPT` pest code ([ArmColumnMap.pestCodeFromSheet])
///   r=14: SE Description
///   r=15: Rating date
///   r=17: SE Name
///   r=18: Part rated
///   r=20–21: Rating type / unit
///   r=22: Sample size
///   r=23: Size unit (`017EBU`)
///   r=24: Collect. basis (`018EUS`) — **not** row 23
///   r=29–31: Crop stage maj / min / max
///   r=39: Assessed By
///   r=41: Rating timing / App timing code
///   r=42–43: Trt-eval / plant-eval interval
///   r=46: Num subsamples
///
/// Row and column indices are **0-based**.
class ArmShellParser {
  ArmShellParser(this.shellFilePath);

  final String shellFilePath;

  Future<ArmShellImport> parse() async {
    final bytes = await File(shellFilePath).readAsBytes();
    return compute(
      parseArmShellBytes,
      ArmShellParseParams(bytes: bytes, shellFilePath: shellFilePath),
    );
  }
}

// --- Private helpers ---

/// Map of (row0, col0) → cell value string from one worksheet `<sheetData>`.
Map<(int, int), String> _cellMapFromWorksheetXml(
  XmlDocument sheetDoc,
  List<String> sharedStrings,
) {
  final cells = <(int, int), String>{};
  for (final row in sheetDoc.findAllElements('row')) {
    final rowNum = int.tryParse(row.getAttribute('r') ?? '');
    if (rowNum == null) continue;
    final rowIdx = rowNum - 1;
    for (final c in row.findElements('c')) {
      final ref = c.getAttribute('r');
      if (ref == null) continue;
      final colIdx = _colIdxFromRef(ref);
      if (colIdx == null) continue;
      final val = _cellValue(c, sharedStrings);
      if (val != null) cells[(rowIdx, colIdx)] = val;
    }
  }
  return cells;
}

int? _cellIntFrom(Map<(int, int), String> cells, int row, int col) {
  final v = cells[(row, col)];
  if (v == null) return null;
  final d = double.tryParse(v);
  if (d != null) return d.toInt();
  return int.tryParse(v);
}

/// Row (0-based) where column A is `001EID` and column C+ hold ARM Column IDs.
/// Falls back to **7** (Excel row 8) when not found — matches standard Plot Data.
int _find001EidDescriptorRow(String? Function(int row, int col) cell) {
  for (var r = 0; r < 100; r++) {
    if (cell(r, 0)?.trim() == '001EID') return r;
  }
  return 7;
}

List<ArmColumnMap> _parseAssessmentColumnsFromCells(
  String? Function(int row, int col) cell,
) {
  final anchor = _find001EidDescriptorRow(cell);
  int dr(int specRow) => anchor + (specRow - 7);

  final assessmentColumns = <ArmColumnMap>[];
  for (var colIdx = 2; colIdx < 512; colIdx++) {
    final rawId = cell(dr(7), colIdx);
    if (rawId == null || rawId.trim().isEmpty) break;
    final armColumnId = rawId.trim();
    final subs = cell(dr(46), colIdx);
    assessmentColumns.add(
      ArmColumnMap(
        armColumnId: armColumnId,
        armColumnIdInteger: int.tryParse(armColumnId),
        columnLetter: columnIndexToLettersZeroBased(colIdx),
        columnIndex: colIdx,
        pestType: cell(dr(8), colIdx),
        pestCodeFromSheet: cell(dr(9), colIdx),
        pestName: cell(dr(10), colIdx),
        cropCodeArm: cell(dr(11), colIdx),
        cropNameArm: cell(dr(12), colIdx),
        cropVariety: cell(dr(13), colIdx),
        seDescription: cell(dr(14), colIdx),
        ratingDate: cell(dr(15), colIdx),
        ratingTime: cell(dr(16), colIdx),
        seName: cell(dr(17), colIdx),
        partRated: cell(dr(18), colIdx),
        cropOrPest: cell(dr(19), colIdx),
        ratingType: cell(dr(20), colIdx),
        ratingUnit: cell(dr(21), colIdx),
        sampleSize: cell(dr(22), colIdx),
        sizeUnit: cell(dr(23), colIdx),
        collectBasis: cell(dr(24), colIdx),
        collectionBasisUnit: cell(dr(25), colIdx),
        reportingBasis: cell(dr(26), colIdx),
        reportingBasisUnit: cell(dr(27), colIdx),
        stageScale: cell(dr(28), colIdx),
        cropStageMaj: cell(dr(29), colIdx),
        cropStageMin: cell(dr(30), colIdx),
        cropStageMax: cell(dr(31), colIdx),
        cropDensity: cell(dr(32), colIdx),
        cropDensityUnit: cell(dr(33), colIdx),
        pestStageMaj: cell(dr(34), colIdx),
        pestStageMin: cell(dr(35), colIdx),
        pestStageMax: cell(dr(36), colIdx),
        pestDensity: cell(dr(37), colIdx),
        pestDensityUnit: cell(dr(38), colIdx),
        assessedBy: cell(dr(39), colIdx),
        equipment: cell(dr(40), colIdx),
        ratingTiming: cell(dr(41), colIdx),
        appTimingCode: cell(dr(41), colIdx),
        trtEvalInterval: cell(dr(42), colIdx),
        datInterval: cell(dr(43), colIdx),
        untreatedRatingType: cell(dr(44), colIdx),
        armActions: cell(dr(45), colIdx),
        numSubsamples: subs != null ? int.tryParse(subs.trim()) : null,
      ),
    );
  }
  return assessmentColumns;
}

List<ArmPlotRow> _parsePlotRowsFromCells(
  String? Function(int row, int col) cell,
  int? Function(int row, int col) cellInt,
) {
  var headerRowIdx = -1;
  for (var rowIdx = 7; rowIdx < 200; rowIdx++) {
    final v = cell(rowIdx, 0);
    if (v != null && v.trim() == '041TRT') {
      headerRowIdx = rowIdx;
      break;
    }
  }
  if (headerRowIdx < 0) {
    throw ArgumentError(
      'Excel rating sheet invalid: 041TRT header row not found.',
    );
  }

  final plotRows = <ArmPlotRow>[];
  for (var rowIdx = headerRowIdx + 1; rowIdx < 1000; rowIdx++) {
    final trt = cellInt(rowIdx, 0);
    if (trt == null) break;
    final plot = cellInt(rowIdx, 1);
    if (plot == null) break;
    plotRows.add(
      ArmPlotRow(
        trtNumber: trt,
        plotNumber: plot,
        blockNumber: plot ~/ 100,
        rowIndex: rowIdx,
      ),
    );
  }
  return plotRows;
}

/// Resolves workbook.xml + rels to find the XML path of a worksheet by
/// its display name (e.g. `'Plot Data'`, `'Treatments'`).
///
/// Returns null when the named sheet is absent or the relationship it
/// references cannot be resolved. Callers handle absence per their own
/// policy — `Plot Data` is required; `Treatments` is optional.
String? _resolveSheetPath(Archive archive, String sheetName) {
  final wbFile = archive.findFile('xl/workbook.xml');
  if (wbFile == null) return null;
  final wbDoc = XmlDocument.parse(utf8.decode(wbFile.content as List<int>));

  XmlElement? match;
  for (final sheet in wbDoc.findAllElements('sheet')) {
    if (sheet.getAttribute('name') == sheetName) {
      match = sheet;
      break;
    }
  }
  if (match == null) return null;

  String? rid;
  for (final a in match.attributes) {
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

/// Extracts the 0-based column index from a cell reference like "C8" → 2.
int? _colIdxFromRef(String ref) {
  final letters = ref.replaceAll(RegExp(r'[0-9]'), '');
  if (letters.isEmpty) return null;
  return columnLettersToIndexZeroBased(letters);
}

/// Extracts the string value from a <c> element, resolving shared strings.
String? _cellValue(XmlElement c, List<String> sharedStrings) {
  final vElem = c.findElements('v').firstOrNull;
  if (vElem == null) return null;
  final raw = vElem.innerText;
  final type = c.getAttribute('t');
  if (type == 's') {
    // Shared string reference
    final idx = int.tryParse(raw);
    if (idx != null && idx < sharedStrings.length) return sharedStrings[idx];
    return null;
  }
  return raw;
}
