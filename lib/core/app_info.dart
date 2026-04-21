/// Single place for app version (align with pubspec.yaml version).
const String kAppVersion = '1.0.0';

/// Short git SHA of this build. Populate at build time with:
///   --dart-define=GIT_SHA=$(git rev-parse --short HEAD)
/// Empty string in plain `flutter run` / local dev builds.
const String kBuildGitSha = String.fromEnvironment('GIT_SHA');

/// Build date in YYYY-MM-DD form. Populate at build time with:
///   --dart-define=BUILD_DATE=$(date +%Y-%m-%d)
/// Empty string in plain `flutter run` / local dev builds.
const String kBuildDate = String.fromEnvironment('BUILD_DATE');

/// Build channel (release / beta / internal / dev). Populate at build time
/// with --dart-define=BUILD_CHANNEL=release. Empty string by default.
const String kBuildChannel = String.fromEnvironment('BUILD_CHANNEL');
