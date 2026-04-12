/// One plot data row in an ARM Rating Shell sheet.
class ArmPlotRow {
  const ArmPlotRow({
    required this.trtNumber,
    required this.plotNumber,
    required this.blockNumber,
    required this.rowIndex,
  });

  final int trtNumber;
  final int plotNumber;

  /// Block encoded in plot number (first digit of block encoding).
  final int blockNumber;

  /// 0-based row index in the sheet.
  final int rowIndex;
}
