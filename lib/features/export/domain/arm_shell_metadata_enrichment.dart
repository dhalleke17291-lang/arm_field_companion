import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import 'shell_link_preview.dart';

/// Whether [a] and [b] refer to the same shell file path for enrichment gating.
bool shellMetadataExportPathsAreSame(String a, String b) {
  return p.equals(p.normalize(a), p.normalize(b));
}

/// True when export should ask to apply shell metadata before filling the shell.
///
/// Requires a preview that can apply, with at least one planned change, and the
/// trial must not already be linked to this same shell path (avoids silent
/// re-application when metadata was applied earlier for this file).
bool shouldOfferShellMetadataEnrichmentBeforeExport({
  required Trial trial,
  required String? existingLinkedShellPath,
  required String selectedShellPath,
  required ShellLinkPreview preview,
}) {
  if (!preview.canApply) return false;
  final hasChanges = preview.trialFieldChanges.isNotEmpty ||
      preview.assessmentFieldChanges.isNotEmpty;
  if (!hasChanges) return false;
  final linked = existingLinkedShellPath?.trim() ?? '';
  if (linked.isNotEmpty &&
      shellMetadataExportPathsAreSame(linked, selectedShellPath)) {
    return false;
  }
  return true;
}
