/// One **Applications** sheet column in an ARM Rating Shell (columns C onward).
///
/// Excel rows **1–79** (0-based indices `0…78`) map to DB columns [row01]…[row79];
/// see `test/fixtures/arm_shells/README.md`.
class ArmApplicationSheetColumn {
  const ArmApplicationSheetColumn({
    required this.columnIndex,
    required List<String?> row01To79,
  })  : assert(row01To79.length == kArmApplicationDescriptorRowCount),
        _rows = row01To79;

  static const int kArmApplicationDescriptorRowCount = 79;

  /// 0-based worksheet column index (A=0, B=1, C=2).
  final int columnIndex;

  final List<String?> _rows;

  /// Verbatim trimmed cell text; `[0]` = Excel row 1 (R1 `ADA`), … `[78]` = R79 `TMA`.
  /// Empty cells are `null`.
  List<String?> get row01To79 => _rows;
}
