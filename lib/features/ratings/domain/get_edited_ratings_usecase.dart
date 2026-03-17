import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/plot_display.dart';
import '../../plots/plot_repository.dart';
import '../../sessions/session_repository.dart';
import '../../trials/trial_repository.dart';

/// One row for the Edited Items screen (read-only aggregate).
class EditedRatingListItem {
  const EditedRatingListItem({
    required this.rating,
    required this.trialName,
    required this.sessionName,
    required this.plotLabel,
    this.assessmentLabel,
    required this.hasCorrection,
  });

  final RatingRecord rating;
  final String trialName;
  final String sessionName;
  final String plotLabel;
  final String? assessmentLabel;
  final bool hasCorrection;

  /// Shown when [hasCorrection] is true; otherwise amended/chain edits.
  String get statusLabel => hasCorrection ? 'Corrected' : 'Amended';

  DateTime get displayDate => rating.amendedAt ?? rating.createdAt;
}

/// Read-only: ratings that are amended, part of a save chain, and/or corrected.
class GetEditedRatingsUseCase {
  GetEditedRatingsUseCase({
    required AppDatabase db,
    required TrialRepository trialRepo,
    required SessionRepository sessionRepo,
    required PlotRepository plotRepo,
  })  : _db = db,
        _trialRepo = trialRepo,
        _sessionRepo = sessionRepo,
        _plotRepo = plotRepo;

  final AppDatabase _db;
  final TrialRepository _trialRepo;
  final SessionRepository _sessionRepo;
  final PlotRepository _plotRepo;

  Future<List<EditedRatingListItem>> call() async {
    final amendedOrChain = await (_db.select(_db.ratingRecords)
          ..where((r) =>
              r.isDeleted.equals(false) &
              (r.amended.equals(true) | r.previousId.isNotNull())))
        .get();

    final correctionRows = await _db.select(_db.ratingCorrections).get();
    final correctionRatingIds =
        correctionRows.map((c) => c.ratingId).toSet();

    final byId = <int, RatingRecord>{
      for (final r in amendedOrChain) r.id: r,
    };

    final missingForCorrection =
        correctionRatingIds.difference(byId.keys.toSet());
    if (missingForCorrection.isNotEmpty) {
      final extra = await (_db.select(_db.ratingRecords)
            ..where((r) =>
                r.id.isIn(missingForCorrection.toList()) &
                r.isDeleted.equals(false)))
          .get();
      for (final r in extra) {
        byId[r.id] = r;
      }
    }

    final ratings = byId.values.toList()
      ..sort((a, b) {
        final da = a.amendedAt ?? a.createdAt;
        final db_ = b.amendedAt ?? b.createdAt;
        return db_.compareTo(da);
      });

    final assessIds = ratings.map((r) => r.assessmentId).toSet();
    final assessmentNames = <int, String>{};
    if (assessIds.isNotEmpty) {
      final rows = await (_db.select(_db.assessments)
            ..where((a) => a.id.isIn(assessIds.toList())))
          .get();
      for (final row in rows) {
        assessmentNames[row.id] = row.name;
      }
    }

    final items = <EditedRatingListItem>[];
    for (final r in ratings) {
      items.add(
        EditedRatingListItem(
          rating: r,
          trialName: await _resolveTrialName(r.trialId),
          sessionName: await _resolveSessionName(r.sessionId),
          plotLabel: await _resolvePlotLabel(r.trialId, r.plotPk),
          assessmentLabel: assessmentNames[r.assessmentId],
          hasCorrection: correctionRatingIds.contains(r.id),
        ),
      );
    }
    return items;
  }

  Future<String> _resolveTrialName(int trialId) async {
    final t = await _trialRepo.getTrialById(trialId) ??
        await _trialRepo.getDeletedTrialById(trialId);
    return (t?.name != null && t!.name.isNotEmpty) ? t.name : 'Trial $trialId';
  }

  Future<String> _resolveSessionName(int sessionId) async {
    final s = await _sessionRepo.getSessionById(sessionId) ??
        await _sessionRepo.getDeletedSessionById(sessionId);
    return (s?.name != null && s!.name.isNotEmpty) ? s.name : 'Session $sessionId';
  }

  Future<String> _resolvePlotLabel(int trialId, int plotPk) async {
    final plots = await _plotRepo.getPlotsForTrial(trialId);
    Plot? plot;
    for (final p in plots) {
      if (p.id == plotPk) {
        plot = p;
        break;
      }
    }
    if (plot != null) {
      return getDisplayPlotLabel(plot, plots);
    }
    final deleted = await _plotRepo.getDeletedPlotByPk(plotPk);
    if (deleted != null) {
      return deleted.plotId.isNotEmpty
          ? deleted.plotId
          : getDisplayPlotNumberFallback(deleted);
    }
    return 'P$plotPk';
  }
}
