import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';

import '../../core/database/app_database.dart';
import 'lane2a_approved_photo_manifest.dart';

/// Lane 2A bundled reference photo categories.
///
/// Lane 2A is metadata-first. No bundled photo is seeded unless an exact image
/// file has been manually reviewed and approved by Parminder.
enum Lane2AReferenceCategory {
  weedSeedlingReference,
  volunteerCropAsWeed,
  cropIdentificationGrowthReference,
}

extension Lane2AReferenceCategoryDb on Lane2AReferenceCategory {
  String get dbValue {
    switch (this) {
      case Lane2AReferenceCategory.weedSeedlingReference:
        return 'weed_seedling_reference';
      case Lane2AReferenceCategory.volunteerCropAsWeed:
        return 'volunteer_crop_as_weed';
      case Lane2AReferenceCategory.cropIdentificationGrowthReference:
        return 'crop_identification_growth_reference';
    }
  }

  String get displayLabel {
    switch (this) {
      case Lane2AReferenceCategory.weedSeedlingReference:
        return 'Weed seedling reference';
      case Lane2AReferenceCategory.volunteerCropAsWeed:
        return 'Volunteer crop as weed';
      case Lane2AReferenceCategory.cropIdentificationGrowthReference:
        return 'Crop identification / growth reference';
    }
  }
}

class Lane2AReferencePhotoSeed {
  const Lane2AReferencePhotoSeed({
    required this.assessmentDefinitionCode,
    required this.category,
    required this.speciesCode,
    required this.speciesScientificName,
    required this.commonName,
    required this.sourceDataset,
    required this.sourceUrl,
    required this.sourceDoi,
    required this.authorCreator,
    required this.exactLicense,
    required this.licenseAppliesToImageFile,
    required this.dateObtained,
    required this.dateLastVerified,
    required this.citationText,
    required this.localAssetPath,
    required this.approvedBy,
    required this.approvedAt,
    required this.approvedForBundling,
    required this.shortReferenceNote,
    this.subjectLabel,
    this.focalX,
    this.focalY,
    this.cropZoom,
    this.sortOrder = 0,
  });

  final String assessmentDefinitionCode;
  final Lane2AReferenceCategory category;
  final String speciesCode;
  final String speciesScientificName;
  final String commonName;
  final String sourceDataset;
  final String? sourceUrl;
  final String? sourceDoi;
  final String? authorCreator;
  final String exactLicense;
  final bool licenseAppliesToImageFile;
  final String dateObtained;
  final String dateLastVerified;
  final String citationText;
  final String localAssetPath;
  final String approvedBy;
  final String approvedAt;
  final bool approvedForBundling;
  final String shortReferenceNote;
  final String? subjectLabel;
  final double? focalX;
  final double? focalY;
  final double? cropZoom;
  final int sortOrder;

  factory Lane2AReferencePhotoSeed.fromManifest(
    Map<String, Object?> manifest,
  ) {
    return Lane2AReferencePhotoSeed(
      assessmentDefinitionCode:
          _requiredString(manifest, 'assessmentDefinitionCode'),
      category: _categoryFromManifest(_requiredString(manifest, 'category')),
      speciesCode: _requiredString(manifest, 'speciesCode'),
      speciesScientificName: _requiredString(
        manifest,
        'speciesScientificName',
      ),
      commonName: _requiredString(manifest, 'commonName'),
      sourceDataset: _requiredString(manifest, 'sourceDataset'),
      sourceUrl: _optionalString(manifest['sourceUrl']),
      sourceDoi: _optionalString(manifest['sourceDoi']),
      authorCreator: _optionalString(manifest['authorCreator']),
      exactLicense: _requiredString(manifest, 'exactLicense'),
      licenseAppliesToImageFile:
          _requiredBool(manifest, 'licenseAppliesToImageFile'),
      dateObtained: _requiredString(manifest, 'dateObtained'),
      dateLastVerified: _requiredString(manifest, 'dateLastVerified'),
      citationText: _requiredString(manifest, 'citationFull'),
      localAssetPath: _requiredString(manifest, 'localAssetPath'),
      approvedBy: _requiredString(manifest, 'approvedBy'),
      approvedAt: _requiredString(manifest, 'approvedAt'),
      approvedForBundling: _requiredBool(manifest, 'approvedForBundling'),
      shortReferenceNote: _requiredString(manifest, 'shortReferenceNote'),
      subjectLabel: _optionalString(manifest['subjectLabel']),
      focalX: _optionalDouble(manifest['focalX']),
      focalY: _optionalDouble(manifest['focalY']),
      cropZoom: _optionalDouble(manifest['cropZoom']),
      sortOrder: _optionalInt(manifest['sortOrder']) ?? 0,
    );
  }

  void validateForBundling() {
    if (!approvedForBundling) {
      throw ArgumentError('Lane 2A photo is not approved for bundling.');
    }
    if (approvedBy.trim().toLowerCase() != 'parminder') {
      throw ArgumentError('Lane 2A photo must be approved by Parminder.');
    }
    if (!licenseAppliesToImageFile) {
      throw ArgumentError(
        'Lane 2A license must be verified for the exact image file.',
      );
    }
    if (!_isAllowedImageLicense(exactLicense)) {
      throw ArgumentError('Unsupported Lane 2A image license: $exactLicense');
    }
    if (_isCcBy(exactLicense) && _isBlank(authorCreator)) {
      throw ArgumentError('CC-BY Lane 2A photos require an author/creator.');
    }
    if (_isBlank(sourceUrl) && _isBlank(sourceDoi)) {
      throw ArgumentError('Lane 2A photo requires a source URL or DOI.');
    }
    if (_isBlank(sourceDataset) ||
        _isBlank(speciesCode) ||
        _isBlank(speciesScientificName) ||
        _isBlank(commonName) ||
        _isBlank(citationText) ||
        _isBlank(localAssetPath) ||
        _isBlank(dateObtained) ||
        _isBlank(dateLastVerified) ||
        _isBlank(approvedAt) ||
        _isBlank(shortReferenceNote)) {
      throw ArgumentError('Lane 2A photo metadata is incomplete.');
    }
  }

  String metadataJson() {
    return jsonEncode({
      'lane': 'lane_2a',
      'category': category.dbValue,
      'categoryLabel': category.displayLabel,
      'speciesCode': speciesCode,
      'speciesScientificName': speciesScientificName,
      'commonName': commonName,
      'sourceDataset': sourceDataset,
      'sourceUrl': sourceUrl,
      'sourceDoi': sourceDoi,
      'authorCreator': authorCreator,
      'exactLicense': exactLicense,
      'licenseAppliesToImageFile': licenseAppliesToImageFile,
      'dateObtained': dateObtained,
      'dateLastVerified': dateLastVerified,
      'citationText': citationText,
      'localAssetPath': localAssetPath,
      'shortReferenceNote': shortReferenceNote,
      'manualReview': {
        'approvedBy': approvedBy,
        'approvedAt': approvedAt,
        'approvedForBundling': approvedForBundling,
      },
      if (!_isBlank(subjectLabel)) 'subjectLabel': subjectLabel,
      if (focalX != null) 'focalX': focalX,
      if (focalY != null) 'focalY': focalY,
      if (cropZoom != null) 'cropZoom': cropZoom,
    });
  }

  String attributionString() {
    final creator = authorCreator == null || authorCreator!.trim().isEmpty
        ? 'creator unavailable'
        : authorCreator!.trim();
    return '$commonName reference photo by $creator. '
        'Dataset: $sourceDataset. License: $exactLicense.';
  }

  static bool _isAllowedImageLicense(String license) {
    final normalized = license.trim().toLowerCase();
    return normalized == 'cc0-1.0' ||
        normalized == 'cc0' ||
        normalized == 'public_domain' ||
        normalized == 'public domain' ||
        normalized == 'cc-by-4.0' ||
        normalized == 'cc-by-3.0' ||
        normalized == 'cc-by-2.0' ||
        normalized == 'pddl-1.0' ||
        normalized == 'pddl';
  }

  static bool _isCcBy(String license) =>
      license.trim().toLowerCase().startsWith('cc-by');

  static bool _isBlank(String? value) => value == null || value.trim().isEmpty;

  static String _requiredString(
    Map<String, Object?> manifest,
    String key,
  ) {
    final value = _optionalString(manifest[key]);
    if (value == null) {
      throw ArgumentError('Lane 2A manifest is missing "$key".');
    }
    return value;
  }

  static String? _optionalString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _requiredBool(
    Map<String, Object?> manifest,
    String key,
  ) {
    final value = manifest[key];
    if (value is bool) return value;
    throw ArgumentError('Lane 2A manifest "$key" must be a boolean.');
  }

  static int? _optionalInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _optionalDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static Lane2AReferenceCategory _categoryFromManifest(String raw) {
    switch (raw.trim()) {
      case 'weed_seedling_reference':
        return Lane2AReferenceCategory.weedSeedlingReference;
      case 'volunteer_crop_as_weed':
        return Lane2AReferenceCategory.volunteerCropAsWeed;
      case 'crop_identification_growth_reference':
        return Lane2AReferenceCategory.cropIdentificationGrowthReference;
    }
    throw ArgumentError('Unsupported Lane 2A reference category: $raw');
  }
}

/// Exact files manually approved for bundled Lane 2A seeding.
///
/// The manifest intentionally starts empty. Add entries only after Parminder has
/// reviewed the exact image file and its file-level license.
List<Lane2AReferencePhotoSeed> approvedLane2AReferencePhotos() {
  return lane2AApprovedPhotoManifestEntries
      .map(Lane2AReferencePhotoSeed.fromManifest)
      .toList(growable: false);
}

typedef Lane2AAssetExists = Future<bool> Function(String path);

class Lane2AReferencePhotoSeedService {
  Lane2AReferencePhotoSeedService(
    this._db, {
    List<Lane2AReferencePhotoSeed>? approvedReferences,
    Lane2AAssetExists? assetExists,
  })  : approvedReferences =
            approvedReferences ?? const <Lane2AReferencePhotoSeed>[],
        _assetExists = assetExists ?? _defaultAssetExists;

  Lane2AReferencePhotoSeedService.fromBundledManifest(
    this._db, {
    Lane2AAssetExists? assetExists,
  })  : approvedReferences = approvedLane2AReferencePhotos(),
        _assetExists = assetExists ?? _defaultAssetExists;

  final AppDatabase _db;
  final List<Lane2AReferencePhotoSeed> approvedReferences;
  final Lane2AAssetExists _assetExists;

  static const String lane = 'identification_photo';
  static const String contentType = 'curated_reference_photo';

  Future<void> seedIfNeeded() async {
    for (final reference in approvedReferences) {
      await seedApprovedReference(reference);
    }
  }

  Future<void> seedApprovedReference(
    Lane2AReferencePhotoSeed reference,
  ) async {
    reference.validateForBundling();
    if (!await _assetExists(reference.localAssetPath)) {
      throw StateError(
        'Lane 2A manifest asset is missing: ${reference.localAssetPath}',
      );
    }

    if (await _anchorExists(reference)) return;

    final defId = await _definitionIdByCode(reference.assessmentDefinitionCode);
    if (defId == null) return;

    final guide = await _getOrCreateDefGuide(defId);

    await _db.into(_db.assessmentGuideAnchors).insert(
          AssessmentGuideAnchorsCompanion.insert(
            guideId: guide.id,
            sortOrder: drift.Value(reference.sortOrder),
            filePath: drift.Value(reference.localAssetPath),
            lane: lane,
            contentType: contentType,
            sourceUrl: drift.Value(reference.sourceUrl ?? reference.sourceDoi),
            licenseIdentifier: drift.Value(reference.exactLicense),
            attributionString: reference.attributionString(),
            generationSpecification: drift.Value(reference.metadataJson()),
            citationFull: drift.Value(reference.citationText),
            dateObtained: reference.dateObtained,
            dateLastVerified: drift.Value(reference.dateLastVerified),
          ),
        );
  }

  Future<bool> _anchorExists(Lane2AReferencePhotoSeed reference) async {
    final sourceLocator = reference.sourceUrl ?? reference.sourceDoi ?? '';
    final existing = await (_db.select(_db.assessmentGuideAnchors)
          ..where(
            (a) =>
                a.lane.equals(lane) &
                a.isDeleted.equals(0) &
                (a.filePath.equals(reference.localAssetPath) |
                    a.sourceUrl.equals(sourceLocator)),
          ))
        .getSingleOrNull();
    return existing != null;
  }

  Future<int?> _definitionIdByCode(String code) async {
    final def = await (_db.select(_db.assessmentDefinitions)
          ..where((d) => d.code.equals(code)))
        .getSingleOrNull();
    return def?.id;
  }

  Future<AssessmentGuide> _getOrCreateDefGuide(
    int assessmentDefinitionId,
  ) async {
    final existing = await (_db.select(_db.assessmentGuides)
          ..where(
            (g) => g.assessmentDefinitionId.equals(assessmentDefinitionId),
          ))
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

  static Future<bool> _defaultAssetExists(String path) async {
    if (path.startsWith('assets/')) {
      try {
        await rootBundle.load(path);
        return true;
      } catch (_) {
        return false;
      }
    }
    return File(path).exists();
  }
}
