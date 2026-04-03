import '../../core/database/app_database.dart';
import '../models/plot_context.dart';
import '../../data/repositories/treatment_repository.dart';
import '../../features/plots/plot_repository.dart';

/// Resolves a canonical PlotContext for a given plot pk.
/// This is the single source of truth for plot + treatment context.
/// Screens must use this — never resolve treatment directly.
class ResolvePlotTreatment {
  final PlotRepository _plotRepository;
  final TreatmentRepository _treatmentRepository;

  ResolvePlotTreatment({
    required PlotRepository plotRepository,
    required TreatmentRepository treatmentRepository,
  })  : _plotRepository = plotRepository,
        _treatmentRepository = treatmentRepository;

  Future<PlotContext> execute(int plotPk) async {
    final plot = await _plotRepository.getPlotByPk(plotPk);
    if (plot == null) throw PlotContextException(plotPk);

    final assignedTreatmentId =
        await _treatmentRepository.getEffectiveTreatmentIdForPlot(plotPk);
    final treatment = assignedTreatmentId != null
        ? await _treatmentRepository.getTreatmentById(assignedTreatmentId)
        : null;

    final components = treatment != null
        ? await _treatmentRepository.getComponentsForTreatment(treatment.id)
        : <TreatmentComponent>[];

    return PlotContext(
      plot: plot,
      treatment: treatment,
      components: components,
      assignedTreatmentId: assignedTreatmentId,
    );
  }
}

class PlotContextException implements Exception {
  final int plotPk;
  PlotContextException(this.plotPk);

  @override
  String toString() => 'Could not resolve PlotContext for plot pk $plotPk.';
}
