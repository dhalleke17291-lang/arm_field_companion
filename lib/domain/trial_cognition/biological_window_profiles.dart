// Biological window profiles for application timing CTQ evaluation.
// Defines BBCH ranges by crop and pesticide category. Used by matchProfile
// and the Step 4 window check in trial_ctq_evaluator.dart.

class BiologicalWindowProfile {
  const BiologicalWindowProfile({
    required this.pesticideCategory,
    required this.cropKey,
    required this.cropAliases,
    required this.optimalBbchMin,
    required this.optimalBbchMax,
    required this.acceptableBbchMin,
    required this.acceptableBbchMax,
    required this.optimalWindowLabel,
    required this.acceptableWindowLabel,
    required this.cropLabel,
  });

  final String pesticideCategory;
  final String cropKey;

  /// Lowercase aliases matched against normalised trials.crop.
  final List<String> cropAliases;
  final int optimalBbchMin;
  final int optimalBbchMax;
  final int acceptableBbchMin;
  final int acceptableBbchMax;
  final String optimalWindowLabel;
  final String acceptableWindowLabel;

  /// Display name used in reason strings.
  final String cropLabel;
}

const List<BiologicalWindowProfile> kBiologicalWindowProfiles = [
  // ── Wheat herbicide ──────────────────────────────────────────────────────
  BiologicalWindowProfile(
    pesticideCategory: 'herbicide',
    cropKey: 'wheat',
    cropAliases: [
      'wheat',
      'spring wheat',
      'winter wheat',
      'cwrs',
      'durum',
      'hard red spring',
      'hrw',
    ],
    optimalBbchMin: 12,
    optimalBbchMax: 30,
    acceptableBbchMin: 12,
    acceptableBbchMax: 45,
    optimalWindowLabel: 'BBCH 12–30',
    acceptableWindowLabel: 'BBCH 12–45',
    cropLabel: 'Wheat',
  ),
  // ── Wheat fungicide (FHB / flag leaf) ────────────────────────────────────
  BiologicalWindowProfile(
    pesticideCategory: 'fungicide',
    cropKey: 'wheat',
    cropAliases: [
      'wheat',
      'spring wheat',
      'winter wheat',
      'cwrs',
      'durum',
      'hard red spring',
      'hrw',
    ],
    optimalBbchMin: 61,
    optimalBbchMax: 65,
    acceptableBbchMin: 37,
    acceptableBbchMax: 69,
    optimalWindowLabel: 'BBCH 61–65 (anthesis)',
    acceptableWindowLabel: 'BBCH 37–69',
    cropLabel: 'Wheat',
  ),
  // ── Canola fungicide (Sclerotinia) ────────────────────────────────────────
  BiologicalWindowProfile(
    pesticideCategory: 'fungicide',
    cropKey: 'canola',
    cropAliases: ['canola', 'rapeseed', 'oilseed rape', 'brassica'],
    optimalBbchMin: 62,
    optimalBbchMax: 63,
    acceptableBbchMin: 62,
    acceptableBbchMax: 65,
    optimalWindowLabel: 'BBCH 62–63 (20–30% bloom)',
    acceptableWindowLabel: 'BBCH 62–65 (up to 50% bloom)',
    cropLabel: 'Canola',
  ),
  // ── Canola herbicide ──────────────────────────────────────────────────────
  BiologicalWindowProfile(
    pesticideCategory: 'herbicide',
    cropKey: 'canola',
    cropAliases: ['canola', 'rapeseed', 'oilseed rape', 'brassica'],
    optimalBbchMin: 12,
    optimalBbchMax: 16,
    acceptableBbchMin: 10,
    acceptableBbchMax: 30,
    optimalWindowLabel: 'BBCH 12–16',
    acceptableWindowLabel: 'BBCH 10–30',
    cropLabel: 'Canola',
  ),
];

/// Returns the first [BiologicalWindowProfile] matching [crop] and
/// [pesticideCategory], or null when no profile is configured.
///
/// Matching: normalise both inputs to lowercase+trim, then test each
/// profile alias as a substring of the normalised crop string.
/// First match across [kBiologicalWindowProfiles] wins.
BiologicalWindowProfile? matchProfile(
  String? crop,
  String? pesticideCategory,
) {
  if (crop == null || pesticideCategory == null) return null;
  final normalizedCrop = crop.trim().toLowerCase();
  final normalizedCategory = pesticideCategory.trim().toLowerCase();
  if (normalizedCrop.isEmpty || normalizedCategory.isEmpty) return null;
  for (final profile in kBiologicalWindowProfiles) {
    if (profile.pesticideCategory != normalizedCategory) continue;
    for (final alias in profile.cropAliases) {
      if (normalizedCrop.contains(alias)) return profile;
    }
  }
  return null;
}
