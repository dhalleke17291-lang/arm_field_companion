/// Maps curated library entry IDs ([AssessmentLibrary] entries) to canonical
/// system definition codes (seeded by [_seedAssessmentDefinitions]).
///
/// When a match exists, the standalone wizard and library picker reuse the
/// existing system definition rather than creating a per-trial LIB_* definition,
/// giving Lane 1 guide resolution a stable target.
///
/// Only entries that have a corresponding seeded system definition and
/// calibration diagram are listed here. Unmapped entries continue to use
/// the LIB_* path.
library;

/// Returns the system definition code for [libraryEntryId], or null if the
/// entry has no system-level counterpart.
String? systemCodeForLibraryEntry(String libraryEntryId) =>
    _kLibraryToSystemCode[libraryEntryId];

const Map<String, String> _kLibraryToSystemCode = {
  'fung_disease_severity': 'DISEASE_SEV',
  'phyto_crop_injury': 'CROP_INJURY',
  'herb_weed_control': 'WEED_COVER',
  'herb_weed_cover': 'WEED_COVER',
};
