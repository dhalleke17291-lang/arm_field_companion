// Shared copy for session export trust surfaces (dialog + caption).
// Metrics are computed elsewhere; this file only formats text.

const String kSessionExportTrustEditedClarification =
    'Info — edited includes amendments, re-saves, and corrections.';

const String kSessionExportTrustDialogIntro =
    'Info — quick summary of this session before you export.';

/// Bullet lines for the pre-export dialog (compact, calm).
List<String> sessionExportTrustDialogBodyLines({
  required bool noRatings,
  required int unratedPlots,
  required int issuesPlotCount,
  required int editedPlotCount,
}) {
  final lines = <String>[];
  if (noRatings) {
    lines.add('Info — no ratings recorded for this session.');
  } else {
    if (unratedPlots > 0) {
      lines.add(
        'Warnings — $unratedPlots plot${unratedPlots == 1 ? '' : 's'} '
        'have no rating in this session yet.',
      );
    }
    if (issuesPlotCount > 0) {
      lines.add(
        'Warnings — $issuesPlotCount plot${issuesPlotCount == 1 ? '' : 's'} '
        'use a status other than recorded (for example missing or N/A).',
      );
    }
    if (editedPlotCount > 0) {
      lines.add(
        'Info — $editedPlotCount plot${editedPlotCount == 1 ? '' : 's'} '
        'have edited data.',
      );
    }
  }
  if (lines.isEmpty) {
    lines.add('Info — export reflects current session data.');
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
    return 'Info — no ratings in this session';
  }
  final parts = <String>[];
  if (unratedPlots > 0) {
    parts.add('Warnings — $unratedPlots not rated yet');
  }
  if (issuesPlotCount > 0) {
    parts.add('Warnings — $issuesPlotCount not recorded');
  }
  if (editedPlotCount > 0) {
    parts.add('Info — $editedPlotCount edited');
  }
  if (parts.isEmpty) {
    return 'Info — no extra notes for this export';
  }
  return parts.join(' · ');
}
