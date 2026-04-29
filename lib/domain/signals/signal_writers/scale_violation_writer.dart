import '../signal_models.dart';
import '../signal_repository.dart';

/// Raises `scaleViolation` signals when plot-entered values fall outside SE bounds.
class ScaleViolationWriter {
  ScaleViolationWriter(this._signals);

  final SignalRepository _signals;

  Future<int?> checkAndRaise({
    required int trialId,
    required int sessionId,
    required int plotId,
    required double enteredValue,
    required double scaleMin,
    required double scaleMax,
    required String seType,
    required String consequenceText,
    int? raisedBy,
  }) async {
    if (enteredValue >= scaleMin && enteredValue <= scaleMax) {
      return null;
    }

    final existing = await _signals.findOpenScaleViolationForPlotSession(
      sessionId: sessionId,
      plotId: plotId,
    );
    if (existing != null) {
      return existing.id;
    }

    return _signals.raiseSignal(
      trialId: trialId,
      sessionId: sessionId,
      plotId: plotId,
      signalType: SignalType.scaleViolation,
      moment: SignalMoment.one,
      severity: SignalSeverity.critical,
      referenceContext: SignalReferenceContext(
        seType: seType,
        enteredValue: enteredValue,
        scaleMin: scaleMin,
        scaleMax: scaleMax,
      ),
      consequenceText: consequenceText,
      raisedBy: raisedBy,
    );
  }
}
