import '../../core/database/app_database.dart';
import '../../data/repositories/assignment_repository.dart';
import '../../data/repositories/treatment_repository.dart';
import '../../features/plots/plot_repository.dart';
import '../../features/ratings/rating_repository.dart';
import '../../features/sessions/session_repository.dart';
import 'csv_export_service.dart';

/// Snapshot of a single session used for row assembly. Pure data — no repos.
class SessionRatingsSnapshot {
  const SessionRatingsSnapshot({
    required this.session,
    required this.assessments,
    required this.ratings,
  });

  final Session session;
  final List<Assessment> assessments;
  final List<RatingRecord> ratings;
}

/// Lightweight trial-wide ratings share — CSV file and TSV-to-clipboard.
///
/// Intentionally narrower than [ExportTrialUsecase]: one analyzable rating
/// table, no ARM handoff bundle, no photos, no validation report. The row
/// assembly is a pure static method so unit tests can exercise it without
/// a database.
class ExportTrialRatingsShareUsecase {
  ExportTrialRatingsShareUsecase({
    required SessionRepository sessionRepository,
    required RatingRepository ratingRepository,
    required PlotRepository plotRepository,
    required TreatmentRepository treatmentRepository,
    required AssignmentRepository assignmentRepository,
  })  : _sessionRepo = sessionRepository,
        _ratingRepo = ratingRepository,
        _plotRepo = plotRepository,
        _treatmentRepo = treatmentRepository,
        _assignmentRepo = assignmentRepository;

  final SessionRepository _sessionRepo;
  final RatingRepository _ratingRepo;
  final PlotRepository _plotRepo;
  final TreatmentRepository _treatmentRepo;
  final AssignmentRepository _assignmentRepo;

  /// Long-format schema. One row per (session × plot × assessment) rating.
  static const List<String> headers = [
    'trial_name',
    'session_name',
    'session_date',
    'plot_id',
    'plot_label',
    'rep',
    'treatment_code',
    'treatment_name',
    'assessment_name',
    'assessment_type',
    'value',
    'unit',
    'rater',
    'rated_at',
  ];

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Builds a long-format CSV of every rating across every session in the
  /// trial. UTF-8 BOM prepended so Excel opens it correctly.
  Future<String> buildCsv(Trial trial) async {
    final rows = await _fetchAndAssembleRows(trial);
    return CsvExportService.buildCsv(headers, rows, utf8BomForExcel: true);
  }

  /// Same data as [buildCsv], tab-delimited. Designed to be pasted directly
  /// into Excel/Sheets/Numbers from the clipboard. No BOM — clipboard text
  /// should not carry byte-order marks.
  Future<String> buildTsv(Trial trial) async {
    final rows = await _fetchAndAssembleRows(trial);
    return buildTsvString(headers, rows);
  }

  // ---------------------------------------------------------------------------
  // Pure helpers — unit-testable without a database
  // ---------------------------------------------------------------------------

  /// Assembles rating rows from pre-fetched data. Pure function.
  ///
  /// Order: sessions in the order given, plots within a session ordered by
  /// the [ratings] list's natural order. Assumes caller has already grouped
  /// assessments into [SessionRatingsSnapshot.assessments] per session.
  static List<List<String>> buildRows({
    required Trial trial,
    required List<SessionRatingsSnapshot> sessionSnapshots,
    required Map<int, Plot> plotMap,
    required Map<int, Treatment> treatmentMap,
    required Map<int, Assignment> assignmentByPlot,
  }) {
    final rows = <List<String>>[];
    for (final snap in sessionSnapshots) {
      final assessmentMap = {for (final a in snap.assessments) a.id: a};
      for (final r in snap.ratings) {
        final plot = plotMap[r.plotPk];
        final assignment = plot != null ? assignmentByPlot[plot.id] : null;
        final treatmentId = assignment?.treatmentId ?? plot?.treatmentId;
        final treatment =
            treatmentId != null ? treatmentMap[treatmentId] : null;
        final assessment = assessmentMap[r.assessmentId];

        final valueCell = r.numericValue != null
            ? _num(r.numericValue!)
            : (r.textValue ?? '');

        rows.add([
          trial.name,
          snap.session.name,
          snap.session.sessionDateLocal,
          plot != null ? plot.id.toString() : '',
          plot?.plotId ?? '',
          _intOrEmpty(assignment?.replication ?? plot?.rep),
          treatment?.code ?? '',
          treatment?.name ?? '',
          assessment?.name ?? '',
          assessment?.dataType ?? '',
          valueCell,
          assessment?.unit ?? '',
          r.raterName ?? '',
          r.createdAt.toIso8601String(),
        ]);
      }
    }
    return rows;
  }

  /// Pure TSV writer. Replaces any tab/newline inside a cell with a single
  /// space — pasted cells must not split or wrap.
  static String buildTsvString(
    List<String> headers,
    List<List<String>> rows,
  ) {
    final buf = StringBuffer();
    buf.writeln(headers.map(_tsvSafe).join('\t'));
    for (final row in rows) {
      buf.writeln(row.map(_tsvSafe).join('\t'));
    }
    return buf.toString();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<List<List<String>>> _fetchAndAssembleRows(Trial trial) async {
    final sessions = await _sessionRepo.getSessionsForTrial(trial.id);
    final plots = await _plotRepo.getPlotsForTrial(trial.id);
    final treatments = await _treatmentRepo.getTreatmentsForTrial(trial.id);
    final assignments = await _assignmentRepo.getForTrial(trial.id);

    final plotMap = {for (final p in plots) p.id: p};
    final treatmentMap = {for (final t in treatments) t.id: t};
    final assignmentByPlot = {for (final a in assignments) a.plotId: a};

    final snapshots = <SessionRatingsSnapshot>[];
    for (final s in sessions) {
      final assessments = await _sessionRepo.getSessionAssessments(s.id);
      final ratings =
          await _ratingRepo.getCurrentRatingsForSession(s.id);
      snapshots.add(SessionRatingsSnapshot(
        session: s,
        assessments: assessments,
        ratings: ratings,
      ));
    }

    return buildRows(
      trial: trial,
      sessionSnapshots: snapshots,
      plotMap: plotMap,
      treatmentMap: treatmentMap,
      assignmentByPlot: assignmentByPlot,
    );
  }

  static String _num(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }

  static String _intOrEmpty(int? v) => v?.toString() ?? '';

  static String _tsvSafe(String v) =>
      v.replaceAll(RegExp(r'[\t\n\r]'), ' ');
}
