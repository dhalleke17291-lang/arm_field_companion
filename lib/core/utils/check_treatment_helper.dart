import '../database/app_database.dart';

/// Returns true if [t] is a check / untreated control treatment.
///
/// Matches on [Treatment.code] or [Treatment.treatmentType]:
/// CHK, UTC, CONTROL (case-insensitive).
bool isCheckTreatment(Treatment t) {
  final code = t.code.trim().toUpperCase();
  if (code == 'CHK' || code == 'UTC' || code == 'CONTROL') return true;
  final type = t.treatmentType?.trim().toUpperCase();
  if (type == 'CHK' || type == 'UTC' || type == 'CONTROL') return true;
  return false;
}
