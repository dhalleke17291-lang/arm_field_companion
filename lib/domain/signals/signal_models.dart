import 'dart:convert';

/// Stored as snake_case in `signals.signal_type`.
enum SignalType {
  scaleViolation,
  spatialAnomaly,
  protocolDivergence,
  causalContextFlag,
  behavioralSignal,
  aovPrediction,
  replicationWarning,
  raterDrift,
  betweenRaterDivergence,
  exportPreflight,
  deviationDeclaration,
  // high CV in untreated check baseline (session-level); distinct from
  // _factorUntreatedCheckPressure which is a trial-level risk factor
  checkBaselineVariability,
}

extension SignalTypeDb on SignalType {
  String get dbValue => switch (this) {
        SignalType.scaleViolation => 'scale_violation',
        SignalType.spatialAnomaly => 'spatial_anomaly',
        SignalType.protocolDivergence => 'protocol_divergence',
        SignalType.causalContextFlag => 'causal_context_flag',
        SignalType.behavioralSignal => 'behavioral_signal',
        SignalType.aovPrediction => 'aov_prediction',
        SignalType.replicationWarning => 'replication_warning',
        SignalType.raterDrift => 'rater_drift',
        SignalType.betweenRaterDivergence => 'between_rater_divergence',
        SignalType.exportPreflight => 'export_preflight',
        SignalType.deviationDeclaration => 'deviation_declaration',
        SignalType.checkBaselineVariability => 'check_baseline_variability',
      };
}

enum SignalSeverity {
  critical,
  review,
  info,
}

extension SignalSeverityDb on SignalSeverity {
  String get dbValue => name;
}

enum SignalStatus {
  open,
  deferred,
  investigating,
  resolved,
  expired,
  suppressed,
}

extension SignalStatusDb on SignalStatus {
  String get dbValue => name;
}

enum SignalDecisionEventType {
  confirm,
  reRate,
  investigate,
  defer,
  suppress,
  expire,
}

extension SignalDecisionEventTypeDb on SignalDecisionEventType {
  String get dbValue => switch (this) {
        SignalDecisionEventType.confirm => 'confirm',
        SignalDecisionEventType.reRate => 're_rate',
        SignalDecisionEventType.investigate => 'investigate',
        SignalDecisionEventType.defer => 'defer',
        SignalDecisionEventType.suppress => 'suppress',
        SignalDecisionEventType.expire => 'expire',
      };
}

SignalStatus resultingStatusForDecision(SignalDecisionEventType eventType) =>
    switch (eventType) {
      SignalDecisionEventType.confirm ||
      SignalDecisionEventType.reRate =>
        SignalStatus.resolved,
      SignalDecisionEventType.investigate => SignalStatus.investigating,
      SignalDecisionEventType.defer => SignalStatus.deferred,
      SignalDecisionEventType.suppress => SignalStatus.suppressed,
      SignalDecisionEventType.expire => SignalStatus.expired,
    };

/// Last Actionable Moment (1–5).
enum SignalMoment {
  one,
  two,
  three,
  four,
  five,
}

extension SignalMomentDb on SignalMoment {
  int get dbValue => index + 1;
}

/// Serialized into `signals.reference_context` JSON.
class SignalReferenceContext {
  const SignalReferenceContext({
    this.neighborValues,
    this.treatmentMean,
    this.sessionMean,
    this.raterBaseline,
    this.protocolExpectedValue,
    this.seType,
    this.evidencePresent,
    this.reliabilityTier,
    this.enteredValue,
    this.scaleMin,
    this.scaleMax,
    this.treatmentId,
  });

  final List<double>? neighborValues;
  final double? treatmentMean;
  final double? sessionMean;
  final double? raterBaseline;
  final String? protocolExpectedValue;
  final String? seType;
  final bool? evidencePresent;

  /// high | medium | low
  final String? reliabilityTier;

  /// Plot-entered observation when raising scale-bound signals.
  final double? enteredValue;
  final double? scaleMin;
  final double? scaleMax;

  /// Used by session-level writers (aovPrediction, replicationWarning) to
  /// uniquely identify the subject treatment for dedup on re-run.
  final int? treatmentId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (neighborValues != null) 'neighborValues': neighborValues,
        if (treatmentMean != null) 'treatmentMean': treatmentMean,
        if (sessionMean != null) 'sessionMean': sessionMean,
        if (raterBaseline != null) 'raterBaseline': raterBaseline,
        if (protocolExpectedValue != null)
          'protocolExpectedValue': protocolExpectedValue,
        if (seType != null) 'seType': seType,
        if (evidencePresent != null) 'evidencePresent': evidencePresent,
        if (reliabilityTier != null) 'reliabilityTier': reliabilityTier,
        if (enteredValue != null) 'enteredValue': enteredValue,
        if (scaleMin != null) 'scaleMin': scaleMin,
        if (scaleMax != null) 'scaleMax': scaleMax,
        if (treatmentId != null) 'treatmentId': treatmentId,
      };

  factory SignalReferenceContext.fromJson(Map<String, dynamic> json) {
    List<double>? neighbors;
    final nv = json['neighborValues'];
    if (nv is List<dynamic>) {
      neighbors = nv.map((e) => (e as num).toDouble()).toList();
    }
    return SignalReferenceContext(
      neighborValues: neighbors,
      treatmentMean: (json['treatmentMean'] as num?)?.toDouble(),
      sessionMean: (json['sessionMean'] as num?)?.toDouble(),
      raterBaseline: (json['raterBaseline'] as num?)?.toDouble(),
      protocolExpectedValue: json['protocolExpectedValue'] as String?,
      seType: json['seType'] as String?,
      evidencePresent: json['evidencePresent'] as bool?,
      reliabilityTier: json['reliabilityTier'] as String?,
      enteredValue: (json['enteredValue'] as num?)?.toDouble(),
      scaleMin: (json['scaleMin'] as num?)?.toDouble(),
      scaleMax: (json['scaleMax'] as num?)?.toDouble(),
      treatmentId: (json['treatmentId'] as num?)?.toInt(),
    );
  }

  String encodeJson() => jsonEncode(toJson());

  static SignalReferenceContext decodeJson(String raw) =>
      SignalReferenceContext.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
}

/// Serialized into `signals.magnitude_context` JSON (nullable column).
class SignalMagnitudeContext {
  const SignalMagnitudeContext({
    this.absoluteDelta,
    this.percentDifference,
    this.sdFromMean,
    this.neighborDelta,
  });

  final double? absoluteDelta;
  final double? percentDifference;
  final double? sdFromMean;
  final double? neighborDelta;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (absoluteDelta != null) 'absoluteDelta': absoluteDelta,
        if (percentDifference != null) 'percentDifference': percentDifference,
        if (sdFromMean != null) 'sdFromMean': sdFromMean,
        if (neighborDelta != null) 'neighborDelta': neighborDelta,
      };

  factory SignalMagnitudeContext.fromJson(Map<String, dynamic> json) {
    return SignalMagnitudeContext(
      absoluteDelta: (json['absoluteDelta'] as num?)?.toDouble(),
      percentDifference: (json['percentDifference'] as num?)?.toDouble(),
      sdFromMean: (json['sdFromMean'] as num?)?.toDouble(),
      neighborDelta: (json['neighborDelta'] as num?)?.toDouble(),
    );
  }

  String encodeJson() => jsonEncode(toJson());

  static SignalMagnitudeContext decodeJson(String raw) =>
      SignalMagnitudeContext.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
}
