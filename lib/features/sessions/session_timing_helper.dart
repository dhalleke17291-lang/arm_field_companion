import '../../core/database/app_database.dart';

/// Relative timing and optional BBCH for a rating session (field display + export helpers).
class SessionTimingContext {
  const SessionTimingContext({
    this.daysAfterSeeding,
    this.daysAfterFirstApp,
    this.daysAfterLastApp,
    this.cropStageBbch,
  });

  final int? daysAfterSeeding;
  final int? daysAfterFirstApp;
  final int? daysAfterLastApp;
  final int? cropStageBbch;

  /// BBCH · DAT · DAS — only non-null parts (matches export/session UX order).
  String get displayLine {
    final parts = <String>[];
    if (cropStageBbch != null) parts.add('BBCH $cropStageBbch');
    if (daysAfterFirstApp != null) parts.add('$daysAfterFirstApp DAT');
    if (daysAfterSeeding != null) parts.add('$daysAfterSeeding DAS');
    return parts.join(' · ');
  }

  /// DAT · DAS only (e.g. header line when BBCH is shown as its own chip).
  String get displayLineDatDasOnly {
    final parts = <String>[];
    if (daysAfterFirstApp != null) parts.add('$daysAfterFirstApp DAT');
    if (daysAfterSeeding != null) parts.add('$daysAfterSeeding DAS');
    return parts.join(' · ');
  }

  bool get isEmpty =>
      daysAfterSeeding == null &&
      daysAfterFirstApp == null &&
      daysAfterLastApp == null &&
      cropStageBbch == null;
}

/// DAS uses completed seeding only; DAT/DAL use applied [TrialApplicationEvent]s only.
SessionTimingContext buildSessionTimingContext({
  required DateTime sessionStartedAt,
  required int? cropStageBbch,
  required SeedingEvent? seeding,
  required List<TrialApplicationEvent> applications,
}) {
  final DateTime? seedingDate =
      (seeding != null && seeding.status == 'completed') ? seeding.seedingDate : null;

  final applied = applications.where((e) => e.status == 'applied').toList();
  DateTime? firstAppDate;
  DateTime? lastAppDate;
  if (applied.isNotEmpty) {
    firstAppDate = applied.map((e) => e.applicationDate).reduce((a, b) => a.isBefore(b) ? a : b);
    lastAppDate = applied.map((e) => e.applicationDate).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  return SessionTimingContext(
    daysAfterSeeding: seedingDate != null
        ? sessionStartedAt.difference(seedingDate).inDays
        : null,
    daysAfterFirstApp:
        firstAppDate != null ? sessionStartedAt.difference(firstAppDate).inDays : null,
    daysAfterLastApp:
        lastAppDate != null ? sessionStartedAt.difference(lastAppDate).inDays : null,
    cropStageBbch: cropStageBbch,
  );
}

/// Validates optional BBCH entry (0–99). Returns parsed value or error message.
String? validateCropStageBbchInput(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final v = int.tryParse(t);
  if (v == null) return 'Enter a whole number or leave blank';
  if (v < 0 || v > 99) return 'BBCH must be between 0 and 99';
  return null;
}

/// Parses optional BBCH; returns null if blank. Caller should validate first.
int? parseCropStageBbchOrNull(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  return int.parse(t);
}
