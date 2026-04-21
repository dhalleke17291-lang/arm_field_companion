import 'package:flutter/material.dart';
import '../../core/widgets/gradient_screen_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/trial_state.dart';
import 'usecases/import_plots_usecase.dart';

class ImportPlotsScreen extends ConsumerStatefulWidget {
  final Trial trial;

  const ImportPlotsScreen({super.key, required this.trial});

  @override
  ConsumerState<ImportPlotsScreen> createState() => _ImportPlotsScreenState();
}

class _ImportPlotsScreenState extends ConsumerState<ImportPlotsScreen> {
  bool _isLoading = false;
  ImportPlotsResult? _lastResult;
  String? _fileName;
  List<Map<String, dynamic>>? _previewRows;
  ImportReviewResult? _reviewResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EB),
      appBar: const GradientScreenHeader(title: 'Import Plots'),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trial banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.energy_savings_leaf,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(widget.trial.name,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // CSV format guide
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 6),
                      Text('CSV Format',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Required column:\n'
                    '  • plot_id\n\n'
                    'Optional columns:\n'
                    '  • rep\n'
                    '  • row\n'
                    '  • column\n'
                    '  • plot_sort_index\n\n'
                    'First row must be column headers.',
                    style: TextStyle(fontSize: 13, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // File picker button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickFile,
                icon: const Icon(Icons.upload_file),
                label: Text(_fileName ?? 'Select CSV File'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            ),

            // Preview + Import Review (Charter PART 16)
            if (_previewRows != null) ...[
              const SizedBox(height: 20),
              Text(
                'Preview — first 5 rows of ${_previewRows!.length} total',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              _buildPreviewTable(),
              if (_reviewResult != null) ...[
                const SizedBox(height: 20),
                _buildImportReviewCard(),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isLoading || !(_reviewResult!.canProceed)
                        ? null
                        : _importPlots,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download_done),
                    label: Text(_isLoading
                        ? 'Importing...'
                        : _reviewResult!.canProceed
                            ? 'Approve and Import ${_reviewResult!.matchedSuccessfullyCount} Plots'
                            : 'Fix errors to enable import'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  ),
                ),
              ],
            ],

            // Result
            if (_lastResult != null) ...[
              const SizedBox(height: 20),
              _buildResultCard(),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildPreviewTable() {
    final preview = _previewRows!.take(5).toList();
    if (preview.isEmpty) return const SizedBox();

    final columns = preview.first.keys.toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        headingRowColor: WidgetStateProperty.all(
            Theme.of(context).colorScheme.primaryContainer),
        columns: columns
            .map((col) => DataColumn(
                  label: Text(col,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ))
            .toList(),
        rows: preview
            .map((row) => DataRow(
                  cells: columns
                      .map((col) => DataCell(Text(row[col]?.toString() ?? '')))
                      .toList(),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildImportReviewCard() {
    final r = _reviewResult!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined,
                  color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text('Import Review',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue.shade700)),
            ],
          ),
          const SizedBox(height: 12),
          _reviewChip(
              'Matched successfully', r.matchedSuccessfullyCount, Colors.green),
          if (r.autoHandledMessages.isNotEmpty)
            _reviewChip(
                'Auto-handled', r.autoHandledMessages.length, Colors.orange),
          if (r.needsUserReviewItems.isNotEmpty)
            _reviewChip('Needs user review', r.needsUserReviewItems.length,
                Colors.amber),
          if (r.mustFixErrors.isNotEmpty)
            _reviewChip(
                'Must fix before import', r.mustFixErrors.length, Colors.red),
          if (r.mustFixErrors.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...r.mustFixErrors.map((e) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text('• $e',
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                )),
          ],
          if (r.autoHandledMessages.isNotEmpty && r.mustFixErrors.isEmpty) ...[
            const SizedBox(height: 6),
            Text('Auto-handled:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800)),
            ...r.autoHandledMessages.take(5).map((e) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 1),
                  child: Text('• $e', style: const TextStyle(fontSize: 11)),
                )),
          ],
          if (r.needsUserReviewItems.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...r.needsUserReviewItems.map((e) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 1),
                  child: Text('• $e',
                      style: TextStyle(
                          fontSize: 11, color: Colors.amber.shade900)),
                )),
          ],
        ],
      ),
    );
  }

  Widget _reviewChip(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text('$label: $count',
              style:
                  TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _lastResult!;
    final isSuccess = result.success;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isSuccess ? Colors.green.shade300 : Colors.red.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                isSuccess ? 'Import Successful' : 'Import Failed',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSuccess ? Colors.green : Colors.red,
                    fontSize: 16),
              ),
            ],
          ),
          if (isSuccess) ...[
            const SizedBox(height: 8),
            Text('✓ ${result.rowsImported} plots imported'),
            if (result.rowsSkipped > 0)
              Text('⚠ ${result.rowsSkipped} rows skipped',
                  style: const TextStyle(color: Colors.orange)),
          ],
          if (!isSuccess) ...[
            const SizedBox(height: 8),
            Text(result.errorMessage ?? 'Unknown error',
                style: const TextStyle(color: Colors.red)),
          ],
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Warnings:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...result.warnings.map((w) => Text('• $w',
                style: const TextStyle(fontSize: 12, color: Colors.orange))),
          ],
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    setState(() {
      _fileName = file.name;
      _lastResult = null;
      _reviewResult = null;
    });

    try {
      final content = await File(file.path!).readAsString();
      final rows = const CsvToListConverter(eol: '\n').convert(content);

      if (rows.isEmpty) {
        setState(() {
          _previewRows = [];
          _reviewResult = null;
        });
        return;
      }

      // First row is headers
      final headers = rows.first.map((e) => e.toString()).toList();
      final dataRows = rows.skip(1).map((row) {
        final map = <String, dynamic>{};
        for (int i = 0; i < headers.length && i < row.length; i++) {
          map[headers[i]] = row[i];
        }
        return map;
      }).toList();

      final useCase = ImportPlotsUseCase(
        ref.read(databaseProvider),
        ref.read(plotRepositoryProvider),
        ref.read(trialRepositoryProvider),
      );
      final reviewResult = useCase.analyzeForImport(ImportPlotsInput(
        trialId: widget.trial.id,
        rows: dataRows,
        fileName: file.name,
      ));

      setState(() {
        _previewRows = dataRows;
        _reviewResult = reviewResult;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error reading file: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importPlots() async {
    if (_reviewResult == null || !_reviewResult!.canProceed) return;
    final normalizedRows = _reviewResult!.normalizedRows!;
    final hasSessionData =
        ref.read(trialHasSessionDataProvider(widget.trial.id)).valueOrNull ??
            false;
    if (!canEditTrialStructure(widget.trial,
        hasSessionData: hasSessionData)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(structureEditBlockedMessage(
            widget.trial,
            hasSessionData: hasSessionData,
          )),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final plotRepo = ref.read(plotRepositoryProvider);
    final trialRepo = ref.read(trialRepositoryProvider);
    final useCase = ImportPlotsUseCase(
      ref.read(databaseProvider),
      plotRepo,
      trialRepo,
    );

    final result = await useCase.execute(ImportPlotsInput(
      trialId: widget.trial.id,
      rows: normalizedRows,
      fileName: _fileName ?? 'unknown.csv',
    ));

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _lastResult = result;
      if (result.success) {
        _previewRows = null;
        _fileName = null;
        _reviewResult = null;
      }
    });
  }
}
