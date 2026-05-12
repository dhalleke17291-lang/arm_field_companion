/// Maps curated library entry IDs to system assessment definition codes.
///
/// When a library entry matches a system definition, the trial assessment uses
/// the system definition ID instead of a per-trial LIB_* definition. This
/// enables Lane 1 and Lane 2 reference guides to appear for these assessment
/// types.
const kLibraryIdToSystemCode = {
  'fung_disease_severity': 'DISEASE_SEV',
  'herb_weed_cover': 'WEED_COVER',
  'growth_canopy_closure': 'STAND_COVER',
};

String? canonicalSystemAssessmentCode({
  String? libraryEntryId,
  required String name,
  required String dataType,
  String? unit,
  double? scaleMin,
  double? scaleMax,
  String? category,
}) {
  final libraryCode = libraryEntryId == null
      ? null
      : kLibraryIdToSystemCode[libraryEntryId.trim()];
  if (libraryCode != null) {
    return _scaleMatchesSystem(
      libraryCode,
      dataType: dataType,
      unit: unit,
      scaleMin: scaleMin,
      scaleMax: scaleMax,
    )
        ? libraryCode
        : null;
  }

  final normalizedName = _normalize(name);
  final normalizedCategory = _normalize(category ?? '');

  if (_isPercentScale(dataType, unit, scaleMin, scaleMax)) {
    if (normalizedName == 'disease severity' ||
        normalizedName == 'percent disease severity' ||
        normalizedName == '% disease severity') {
      return 'DISEASE_SEV';
    }
    if (normalizedName.contains('weed cover')) {
      return 'WEED_COVER';
    }
    if (normalizedName.contains('stand coverage') ||
        normalizedName.contains('stand cover') ||
        normalizedName.contains('crop stand coverage') ||
        normalizedName.contains('canopy closure')) {
      return 'STAND_COVER';
    }
  }

  if (_isCropInjuryScore(dataType, unit, scaleMin, scaleMax) &&
      (normalizedName.contains('crop injury') ||
          normalizedName.contains('phytotoxicity') ||
          normalizedCategory.contains('crop safety'))) {
    return 'CROP_INJURY';
  }

  return null;
}

bool _scaleMatchesSystem(
  String systemCode, {
  required String dataType,
  String? unit,
  double? scaleMin,
  double? scaleMax,
}) {
  switch (systemCode) {
    case 'DISEASE_SEV':
    case 'WEED_COVER':
    case 'STAND_COVER':
      return _isPercentScale(dataType, unit, scaleMin, scaleMax);
    case 'CROP_INJURY':
      return _isCropInjuryScore(dataType, unit, scaleMin, scaleMax);
  }
  return false;
}

bool _isPercentScale(
  String dataType,
  String? unit,
  double? scaleMin,
  double? scaleMax,
) {
  return dataType.trim().toLowerCase() == 'numeric' &&
      (unit ?? '').trim() == '%' &&
      scaleMin == 0 &&
      scaleMax == 100;
}

bool _isCropInjuryScore(
  String dataType,
  String? unit,
  double? scaleMin,
  double? scaleMax,
) {
  final normalizedUnit = (unit ?? '').trim().toLowerCase();
  return dataType.trim().toLowerCase() == 'ordinal' &&
      (normalizedUnit == 'score' || normalizedUnit.isEmpty) &&
      scaleMin == 0 &&
      scaleMax == 4;
}

String _normalize(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('%', 'percent')
      .replaceAll(RegExp(r'\s+'), ' ');
}
