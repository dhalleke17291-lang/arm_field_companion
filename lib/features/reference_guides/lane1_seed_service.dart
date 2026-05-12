import 'dart:convert';

import 'package:drift/drift.dart' as drift;

import '../../core/database/app_database.dart';

/// Seeds Lane 1 (calibration diagram) content into assessment_guide_anchors.
///
/// Idempotent: checks for existing calibration_diagram rows for each
/// source_url before inserting. Calling seedIfNeeded() multiple times
/// produces the same result as calling it once.
///
/// Diagrams are seeded as unvalidated (validated_by = null) and display
/// a "Pending validation" badge in the overlay until a human marks them
/// validated. The seed call must run after _seedAssessmentDefinitions()
/// so that the assessment definition codes are already present.
class Lane1SeedService {
  const Lane1SeedService(this._db);

  final AppDatabase _db;

  static const String _lane = 'calibration_diagram';
  static const String _contentType = 'ai_generated_svg';
  static const String _license = 'original_work_agnexis';
  static const String _weedCoverAssetPath =
      'assets/reference_guides/lane1/weed_cover_percent.svg';
  static const String _weedCoverLegacyAssetPath =
      'assets/reference_guides/lane1/weed_control_percent.svg';
  static const String _weedCoverAttribution =
      'Weed cover reference diagram © Agnexis.';

  static const String _eppopp152Citation =
      'EPPO (2021). PP 1/152 Design and analysis of efficacy evaluation '
      'trials. European and Mediterranean Plant Protection Organization.';

  static const String _eppopp181Citation =
      'EPPO (2021). PP 1/181 Phytotoxicity assessment. European and '
      'Mediterranean Plant Protection Organization.';

  Future<void> seedIfNeeded() async {
    await _repairSeededLane1Anchors();
    await _seedDiseaseSeverity();
    await _seedWeedCover();
    await _seedCropInjury();
    await _seedStandCoverage();
  }

  // ── Disease severity — wheat + canola in one guide ───────────────────────

  Future<void> _seedDiseaseSeverity() async {
    const wheat = 'assets/reference_guides/lane1/wheat_disease_severity.svg';
    const canola = 'assets/reference_guides/lane1/canola_disease_severity.svg';

    // Both diagrams share the DISEASE_SEV guide. Check both source_urls.
    final alreadySeeded = await _anyAnchorExists([wheat, canola]);
    if (alreadySeeded) return;

    final defId = await _definitionIdByCode('DISEASE_SEV');
    if (defId == null) return;

    final guide = await _getOrCreateDefGuide(defId);
    final today = _today();

    await _db.into(_db.assessmentGuideAnchors).insert(
          AssessmentGuideAnchorsCompanion.insert(
            guideId: guide.id,
            sortOrder: const drift.Value(0),
            lane: _lane,
            contentType: _contentType,
            sourceUrl: const drift.Value(wheat),
            licenseIdentifier: const drift.Value(_license),
            attributionString:
                'Wheat disease severity scale diagram © Agnexis. '
                'Scale based on EPPO PP1/152 guidelines.',
            generationSpecification: drift.Value(jsonEncode({
              'crop': 'wheat',
              'assessment_type': 'disease_severity',
              'scale_values': [0, 5, 10, 25, 50, 75, 100],
              'visual': 'sad_style_wheat_leaf_irregular_lesions',
            })),
            citationFull: const drift.Value(_eppopp152Citation),
            dateObtained: today,
            dateLastVerified: drift.Value(today),
          ),
        );

    await _db.into(_db.assessmentGuideAnchors).insert(
          AssessmentGuideAnchorsCompanion.insert(
            guideId: guide.id,
            sortOrder: const drift.Value(1),
            lane: _lane,
            contentType: _contentType,
            sourceUrl: const drift.Value(canola),
            licenseIdentifier: const drift.Value(_license),
            attributionString:
                'Canola sclerotinia severity score diagram © Agnexis. '
                'Original calibration reference pending crop-pathology validation.',
            generationSpecification: drift.Value(jsonEncode({
              'crop': 'canola',
              'assessment_type': 'sclerotinia_stem_severity_score',
              'scale_values': [0, 1, 2, 3, 4, 5],
              'scale_labels': [
                'Healthy',
                'Superficial stem lesion',
                'Limited wilt',
                'Moderate wilt',
                'Severe girdling',
                'Collapse/lodging'
              ],
              'visual': 'whole_plant_stem_sclerotinia_progression',
            })),
            citationFull: const drift.Value(_eppopp152Citation),
            dateObtained: today,
            dateLastVerified: drift.Value(today),
          ),
        );
  }

  // ── Weed cover ───────────────────────────────────────────────────────────

  Future<void> _seedWeedCover() async {
    if (await _anyAnchorExists([_weedCoverAssetPath])) return;

    final defId = await _definitionIdByCode('WEED_COVER');
    if (defId == null) return;

    final guide = await _getOrCreateDefGuide(defId);
    final today = _today();

    await _db.into(_db.assessmentGuideAnchors).insert(
          AssessmentGuideAnchorsCompanion.insert(
            guideId: guide.id,
            sortOrder: const drift.Value(0),
            lane: _lane,
            contentType: _contentType,
            sourceUrl: const drift.Value(_weedCoverAssetPath),
            licenseIdentifier: const drift.Value(_license),
            attributionString: _weedCoverAttribution,
            generationSpecification: drift.Value(_weedCoverSpecJson()),
            citationFull: const drift.Value(_eppopp152Citation),
            dateObtained: today,
            dateLastVerified: drift.Value(today),
          ),
        );
  }

  // ── Crop injury ───────────────────────────────────────────────────────────

  Future<void> _seedCropInjury() async {
    const assetPath =
        'assets/reference_guides/lane1/crop_injury_categorical.svg';
    if (await _anyAnchorExists([assetPath])) return;

    final defId = await _definitionIdByCode('CROP_INJURY');
    if (defId == null) return;

    final guide = await _getOrCreateDefGuide(defId);
    final today = _today();

    await _db.into(_db.assessmentGuideAnchors).insert(
          AssessmentGuideAnchorsCompanion.insert(
            guideId: guide.id,
            sortOrder: const drift.Value(0),
            lane: _lane,
            contentType: _contentType,
            sourceUrl: const drift.Value(assetPath),
            licenseIdentifier: const drift.Value(_license),
            attributionString:
                'Crop injury categorical scale diagram © Agnexis. '
                'Scale based on EPPO PP1/181 guidelines.',
            generationSpecification: drift.Value(jsonEncode({
              'assessment_type': 'crop_injury',
              'scale_values': [0, 1, 2, 3, 4],
              'scale_labels': [
                'None',
                'Slight',
                'Moderate',
                'Severe',
                'Plant death'
              ],
              'visual': 'plant_silhouette_progressive_damage',
            })),
            citationFull: const drift.Value(_eppopp181Citation),
            dateObtained: today,
            dateLastVerified: drift.Value(today),
          ),
        );
  }

  // ── Stand coverage ────────────────────────────────────────────────────────

  Future<void> _seedStandCoverage() async {
    const assetPath =
        'assets/reference_guides/lane1/stand_coverage_percent.svg';
    if (await _anyAnchorExists([assetPath])) return;

    final defId = await _definitionIdByCode('STAND_COVER');
    if (defId == null) return;

    final guide = await _getOrCreateDefGuide(defId);
    final today = _today();

    await _db.into(_db.assessmentGuideAnchors).insert(
          AssessmentGuideAnchorsCompanion.insert(
            guideId: guide.id,
            sortOrder: const drift.Value(0),
            lane: _lane,
            contentType: _contentType,
            sourceUrl: const drift.Value(assetPath),
            licenseIdentifier: const drift.Value(_license),
            attributionString: 'Stand coverage scale diagram © Agnexis. '
                'Scale based on EPPO PP1/152 guidelines.',
            generationSpecification: drift.Value(jsonEncode({
              'assessment_type': 'stand_coverage',
              'scale_values': [0, 25, 50, 75, 100],
              'visual': 'overhead_crop_row_canopy_occupancy',
            })),
            citationFull: const drift.Value(_eppopp152Citation),
            dateObtained: today,
            dateLastVerified: drift.Value(today),
          ),
        );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _repairSeededLane1Anchors() async {
    await _repairWeedCoverAnchor();
  }

  Future<void> _repairWeedCoverAnchor() async {
    final defId = await _definitionIdByCode('WEED_COVER');
    final guideIds = <int>{};
    if (defId != null) {
      final guide = await (_db.select(_db.assessmentGuides)
            ..where((g) => g.assessmentDefinitionId.equals(defId)))
          .getSingleOrNull();
      if (guide != null) guideIds.add(guide.id);
    }

    final candidates = await (_db.select(_db.assessmentGuideAnchors)
          ..where(
            (a) =>
                a.lane.equals(_lane) &
                a.isDeleted.equals(0) &
                a.sourceUrl.isIn(
                  [_weedCoverLegacyAssetPath, _weedCoverAssetPath],
                ),
          ))
        .get();

    for (final anchor in candidates) {
      if (guideIds.isNotEmpty && !guideIds.contains(anchor.guideId)) {
        continue;
      }
      await (_db.update(_db.assessmentGuideAnchors)
            ..where((a) => a.id.equals(anchor.id)))
          .write(
        AssessmentGuideAnchorsCompanion(
          sourceUrl: const drift.Value(_weedCoverAssetPath),
          contentType: const drift.Value(_contentType),
          licenseIdentifier: const drift.Value(_license),
          attributionString: const drift.Value(_weedCoverAttribution),
          generationSpecification: drift.Value(_weedCoverSpecJson()),
          citationFull: const drift.Value(_eppopp152Citation),
        ),
      );
    }
  }

  /// Returns true if any non-deleted anchor already exists for any of the
  /// given source_url values. Used for idempotency check.
  Future<bool> _anyAnchorExists(List<String> sourceUrls) async {
    for (final url in sourceUrls) {
      final row = await (_db.select(_db.assessmentGuideAnchors)
            ..where((a) =>
                a.sourceUrl.equals(url) &
                a.lane.equals(_lane) &
                a.isDeleted.equals(0)))
          .getSingleOrNull();
      if (row != null) return true;
    }
    return false;
  }

  Future<int?> _definitionIdByCode(String code) async {
    final def = await (_db.select(_db.assessmentDefinitions)
          ..where((d) => d.code.equals(code)))
        .getSingleOrNull();
    return def?.id;
  }

  Future<AssessmentGuide> _getOrCreateDefGuide(
      int assessmentDefinitionId) async {
    final existing = await (_db.select(_db.assessmentGuides)
          ..where(
              (g) => g.assessmentDefinitionId.equals(assessmentDefinitionId)))
        .getSingleOrNull();
    if (existing != null) return existing;

    final id = await _db.into(_db.assessmentGuides).insert(
          AssessmentGuidesCompanion.insert(
            assessmentDefinitionId: drift.Value(assessmentDefinitionId),
          ),
        );
    return (_db.select(_db.assessmentGuides)..where((g) => g.id.equals(id)))
        .getSingle();
  }

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);

  static String _weedCoverSpecJson() => jsonEncode({
        'assessment_type': 'weed_cover',
        'scale_values': [0, 10, 25, 50, 75, 90, 100],
        'visual': 'overhead_quadrat_irregular_canopy_occupancy',
        'description':
            'Focused reference view: weed cover overhead quadrat reference. '
                'Absolute canopy/ground occupancy, pending validation.',
      });
}
