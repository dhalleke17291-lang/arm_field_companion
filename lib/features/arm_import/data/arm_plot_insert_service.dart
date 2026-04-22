import '../../../core/database/app_database.dart';
import '../../../core/protocol_edit_blocked_exception.dart';
import '../../../core/trial_state.dart';
import '../../plots/plot_repository.dart';
import '../../trials/trial_repository.dart';

/// Wraps [PlotRepository.insertPlotsBulk] with the same protocol guard as single-plot inserts.
class ArmPlotInsertService {
  ArmPlotInsertService(this._db, this._plotRepository, this._trialRepository);

  final AppDatabase _db;
  final PlotRepository _plotRepository;
  final TrialRepository _trialRepository;

  Future<void> insertPlotsForArmImport({
    required int trialId,
    required List<PlotsCompanion> plots,
  }) async {
    final trial = await _trialRepository.getTrialById(trialId);
    if (trial == null) {
      throw StateError('Trial not found');
    }
    final hasData = await trialHasAnySessionData(_db, trialId);
    final armLinked = await loadTrialIsArmLinked(_db, trialId);
    if (!canEditTrialStructure(
      trial,
      hasSessionData: hasData,
      trialIsArmLinked: armLinked,
    )) {
      throw ProtocolEditBlockedException(
        structureEditBlockedMessage(
          trial,
          hasSessionData: hasData,
          trialIsArmLinked: armLinked,
        ),
      );
    }
    await _plotRepository.insertPlotsBulk(plots);
  }
}
