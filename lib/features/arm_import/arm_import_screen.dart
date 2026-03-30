import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../trials/trial_detail_screen.dart';
import 'domain/results/arm_import_result.dart';

/// Minimal entry point: pick an ARM CSV and run [ArmImportUseCase.execute].
class ArmImportScreen extends ConsumerStatefulWidget {
  const ArmImportScreen({super.key});

  @override
  ConsumerState<ArmImportScreen> createState() => _ArmImportScreenState();
}

class _ArmImportScreenState extends ConsumerState<ArmImportScreen> {
  bool _busy = false;
  ArmImportResult? _result;

  Future<void> _pickAndImport() async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (pick == null || pick.files.isEmpty) return;

    final file = pick.files.first;
    final fileName = file.name;
    String content;
    if (file.path != null) {
      content = await File(file.path!).readAsString();
    } else if (file.bytes != null) {
      content = utf8.decode(file.bytes!);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read the selected file.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final r = await ref.read(armImportUseCaseProvider).execute(
            content,
            sourceFileName: fileName,
          );
      if (!mounted) return;
      setState(() => _result = r);
      if (r.success) {
        ref.invalidate(trialsStreamProvider);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = ArmImportResult.failure('ARM import failed: $e');
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openCreatedTrial(ArmImportResult r) async {
    final id = r.trialId;
    if (id == null) return;
    final trial = await ref.read(trialRepositoryProvider).getTrialById(id);
    if (!mounted) return;
    if (trial == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trial could not be loaded.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TrialDetailScreen(trial: trial),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EB),
      appBar: const GradientScreenHeader(
        title: 'Import ARM Trial',
        titleFontSize: 18,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _pickAndImport,
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(_busy ? 'Importing…' : 'Select ARM CSV File'),
              ),
            ),
            if (!_busy && _result != null) ...[
              const SizedBox(height: 24),
              _buildOutcome(context, theme, _result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOutcome(
    BuildContext context,
    ThemeData theme,
    ArmImportResult r,
  ) {
    if (!r.success) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import failed',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            r.errorMessage ?? 'Unknown error',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Import complete',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text('Confidence: ${r.confidence.name}'),
        Text('Plots detected: ${r.plotCount ?? '—'}'),
        Text('Treatments detected: ${r.treatmentCount ?? '—'}'),
        Text('Assessments detected: ${r.assessmentCount ?? '—'}'),
        if (r.warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Warnings',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ...r.warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('· $w'),
            ),
          ),
        ],
        if (r.unknownPatterns.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Unknown patterns',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ...r.unknownPatterns.map(
            (u) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· ${u.type}: ${u.rawValue} (${u.severity.name}, '
                'export ${u.affectsExport ? 'affected' : 'not affected'})',
              ),
            ),
          ),
        ],
        if (r.trialId != null) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _openCreatedTrial(r),
              child: const Text('Open Trial'),
            ),
          ),
        ],
      ],
    );
  }
}
