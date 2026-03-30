import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../arm_import/data/arm_import_persistence_repository.dart';
import 'export_confidence_policy.dart';
import 'report_data_assembly_service.dart';
import 'report_pdf_builder_service.dart';

/// Optional share override for testing. When non-null, used instead of Share.
typedef ShareOverride = Future<void> Function(List<XFile> files, {String? text});

/// Result of [ExportTrialPdfReportUseCase.execute]; [warningMessage] is set when import confidence was low.
class ExportPdfExecutionResult {
  const ExportPdfExecutionResult({this.warningMessage});

  final String? warningMessage;
}

/// Exports a trial as a PDF report using the standalone report data layer.
/// Assembles data, builds PDF, writes to temp file, and shares.
class ExportTrialPdfReportUseCase {
  ExportTrialPdfReportUseCase({
    required ReportDataAssemblyService assemblyService,
    required ReportPdfBuilderService pdfBuilder,
    required ArmImportPersistenceRepository armImportPersistenceRepository,
    ShareOverride? shareOverride,
  })  : _assemblyService = assemblyService,
        _pdfBuilder = pdfBuilder,
        _armImportPersistenceRepository = armImportPersistenceRepository,
        _shareOverride = shareOverride;

  final ReportDataAssemblyService _assemblyService;
  final ReportPdfBuilderService _pdfBuilder;
  final ArmImportPersistenceRepository _armImportPersistenceRepository;
  final ShareOverride? _shareOverride;

  /// Assembles report data, builds PDF, writes to temp file, and shares.
  Future<ExportPdfExecutionResult> execute({required Trial trial}) async {
    final profile = await _armImportPersistenceRepository
        .getLatestCompatibilityProfileForTrial(trial.id);
    final gate = gateFromConfidence(profile?.exportConfidence);
    if (gate == ExportGate.block) {
      var msg = kBlockedExportMessage;
      final reason = profile?.exportBlockReason;
      if (reason != null && reason.trim().isNotEmpty) {
        msg = '$msg Reason: $reason';
      }
      throw ExportBlockedByConfidenceException(msg);
    }
    String? confidenceWarningMessage;
    if (gate == ExportGate.warn) {
      confidenceWarningMessage = kWarnExportMessage;
    }

    final reportData = await _assemblyService.assembleForTrial(trial);
    final bytes = await _pdfBuilder.build(reportData);

    final dir = await getTemporaryDirectory();
    final safeName =
        trial.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final timestamp =
        DateFormat('yyyyMMdd_HHmmss_SSS').format(DateTime.now());
    final path = '${dir.path}/AGQ_${safeName}_$timestamp.pdf';

    await File(path).writeAsBytes(bytes);
    if (_shareOverride != null) {
      await _shareOverride!([XFile(path)], text: '${trial.name} – PDF field report');
    } else {
      await Share.shareXFiles(
        [XFile(path)],
        text: '${trial.name} – PDF field report',
      );
    }
    return ExportPdfExecutionResult(warningMessage: confidenceWarningMessage);
  }
}
