import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';

const _uuid = Uuid();

class AssessmentGuideRepository {
  AssessmentGuideRepository(this._db);

  final AppDatabase _db;

  static const _wheatDiseaseAsset =
      'assets/reference_guides/lane1/wheat_disease_severity.svg';
  static const _canolaSclerotiniaAsset =
      'assets/reference_guides/lane1/canola_disease_severity.svg';

  // ── Lane-priority query for rating screen icon ──────────────────────────

  /// True when any non-deleted anchor exists for this assessment, across all
  /// lanes. Lane 3 checks trialAssessmentId; Lanes 1/2 check assessmentDefId.
  Stream<bool> watchHasAnyGuide({
    required int trialAssessmentId,
    int? assessmentDefinitionId,
  }) {
    // Lane 3: customer upload for this specific trial assessment
    final guideQuery = _db.select(_db.assessmentGuides)
      ..where((g) => g.trialAssessmentId.equals(trialAssessmentId));

    return guideQuery.watch().asyncMap((guides) async {
      for (final g in guides) {
        final anchors = await (_db.select(_db.assessmentGuideAnchors)
              ..where((a) => a.guideId.equals(g.id) & a.isDeleted.equals(0)))
            .get();
        if (anchors.isNotEmpty) return true;
      }
      // Lanes 1/2: type-wide content keyed by assessment definition
      if (assessmentDefinitionId != null) {
        final lane2 = await _resolveDefGuideForLane(
          trialAssessmentId: trialAssessmentId,
          assessmentDefinitionId: assessmentDefinitionId,
          lane: 'identification_photo',
        );
        if (lane2 != null) return true;

        final lane1 = await _resolveDefGuideForLane(
          trialAssessmentId: trialAssessmentId,
          assessmentDefinitionId: assessmentDefinitionId,
          lane: 'calibration_diagram',
        );
        if (lane1 != null) return true;
      }
      return false;
    });
  }

  Future<GuideAvailabilityDiagnostics> diagnoseGuideAvailability({
    required int trialAssessmentId,
    int? assessmentDefinitionId,
  }) async {
    final ta = trialAssessmentId > 0
        ? await (_db.select(_db.trialAssessments)
              ..where((t) => t.id.equals(trialAssessmentId)))
            .getSingleOrNull()
        : null;
    final trial = ta == null
        ? null
        : await (_db.select(_db.trials)..where((t) => t.id.equals(ta.trialId)))
            .getSingleOrNull();
    final aam = ta == null
        ? null
        : await (_db.select(_db.armAssessmentMetadata)
              ..where((a) => a.trialAssessmentId.equals(ta.id)))
            .getSingleOrNull();
    final def = assessmentDefinitionId == null
        ? null
        : await (_db.select(_db.assessmentDefinitions)
              ..where((d) => d.id.equals(assessmentDefinitionId)))
            .getSingleOrNull();

    final cropContext = _contextText([
      trial?.crop,
      trial?.name,
      aam?.shellCropName,
      aam?.shellCropCode,
    ]);
    final targetContext = _contextText([
      ta?.displayNameOverride,
      ta?.pestName,
      ta?.eppoCodeLocal,
      ta?.methodOverride,
      ta?.instructionOverride,
      def?.name,
      def?.target,
      def?.method,
      def?.defaultInstructions,
      def?.eppoCode,
      def?.cropPart,
      aam?.seName,
      aam?.seDescription,
      aam?.partRated,
      aam?.ratingType,
      aam?.pestCode,
      aam?.pestCodeSecondary,
      aam?.shellPestType,
      aam?.shellPestName,
      aam?.shellCropOrPest,
    ]);

    if (trialAssessmentId <= 0) {
      return GuideAvailabilityDiagnostics(
        hasGuide: false,
        reason: 'no trialAssessmentId',
        trialAssessmentId: trialAssessmentId,
        assessmentDefinitionId: assessmentDefinitionId,
        assessmentDefinitionCode: def?.code,
        cropContext: cropContext,
        targetContext: targetContext,
      );
    }

    final lane3Anchors = await _anchorCountForTrialAssessmentLane(
      trialAssessmentId: trialAssessmentId,
      lane: 'customer_upload',
    );
    if (lane3Anchors > 0) {
      return GuideAvailabilityDiagnostics(
        hasGuide: true,
        reason: 'guide exists and is safe: customer_upload',
        trialAssessmentId: trialAssessmentId,
        assessmentDefinitionId: assessmentDefinitionId,
        assessmentDefinitionCode: def?.code,
        cropContext: cropContext,
        targetContext: targetContext,
        lane3AnchorCount: lane3Anchors,
      );
    }

    if (assessmentDefinitionId == null) {
      return GuideAvailabilityDiagnostics(
        hasGuide: false,
        reason: 'no assessmentDefinitionId',
        trialAssessmentId: trialAssessmentId,
        assessmentDefinitionId: assessmentDefinitionId,
        cropContext: cropContext,
        targetContext: targetContext,
      );
    }

    final guides = await (_db.select(_db.assessmentGuides)
          ..where(
              (g) => g.assessmentDefinitionId.equals(assessmentDefinitionId)))
        .get();
    if (guides.isEmpty) {
      return GuideAvailabilityDiagnostics(
        hasGuide: false,
        reason: 'no guide rows for definition',
        trialAssessmentId: trialAssessmentId,
        assessmentDefinitionId: assessmentDefinitionId,
        assessmentDefinitionCode: def?.code,
        cropContext: cropContext,
        targetContext: targetContext,
      );
    }

    final lane2Anchors = await _anchorCountForDefinitionLane(
      assessmentDefinitionId: assessmentDefinitionId,
      lane: 'identification_photo',
    );
    if (lane2Anchors > 0) {
      return GuideAvailabilityDiagnostics(
        hasGuide: true,
        reason: 'guide exists and is safe: identification_photo',
        trialAssessmentId: trialAssessmentId,
        assessmentDefinitionId: assessmentDefinitionId,
        assessmentDefinitionCode: def?.code,
        cropContext: cropContext,
        targetContext: targetContext,
        definitionGuideCount: guides.length,
        lane2AnchorCount: lane2Anchors,
      );
    }

    final lane1RawAnchors = await _anchorCountForDefinitionLane(
      assessmentDefinitionId: assessmentDefinitionId,
      lane: 'calibration_diagram',
    );
    if (lane1RawAnchors == 0) {
      return GuideAvailabilityDiagnostics(
        hasGuide: false,
        reason: 'no calibration anchors for definition',
        trialAssessmentId: trialAssessmentId,
        assessmentDefinitionId: assessmentDefinitionId,
        assessmentDefinitionCode: def?.code,
        cropContext: cropContext,
        targetContext: targetContext,
        definitionGuideCount: guides.length,
      );
    }

    var lane1SafeAnchors = 0;
    for (final guide in guides) {
      final anchors = await (_db.select(_db.assessmentGuideAnchors)
            ..where((a) =>
                a.guideId.equals(guide.id) &
                a.isDeleted.equals(0) &
                a.lane.equals('calibration_diagram')))
          .get();
      lane1SafeAnchors += (await _filterCalibrationAnchorsForContext(
        trialAssessmentId: trialAssessmentId,
        assessmentDefinitionId: assessmentDefinitionId,
        anchors: anchors,
      ))
          .length;
    }

    if (lane1SafeAnchors > 0) {
      return GuideAvailabilityDiagnostics(
        hasGuide: true,
        reason: 'guide exists and is safe: calibration_diagram',
        trialAssessmentId: trialAssessmentId,
        assessmentDefinitionId: assessmentDefinitionId,
        assessmentDefinitionCode: def?.code,
        cropContext: cropContext,
        targetContext: targetContext,
        definitionGuideCount: guides.length,
        lane1RawAnchorCount: lane1RawAnchors,
        lane1SafeAnchorCount: lane1SafeAnchors,
      );
    }

    final decision = def?.code == 'DISEASE_SEV'
        ? await _diseaseGuideDecision(trialAssessmentId, def)
        : null;
    return GuideAvailabilityDiagnostics(
      hasGuide: false,
      reason: decision?.reason ?? 'only unsafe filtered guide anchors found',
      trialAssessmentId: trialAssessmentId,
      assessmentDefinitionId: assessmentDefinitionId,
      assessmentDefinitionCode: def?.code,
      cropContext: cropContext,
      targetContext: targetContext,
      definitionGuideCount: guides.length,
      lane1RawAnchorCount: lane1RawAnchors,
      lane1SafeAnchorCount: lane1SafeAnchors,
    );
  }

  // ── Lane 3: customer uploads ─────────────────────────────────────────────

  /// All non-deleted Lane 3 anchors for [trialAssessmentId], ordered by sortOrder.
  Stream<List<AssessmentGuideAnchor>> watchCustomerAnchors(
      int trialAssessmentId) {
    final guideQuery = _db.select(_db.assessmentGuides)
      ..where((g) => g.trialAssessmentId.equals(trialAssessmentId));

    return guideQuery.watch().asyncExpand((guides) {
      if (guides.isEmpty) return Stream.value(<AssessmentGuideAnchor>[]);
      final ids = guides.map((g) => g.id).toList();
      return (_db.select(_db.assessmentGuideAnchors)
            ..where((a) =>
                a.guideId.isIn(ids) &
                a.isDeleted.equals(0) &
                a.lane.equals('customer_upload'))
            ..orderBy([(a) => drift.OrderingTerm.asc(a.sortOrder)]))
          .watch();
    });
  }

  /// Adds a customer image for [trialAssessmentId].
  /// [tempPath] is the picked file's temporary location — moved into the
  /// app documents directory under guides/ with a UUID filename.
  Future<void> addCustomerImage({
    required int trialAssessmentId,
    required String tempPath,
    required String attributionString,
  }) async {
    final guide = await _getOrCreateGuideForTrialAssessment(trialAssessmentId);
    final finalPath = await _moveToGuidesDir(tempPath);
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final nextOrder = await (_db.customSelect(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next '
      'FROM assessment_guide_anchors WHERE guide_id = ?',
      variables: [drift.Variable.withInt(guide.id)],
    ).getSingle())
        .then((r) => r.read<int>('next'));

    await _db.into(_db.assessmentGuideAnchors).insert(
          AssessmentGuideAnchorsCompanion.insert(
            guideId: guide.id,
            sortOrder: drift.Value(nextOrder),
            filePath: drift.Value(finalPath),
            lane: 'customer_upload',
            contentType: 'customer_photo',
            attributionString: attributionString,
            licenseIdentifier: const drift.Value('customer_grant_v1'),
            dateObtained: today,
          ),
        );
  }

  /// Soft-deletes a guide anchor. Does not delete the file on disk.
  Future<void> deleteAnchor(int anchorId) async {
    await (_db.update(_db.assessmentGuideAnchors)
          ..where((a) => a.id.equals(anchorId)))
        .write(
            const AssessmentGuideAnchorsCompanion(isDeleted: drift.Value(1)));
  }

  // ── GLP audit trail ──────────────────────────────────────────────────────

  /// Writes one view event when the reference overlay opens. Call on open,
  /// not on close. This is the GLP audit trail for the guide view.
  Future<void> recordViewEvent({
    required int guideId,
    required int trialAssessmentId,
    required int sessionId,
    int? raterUserId,
  }) async {
    await _db.into(_db.ratingGuideViewEvents).insert(
          RatingGuideViewEventsCompanion.insert(
            guideId: guideId,
            trialAssessmentId: trialAssessmentId,
            sessionId: sessionId,
            viewedAt: DateTime.now().millisecondsSinceEpoch,
            raterUserId: drift.Value(raterUserId),
          ),
        );
  }

  // ── Priority resolver for overlay content ────────────────────────────────

  /// Returns the highest-priority non-empty guide + its anchors for the
  /// rating screen overlay. Priority: Lane 3 > Lane 2 > Lane 1.
  /// Returns null when nothing exists (icon must not be shown).
  Future<ResolvedGuide?> resolveGuideForDisplay({
    required int trialAssessmentId,
    int? assessmentDefinitionId,
  }) async {
    // Lane 3 — trial-specific customer upload
    final lane3 = await _resolveGuideForLane(
      trialAssessmentId: trialAssessmentId,
      lane: 'customer_upload',
    );
    if (lane3 != null) return lane3;

    // Lanes 1/2 — type-wide (by assessment definition)
    if (assessmentDefinitionId != null) {
      final lane2 = await _resolveDefGuideForLane(
        trialAssessmentId: trialAssessmentId,
        assessmentDefinitionId: assessmentDefinitionId,
        lane: 'identification_photo',
      );
      if (lane2 != null) return lane2;

      final lane1 = await _resolveDefGuideForLane(
        trialAssessmentId: trialAssessmentId,
        assessmentDefinitionId: assessmentDefinitionId,
        lane: 'calibration_diagram',
      );
      if (lane1 != null) return lane1;
    }
    return null;
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  Future<AssessmentGuide> _getOrCreateGuideForTrialAssessment(
      int trialAssessmentId) async {
    final existing = await (_db.select(_db.assessmentGuides)
          ..where((g) => g.trialAssessmentId.equals(trialAssessmentId)))
        .getSingleOrNull();
    if (existing != null) return existing;

    final id = await _db.into(_db.assessmentGuides).insert(
          AssessmentGuidesCompanion.insert(
            trialAssessmentId: drift.Value(trialAssessmentId),
          ),
        );
    return (_db.select(_db.assessmentGuides)..where((g) => g.id.equals(id)))
        .getSingle();
  }

  Future<ResolvedGuide?> _resolveGuideForLane({
    required int trialAssessmentId,
    required String lane,
  }) async {
    final guides = await (_db.select(_db.assessmentGuides)
          ..where((g) => g.trialAssessmentId.equals(trialAssessmentId)))
        .get();
    for (final g in guides) {
      final anchors = await (_db.select(_db.assessmentGuideAnchors)
            ..where((a) =>
                a.guideId.equals(g.id) &
                a.isDeleted.equals(0) &
                a.lane.equals(lane))
            ..orderBy([(a) => drift.OrderingTerm.asc(a.sortOrder)]))
          .get();
      if (anchors.isNotEmpty) return ResolvedGuide(guide: g, anchors: anchors);
    }
    return null;
  }

  Future<ResolvedGuide?> _resolveDefGuideForLane({
    required int trialAssessmentId,
    required int assessmentDefinitionId,
    required String lane,
  }) async {
    final guides = await (_db.select(_db.assessmentGuides)
          ..where(
              (g) => g.assessmentDefinitionId.equals(assessmentDefinitionId)))
        .get();
    for (final g in guides) {
      final anchors = await (_db.select(_db.assessmentGuideAnchors)
            ..where((a) =>
                a.guideId.equals(g.id) &
                a.isDeleted.equals(0) &
                a.lane.equals(lane))
            ..orderBy([(a) => drift.OrderingTerm.asc(a.sortOrder)]))
          .get();
      final filtered = lane == 'calibration_diagram'
          ? await _filterCalibrationAnchorsForContext(
              trialAssessmentId: trialAssessmentId,
              assessmentDefinitionId: assessmentDefinitionId,
              anchors: anchors,
            )
          : anchors;
      if (filtered.isNotEmpty) {
        return ResolvedGuide(guide: g, anchors: filtered);
      }
    }
    return null;
  }

  Future<List<AssessmentGuideAnchor>> _filterCalibrationAnchorsForContext({
    required int trialAssessmentId,
    required int assessmentDefinitionId,
    required List<AssessmentGuideAnchor> anchors,
  }) async {
    if (anchors.isEmpty) return anchors;

    final def = await (_db.select(_db.assessmentDefinitions)
          ..where((d) => d.id.equals(assessmentDefinitionId)))
        .getSingleOrNull();
    if (def?.code != 'DISEASE_SEV') return anchors;

    final diseaseGuideAsset = await _diseaseGuideAssetForContext(
      trialAssessmentId,
      def,
    );
    if (diseaseGuideAsset == null) return const [];

    return anchors
        .where((a) => a.sourceUrl == diseaseGuideAsset)
        .toList(growable: false);
  }

  Future<String?> _diseaseGuideAssetForContext(
    int trialAssessmentId,
    AssessmentDefinition? def,
  ) async {
    return (await _diseaseGuideDecision(trialAssessmentId, def)).asset;
  }

  Future<_DiseaseGuideDecision> _diseaseGuideDecision(
    int trialAssessmentId,
    AssessmentDefinition? def,
  ) async {
    final ta = await (_db.select(_db.trialAssessments)
          ..where((t) => t.id.equals(trialAssessmentId)))
        .getSingleOrNull();
    if (ta == null) {
      return const _DiseaseGuideDecision(
        asset: null,
        reason: 'no trialAssessment row',
      );
    }

    final trial = await (_db.select(_db.trials)
          ..where((t) => t.id.equals(ta.trialId)))
        .getSingleOrNull();
    final aam = await (_db.select(_db.armAssessmentMetadata)
          ..where((a) => a.trialAssessmentId.equals(ta.id)))
        .getSingleOrNull();

    final cropText = _contextText([
      trial?.crop,
      trial?.name,
      aam?.shellCropName,
      aam?.shellCropCode,
    ]);
    final targetText = _contextText([
      ta.displayNameOverride,
      ta.pestName,
      ta.eppoCodeLocal,
      ta.methodOverride,
      ta.instructionOverride,
      def?.name,
      def?.target,
      def?.method,
      def?.defaultInstructions,
      def?.eppoCode,
      def?.cropPart,
      aam?.seName,
      aam?.seDescription,
      aam?.partRated,
      aam?.ratingType,
      aam?.pestCode,
      aam?.pestCodeSecondary,
      aam?.shellPestType,
      aam?.shellPestName,
      aam?.shellCropOrPest,
    ]);

    if (_isCanola(cropText) && _isSclerotinia(targetText)) {
      return const _DiseaseGuideDecision(
        asset: _canolaSclerotiniaAsset,
        reason: 'guide exists and is safe: canola sclerotinia context',
      );
    }
    if (_isWheat(cropText)) {
      return const _DiseaseGuideDecision(
        asset: _wheatDiseaseAsset,
        reason: 'guide exists and is safe: wheat disease context',
      );
    }
    if (cropText.isEmpty) {
      return const _DiseaseGuideDecision(
        asset: null,
        reason: 'crop context missing',
      );
    }
    if (_isCanola(cropText)) {
      return const _DiseaseGuideDecision(
        asset: null,
        reason:
            'rejected canola sclerotinia guide for generic disease severity',
      );
    }
    return const _DiseaseGuideDecision(
      asset: null,
      reason: 'only crop-specific disease guides found for another crop',
    );
  }

  Future<int> _anchorCountForTrialAssessmentLane({
    required int trialAssessmentId,
    required String lane,
  }) async {
    final guides = await (_db.select(_db.assessmentGuides)
          ..where((g) => g.trialAssessmentId.equals(trialAssessmentId)))
        .get();
    if (guides.isEmpty) return 0;
    final guideIds = guides.map((g) => g.id).toList(growable: false);
    final row = await (_db.customSelect(
      'SELECT COUNT(*) AS count FROM assessment_guide_anchors '
      'WHERE guide_id IN (${guideIds.map((_) => '?').join(',')}) '
      'AND is_deleted = 0 AND lane = ?',
      variables: [
        for (final id in guideIds) drift.Variable.withInt(id),
        drift.Variable.withString(lane),
      ],
    )).getSingle();
    return row.read<int>('count');
  }

  Future<int> _anchorCountForDefinitionLane({
    required int assessmentDefinitionId,
    required String lane,
  }) async {
    final guides = await (_db.select(_db.assessmentGuides)
          ..where(
              (g) => g.assessmentDefinitionId.equals(assessmentDefinitionId)))
        .get();
    if (guides.isEmpty) return 0;
    final guideIds = guides.map((g) => g.id).toList(growable: false);
    final row = await (_db.customSelect(
      'SELECT COUNT(*) AS count FROM assessment_guide_anchors '
      'WHERE guide_id IN (${guideIds.map((_) => '?').join(',')}) '
      'AND is_deleted = 0 AND lane = ?',
      variables: [
        for (final id in guideIds) drift.Variable.withInt(id),
        drift.Variable.withString(lane),
      ],
    )).getSingle();
    return row.read<int>('count');
  }

  static String _contextText(Iterable<String?> values) {
    return values
        .whereType<String>()
        .map((v) => v.trim().toLowerCase())
        .where((v) => v.isNotEmpty)
        .join(' ');
  }

  static bool _isWheat(String text) =>
      text.contains('wheat') || text.contains('triticum');

  static bool _isCanola(String text) =>
      text.contains('canola') ||
      text.contains('rapeseed') ||
      text.contains('brassica napus');

  static bool _isSclerotinia(String text) =>
      text.contains('sclerotinia') ||
      text.contains('sclerotiorum') ||
      text.contains('white mold') ||
      text.contains('white mould') ||
      text.contains('stem rot') ||
      text.contains('scle');

  static Future<String> _moveToGuidesDir(String tempPath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final guidesDir = Directory(path.join(docsDir.path, 'guides'));
    if (!guidesDir.existsSync()) guidesDir.createSync(recursive: true);
    final ext = path.extension(tempPath).toLowerCase();
    final fileName = '${_uuid.v4()}$ext';
    final finalPath = path.join(guidesDir.path, fileName);
    await File(tempPath).copy(finalPath);
    return finalPath;
  }
}

class ResolvedGuide {
  const ResolvedGuide({required this.guide, required this.anchors});
  final AssessmentGuide guide;
  final List<AssessmentGuideAnchor> anchors;
}

class GuideAvailabilityDiagnostics {
  const GuideAvailabilityDiagnostics({
    required this.hasGuide,
    required this.reason,
    required this.trialAssessmentId,
    required this.assessmentDefinitionId,
    this.assessmentDefinitionCode,
    this.cropContext = '',
    this.targetContext = '',
    this.definitionGuideCount = 0,
    this.lane3AnchorCount = 0,
    this.lane2AnchorCount = 0,
    this.lane1RawAnchorCount = 0,
    this.lane1SafeAnchorCount = 0,
  });

  final bool hasGuide;
  final String reason;
  final int trialAssessmentId;
  final int? assessmentDefinitionId;
  final String? assessmentDefinitionCode;
  final String cropContext;
  final String targetContext;
  final int definitionGuideCount;
  final int lane3AnchorCount;
  final int lane2AnchorCount;
  final int lane1RawAnchorCount;
  final int lane1SafeAnchorCount;

  Map<String, Object?> toLogMap() => {
        'hasGuide': hasGuide,
        'reason': reason,
        'trialAssessmentId': trialAssessmentId,
        'assessmentDefinitionId': assessmentDefinitionId,
        'assessmentDefinitionCode': assessmentDefinitionCode,
        'cropContext': cropContext,
        'targetContext': targetContext,
        'definitionGuideCount': definitionGuideCount,
        'lane3AnchorCount': lane3AnchorCount,
        'lane2AnchorCount': lane2AnchorCount,
        'lane1RawAnchorCount': lane1RawAnchorCount,
        'lane1SafeAnchorCount': lane1SafeAnchorCount,
      };
}

class _DiseaseGuideDecision {
  const _DiseaseGuideDecision({
    required this.asset,
    required this.reason,
  });

  final String? asset;
  final String reason;
}
