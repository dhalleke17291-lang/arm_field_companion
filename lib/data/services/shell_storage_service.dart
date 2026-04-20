import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Copies a shell file into the app's internal documents directory and returns
/// the internal path. The stored path is stable across app restarts.
class ShellStorageService {
  /// Copies [sourcePath] to `{appDocumentsDir}/shells/{trialId}.xlsx`.
  /// Returns the internal path.
  static Future<String> storeShell({
    required String sourcePath,
    required int trialId,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final shellDir = Directory('${appDir.path}/shells');
    if (!shellDir.existsSync()) {
      await shellDir.create(recursive: true);
    }
    final destPath = '${shellDir.path}/$trialId.xlsx';
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// Returns the stored shell path for [trialId], or null if it doesn't exist.
  static Future<String?> resolveShellPath(int trialId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final destPath = '${appDir.path}/shells/$trialId.xlsx';
    final file = File(destPath);
    if (await file.exists()) return destPath;
    return null;
  }
}
