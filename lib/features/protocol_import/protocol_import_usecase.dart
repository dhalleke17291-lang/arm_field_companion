import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../data/repositories/treatment_repository.dart';
import '../../data/repositories/assignment_repository.dart';
import '../plots/plot_repository.dart';
import '../trials/trial_repository.dart';
import 'protocol_import_models.dart';

/// Full protocol import: Source Detection → Structural Scan → Mapping → Validation → Review → User Approval → Integration (Charter PART 16).
class ProtocolImportUseCase {
  final TrialRepository _trialRepository;
  final TreatmentRepository _treatmentRepository;
  final PlotRepository _plotRepository;
  final AssignmentRepository _assignmentRepository;

  ProtocolImportUseCase(
    this._trialRepository,
    this._treatmentRepository,
    this._plotRepository,
    this._assignmentRepository,
  );

  /// [existingTrialId] if adding to existing trial; null to create new trial from TRIAL section.
  ProtocolImportReviewResult analyzeProtocolFile(
    List<Map<String, dynamic>> rows, {
    int? existingTrialId,
  }) {
    if (rows.isEmpty) {
      return const ProtocolImportReviewResult(
        trialSection:
            SectionReview(matchedCount: 0, mustFix: ['No rows in file']),
        treatmentSection: SectionReview(matchedCount: 0),
        plotSection: SectionReview(matchedCount: 0),
        assignmentSection: SectionReview(matchedCount: 0),
      );
    }

    final sectionKey = _detectSectionColumn(rows.first);
    if (sectionKey == null) {
      return const ProtocolImportReviewResult(
        trialSection: SectionReview(matchedCount: 0, mustFix: [
          'Required column "section" (or "type") missing. Values: TRIAL, TREATMENT, PLOT'
        ]),
        treatmentSection: SectionReview(matchedCount: 0),
        plotSection: SectionReview(matchedCount: 0),
        assignmentSection: SectionReview(matchedCount: 0),
      );
    }

    final trialRows = <Map<String, dynamic>>[];
    final treatmentRows = <Map<String, dynamic>>[];
    final plotRows = <Map<String, dynamic>>[];

    for (final row in rows) {
      final s = row[sectionKey]?.toString().trim().toUpperCase();
      if (s == kSectionTrial) {
        trialRows.add(row);
      } else if (s == kSectionTreatment) {
        treatmentRows.add(row);
      } else if (s == kSectionPlot) {
        plotRows.add(row);
      }
    }

    final trialReview = _analyzeTrialSection(trialRows, existingTrialId);
    final treatmentReview = _analyzeTreatmentSection(treatmentRows);
    final plotReview = _analyzePlotSection(plotRows);
    final treatmentCodes =
        treatmentReview.normalized.map((e) => e['code'] as String).toSet();
    final assignmentReview =
        _analyzeAssignmentSection(plotRows, treatmentCodes);

    return ProtocolImportReviewResult(
      trialSection: trialReview.sectionReview,
      treatmentSection: treatmentReview.sectionReview,
      plotSection: plotReview.sectionReview,
      assignmentSection: assignmentReview.sectionReview,
      normalizedTrial: trialReview.normalized,
      normalizedTreatments: treatmentReview.normalized,
      normalizedPlots: plotReview.normalized,
    );
  }

  String? _detectSectionColumn(Map<String, dynamic> firstRow) {
    final keys =
        firstRow.keys.map((k) => k.toString().trim().toLowerCase()).toList();
    if (keys.contains('section'))
      return firstRow.keys
          .firstWhere((k) => k.toString().trim().toLowerCase() == 'section');
    if (keys.contains('type'))
      return firstRow.keys
          .firstWhere((k) => k.toString().trim().toLowerCase() == 'type');
    return null;
  }

  ({SectionReview sectionReview, Map<String, dynamic>? normalized})
      _analyzeTrialSection(
    List<Map<String, dynamic>> rows,
    int? existingTrialId,
  ) {
    final mustFix = <String>[];
    final autoHandled = <String>[];
    if (existingTrialId != null) {
      if (rows.isNotEmpty)
        autoHandled.add('TRIAL section ignored (adding to existing trial)');
      return (
        sectionReview: SectionReview(matchedCount: 0, autoHandled: autoHandled),
        normalized: null
      );
    }
    if (rows.isEmpty) {
      mustFix.add(
          'TRIAL section missing. Add one row with section=TRIAL and trial_name.');
      return (
        sectionReview: SectionReview(matchedCount: 0, mustFix: mustFix),
        normalized: null
      );
    }
    if (rows.length > 1) {
      mustFix.add('TRIAL section must have exactly one row.');
      return (
        sectionReview: SectionReview(matchedCount: 0, mustFix: mustFix),
        normalized: null
      );
    }
    final row = rows.single;
    final name = row['trial_name']?.toString().trim() ??
        row['trial name']?.toString().trim();
    if (name == null || name.isEmpty) {
      mustFix.add('TRIAL row: trial_name is required.');
      return (
        sectionReview: SectionReview(matchedCount: 0, mustFix: mustFix),
        normalized: null
      );
    }
    final normalized = <String, dynamic>{
      'trial_name': name,
      'crop': row['crop']?.toString().trim(),
      'location': row['location']?.toString().trim(),
      'season': row['season']?.toString().trim(),
    };
    return (
      sectionReview: const SectionReview(matchedCount: 1),
      normalized: normalized
    );
  }

  ({SectionReview sectionReview, List<Map<String, dynamic>> normalized})
      _analyzeTreatmentSection(
    List<Map<String, dynamic>> rows,
  ) {
    final mustFix = <String>[];
    final autoHandled = <String>[];
    final normalized = <Map<String, dynamic>>[];
    final codes = <String>{};

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final code = row['code']?.toString().trim();
      final name = row['name']?.toString().trim();
      if (code == null || code.isEmpty) {
        mustFix.add('TREATMENT row ${i + 1}: code is required.');
        continue;
      }
      if (name == null || name.isEmpty) {
        mustFix.add('TREATMENT row ${i + 1}: name is required.');
        continue;
      }
      if (codes.contains(code)) {
        mustFix.add('TREATMENT: duplicate code "$code".');
        continue;
      }
      codes.add(code);
      normalized.add({
        'code': code,
        'name': name,
        'description': row['description']?.toString().trim(),
      });
    }

    return (
      sectionReview: SectionReview(
        matchedCount: normalized.length,
        autoHandled: autoHandled,
        mustFix: mustFix,
      ),
      normalized: normalized,
    );
  }

  ({SectionReview sectionReview, List<Map<String, dynamic>> normalized})
      _analyzePlotSection(
    List<Map<String, dynamic>> rows,
  ) {
    final mustFix = <String>[];
    final autoHandled = <String>[];
    final normalized = <Map<String, dynamic>>[];
    final plotIds = <String>{};

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final plotId = row['plot_id']?.toString().trim() ??
          row['plot']?.toString().trim() ??
          row['Plot']?.toString().trim();
      if (plotId == null || plotId.isEmpty) {
        mustFix.add('PLOT row ${i + 1}: plot_id is required.');
        continue;
      }
      if (plotIds.contains(plotId)) {
        mustFix.add('PLOT: duplicate plot_id "$plotId".');
        continue;
      }
      plotIds.add(plotId);
      final treatmentCode = row['treatment_code']?.toString().trim() ??
          row['treatment']?.toString().trim();
      normalized.add({
        'plot_id': plotId,
        'rep': row['rep'] != null ? int.tryParse(row['rep'].toString()) : null,
        'row': row['row']?.toString(),
        'column': row['column']?.toString(),
        'plot_sort_index': row['plot_sort_index'] != null
            ? int.tryParse(row['plot_sort_index'].toString())
            : (i + 1),
        'treatment_code':
            treatmentCode?.isNotEmpty == true ? treatmentCode : null,
      });
    }

    return (
      sectionReview: SectionReview(
        matchedCount: normalized.length,
        autoHandled: autoHandled,
        mustFix: mustFix,
      ),
      normalized: normalized,
    );
  }

  ({SectionReview sectionReview}) _analyzeAssignmentSection(
    List<Map<String, dynamic>> plotRows,
    Set<String> treatmentCodes,
  ) {
    int matched = 0;
    final mustFix = <String>[];
    for (final row in plotRows) {
      final tc = row['treatment_code']?.toString().trim() ??
          row['treatment']?.toString().trim();
      if (tc == null || tc.isEmpty) continue;
      if (treatmentCodes.contains(tc)) {
        matched++;
      } else {
        mustFix.add(
            'PLOT references treatment_code "$tc" which is not in TREATMENT section.');
      }
    }
    return (
      sectionReview: SectionReview(
        matchedCount: matched,
        mustFix: mustFix,
      ),
    );
  }

  /// Execute after user approval. [existingTrialId] when adding to existing trial; null when creating from file.
  Future<ProtocolImportExecuteResult> execute({
    required ProtocolImportReviewResult review,
    required int? existingTrialId,
    bool isProtocolLocked = false,
    String? protocolLockMessage,
  }) async {
    if (isProtocolLocked) {
      return ProtocolImportExecuteResult.failure(protocolLockMessage ??
          'Protocol is locked. Change trial status to import.');
    }
    if (!review.canProceed) {
      return ProtocolImportExecuteResult.failure(
          'Import has errors. Resolve Must Fix items before importing.');
    }

    try {
      int trialId = existingTrialId ?? -1;

      if (existingTrialId == null && review.normalizedTrial != null) {
        final t = review.normalizedTrial!;
        trialId = await _trialRepository.createTrial(
          name: t['trial_name'] as String,
          crop: t['crop'] as String?,
          location: t['location'] as String?,
          season: t['season'] as String?,
        );
      } else if (existingTrialId == null) {
        return ProtocolImportExecuteResult.failure(
            'No trial to create and no existing trial selected.');
      }

      final codeToId = <String, int>{};
      for (final tr in review.normalizedTreatments) {
        final id = await _treatmentRepository.insertTreatment(
          trialId: trialId,
          code: tr['code'] as String,
          name: tr['name'] as String,
          description: tr['description'] as String?,
        );
        codeToId[tr['code'] as String] = id;
      }

      if (review.normalizedPlots.isEmpty) {
        return ProtocolImportExecuteResult.ok(
          trialId: trialId,
          treatmentsImported: review.normalizedTreatments.length,
          plotsImported: 0,
        );
      }

      // Insert plots in CSV order; layout position is preserved (no sort by treatment).
      final companions = <PlotsCompanion>[];
      for (var i = 0; i < review.normalizedPlots.length; i++) {
        final p = review.normalizedPlots[i];
        companions.add(PlotsCompanion.insert(
          trialId: trialId,
          plotId: p['plot_id'] as String,
          plotSortIndex: Value(p['plot_sort_index'] as int? ?? (i + 1)),
          rep: Value(p['rep'] as int?),
          row: Value(p['row'] as String?),
          column: Value(p['column'] as String?),
        ));
      }
      await _plotRepository.insertPlotsBulk(companions);

      // Apply treatment assignment via Assignments table (randomization preserved).
      for (final p in review.normalizedPlots) {
        final treatmentCode = p['treatment_code'] as String?;
        if (treatmentCode == null) continue;
        final tid = codeToId[treatmentCode];
        if (tid == null) continue;
        final plot = await _plotRepository.getPlotByPlotId(
            trialId, p['plot_id'] as String);
        if (plot != null) {
          await _assignmentRepository.upsert(
            trialId: trialId,
            plotId: plot.id,
            treatmentId: tid,
            replication: plot.rep,
            range: plot.fieldRow,
            column: plot.fieldColumn,
            assignmentSource: 'imported',
            assignedAt: DateTime.now().toUtc(),
          );
        }
      }

      return ProtocolImportExecuteResult.ok(
        trialId: trialId,
        treatmentsImported: review.normalizedTreatments.length,
        plotsImported: review.normalizedPlots.length,
      );
    } catch (e) {
      return ProtocolImportExecuteResult.failure('Import failed: $e');
    }
  }
}
