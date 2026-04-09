import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> copyDirectory(Directory source, Directory destination) async {
  if (!await source.exists()) return;
  await destination.create(recursive: true);
  await for (final entity in source.list(recursive: false)) {
    final base = p.basename(entity.path);
    final destPath = p.join(destination.path, base);
    if (entity is Directory) {
      await copyDirectory(entity, Directory(destPath));
    } else if (entity is File) {
      await entity.copy(destPath);
    }
  }
}

Future<void> deleteDirectoryIfExists(Directory dir) async {
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
}

Future<int> directorySizeBytes(Directory dir) async {
  if (!await dir.exists()) return 0;
  var total = 0;
  await for (final entity in dir.list(recursive: true)) {
    if (entity is File) {
      total += await entity.length();
    }
  }
  return total;
}
