import 'arm_column_map.dart';
import 'arm_plot_row.dart';

/// Parsed ARM Excel Rating Shell (structure only; values optional).
class ArmShellImport {
  const ArmShellImport({
    required this.title,
    required this.trialId,
    required this.assessmentColumns,
    required this.plotRows,
    required this.shellFilePath,
    this.cooperator,
    this.crop,
  });

  final String title;
  final String trialId;
  final String? cooperator;
  final String? crop;

  final List<ArmColumnMap> assessmentColumns;
  final List<ArmPlotRow> plotRows;

  final String shellFilePath;
}
