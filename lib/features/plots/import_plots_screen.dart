import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Plots'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
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

            // Preview
            if (_previewRows != null) ...[
              const SizedBox(height: 20),
              Text(
                'Preview — first 5 rows of ${_previewRows!.length} total',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              _buildPreviewTable(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _importPlots,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_done),
                  label: Text(_isLoading
                      ? 'Importing...'
                      : 'Import ${_previewRows!.length} Plots'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
              ),
            ],

            // Result
            if (_lastResult != null) ...[
              const SizedBox(height: 20),
              _buildResultCard(),
            ],
          ],
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
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                ))
            .toList(),
        rows: preview
            .map((row) => DataRow(
                  cells: columns
                      .map((col) =>
                          DataCell(Text(row[col]?.toString() ?? '')))
                      .toList(),
                ))
            .toList(),
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
            color: isSuccess
                ? Colors.green.shade300
                : Colors.red.shade300),
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
                isSuccess
                    ? 'Import Successful'
                    : 'Import Failed',
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    setState(() {
      _fileName = file.name;
      _lastResult = null;
    });

    try {
      final content = await File(file.path!).readAsString();
      final rows = const CsvToListConverter(eol: '\n').convert(content);

      if (rows.isEmpty) {
        setState(() => _previewRows = []);
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

      setState(() => _previewRows = dataRows);
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
    if (_previewRows == null || _previewRows!.isEmpty) return;

    setState(() => _isLoading = true);

    final plotRepo = ref.read(plotRepositoryProvider);
    final trialRepo = ref.read(trialRepositoryProvider);
    final useCase = ImportPlotsUseCase(plotRepo, trialRepo);

    final result = await useCase.execute(ImportPlotsInput(
      trialId: widget.trial.id,
      rows: _previewRows!,
      fileName: _fileName ?? 'unknown.csv',
    ));

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _lastResult = result;
      if (result.success) {
        _previewRows = null;
        _fileName = null;
      }
    });
  }
}
