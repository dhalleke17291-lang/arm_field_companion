import '../../../core/protocol_edit_blocked_exception.dart';
import '../../../core/trial_state.dart';
import '../../trials/trial_repository.dart';
import '../plot_repository.dart';

/// V1: add G{rep}-L and G{rep}-R per layout rep (display + storage only).
class GenerateRepGuardPlotsUseCase {
  GenerateRepGuardPlotsUseCase(this._plotRepository, this._trialRepository);

  final PlotRepository _plotRepository;
  final TrialRepository _trialRepository;

  Future<int> countToInsert(int trialId) async {
    final trial = await _trialRepository.getTrialById(trialId);
    if (trial == null) return 0;
    if (!canEditProtocol(trial)) {
      throw ProtocolEditBlockedException(protocolEditBlockedMessage(trial));
    }
    return _plotRepository.countRepGuardPlotsToInsert(trialId);
  }

  Future<int> execute(int trialId) async {
    final trial = await _trialRepository.getTrialById(trialId);
    if (trial == null) return 0;
    if (!canEditProtocol(trial)) {
      throw ProtocolEditBlockedException(protocolEditBlockedMessage(trial));
    }
    return _plotRepository.insertRepGuardPlotsIfNeeded(trialId);
  }
}
