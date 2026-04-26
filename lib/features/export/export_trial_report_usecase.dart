import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/export_hash.dart';
import '../../core/ui/assessment_display_helper.dart';
import '../../data/repositories/application_repository.dart';
import '../../data/repositories/assessment_definition_repository.dart';
import '../../data/repositories/assignment_repository.dart';
import '../../data/repositories/notes_repository.dart';
import '../../data/repositories/treatment_repository.dart';
import '../../data/repositories/trial_assessment_repository.dart';
import '../plots/plot_repository.dart';
import '../ratings/rating_repository.dart';
import '../sessions/session_repository.dart';
import 'trial_report_pdf_builder.dart';

/// Assembles trial data and generates the Trial Report PDF (sections 1-5).
/// Shares via system share sheet.
class ExportTrialReportUseCase {
  ExportTrialReportUseCase({
    required PlotRepository plotRepository,
    required TreatmentRepository treatmentRepository,
    required ApplicationRepository applicationRepository,
    required SessionRepository sessionRepository,
    required AssignmentRepository assignmentRepository,
    required RatingRepository ratingRepository,
    required NotesRepository notesRepository,
    required TrialAssessmentRepository trialAssessmentRepository,
    required AssessmentDefinitionRepository assessmentDefinitionRepository,
  })  : _plotRepo = plotRepository,
        _treatmentRepo = treatmentRepository,
        _applicationRepo = applicationRepository,
        _sessionRepo = sessionRepository,
        _assignmentRepo = assignmentRepository,
        _ratingRepo = ratingRepository,
        _notesRepo = notesRepository,
        _trialAssessmentRepo = trialAssessmentRepository,
        _assessmentDefinitionRepo = assessmentDefinitionRepository;

  final PlotRepository _plotRepo;
  final TreatmentRepository _treatmentRepo;
  final ApplicationRepository _applicationRepo;
  final SessionRepository _sessionRepo;
  final AssignmentRepository _assignmentRepo;
  final RatingRepository _ratingRepo;
  final NotesRepository _notesRepo;
  final TrialAssessmentRepository _trialAssessmentRepo;
  final AssessmentDefinitionRepository _assessmentDefinitionRepo;

  Future<void> execute({required Trial trial}) async {
    final plots = await _plotRepo.getPlotsForTrial(trial.id);
    final treatments = await _treatmentRepo.getTreatmentsForTrial(trial.id);
    final componentsByTreatment = <int, List<TreatmentComponent>>{};
    for (final t in treatments) {
      componentsByTreatment[t.id] =
          await _treatmentRepo.getComponentsForTreatment(t.id);
    }
    final sessions = await _sessionRepo.getSessionsForTrial(trial.id);
    final applications =
        await _applicationRepo.getApplicationsForTrial(trial.id);
    final assignments = await _assignmentRepo.getForTrial(trial.id);
    final notes = await _notesRepo.getNotesForTrial(trial.id);

    // Collect all ratings across sessions.
    final allRatings = <RatingRecord>[];
    final assessmentSet = <int>{};
    for (final s in sessions) {
      final ratings = await _ratingRepo.getCurrentRatingsForSession(s.id);
      allRatings.addAll(ratings);
      for (final r in ratings) {
        assessmentSet.add(r.assessmentId);
      }
    }

    // Load assessments that appear in ratings.
    // Use the first session's assessments as the canonical list.
    final assessments = sessions.isNotEmpty
        ? await _sessionRepo.getSessionAssessments(sessions.first.id)
        : <Assessment>[];

    // Build description-first display names: compactName for linked
    // assessments, legacyAssessmentDisplayName for unlinked ones.
    // AAM fields (seDescription, seName) are not loaded here — the ARM
    // separation boundary prevents importing ArmColumnMappingRepository
    // into a generic export path. ARM shell-imported trials have
    // displayNameOverride set at import time, so compactName still
    // produces the correct string without AAM data.
    final trialAssessments =
        await _trialAssessmentRepo.getForTrial(trial.id);
    final allDefs =
        await _assessmentDefinitionRepo.getAll(activeOnly: false);
    final defById = <int, AssessmentDefinition>{
      for (final d in allDefs) d.id: d,
    };
    final assessmentDisplayNames = <int, String>{};
    for (final ta in trialAssessments) {
      final lid = ta.legacyAssessmentId;
      if (lid != null) {
        assessmentDisplayNames[lid] = AssessmentDisplayHelper.compactName(
          ta,
          def: defById[ta.assessmentDefinitionId],
        );
      }
    }
    for (final a in assessments) {
      if (!assessmentDisplayNames.containsKey(a.id)) {
        assessmentDisplayNames[a.id] =
            AssessmentDisplayHelper.legacyAssessmentDisplayName(a.name);
      }
    }

    final builder = TrialReportPdfBuilder();
    final bytes = await builder.build(
      trial: trial,
      plots: plots,
      treatments: treatments,
      componentsByTreatment: componentsByTreatment,
      sessions: sessions,
      ratings: allRatings,
      assessments: assessments,
      applications: applications,
      assignments: assignments,
      assessmentDisplayNames: assessmentDisplayNames,
      fieldNotes: notes,
    );

    final dir = await getTemporaryDirectory();
    final safeName =
        trial.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final timestamp =
        DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final path = '${dir.path}/TrialReport_${safeName}_$timestamp.pdf';
    final file = File(path);
    await file.writeAsBytes(bytes);

    // Compute and return hash for audit trail.
    final hash = await computeExportHash(file);

    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/pdf')],
      text: '${trial.name} — Trial Report\n${formatExportHash(hash)}',
    );
  }
}
