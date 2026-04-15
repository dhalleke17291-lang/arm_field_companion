import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import 'evidence_report_assembly_service.dart';
import 'evidence_report_pdf_builder.dart';

/// Assembles evidence data, builds PDF, writes to temp, and shares.
class ExportEvidenceReportUseCase {
  ExportEvidenceReportUseCase({
    required EvidenceReportAssemblyService assemblyService,
    required EvidenceReportPdfBuilder pdfBuilder,
  })  : _assemblyService = assemblyService,
        _pdfBuilder = pdfBuilder;

  final EvidenceReportAssemblyService _assemblyService;
  final EvidenceReportPdfBuilder _pdfBuilder;

  Future<void> execute({required Trial trial}) async {
    final data = await _assemblyService.assembleForTrial(trial);
    final bytes = await _pdfBuilder.build(data);

    final dir = await getTemporaryDirectory();
    final safeName =
        trial.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final timestamp =
        DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final path = '${dir.path}/Evidence_${safeName}_$timestamp.pdf';

    await File(path).writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/pdf')],
      text: '${trial.name} — Field Evidence Report',
    );
  }
}
