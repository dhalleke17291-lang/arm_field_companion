import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:xml/xml.dart';

import '../../core/excel_column_letters.dart';
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

  // --- Build cell grid from XML rows ---
  // Map of (row0, col0) → cell value string
  final cells = <(int, int), String>{};
  for (final row in plotDoc.findAllElements('row')) {
    final rowNum = int.tryParse(row.getAttribute('r') ?? '');
    if (rowNum == null) continue;
    final rowIdx = rowNum - 1; // 0-based
    for (final c in row.findElements('c')) {
      final ref = c.getAttribute('r'); // e.g. "C8"
      if (ref == null) continue;
      final colIdx = _colIdxFromRef(ref);
      if (colIdx == null) continue;
      final val = _cellValue(c, strings);
      if (val != null) cells[(rowIdx, colIdx)] = val;
    }
  }

  // --- Helper to read a cell ---
  String? cell(int row, int col) => cells[(row, col)];
  int? cellInt(int row, int col) {
    final v = cell(row, col);
    if (v == null) return null;
    final d = double.tryParse(v);
    if (d != null) return d.toInt();
    return int.tryParse(v);
  }

  // --- Metadata ---
  final title = cell(1, 2) ?? '';
  final trialId = cell(2, 2) ?? '';
  final cooperator = cell(3, 2);
  final crop = cell(4, 2);

  // --- Assessment columns (c=2 onward, until empty ID cell at row 7) ---
  final assessmentColumns = <ArmColumnMap>[];
  for (var colIdx = 2; colIdx < 512; colIdx++) {
    final rawId = cell(7, colIdx);
    if (rawId == null || rawId.trim().isEmpty) break;
    final armColumnId = rawId.trim();
    final subs = cell(46, colIdx);
    assessmentColumns.add(
      ArmColumnMap(
        armColumnId: armColumnId,
        armColumnIdInteger: int.tryParse(armColumnId),
        columnLetter: columnIndexToLettersZeroBased(colIdx),
        columnIndex: colIdx,
        pestType: cell(8, colIdx),
        pestCodeFromSheet: cell(9, colIdx),
        pestName: cell(10, colIdx),
        cropCodeArm: cell(11, colIdx),
        cropNameArm: cell(12, colIdx),
        cropVariety: cell(13, colIdx),
        seDescription: cell(14, colIdx),
        ratingDate: cell(15, colIdx),
        ratingTime: cell(16, colIdx),
        seName: cell(17, colIdx),
        partRated: cell(18, colIdx),
        cropOrPest: cell(19, colIdx),
        ratingType: cell(20, colIdx),
        ratingUnit: cell(21, colIdx),
        sampleSize: cell(22, colIdx),
        sizeUnit: cell(23, colIdx),
        collectBasis: cell(24, colIdx),
        collectionBasisUnit: cell(25, colIdx),
        reportingBasis: cell(26, colIdx),
        reportingBasisUnit: cell(27, colIdx),
        stageScale: cell(28, colIdx),
        cropStageMaj: cell(29, colIdx),
        cropStageMin: cell(30, colIdx),
        cropStageMax: cell(31, colIdx),
        cropDensity: cell(32, colIdx),
        cropDensityUnit: cell(33, colIdx),
        pestStageMaj: cell(34, colIdx),
        pestStageMin: cell(35, colIdx),
        pestStageMax: cell(36, colIdx),
        pestDensity: cell(37, colIdx),
        pestDensityUnit: cell(38, colIdx),
        assessedBy: cell(39, colIdx),
        equipment: cell(40, colIdx),
        ratingTiming: cell(41, colIdx),
        appTimingCode: cell(41, colIdx),
        trtEvalInterval: cell(42, colIdx),
        datInterval: cell(43, colIdx),
        untreatedRatingType: cell(44, colIdx),
        armActions: cell(45, colIdx),
        numSubsamples: subs != null ? int.tryParse(subs.trim()) : null,
      ),
    );
  }

  // --- Plot data rows: find 041TRT marker, data starts next row ---
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

  return ArmShellImport(
    title: title,
    trialId: trialId,
    cooperator: cooperator,
    crop: crop,
    assessmentColumns: assessmentColumns,
    plotRows: plotRows,
    treatmentSheetRows: treatmentSheetRows,
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

/// Reads an ARM Excel Rating Shell and extracts trial metadata, columns, and plot rows.
///
/// Parses the xlsx ZIP directly — only reads the Plot Data worksheet XML
/// and shared strings. Does NOT use the `excel` package (which decodes all
/// sheets including formula-heavy ones that can hang).
///
/// ARM Rating Shell layout contract (ARM 2025/2026):
/// Sheet: "Plot Data" (exact name)
///
/// Assessment columns (c=2 onward, until empty ID cell at **0-based row 7**).
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
