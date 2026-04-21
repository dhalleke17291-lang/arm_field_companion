import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/plot_analysis_eligibility.dart';
import '../../data/repositories/application_repository.dart';
import '../../data/repositories/application_product_repository.dart';
import '../../data/repositories/assignment_repository.dart';
import '../../data/repositories/notes_repository.dart';
import '../../data/repositories/treatment_repository.dart';
import '../../data/repositories/weather_snapshot_repository.dart';
import '../../domain/intelligence/trial_intelligence_service.dart';
import '../../domain/models/trial_insight.dart';
import '../photos/photo_repository.dart';
import '../plots/plot_repository.dart';
import '../ratings/rating_repository.dart';
import '../sessions/session_repository.dart';
import '../sessions/session_timing_helper.dart';

class ExportTrialJsonUseCase {
  ExportTrialJsonUseCase({
    required PlotRepository plotRepository,
    required TreatmentRepository treatmentRepository,
    required ApplicationRepository applicationRepository,
    required ApplicationProductRepository applicationProductRepository,
    required SessionRepository sessionRepository,
    required AssignmentRepository assignmentRepository,
    required RatingRepository ratingRepository,
    required NotesRepository notesRepository,
    required PhotoRepository photoRepository,
    required WeatherSnapshotRepository weatherSnapshotRepository,
    required TrialIntelligenceService intelligenceService,
  })  : _plotRepo = plotRepository,
        _treatmentRepo = treatmentRepository,
        _applicationRepo = applicationRepository,
        _applicationProductRepo = applicationProductRepository,
        _sessionRepo = sessionRepository,
        _assignmentRepo = assignmentRepository,
        _ratingRepo = ratingRepository,
        _notesRepo = notesRepository,
        _photoRepo = photoRepository,
        _weatherRepo = weatherSnapshotRepository,
        _intelligenceService = intelligenceService;

  final PlotRepository _plotRepo;
  final TreatmentRepository _treatmentRepo;
  final ApplicationRepository _applicationRepo;
  final ApplicationProductRepository _applicationProductRepo;
  final SessionRepository _sessionRepo;
  final AssignmentRepository _assignmentRepo;
  final RatingRepository _ratingRepo;
  final NotesRepository _notesRepo;
  final PhotoRepository _photoRepo;
  final WeatherSnapshotRepository _weatherRepo;
  final TrialIntelligenceService _intelligenceService;

  Future<String> buildJson({required Trial trial}) async {
    final plots = await _plotRepo.getPlotsForTrial(trial.id);
    final dataPlots = plots.where(isAnalyzablePlot).toList();
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
    final photos = await _photoRepo.getPhotosForTrial(trial.id);

    final plotToTreatment = <int, int>{};
    for (final a in assignments) {
      if (a.treatmentId != null) plotToTreatment[a.plotId] = a.treatmentId!;
    }
    final treatmentById = {for (final t in treatments) t.id: t};

    // Assessments
    final assessments = sessions.isNotEmpty
        ? await _sessionRepo.getSessionAssessments(sessions.first.id)
        : <Assessment>[];

    // Intelligence
    List<TrialInsight> insights;
    try {
      insights = await _intelligenceService.computeInsights(
        trialId: trial.id,
        treatments: treatments,
      );
    } catch (_) {
      insights = [];
    }

    final data = <String, dynamic>{
      'exportVersion': '1.0',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'schemaVersion': 54,
      'trial': {
        'id': trial.id,
        'name': trial.name,
        'crop': trial.crop,
        'workspaceType': trial.workspaceType,
        'status': trial.status,
        'createdAt': trial.createdAt.toIso8601String(),
        'site': _buildSite(trial),
        'design': _buildDesign(trial, dataPlots),
        'treatments': [
          for (final t in treatments)
            _buildTreatment(t, componentsByTreatment[t.id] ?? []),
        ],
        'applications': await _buildApplications(applications),
        'sessions': await _buildSessions(
          trial, sessions, assessments, assignments,
          plotToTreatment, treatmentById, dataPlots,
        ),
        'fieldNotes': [
          for (final n in notes) _buildNote(n),
        ],
        'photosManifest': [
          for (final p in photos) _buildPhoto(p),
        ],
        'completeness': _buildCompleteness(
          trial, sessions, dataPlots, assessments, photos,
        ),
        'insights': [
          for (final i in insights) _buildInsight(i),
        ],
      },
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> execute({required Trial trial}) async {
    final json = await buildJson(trial: trial);
    final dir = await getTemporaryDirectory();
    final safeName = trial.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final path = '${dir.path}/TrialExport_${safeName}_$timestamp.json';
    final file = File(path);
    await file.writeAsString(json);

    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/json')],
      text: '${trial.name} — JSON Export',
    );
  }

  Map<String, dynamic> _buildSite(Trial trial) => {
        'location': trial.location,
        'season': trial.season,
        'cultivar': trial.cultivar,
        'rowSpacingCm': trial.rowSpacingCm,
        'plantSpacingCm': trial.plantSpacingCm,
      };

  Map<String, dynamic> _buildDesign(Trial trial, List<Plot> dataPlots) {
    final reps = dataPlots.map((p) => p.rep).whereType<int>().toSet();
    return {
      'type': trial.experimentalDesign ?? 'RCBD',
      'plotCount': dataPlots.length,
      'repCount': reps.length,
    };
  }

  Map<String, dynamic> _buildTreatment(
      Treatment t, List<TreatmentComponent> components) => {
        'id': t.id,
        'code': t.code,
        'name': t.name,
        'type': t.treatmentType,
        'components': [
          for (final c in components)
            {
              'productName': c.productName,
              'activeIngredient': c.activeIngredientName,
              'rate': c.labelRate,
              'rateUnit': c.labelRateUnit,
              'isTestProduct': c.isTestProduct,
            },
        ],
      };

  Future<List<Map<String, dynamic>>> _buildApplications(
      List<TrialApplicationEvent> applications) async {
    final result = <Map<String, dynamic>>[];
    for (final app in applications) {
      final products =
          await _applicationProductRepo.getProductsForEvent(app.id);
      result.add({
        'id': app.id,
        'date': DateFormat('yyyy-MM-dd').format(app.applicationDate),
        'status': app.status,
        'method': app.applicationMethod,
        'growthStage': app.growthStageCode,
        'weather': {
          'temperature': app.temperature,
          'humidity': app.humidity,
          'windSpeed': app.windSpeed,
          'windDirection': app.windDirection,
        },
        'equipment': {
          'method': app.applicationMethod,
          'nozzleType': app.nozzleType,
          'pressure': app.operatingPressure,
          'pressureUnit': app.pressureUnit,
          'groundSpeed': app.groundSpeed,
          'speedUnit': app.speedUnit,
        },
        'products': [
          for (final p in products)
            {
              'productName': p.productName,
              'actualRate': p.rate,
              'plannedRate': p.plannedRate,
              'rateUnit': p.rateUnit,
              'deviationFlag': p.deviationFlag,
            },
        ],
      });
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _buildSessions(
    Trial trial,
    List<Session> sessions,
    List<Assessment> assessments,
    List<Assignment> assignments,
    Map<int, int> plotToTreatment,
    Map<int, Treatment> treatmentById,
    List<Plot> dataPlots,
  ) async {
    final result = <Map<String, dynamic>>[];
    for (final s in sessions) {
      final ratings = await _ratingRepo.getCurrentRatingsForSession(s.id);
      final weather = await _weatherRepo.getWeatherSnapshotForParent(
        kWeatherParentTypeRatingSession, s.id);

      // Build timing
      final allApps =
          await _applicationRepo.getApplicationsForTrial(trial.id);
      const seeding = null; // Seeding lookup would require SeedingRepository
      final timing = buildSessionTimingContext(
        sessionStartedAt: s.startedAt,
        cropStageBbch: s.cropStageBbch,
        seeding: seeding,
        applications: allApps,
      );

      // Group ratings by plot
      final ratingsByPlot = <int, List<RatingRecord>>{};
      for (final r in ratings) {
        ratingsByPlot.putIfAbsent(r.plotPk, () => []).add(r);
      }

      result.add({
        'id': s.id,
        'name': s.name,
        'date': s.sessionDateLocal,
        'rater': s.raterName,
        'bbch': s.cropStageBbch,
        'dat': timing.daysAfterFirstApp != null
            ? '${timing.daysAfterFirstApp} DAT'
            : null,
        'das': timing.daysAfterSeeding != null
            ? '${timing.daysAfterSeeding} DAS'
            : null,
        'cropInjuryStatus': s.cropInjuryStatus,
        'cropInjuryNotes': s.cropInjuryNotes,
        'weather': weather != null
            ? {
                'temperature': weather.temperature,
                'temperatureUnit': weather.temperatureUnit,
                'humidity': weather.humidity,
                'windSpeed': weather.windSpeed,
                'windDirection': weather.windDirection,
                'cloudCover': weather.cloudCover,
              }
            : null,
        'ratings': [
          for (final plot in dataPlots)
            if (ratingsByPlot.containsKey(plot.id))
              {
                'plotId': plot.plotId,
                'rep': plot.rep,
                'treatmentId': plotToTreatment[plot.id],
                'treatmentCode':
                    treatmentById[plotToTreatment[plot.id]]?.code,
                'assessments': {
                  for (final r in ratingsByPlot[plot.id]!)
                    if (r.numericValue != null)
                      '${r.assessmentId}': r.numericValue,
                },
              },
        ],
      });
    }
    return result;
  }

  Map<String, dynamic> _buildNote(Note n) => {
        'date': n.createdAt.toIso8601String(),
        'text': n.content,
        'plotPk': n.plotPk,
        'sessionId': n.sessionId,
      };

  Map<String, dynamic> _buildPhoto(Photo p) => {
        'filename': p.filePath.split('/').last,
        'plotPk': p.plotPk,
        'sessionId': p.sessionId,
        'assessmentId': p.assessmentId,
        'ratingValue': p.ratingValue,
        'timestamp': p.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _buildCompleteness(
    Trial trial,
    List<Session> sessions,
    List<Plot> dataPlots,
    List<Assessment> assessments,
    List<Photo> photos,
  ) {
    final bbchRecorded =
        sessions.where((s) => s.cropStageBbch != null).length;
    final cropInjuryRecorded =
        sessions.where((s) => s.cropInjuryStatus != null).length;
    return {
      'sessions': {'complete': sessions.length, 'total': sessions.length},
      'bbchCoverage': {'recorded': bbchRecorded, 'total': sessions.length},
      'cropInjuryCoverage': {
        'recorded': cropInjuryRecorded,
        'total': sessions.length,
      },
      'photoCount': photos.length,
    };
  }

  Map<String, dynamic> _buildInsight(TrialInsight i) => {
        'category': i.type.name,
        'severity': i.severity.name,
        'title': i.title,
        'detail': i.detail,
        'confidence': i.basis.confidenceLabel,
        'method': i.basis.method,
      };
}
