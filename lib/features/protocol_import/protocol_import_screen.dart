import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/trial_state.dart';
import 'protocol_import_models.dart';

/// Full protocol import (Charter PART 16): one CSV with sections TRIAL, TREATMENT, PLOT.
/// [trial] null = create new trial from file; non-null = add treatments/plots to this trial.
class ProtocolImportScreen extends ConsumerStatefulWidget {
  final Trial? trial;

  const ProtocolImportScreen({super.key, this.trial});

  @override
  ConsumerState<ProtocolImportScreen> createState() => _ProtocolImportScreenState();
}

class _ProtocolImportScreenState extends ConsumerState<ProtocolImportScreen> {
  bool _isLoading = false;
  String? _fileName;
  List<Map<String, dynamic>>? _rows;
  ProtocolImportReviewResult? _review;
  ProtocolImportExecuteResult? _executeResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trial == null ? 'Import Protocol (New Trial)' : 'Import Protocol (Add to Trial)'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.trial != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.science, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      widget.trial!.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _buildFormatHelp(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickFile,
                icon: const Icon(Icons.upload_file),
                label: Text(_fileName ?? 'Select Protocol CSV'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
              ),
            ),
            if (_review != null) ...[
              const SizedBox(height: 20),
              _buildReviewCard(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading || !_review!.canProceed
                      ? null
                      : _runImport,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download_done),
                  label: Text(
                    _isLoading
                        ? 'Importing...'
                        : _review!.canProceed
                            ? 'Approve and Import'
                            : 'Fix errors to enable import',
                  ),
                  style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                ),
              ),
            ],
            if (_executeResult != null) _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatHelp() {
    return Container(
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
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
              const SizedBox(width: 6),
              Text(
                'Protocol CSV format',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'First row = headers. Include column "section" (or "type") with values:\n\n'
            '• TRIAL — one row: trial_name, crop?, location?, season?\n'
            '• TREATMENT — code, name, description?\n'
            '• PLOT — plot_id, rep?, row?, column?, plot_sort_index?, treatment_code?\n\n'
            'treatment_code in PLOT links to TREATMENT.code. When adding to existing trial, TRIAL section is ignored.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionReview(String title, SectionReview r, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _chip('Matched', r.matchedCount, Colors.green),
              if (r.autoHandled.isNotEmpty) _chip('Auto-handled', r.autoHandled.length, Colors.orange),
              if (r.needsReview.isNotEmpty) _chip('Needs review', r.needsReview.length, Colors.amber),
              if (r.mustFix.isNotEmpty) _chip('Must fix', r.mustFix.length, Colors.red),
            ],
          ),
          if (r.mustFix.isNotEmpty)
            ...r.mustFix.take(3).map((e) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text('• $e', style: const TextStyle(fontSize: 11, color: Colors.red)),
                )),
        ],
      ),
    );
  }

  Widget _chip(String label, int n, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('$label: $n', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildReviewCard() {
    final r = _review!;
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
              Icon(Icons.fact_check_outlined, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Import Review',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSectionReview('Trial', r.trialSection, Colors.blue.shade800),
          _buildSectionReview('Treatments', r.treatmentSection, Colors.blue.shade800),
          _buildSectionReview('Plots', r.plotSection, Colors.blue.shade800),
          _buildSectionReview('Assignments', r.assignmentSection, Colors.blue.shade800),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _executeResult!;
    final isSuccess = result.success;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isSuccess ? Colors.green.shade300 : Colors.red.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isSuccess ? Icons.check_circle : Icons.error, color: isSuccess ? Colors.green : Colors.red),
              const SizedBox(width: 8),
              Text(
                isSuccess ? 'Import successful' : 'Import failed',
                style: TextStyle(fontWeight: FontWeight.bold, color: isSuccess ? Colors.green : Colors.red, fontSize: 16),
              ),
            ],
          ),
          if (isSuccess) ...[
            const SizedBox(height: 8),
            Text('Trial ID: ${result.trialId}'),
            Text('Treatments imported: ${result.treatmentsImported}'),
            Text('Plots imported: ${result.plotsImported}'),
          ],
          if (!isSuccess) ...[
            const SizedBox(height: 8),
            Text(result.errorMessage ?? 'Unknown error', style: const TextStyle(color: Colors.red)),
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
      _review = null;
      _executeResult = null;
    });

    try {
      final content = await File(file.path!).readAsString();
      final list = const CsvToListConverter(eol: '\n').convert(content);
      if (list.isEmpty) {
        setState(() => _rows = []);
        _runAnalyze();
        return;
      }
      final headers = list.first.map((e) => e.toString().trim()).toList();
      final rows = <Map<String, dynamic>>[];
      for (var i = 1; i < list.length; i++) {
        final map = <String, dynamic>{};
        for (var j = 0; j < headers.length && j < list[i].length; j++) {
          map[headers[j]] = list[i][j]?.toString();
        }
        rows.add(map);
      }
      setState(() => _rows = rows);
      _runAnalyze();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _runAnalyze() {
    if (_rows == null) return;
    final useCase = ref.read(protocolImportUseCaseProvider);
    final review = useCase.analyzeProtocolFile(_rows!, existingTrialId: widget.trial?.id);
    setState(() => _review = review);
  }

  Future<void> _runImport() async {
    if (_review == null || !_review!.canProceed) return;
    final useCase = ref.read(protocolImportUseCaseProvider);
    final locked = widget.trial != null && isProtocolLocked(widget.trial!.status);

    setState(() => _isLoading = true);
    final result = await useCase.execute(
      review: _review!,
      existingTrialId: widget.trial?.id,
      isProtocolLocked: locked,
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _executeResult = result;
      if (result.success) {
        _rows = null;
        _fileName = null;
        _review = null;
      }
    });
    if (result.success && result.trialId != null && widget.trial == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Trial created. ID: ${result.trialId}')),
      );
    }
  }
}
