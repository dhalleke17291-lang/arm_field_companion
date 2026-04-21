import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:xml/xml.dart';

import '../../core/excel_column_letters.dart';
import '../../domain/models/arm_column_map.dart';
import '../../domain/models/arm_plot_row.dart';
import '../../domain/models/arm_shell_import.dart';

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
  final plotDataPath = _resolvePlotDataWorksheetPath(archive);
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
        ratingDate: cell(15, colIdx),
        seDescription: cell(14, colIdx),
        seName: cell(17, colIdx),
        ratingType: cell(20, colIdx),
        ratingUnit: cell(21, colIdx),
        cropStageMaj: cell(29, colIdx),
        ratingTiming: cell(41, colIdx),
        numSubsamples: subs != null ? int.tryParse(subs.trim()) : null,
        pestCode: cell(17, colIdx),
        partRated: cell(18, colIdx),
        collectBasis: cell(23, colIdx),
        appTimingCode: cell(41, colIdx),
        trtEvalInterval: cell(42, colIdx),
        datInterval: cell(43, colIdx),
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

  return ArmShellImport(
    title: title,
    trialId: trialId,
    cooperator: cooperator,
    crop: crop,
    assessmentColumns: assessmentColumns,
    plotRows: plotRows,
    shellFilePath: p.shellFilePath,
  );
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
/// Assessment columns (c=2 onward, until empty ID cell):
///   r=7:  ARM Column ID (identity anchor; integer for AgQuest shells)
///   r=14: SE Description
///   r=15: Rating date
///   r=17: SE Name / Pest code (W003, W001, CF013)
///   r=18: Part rated (PLANT, LEAF3)
///   r=20: Rating type
///   r=21: Rating unit
///   r=23: Collect basis (PLOT)
///   r=29: Crop stage major
///   r=41: Rating timing / App timing code (A1, A3, A6, A9, AA)
///   r=42: Trt-eval interval (-28 DA-A, -7 DA-A)
///   r=43: DAT interval (-7 DP-1, 1 DP-1, 14 DP-1)
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

/// Resolves workbook.xml + rels to find the Plot Data sheet XML path.
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
