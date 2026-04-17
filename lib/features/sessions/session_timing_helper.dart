import '../../core/database/app_database.dart';

/// DAT / DAS fragments for session headers. When both counts are [0], only
/// **Application day** is emitted (application precedence over seeding).
List<String> timingDatDasDisplayParts({
  int? daysAfterFirstApp,
  int? daysAfterSeeding,
}) {
  final parts = <String>[];
  final hasDat = daysAfterFirstApp != null;
  final hasDas = daysAfterSeeding != null;
  final bothZero = hasDat &&
      hasDas &&
      daysAfterFirstApp == 0 &&
      daysAfterSeeding == 0;
  if (hasDat) {
    parts.add(daysAfterFirstApp == 0
        ? 'Application day'
        : '$daysAfterFirstApp DAT');
  }
  if (hasDas) {
    if (bothZero) return parts;
    parts.add(
        daysAfterSeeding == 0 ? 'Seeding day' : '$daysAfterSeeding DAS');
  }
  return parts;
}

/// Relative timing and optional BBCH for a rating session (field display + export helpers).
class SessionTimingContext {
  const SessionTimingContext({
    this.daysAfterSeeding,
    this.daysAfterFirstApp,
    this.daysAfterLastApp,
    this.cropStageBbch,
    this.lastAppLabel,
  });

  final int? daysAfterSeeding;
  final int? daysAfterFirstApp;
  final int? daysAfterLastApp;
  final int? cropStageBbch;

  /// Human-readable label for the most recent application, e.g.
  /// "Application 2, Apr 15". Null when no applications exist.
  final String? lastAppLabel;

  /// BBCH · DAT (App label) · DAS — non-null parts with application context.
  String get displayLine {
    final parts = <String>[];
    if (cropStageBbch != null) parts.add('BBCH $cropStageBbch');
    final datDas = timingDatDasDisplayParts(
      daysAfterFirstApp: daysAfterFirstApp,
      daysAfterSeeding: daysAfterSeeding,
    );
    if (datDas.isNotEmpty && lastAppLabel != null) {
      parts.add('${datDas.first} ($lastAppLabel)');
      if (datDas.length > 1) parts.addAll(datDas.skip(1));
    } else {
      parts.addAll(datDas);
    }
    return parts.join(' · ');
  }

  /// DAT · DAS only (e.g. header line when BBCH is shown as its own chip).
  String get displayLineDatDasOnly {
    return timingDatDasDisplayParts(
      daysAfterFirstApp: daysAfterFirstApp,
      daysAfterSeeding: daysAfterSeeding,
    ).join(' · ');
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

  // Build a label for the most recent application.
  String? lastAppLabel;
  if (applied.isNotEmpty) {
    applied.sort((a, b) => a.applicationDate.compareTo(b.applicationDate));
    final lastIdx = applied.length;
    final lastApp = applied.last;
    final m = lastApp.applicationDate.month;
    final d = lastApp.applicationDate.day;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    lastAppLabel = 'Application $lastIdx, ${months[m - 1]} $d';
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
    lastAppLabel: lastAppLabel,
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
