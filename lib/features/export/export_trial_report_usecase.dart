import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/export_hash.dart';
import '../../data/repositories/application_repository.dart';
import '../../data/repositories/assignment_repository.dart';
import '../../data/repositories/notes_repository.dart';
import '../../data/repositories/treatment_repository.dart';
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
  })  : _plotRepo = plotRepository,
        _treatmentRepo = treatmentRepository,
        _applicationRepo = applicationRepository,
        _sessionRepo = sessionRepository,
        _assignmentRepo = assignmentRepository,
        _ratingRepo = ratingRepository,
        _notesRepo = notesRepository;

  final PlotRepository _plotRepo;
  final TreatmentRepository _treatmentRepo;
  final ApplicationRepository _applicationRepo;
  final SessionRepository _sessionRepo;
  final AssignmentRepository _assignmentRepo;
  final RatingRepository _ratingRepo;
  final NotesRepository _notesRepo;

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
