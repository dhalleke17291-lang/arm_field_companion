/// Validation for optional numeric fields on trial application event sheets (UI + save path).
const double _kMaxMagnitude = 1e8;

String? validateOptionalFiniteNumber(String label, double? value) {
  if (value == null) return null;
  if (value.isNaN || value.isInfinite) {
    return '$label must be a valid number';
  }
  if (value.abs() > _kMaxMagnitude) {
    return '$label is too large';
  }
  return null;
}

String? validateOptionalNonNegative(String label, double? value) {
  final fin = validateOptionalFiniteNumber(label, value);
  if (fin != null) return fin;
  if (value != null && value < 0) {
    return '$label cannot be negative';
  }
  return null;
}

String? validateOptionalHumidityPercent(String label, double? value) {
  final fin = validateOptionalFiniteNumber(label, value);
  if (fin != null) return fin;
  if (value == null) return null;
  if (value < 0 || value > 100) {
    return '$label must be between 0 and 100';
  }
  return null;
}

String? validateOptionalPh(String label, double? value) {
  final fin = validateOptionalFiniteNumber(label, value);
  if (fin != null) return fin;
  if (value == null) return null;
  if (value < 0 || value > 14) {
    return '$label must be between 0 and 14';
  }
  return null;
}

/// When [raw] is non-empty but not parseable as double.
String? validateRawDoubleField(String label, String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  if (double.tryParse(t) == null) {
    return '$label must be a valid number';
  }
  return null;
}
