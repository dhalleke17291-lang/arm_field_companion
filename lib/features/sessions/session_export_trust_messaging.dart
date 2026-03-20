// Shared copy for session export trust surfaces (dialog + caption).
// Metrics are computed elsewhere; this file only formats text.

const String kSessionExportTrustEditedClarification =
    'Edited includes amendments, re-saves, and corrections.';

const String kSessionExportTrustDialogIntro =
    'Quick summary of this session before you export.';

/// Bullet lines for the pre-export dialog (compact, calm).
List<String> sessionExportTrustDialogBodyLines({
  required bool noRatings,
  required int unratedPlots,
  required int issuesPlotCount,
  required int editedPlotCount,
}) {
  final lines = <String>[];
  if (noRatings) {
    lines.add('No ratings recorded for this session.');
  } else {
    if (unratedPlots > 0) {
      lines.add(
        '$unratedPlots plot${unratedPlots == 1 ? '' : 's'} '
        'have no rating in this session yet.',
      );
    }
    if (issuesPlotCount > 0) {
      lines.add(
        '$issuesPlotCount plot${issuesPlotCount == 1 ? '' : 's'} '
        'use a status other than recorded (for example missing or N/A).',
      );
    }
    if (editedPlotCount > 0) {
      lines.add(
        '$editedPlotCount plot${editedPlotCount == 1 ? '' : 's'} '
        'have edited data.',
      );
    }
  }
  if (lines.isEmpty) {
    lines.add('No extra notes — the export reflects current session data.');
  }
  return lines;
}

/// Single-line summary for the session detail caption (matches dialog signals).
String sessionExportTrustCaptionPrimaryLine({
  required bool noRatings,
  required int unratedPlots,
  required int issuesPlotCount,
  required int editedPlotCount,
}) {
  if (noRatings) {
    return 'No ratings in this session';
  }
  final parts = <String>[];
  if (unratedPlots > 0) {
    parts.add('$unratedPlots not rated yet');
  }
  if (issuesPlotCount > 0) {
    parts.add('$issuesPlotCount non-recorded status');
  }
  if (editedPlotCount > 0) {
    parts.add('$editedPlotCount edited');
  }
  if (parts.isEmpty) {
    return 'No extra notes for this export';
  }
  return parts.join(' · ');
}
