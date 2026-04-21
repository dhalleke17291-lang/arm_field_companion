import '../app_info.dart'
    show kAppVersion, kBuildChannel, kBuildDate, kBuildGitSha;

/// Single source for app display name used by Recovery export (ZIP name, README, manifest).
/// Rename the app here; do not duplicate this string in export code.
abstract final class AppInfo {
  AppInfo._();

  static const String appName = 'Agnexis';

  /// Mirrors [kAppVersion] (pubspec.yaml) for manifest/README traceability.
  static String get appVersion => kAppVersion;

  /// Short git SHA for this build, or empty in local dev.
  static String get buildGitSha => kBuildGitSha;

  /// Build date (YYYY-MM-DD) for this build, or empty in local dev.
  static String get buildDate => kBuildDate;

  /// Build channel label, or empty in local dev.
  static String get buildChannel => kBuildChannel;

  /// True when any build-time identity was injected.
  static bool get hasBuildMetadata =>
      kBuildGitSha.isNotEmpty ||
      kBuildDate.isNotEmpty ||
      kBuildChannel.isNotEmpty;

  /// Compact one-line build identity like "abc1234 · 2026-04-20 · release".
  /// Returns empty string when no metadata was injected.
  static String get buildIdentity {
    final parts = <String>[
      if (kBuildGitSha.isNotEmpty) kBuildGitSha,
      if (kBuildDate.isNotEmpty) kBuildDate,
      if (kBuildChannel.isNotEmpty) kBuildChannel,
    ];
    return parts.join(' · ');
  }
}
