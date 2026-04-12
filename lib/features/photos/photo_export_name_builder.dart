import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';

/// English month abbreviations for export filenames (e.g. Apr-6-2026).
final DateFormat _asmDateFormat = DateFormat('MMM-d-yyyy', 'en_US');

/// Sanitizes [trialName] for use in photo export filenames.
///
/// Replaces any character that is not alphanumeric, space, hyphen, or
/// underscore with `_`, then replaces spaces with `_`. Trims. If empty,
/// returns `Trial`.
String sanitizeTrialNameForPhotoExport(String trialName) {
  var s = trialName.replaceAll(RegExp(r'[^a-zA-Z0-9 \-_]'), '_');
  s = s.replaceAll(RegExp(r'\s+'), '_').trim();
  if (s.isEmpty || !RegExp(r'[0-9a-zA-Z]').hasMatch(s)) {
    return 'Trial';
  }
  return s;
}

/// Plot segment: `P` + [Plot.armPlotNumber] when set, else `P` + sanitized
/// [Plot.plotId]. [plot] null → `P000`.
String formatPlotSegmentForPhotoExport(Plot? plot) {
  if (plot == null) return 'P000';
  if (plot.armPlotNumber != null) return 'P${plot.armPlotNumber}';
  final id = plot.plotId.replaceAll(RegExp(r'[^a-zA-Z0-9\-_]'), '_');
  if (id.isEmpty) return 'P000';
  return 'P$id';
}

/// Treatment segment for export filenames.
///
/// When [assignment] is null → `T0000`. Otherwise uses digits from
/// [Treatment.code] (first run); pads to 4 digits after `T`. Missing or
/// non-numeric code → `T0000`.
String formatTreatmentSegmentForPhotoExport(
  Assignment? assignment,
  Treatment? treatment,
) {
  if (assignment == null) return 'T0000';
  if (treatment == null) return 'T0000';
  final code = treatment.code.trim();
  if (code.isEmpty) return 'T0000';
  final match = RegExp(r'\d+').firstMatch(code);
  if (match == null) return 'T0000';
  final n = int.tryParse(match.group(0)!) ?? 0;
  return 'T${n.toString().padLeft(4, '0')}';
}

/// Filename stem (no extension, no sequence suffix) for collision grouping.
///
/// Photos sharing the same stem need `_01`, `_02`, … suffixes.
String buildPhotoExportNameStem({
  required Trial trial,
  Plot? plot,
  Assignment? assignment,
  Treatment? treatment,
  required DateTime photoCreatedAt,
}) {
  final trialSeg = sanitizeTrialNameForPhotoExport(trial.name);
  final tSeg = formatTreatmentSegmentForPhotoExport(assignment, treatment);
  final dSeg = _asmDateFormat.format(photoCreatedAt.toLocal());
  final pSeg = formatPlotSegmentForPhotoExport(plot);
  return '${trialSeg}_${tSeg}_${dSeg}_$pSeg';
}

/// Standard handoff ZIP photo basename:
/// `{trial}_{T####}_{MMM-d-yyyy}_{plot}[_NN].jpg`
///
/// [sequenceNumber]: `0` = no suffix; `1`…`99` → `_01`…`_99`.
String buildPhotoExportFileName({
  required Photo photo,
  required Trial trial,
  Plot? plot,
  Assignment? assignment,
  Treatment? treatment,
  required int sequenceNumber,
}) {
  final stem = buildPhotoExportNameStem(
    trial: trial,
    plot: plot,
    assignment: assignment,
    treatment: treatment,
    photoCreatedAt: photo.createdAt,
  );
  final seqSuffix = sequenceNumber > 0
      ? '_${sequenceNumber.toString().padLeft(2, '0')}'
      : '';
  return '$stem$seqSuffix.jpg';
}
