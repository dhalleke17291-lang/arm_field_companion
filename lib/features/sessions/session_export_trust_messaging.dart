// Shared copy for session export trust surfaces (dialog + caption).
// Metrics are computed elsewhere; this file only formats text.

const String kSessionExportTrustEditedClarification =
    'Info — edited includes amendments, re-saves, and corrections.';

const String kSessionExportTrustDialogIntro =
    'Info — quick summary of this session before you export.';

/// Session completeness (scientific): target plots, excludes guard rows — [expected]/[completed]/[incomplete]/[canClose].
List<String> sessionExportTrustSessionCompletenessDialogLines({
  required int expectedPlots,
  required int completedPlots,
  required int incompletePlots,
  required bool canClose,
}) {
  return [
    'Session completeness (target plots, excludes guard rows).',
    'Complete: $completedPlots / $expectedPlots · Incomplete: $incompletePlots · '
        '${canClose ? "Ready to close." : "Not ready to close — resolve session completeness blockers."}',
  ];
}

/// Navigation progress: trial plots without any current rating (not scientific completeness).
List<String> sessionExportTrustNavigationDialogLines({
  required bool noRatings,
  required int unratedPlots,
}) {
  if (noRatings || unratedPlots <= 0) return [];
  return [
    'Navigation progress (not session completeness).',
    'Plots without any current rating (all trial rows): $unratedPlots.',
  ];
}

/// Data quality: non-recorded statuses and edited plots.
List<String> sessionExportTrustDataQualityDialogLines({
  required bool noRatings,
  required int issuesPlotCount,
  required int editedPlotCount,
}) {
  if (noRatings) return [];
  final lines = <String>[];
  if (issuesPlotCount > 0 || editedPlotCount > 0) {
    lines.add('Data quality signals.');
    if (issuesPlotCount > 0) {
      lines.add(
        'Plots with a status other than recorded (for example missing or N/A): $issuesPlotCount.',
      );
    }
    if (editedPlotCount > 0) {
      lines.add(
        'Plots with edited data (amendments, re-saves, or corrections): $editedPlotCount.',
      );
    }
  }
  return lines;
}

/// Bullet lines for the pre-export dialog (compact, calm). Order: scientific → optional no-ratings → navigation → data quality.
List<String> sessionExportTrustDialogBodyLines({
  required int sessionExpectedPlots,
  required int sessionCompletedPlots,
  required int sessionIncompletePlots,
  required bool sessionCanClose,
  required bool noRatings,
  required int unratedPlots,
  required int issuesPlotCount,
  required int editedPlotCount,
}) {
  final lines = <String>[];

  lines.addAll(sessionExportTrustSessionCompletenessDialogLines(
    expectedPlots: sessionExpectedPlots,
    completedPlots: sessionCompletedPlots,
    incompletePlots: sessionIncompletePlots,
    canClose: sessionCanClose,
  ));

  if (noRatings) {
    lines.add('Info — no ratings recorded for this session.');
    return lines;
  }

  lines.addAll(sessionExportTrustNavigationDialogLines(
    noRatings: noRatings,
    unratedPlots: unratedPlots,
  ));

  lines.addAll(sessionExportTrustDataQualityDialogLines(
    noRatings: noRatings,
    issuesPlotCount: issuesPlotCount,
    editedPlotCount: editedPlotCount,
  ));

  if (lines.length <= 2) {
    // Only scientific section + no extra warnings — affirm export still reflects data.
    lines.add('Info — export reflects current session data.');
  }

  return lines;
}

/// Primary caption lines (same concepts as [sessionExportTrustDialogBodyLines], compressed).
List<String> sessionExportTrustCaptionLines({
  required int sessionExpectedPlots,
  required int sessionCompletedPlots,
  required int sessionIncompletePlots,
  required bool sessionCanClose,
  required bool noRatings,
  required int unratedPlots,
  required int issuesPlotCount,
  required int editedPlotCount,
}) {
  final line1 =
      'Session completeness: $sessionCompletedPlots / $sessionExpectedPlots complete · '
      '$sessionIncompletePlots incomplete · '
      '${sessionCanClose ? "Ready to close" : "Not ready to close"}';

  if (noRatings) {
    return [line1, 'Info — no ratings in this session'];
  }

  final navParts = <String>[];
  if (unratedPlots > 0) {
    navParts.add(
      'Navigation: $unratedPlots plot${unratedPlots == 1 ? '' : 's'} without any current rating',
    );
  }

  final dqParts = <String>[];
  if (issuesPlotCount > 0) {
    dqParts.add('$issuesPlotCount not recorded');
  }
  if (editedPlotCount > 0) {
    dqParts.add('$editedPlotCount edited');
  }

  final secondary = <String>[];
  if (navParts.isNotEmpty) secondary.add(navParts.join());
  if (dqParts.isNotEmpty) {
    secondary.add('Data quality: ${dqParts.join(' · ')}');
  }

  if (secondary.isEmpty) {
    return [line1, 'Info — no extra notes for this export'];
  }
  return [line1, secondary.join(' · ')];
}
