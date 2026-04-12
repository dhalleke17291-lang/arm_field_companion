/// Thrown when persisted operational dates violate field rules.
class OperationalDateRuleException implements Exception {
  OperationalDateRuleException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Local calendar date (year, month, day); ignores clock time.
DateTime dateOnlyLocal(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

DateTime _todayDateOnlyLocal() => dateOnlyLocal(DateTime.now());

/// Seeding date: not in the future; not before trial existed.
String? validateSeedingDate({
  required DateTime seedingDate,
  required DateTime trialCreatedAt,
}) {
  final sd = dateOnlyLocal(seedingDate);
  final tc = dateOnlyLocal(trialCreatedAt);
  if (sd.isAfter(_todayDateOnlyLocal())) {
    return 'Seeding date cannot be in the future';
  }
  if (sd.isBefore(tc)) {
    return 'Seeding date cannot be before the trial was created';
  }
  return null;
}

/// Emergence must be strictly after seeding day, not in the future.
String? validateEmergenceDate({
  required DateTime seedingDate,
  required DateTime emergenceDate,
}) {
  final ed = dateOnlyLocal(emergenceDate);
  final seed = dateOnlyLocal(seedingDate);
  if (ed.isAfter(_todayDateOnlyLocal())) {
    return 'Emergence date cannot be in the future';
  }
  if (!ed.isAfter(seed)) {
    return 'Emergence date must be after seeding date';
  }
  return null;
}

/// Emergence % in [0, 100], or null if omitted.
String? validateEmergencePercent(double? emergencePct) {
  if (emergencePct == null) return null;
  if (emergencePct < 0 || emergencePct > 100) {
    return 'Emergence percentage must be between 0 and 100';
  }
  return null;
}

/// Application (planned) date: not future; not before trial; after seeding day if seeding exists.
String? validateApplicationEventDate({
  required DateTime applicationDate,
  required DateTime trialCreatedAt,
  DateTime? seedingDate,
}) {
  final ad = dateOnlyLocal(applicationDate);
  if (ad.isAfter(_todayDateOnlyLocal())) {
    return 'Application date cannot be in the future';
  }
  final tc = dateOnlyLocal(trialCreatedAt);
  if (ad.isBefore(tc)) {
    return 'Application date cannot be before the trial was created';
  }
  if (seedingDate != null) {
    final sd = dateOnlyLocal(seedingDate);
    if (!ad.isAfter(sd)) {
      return 'Application date must be after seeding date';
    }
  }
  return null;
}

/// Applied timestamp: date part not future; not on/before seeding day if seeding exists;
/// not before trial creation date.
String? validateAppliedDateTime({
  required DateTime appliedAt,
  required DateTime trialCreatedAt,
  DateTime? seedingDate,
}) {
  final ad = dateOnlyLocal(appliedAt);
  if (ad.isAfter(_todayDateOnlyLocal())) {
    return 'Applied date cannot be in the future';
  }
  final tc = dateOnlyLocal(trialCreatedAt);
  if (ad.isBefore(tc)) {
    return 'Applied date cannot be before the trial was created';
  }
  if (seedingDate != null) {
    final sd = dateOnlyLocal(seedingDate);
    if (!ad.isAfter(sd)) {
      return 'Applied date must be after seeding date';
    }
  }
  return null;
}

/// [sessionDateLocal] is `yyyy-MM-dd`.
String? validateSessionDateLocal({
  required String sessionDateLocal,
  required DateTime trialCreatedAt,
}) {
  final d = DateTime.tryParse('$sessionDateLocal 12:00:00');
  if (d == null) {
    return 'Invalid session date';
  }
  final sd = dateOnlyLocal(d);
  if (sd.isAfter(_todayDateOnlyLocal())) {
    return 'Session date cannot be in the future';
  }
  final tc = dateOnlyLocal(trialCreatedAt);
  if (sd.isBefore(tc)) {
    return 'Session date cannot be before the trial was created';
  }
  return null;
}

String? validateNotFutureUtc(DateTime at) {
  final today = _todayDateOnlyLocal();
  final d = dateOnlyLocal(at.toLocal());
  if (d.isAfter(today)) {
    return 'Date cannot be in the future';
  }
  return null;
}

/// Full [appliedAt] instant must not be after wall-clock now (field recording).
String? validateAppliedTimestampNotInFuture(DateTime appliedAt) {
  if (appliedAt.isAfter(DateTime.now())) {
    return 'Applied time cannot be in the future';
  }
  return null;
}

/// Earliest calendar day allowed for applications (and "applied on") after seeding exists.
DateTime minimumApplicationOrAppliedDate({
  required DateTime trialCreatedAt,
  DateTime? seedingDate,
}) {
  var min = dateOnlyLocal(trialCreatedAt);
  if (seedingDate != null) {
    final afterSeed =
        dateOnlyLocal(seedingDate).add(const Duration(days: 1));
    if (afterSeed.isAfter(min)) {
      min = afterSeed;
    }
  }
  return min;
}
