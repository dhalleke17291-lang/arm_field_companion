import 'dart:convert';

enum FieldConfidence { high, moderate, low, cannotInfer }

extension FieldConfidenceJson on FieldConfidence {
  String toJson() => name;

  static FieldConfidence fromJson(String s) =>
      FieldConfidence.values.firstWhere(
        (e) => e.name == s,
        orElse: () => FieldConfidence.cannotInfer,
      );
}

class InferredTreatmentRole {
  const InferredTreatmentRole({
    required this.treatmentId,
    required this.treatmentName,
    required this.inferredRole,
    required this.confidence,
    required this.basis,
  });

  final int treatmentId;
  final String treatmentName;

  /// 'untreated_check' | 'reference_standard' | 'test_item' | 'elevated_rate'
  final String inferredRole;
  final FieldConfidence confidence;

  /// Plain English: "Treatment name contains 'UTC'"
  final String basis;

  Map<String, dynamic> toJson() => {
        'treatmentId': treatmentId,
        'treatmentName': treatmentName,
        'inferredRole': inferredRole,
        'confidence': confidence.toJson(),
        'basis': basis,
      };

  static InferredTreatmentRole fromJson(Map<String, dynamic> m) =>
      InferredTreatmentRole(
        treatmentId: (m['treatmentId'] as num).toInt(),
        treatmentName: m['treatmentName'] as String,
        inferredRole: m['inferredRole'] as String,
        confidence: FieldConfidenceJson.fromJson(m['confidence'] as String),
        basis: m['basis'] as String,
      );
}

class InferredTrialPurpose {
  const InferredTrialPurpose({
    this.trialType,
    required this.trialTypeConfidence,
    this.primaryEndpointAssessmentKey,
    required this.primaryEndpointConfidence,
    required this.treatmentRoles,
    this.claimStatement,
    required this.claimConfidence,
    this.regulatoryContext,
    required this.regulatoryContextConfidence,
    required this.inferenceSource,
    required this.inferenceNotes,
  });

  final String? trialType;
  final FieldConfidence trialTypeConfidence;

  final String? primaryEndpointAssessmentKey;
  final FieldConfidence primaryEndpointConfidence;

  final List<InferredTreatmentRole> treatmentRoles;

  final String? claimStatement;
  final FieldConfidence claimConfidence;

  final String? regulatoryContext;
  final FieldConfidence regulatoryContextConfidence;

  /// 'arm_structure' | 'standalone_structure' | 'mixed'
  final String inferenceSource;

  final List<String> inferenceNotes;

  Map<String, dynamic> toJson() => {
        'trialType': trialType,
        'trialTypeConfidence': trialTypeConfidence.toJson(),
        'primaryEndpointAssessmentKey': primaryEndpointAssessmentKey,
        'primaryEndpointConfidence': primaryEndpointConfidence.toJson(),
        'treatmentRoles': treatmentRoles.map((r) => r.toJson()).toList(),
        'claimStatement': claimStatement,
        'claimConfidence': claimConfidence.toJson(),
        'regulatoryContext': regulatoryContext,
        'regulatoryContextConfidence': regulatoryContextConfidence.toJson(),
        'inferenceSource': inferenceSource,
        'inferenceNotes': inferenceNotes,
      };

  String toJsonString() => jsonEncode(toJson());

  static InferredTrialPurpose fromJsonString(String s) {
    final m = jsonDecode(s) as Map<String, dynamic>;
    return InferredTrialPurpose(
      trialType: m['trialType'] as String?,
      trialTypeConfidence:
          FieldConfidenceJson.fromJson(m['trialTypeConfidence'] as String),
      primaryEndpointAssessmentKey:
          m['primaryEndpointAssessmentKey'] as String?,
      primaryEndpointConfidence: FieldConfidenceJson.fromJson(
          m['primaryEndpointConfidence'] as String),
      treatmentRoles: (m['treatmentRoles'] as List<dynamic>)
          .map((e) => InferredTreatmentRole.fromJson(e as Map<String, dynamic>))
          .toList(),
      claimStatement: m['claimStatement'] as String?,
      claimConfidence:
          FieldConfidenceJson.fromJson(m['claimConfidence'] as String),
      regulatoryContext: m['regulatoryContext'] as String?,
      regulatoryContextConfidence: FieldConfidenceJson.fromJson(
          m['regulatoryContextConfidence'] as String),
      inferenceSource: m['inferenceSource'] as String,
      inferenceNotes:
          (m['inferenceNotes'] as List<dynamic>).cast<String>(),
    );
  }
}

/// Input data for the pure inference function.
class TrialInferenceInput {
  const TrialInferenceInput({
    required this.workspaceType,
    this.crop,
    required this.treatments,
    required this.assessments,
    required this.inferenceSource,
  });

  final String workspaceType;
  final String? crop;
  final List<TreatmentInferenceData> treatments;
  final List<AssessmentInferenceData> assessments;

  /// 'arm_structure' | 'standalone_structure'
  final String inferenceSource;
}

class TreatmentInferenceData {
  const TreatmentInferenceData({
    required this.id,
    required this.name,
    required this.code,
    this.treatmentType,
  });

  final int id;
  final String name;
  final String code;
  final String? treatmentType;
}

class AssessmentInferenceData {
  const AssessmentInferenceData({
    required this.name,
    this.eppoCode,
    this.pestCode,
    this.daysAfterTreatment,
    this.timingCode,
    this.definitionCategory,
  });

  final String name;
  final String? eppoCode;
  final String? pestCode;
  final int? daysAfterTreatment;
  final String? timingCode;
  final String? definitionCategory;
}

// ── Known reference product name fragments ─────────────────────────────────
const _kReferenceProductKeywords = [
  'proline', 'prosaro', 'headline', 'trivapro', 'folicur', 'tilt',
  'quilt', 'priaxor', 'stratego', 'aproach', 'lance', 'adepidyn',
  'miravis', 'veltyma', 'revytek', 'ascendis',
];

const _kCheckKeywords = [
  'utc', 'chk', 'untreated', 'control', 'untr', 'check',
  'untreatd', 'no treatment', 'no-treatment',
];

// ── Pure inference entry point ─────────────────────────────────────────────

/// Pure function. No DB calls. No async. Deterministic.
InferredTrialPurpose inferTrialPurpose(TrialInferenceInput input) {
  final notes = <String>[];

  // ── Trial type ─────────────────────────────────────────────────────────
  final (trialType, trialTypeConf, trialTypeNote) =
      _inferTrialType(input.workspaceType);
  if (trialTypeNote != null) notes.add(trialTypeNote);

  // ── Regulatory context ─────────────────────────────────────────────────
  final (regCtx, regConf, regNote) =
      _inferRegulatoryContext(input.workspaceType);
  if (regNote != null) notes.add(regNote);

  // ── Treatment roles ────────────────────────────────────────────────────
  final roles = inferTreatmentRoles(input.treatments);
  if (input.treatments.isEmpty) {
    notes.add('No treatments available — treatment roles cannot be inferred.');
  } else {
    for (final r in roles) {
      notes.add('${r.treatmentName}: ${r.basis}');
    }
  }

  // ── Primary endpoint ───────────────────────────────────────────────────
  final (endpoint, endpointConf, endpointNote) =
      _inferPrimaryEndpoint(input.assessments);
  if (endpointNote != null) notes.add(endpointNote);

  // ── Target pest ────────────────────────────────────────────────────────
  final targetPest = _inferTargetPest(input.assessments);

  // ── Claim statement ────────────────────────────────────────────────────
  final testItems = roles
      .where((r) => r.inferredRole == 'test_item')
      .map((r) => r.treatmentName)
      .toList();
  final (claim, claimConf, claimNote) = _assembleClaimStatement(
    crop: input.crop,
    testItemNames: testItems,
    targetPest: targetPest,
    trialType: trialType,
    trialTypeConfidence: trialTypeConf,
  );
  if (claimNote != null) notes.add(claimNote);

  return InferredTrialPurpose(
    trialType: trialType,
    trialTypeConfidence: trialTypeConf,
    primaryEndpointAssessmentKey: endpoint,
    primaryEndpointConfidence: endpointConf,
    treatmentRoles: roles,
    claimStatement: claim,
    claimConfidence: claimConf,
    regulatoryContext: regCtx,
    regulatoryContextConfidence: regConf,
    inferenceSource: input.inferenceSource,
    inferenceNotes: List.unmodifiable(notes),
  );
}

// ── Treatment role inference ───────────────────────────────────────────────

List<InferredTreatmentRole> inferTreatmentRoles(
    List<TreatmentInferenceData> treatments) {
  if (treatments.isEmpty) return const [];
  final result = <InferredTreatmentRole>[];
  for (final t in treatments) {
    final (role, conf, basis) = _inferRoleForTreatment(t);
    result.add(InferredTreatmentRole(
      treatmentId: t.id,
      treatmentName: t.name,
      inferredRole: role,
      confidence: conf,
      basis: basis,
    ));
  }
  return result;
}

(String, FieldConfidence, String) _inferRoleForTreatment(
    TreatmentInferenceData t) {
  final nameLower = t.name.toLowerCase();
  final codeLower = t.code.toLowerCase();
  final typeLower = (t.treatmentType ?? '').toLowerCase();

  // Check keywords in name or code (high confidence)
  for (final kw in _kCheckKeywords) {
    if (nameLower.contains(kw) || codeLower.contains(kw) ||
        typeLower.contains(kw)) {
      return (
        'untreated_check',
        FieldConfidence.high,
        "Treatment name or code contains '${kw.toUpperCase()}'",
      );
    }
  }

  // ARM type code CHK (high confidence)
  if (typeLower == 'chk') {
    return (
      'untreated_check',
      FieldConfidence.high,
      "ARM type code is 'CHK'",
    );
  }

  // Reference standard keywords in name (moderate confidence)
  for (final kw in _kReferenceProductKeywords) {
    if (nameLower.contains(kw)) {
      return (
        'reference_standard',
        FieldConfidence.moderate,
        "Treatment name contains known registered product '$kw'",
      );
    }
  }

  if (nameLower.contains('ref') ||
      nameLower.contains('reference') ||
      nameLower.contains('standard')) {
    return (
      'reference_standard',
      FieldConfidence.moderate,
      "Treatment name contains 'REF' or 'REFERENCE' or 'STANDARD'",
    );
  }

  return (
    'test_item',
    FieldConfidence.moderate,
    'No check or reference keywords found — inferred as test item',
  );
}

// ── Trial type inference ───────────────────────────────────────────────────

(String?, FieldConfidence, String?) _inferTrialType(String workspaceType) {
  return switch (workspaceType) {
    'glp' => (
        'registration_efficacy',
        FieldConfidence.high,
        "Trial type inferred as registration efficacy from 'glp' workspace.",
      ),
    'efficacy' => (
        'efficacy',
        FieldConfidence.high,
        "Trial type inferred as efficacy from 'efficacy' workspace.",
      ),
    'variety' => (
        'variety_evaluation',
        FieldConfidence.high,
        "Trial type inferred as variety evaluation from 'variety' workspace.",
      ),
    'standalone' => (
        'efficacy',
        FieldConfidence.moderate,
        "Trial type inferred as efficacy from standalone workspace — confirm or correct.",
      ),
    _ => (
        null,
        FieldConfidence.cannotInfer,
        "Workspace type '$workspaceType' not recognised — trial type cannot be inferred.",
      ),
  };
}

// ── Regulatory context inference ───────────────────────────────────────────

(String?, FieldConfidence, String?) _inferRegulatoryContext(
    String workspaceType) {
  return switch (workspaceType) {
    'glp' => (
        'PMRA or regulatory submission likely',
        FieldConfidence.moderate,
        'Regulatory context inferred from glp workspace — PMRA or regulatory submission likely.',
      ),
    'efficacy' => (
        'Internal research or market positioning',
        FieldConfidence.low,
        'Regulatory context inferred as internal research from efficacy workspace — low confidence.',
      ),
    _ => (null, FieldConfidence.cannotInfer, null),
  };
}

// ── Primary endpoint inference ─────────────────────────────────────────────

(String?, FieldConfidence, String?) _inferPrimaryEndpoint(
    List<AssessmentInferenceData> assessments) {
  if (assessments.isEmpty) {
    return (null, FieldConfidence.cannotInfer,
        'No assessments defined — primary endpoint cannot be inferred.');
  }

  if (assessments.length == 1) {
    return (
      assessments.first.name,
      FieldConfidence.high,
      "Single assessment '${assessments.first.name}' inferred as primary endpoint.",
    );
  }

  // Multiple assessments: latest timing wins as primary endpoint candidate.
  // Prefer assessments with daysAfterTreatment, else fall back to last in list.
  AssessmentInferenceData? latest;
  int? latestDat;
  for (final a in assessments) {
    if (a.daysAfterTreatment != null) {
      if (latestDat == null || a.daysAfterTreatment! > latestDat) {
        latestDat = a.daysAfterTreatment;
        latest = a;
      }
    }
  }

  if (latest != null) {
    return (
      latest.name,
      FieldConfidence.moderate,
      "Primary endpoint inferred as '${latest.name}' — latest planned timing "
          '(${latestDat}d after treatment) across ${assessments.length} assessments.',
    );
  }

  // No timing info: last assessment in definition order.
  final last = assessments.last;
  return (
    last.name,
    FieldConfidence.moderate,
    "Primary endpoint inferred as '${last.name}' — last assessment in definition order "
        '(no timing data available).',
  );
}

// ── Target pest extraction ─────────────────────────────────────────────────

String? _inferTargetPest(List<AssessmentInferenceData> assessments) {
  if (assessments.isEmpty) return null;
  // Prefer EPPO code first, then pest code, then assessment name
  for (final a in assessments) {
    if (a.eppoCode != null && a.eppoCode!.isNotEmpty) return a.eppoCode;
  }
  for (final a in assessments) {
    if (a.pestCode != null && a.pestCode!.isNotEmpty) return a.pestCode;
  }
  return assessments.first.name;
}

// ── Claim statement assembly ───────────────────────────────────────────────

(String?, FieldConfidence, String?) _assembleClaimStatement({
  required String? crop,
  required List<String> testItemNames,
  required String? targetPest,
  required String? trialType,
  required FieldConfidence trialTypeConfidence,
}) {
  if (testItemNames.isEmpty && targetPest == null && crop == null) {
    return (
      null,
      FieldConfidence.cannotInfer,
      'Insufficient data to assemble a claim statement.',
    );
  }

  final testPart = testItemNames.isNotEmpty
      ? testItemNames.join(', ')
      : 'test treatments';
  final pestPart = targetPest ?? 'target pest';
  final cropPart = crop ?? 'crop';

  final claim =
      'Evaluate efficacy of $testPart against $pestPart in $cropPart.';

  // Confidence is bounded by the weakest component
  final conf = (trialTypeConfidence == FieldConfidence.high &&
          testItemNames.isNotEmpty &&
          targetPest != null)
      ? FieldConfidence.moderate
      : FieldConfidence.low;

  return (
    claim,
    conf,
    'Claim assembled from inferred components — review and confirm before export.',
  );
}
