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

/// Earliest allowed operation date: Jan 1 of the year the trial was created.
/// Allows backdating field operations that happened before the trial was
/// entered into the app.
DateTime earliestTrialOperationDate(DateTime trialCreatedAt) =>
    DateTime(trialCreatedAt.toLocal().year, 1, 1);

/// Seeding date: not in the future; not before start of trial year.
String? validateSeedingDate({
  required DateTime seedingDate,
  required DateTime trialCreatedAt,
}) {
  final sd = dateOnlyLocal(seedingDate);
  final floor = earliestTrialOperationDate(trialCreatedAt);
  if (sd.isAfter(_todayDateOnlyLocal())) {
    return 'Seeding date cannot be in the future';
  }
  if (sd.isBefore(floor)) {
    return 'Seeding date cannot be before ${floor.year}';
  }
  return null;
}

/// Emergence calendar day must be on or after seeding day; not in the future.
String? validateEmergenceDate({
  required DateTime seedingDate,
  required DateTime emergenceDate,
}) {
  final ed = dateOnlyLocal(emergenceDate);
  final seed = dateOnlyLocal(seedingDate);
  if (ed.isAfter(_todayDateOnlyLocal())) {
    return 'Emergence date cannot be in the future';
  }
  if (ed.isBefore(seed)) {
    return 'Emergence date cannot be before seeding date';
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

/// Application (planned) date: not future; not before start of trial year;
/// on or after seeding day if seeding exists.
String? validateApplicationEventDate({
  required DateTime applicationDate,
  required DateTime trialCreatedAt,
  DateTime? seedingDate,
}) {
  final ad = dateOnlyLocal(applicationDate);
  if (ad.isAfter(_todayDateOnlyLocal())) {
    return 'Application date cannot be in the future';
  }
  final floor = earliestTrialOperationDate(trialCreatedAt);
  if (ad.isBefore(floor)) {
    return 'Application date cannot be before ${floor.year}';
  }
  if (seedingDate != null) {
    final sd = dateOnlyLocal(seedingDate);
    if (ad.isBefore(sd)) {
      return 'Application date cannot be before seeding date';
    }
  }
  return null;
}

/// Applied timestamp: date part not future; on or after seeding calendar day
/// if seeding exists; not before start of trial year.
String? validateAppliedDateTime({
  required DateTime appliedAt,
  required DateTime trialCreatedAt,
  DateTime? seedingDate,
}) {
  final ad = dateOnlyLocal(appliedAt);
  if (ad.isAfter(_todayDateOnlyLocal())) {
    return 'Applied date cannot be in the future';
  }
  final floor = earliestTrialOperationDate(trialCreatedAt);
  if (ad.isBefore(floor)) {
    return 'Applied date cannot be before ${floor.year}';
  }
  if (seedingDate != null) {
    final sd = dateOnlyLocal(seedingDate);
    if (ad.isBefore(sd)) {
      return 'Applied date cannot be before seeding date';
    }
  }
  return null;
}

/// [sessionDateLocal] is `yyyy-MM-dd`. Sessions must always be today.
String? validateSessionDateLocal({
  required String sessionDateLocal,
  required DateTime trialCreatedAt,
}) {
  final d = DateTime.tryParse('$sessionDateLocal 12:00:00');
  if (d == null) {
    return 'Invalid session date';
  }
  final sd = dateOnlyLocal(d);
  final today = _todayDateOnlyLocal();
  if (sd.isBefore(today) || sd.isAfter(today)) {
    return 'Sessions can only be created for today';
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

/// Earliest calendar day allowed for applications (and "applied on"):
/// start of trial year, or seeding day if that is later.
DateTime minimumApplicationOrAppliedDate({
  required DateTime trialCreatedAt,
  DateTime? seedingDate,
}) {
  var min = earliestTrialOperationDate(trialCreatedAt);
  if (seedingDate != null) {
    final seed = dateOnlyLocal(seedingDate);
    if (seed.isAfter(min)) {
      min = seed;
    }
  }
  return min;
}
