import '../../core/database/app_database.dart';
import 'report_data_assembly_service.dart';

/// Exports a trial as a PDF report using the standalone report data layer.
/// PDF generation is not yet implemented; this use case wires assembly only.
class ExportTrialPdfReportUseCase {
  ExportTrialPdfReportUseCase({
    required ReportDataAssemblyService assemblyService,
  }) : _assemblyService = assemblyService;

  final ReportDataAssemblyService _assemblyService;

  /// Assembles report data and triggers PDF generation (not yet implemented).
  /// Throws [PdfReportNotImplementedException] after successful assembly.
  Future<void> execute({required Trial trial}) async {
    final reportData = await _assemblyService.assembleForTrial(trial);
    // PDF generation is not implemented yet. Assembly succeeded.
    throw PdfReportNotImplementedException(
      trialName: reportData.trial.name,
      message: 'PDF report generation is not implemented yet after data assembly.',
    );
  }
}

/// Thrown when PDF report generation is requested but not yet implemented.
class PdfReportNotImplementedException implements Exception {
  PdfReportNotImplementedException({
    required this.trialName,
    required this.message,
  });

  final String trialName;
  final String message;

  @override
  String toString() => 'PdfReportNotImplementedException: $message';
}
