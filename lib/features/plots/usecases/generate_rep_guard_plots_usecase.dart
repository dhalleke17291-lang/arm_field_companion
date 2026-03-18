import '../plot_repository.dart';

/// V1: add G{rep}-L and G{rep}-R per layout rep (display + storage only).
class GenerateRepGuardPlotsUseCase {
  GenerateRepGuardPlotsUseCase(this._plotRepository);

  final PlotRepository _plotRepository;

  Future<int> countToInsert(int trialId) =>
      _plotRepository.countRepGuardPlotsToInsert(trialId);

  Future<int> execute(int trialId) =>
      _plotRepository.insertRepGuardPlotsIfNeeded(trialId);
}
