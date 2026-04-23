import 'arm_application_sheet_column.dart';
import 'arm_column_map.dart';
import 'arm_plot_row.dart';
import 'arm_treatment_sheet_row.dart';

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
    this.treatmentSheetRows = const [],
    this.applicationSheetColumns = const [],
  });

  final String title;
  final String trialId;
  final String? cooperator;
  final String? crop;

  final List<ArmColumnMap> assessmentColumns;
  final List<ArmPlotRow> plotRows;

  /// Rows parsed from the shell's **Treatments** sheet (sheet 7). Empty
  /// when the shell has no Treatments sheet or it could not be read —
  /// the Plot Data-derived treatment path still works without it.
  ///
  /// Phase 2a — populated by the parser but not yet consumed by any
  /// writer. Slice 2b wires it into [ImportArmRatingShellUseCase].
  final List<ArmTreatmentSheetRow> treatmentSheetRows;

  /// Columns parsed from the shell's **Applications** sheet (descriptor
  /// rows 1–79, values from column C onward). Empty when the sheet is
  /// missing, unreadable, or has no populated application blocks.
  final List<ArmApplicationSheetColumn> applicationSheetColumns;

  final String shellFilePath;
}
