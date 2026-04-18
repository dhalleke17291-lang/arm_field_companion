import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../trials/trial_detail_screen.dart';
import 'domain/enums/import_confidence.dart';
import 'domain/models/unknown_pattern_flag.dart';
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
        _result = ArmImportResult.failure('CSV import failed: $e');
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _exportReadinessLabel(ImportConfidence c) {
    switch (c) {
      case ImportConfidence.high:
        return 'Rating sheet export: Ready';
      case ImportConfidence.medium:
      case ImportConfidence.low:
        return 'Rating sheet export: Needs Review';
      case ImportConfidence.blocked:
        return 'Rating sheet export: Blocked';
    }
  }

  String _displayWarningForUi(String w) {
    if (w.contains('Rating sheet export may be blocked')) {
      return w.replaceFirst(
        'Rating sheet export may be blocked',
        'Rating sheet export is blocked until issues are resolved',
      );
    }
    return w;
  }

  String _structureIssueUserMessage(UnknownPatternFlag u) {
    switch (u.type) {
      case 'repeated-assessment-key':
        return 'Repeated assessment columns detected (${u.rawValue})';
      case 'repeated-semantic-assessment-key':
        return 'Same assessment identity on multiple columns (${u.rawValue}); '
            'each column is kept separate for export.';
      case 'duplicate-assessment-column-instance':
        return 'Duplicate assessment column instance (${u.rawValue}).';
      case 'missing-or-invalid-plot-number':
        return 'One or more rows have an invalid or missing plot number.';
      case 'duplicate-plot-number':
        return 'Duplicate plot number used: ${u.rawValue}.';
      case 'missing-treatment-number':
        return 'One or more rows are missing a treatment number.';
      case 'missing-rep':
        return 'One or more rows are missing a rep value.';
      case 'assessment_definition':
        final v = u.rawValue.trim();
        if (v.isEmpty) {
          return 'One or more assessment columns need review.';
        }
        return 'Assessment column needs review ($v).';
      default:
        final v = u.rawValue.trim();
        if (v.isEmpty) {
          return 'One or more structure issues need review.';
        }
        return 'Issue needs review: $v';
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
        title: 'Import Trial (CSV)',
        
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
                label: Text(_busy ? 'Importing…' : 'Select CSV File'),
              ),
            ),
            if (!_busy && _result != null) ...[
              const SizedBox(height: 24),
              _buildOutcome(context, theme, _result!),
            ],
          ],
        ),
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

    final repeatedAssessmentKeys = <String>{
      for (final u in r.unknownPatterns)
        if ((u.type == 'repeated-assessment-key' ||
                u.type == 'repeated-semantic-assessment-key') &&
            u.rawValue.trim().isNotEmpty)
          u.rawValue.trim(),
    };

    final bodyStyle = theme.textTheme.bodyMedium;
    final emphasis = bodyStyle?.copyWith(fontWeight: FontWeight.w600);
    final hasWarningsOrIssues = r.confidence != ImportConfidence.high ||
        r.warnings.isNotEmpty ||
        r.unknownPatterns.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasWarningsOrIssues
              ? 'Import Completed With Warnings'
              : 'Import Completed',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (!hasWarningsOrIssues)
          Text(
            'The trial was created from your file. You can continue field work.',
            style: bodyStyle,
          )
        else ...[
          Text(
            'The trial was created from your file.',
            style: bodyStyle,
          ),
          const SizedBox(height: 6),
          Text(
            'Some imported data may need review before rating sheet export.',
            style: bodyStyle,
          ),
        ],
        const SizedBox(height: 10),
        Text(
          _exportReadinessLabel(r.confidence),
          style: emphasis,
        ),
        const SizedBox(height: 8),
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
              child: Text('· ${_displayWarningForUi(w)}'),
            ),
          ),
        ],
        if (r.unknownPatterns.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Structure issues',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ...r.unknownPatterns.map(
            (u) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('· ${_structureIssueUserMessage(u)}'),
            ),
          ),
        ],
        if (repeatedAssessmentKeys.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Detected sessions',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ...(() {
            final sorted = repeatedAssessmentKeys.toList()..sort();
            return sorted.map(
              (key) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '· $key → multiple occurrences (treated as separate sessions)',
                ),
              ),
            );
          })(),
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
