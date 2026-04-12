import 'package:intl/intl.dart';

/// Generates a deterministic photo filename for a plot/session capture.
///
/// Pattern: `{trialId}_P{plotLabel}_S{sessionId}_{yyyyMMdd}_{HHmm}_{seq}.jpg`
/// Example: `001_P101_S2_20260314_1034_01.jpg`
///
/// Uses project field names: [trialId] (Trials.id), [plotLabel] from
/// getDisplayPlotLabel(plot, sameTrialPlots), [sessionId] (Sessions.id).
String generatePhotoFileName({
  required int trialId,
  required String plotLabel,
  required int sessionId,
  required DateTime capturedAt,
  required int sequenceNumber,
}) {
  final t = trialId.toString().padLeft(3, '0');
  final safePlot = _sanitizeForFilename(plotLabel);
  final p = 'P$safePlot';
  final s = 'S$sessionId';
  final date = DateFormat('yyyyMMdd').format(capturedAt);
  final time = DateFormat('HHmm').format(capturedAt);
  final seq = sequenceNumber.toString().padLeft(2, '0');
  return '${t}_${p}_${s}_${date}_${time}_$seq.jpg';
}

String _sanitizeForFilename(String s) {
  return s.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_').trim();
}
