/// Provider key for per-session distribution analysis.
class PlotAnalysisParams {
  final int trialId;
  final int sessionId;
  final int assessmentId;

  const PlotAnalysisParams({
    required this.trialId,
    required this.sessionId,
    required this.assessmentId,
  });

  @override
  bool operator ==(Object other) =>
      other is PlotAnalysisParams &&
      other.trialId == trialId &&
      other.sessionId == sessionId &&
      other.assessmentId == assessmentId;

  @override
  int get hashCode => Object.hash(trialId, sessionId, assessmentId);
}

/// Provider key for cross-session progression analysis.
class PlotProgressionParams {
  final int trialId;
  final int assessmentId;

  const PlotProgressionParams({
    required this.trialId,
    required this.assessmentId,
  });

  @override
  bool operator ==(Object other) =>
      other is PlotProgressionParams &&
      other.trialId == trialId &&
      other.assessmentId == assessmentId;

  @override
  int get hashCode => Object.hash(trialId, assessmentId);
}

class TreatmentDistribution {
  final int treatmentId;
  final String treatmentCode;
  final String treatmentName;
  final bool isCheck;
  final int n;
  final double mean;
  final double sd;
  final double min;
  final double q1;
  final double median;
  final double q3;
  final double max;
  final List<double> values;
  final bool hasOutliers;
  final double scaleMin;
  final double scaleMax;

  const TreatmentDistribution({
    required this.treatmentId,
    required this.treatmentCode,
    required this.treatmentName,
    required this.isCheck,
    required this.n,
    required this.mean,
    required this.sd,
    required this.min,
    required this.q1,
    required this.median,
    required this.q3,
    required this.max,
    required this.values,
    required this.scaleMin,
    required this.scaleMax,
    this.hasOutliers = false,
  });
}

class DistributionResult {
  final List<TreatmentDistribution> treatments;
  final double? pooledCv;

  const DistributionResult({
    required this.treatments,
    this.pooledCv,
  });
}

class ProgressionPoint {
  final int sessionId;
  final String sessionLabel;
  final double mean;
  final int n;

  const ProgressionPoint({
    required this.sessionId,
    required this.sessionLabel,
    required this.mean,
    required this.n,
  });
}

class ProgressionSeries {
  final int treatmentId;
  final String treatmentCode;
  final String treatmentName;
  final bool isCheck;
  final List<ProgressionPoint> points;

  const ProgressionSeries({
    required this.treatmentId,
    required this.treatmentCode,
    required this.treatmentName,
    required this.isCheck,
    required this.points,
  });
}

class ProgressionResult {
  final List<ProgressionSeries> series;
  final String assessmentName;
  final List<String> sessionLabels;

  const ProgressionResult({
    required this.series,
    required this.assessmentName,
    required this.sessionLabels,
  });
}
