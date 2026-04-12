import '../app_info.dart' show kAppVersion;

/// Single source for app display name used by Recovery export (ZIP name, README, manifest).
/// Rename the app here; do not duplicate this string in export code.
abstract final class AppInfo {
  AppInfo._();

  static const String appName = 'Agnexis';

  /// Mirrors [kAppVersion] (pubspec.yaml) for manifest/README traceability.
  static String get appVersion => kAppVersion;
}
