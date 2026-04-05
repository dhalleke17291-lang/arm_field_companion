import '../plot_repository.dart';
import '../plot_detail_form_controller.dart';

/// Result of a plot detail write (dimensions or guard row).
class PlotDetailWriteResult {
  const PlotDetailWriteResult._({
    required this.isSuccess,
    this.errorMessage,
  });

  final bool isSuccess;
  final String? errorMessage;

  factory PlotDetailWriteResult.success() {
    return const PlotDetailWriteResult._(isSuccess: true);
  }

  factory PlotDetailWriteResult.failure(String message) {
    return PlotDetailWriteResult._(isSuccess: false, errorMessage: message);
  }
}

/// Persists plot dimension and field-condition fields via [PlotRepository].
class UpdatePlotDetailsUseCase {
  UpdatePlotDetailsUseCase(this._plotRepository);

  final PlotRepository _plotRepository;

  Future<PlotDetailWriteResult> execute(
    int plotPk,
    UpdatePlotDetailsPayload payload,
  ) async {
    try {
      await _plotRepository.updatePlotDetails(
        plotPk,
        plotLengthM: payload.plotLengthM,
        plotWidthM: payload.plotWidthM,
        plotAreaM2: payload.plotAreaM2,
        harvestLengthM: payload.harvestLengthM,
        harvestWidthM: payload.harvestWidthM,
        harvestAreaM2: payload.harvestAreaM2,
        plotDirection: payload.plotDirection,
        soilSeries: payload.soilSeries,
        plotNotes: payload.plotNotes,
      );
      return PlotDetailWriteResult.success();
    } catch (e) {
      return PlotDetailWriteResult.failure('Save failed: $e');
    }
  }
}

/// Persists guard-row flag via [PlotRepository].
class UpdatePlotGuardRowUseCase {
  UpdatePlotGuardRowUseCase(this._plotRepository);

  final PlotRepository _plotRepository;

  Future<PlotDetailWriteResult> execute(int plotPk, bool isGuardRow) async {
    try {
      await _plotRepository.updatePlotGuardRow(plotPk, isGuardRow);
      return PlotDetailWriteResult.success();
    } catch (e) {
      return PlotDetailWriteResult.failure('Update failed: $e');
    }
  }
}
