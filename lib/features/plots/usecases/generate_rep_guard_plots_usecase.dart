import '../../../core/database/app_database.dart';
import '../../../core/protocol_edit_blocked_exception.dart';
import '../../../core/trial_state.dart';
import '../../trials/trial_repository.dart';
import '../plot_repository.dart';

/// V1: add G{rep}-L and G{rep}-R per layout rep (display + storage only).
class GenerateRepGuardPlotsUseCase {
  GenerateRepGuardPlotsUseCase(
    this._db,
    this._plotRepository,
    this._trialRepository,
  );

  final AppDatabase _db;
  final PlotRepository _plotRepository;
  final TrialRepository _trialRepository;

  Future<int> countToInsert(int trialId) async {
    final trial = await _trialRepository.getTrialById(trialId);
    if (trial == null) return 0;
    final hasData = await trialHasAnySessionData(_db, trialId);
    if (!canEditTrialStructure(trial, hasSessionData: hasData)) {
      throw ProtocolEditBlockedException(
        structureEditBlockedMessage(trial, hasSessionData: hasData),
      );
    }
    return _plotRepository.countRepGuardPlotsToInsert(trialId);
  }

  Future<int> execute(int trialId) async {
    final trial = await _trialRepository.getTrialById(trialId);
    if (trial == null) return 0;
    final hasData = await trialHasAnySessionData(_db, trialId);
    if (!canEditTrialStructure(trial, hasSessionData: hasData)) {
      throw ProtocolEditBlockedException(
        structureEditBlockedMessage(trial, hasSessionData: hasData),
      );
    }
    return _plotRepository.insertRepGuardPlotsIfNeeded(trialId);
  }
}
