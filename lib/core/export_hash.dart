import 'dart:io';

import 'package:crypto/crypto.dart';

/// Computes SHA-256 hash of an exported file and returns it as a hex string.
/// Used to prove the file hasn't been modified after export.
Future<String> computeExportHash(File file) async {
  final bytes = await file.readAsBytes();
  final digest = sha256.convert(bytes);
  return digest.toString();
}

/// Formats hash for display: algorithm + first 16 chars.
String formatExportHash(String fullHash) {
  final short = fullHash.length > 16 ? fullHash.substring(0, 16) : fullHash;
  return 'SHA-256: $short...';
}
