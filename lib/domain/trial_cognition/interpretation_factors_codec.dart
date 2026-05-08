import 'dart:convert';

/// Canonical keys for trial_purposes.known_interpretation_factors.
///
/// The DB column stores a JSON array of these keys, with an optional
/// {"other": "text"} object for free-text elaboration.
///
/// Encoding contract:
///   null   → question not asked / not answered
///   '[]'   → researcher reviewed and selected none
///   '[...]' → one or more selected keys, optionally with {"other":"..."}
const List<String> kInterpretationFactorKeys = [
  'low_pest_pressure',
  'high_pest_pressure',
  'drought_stress',
  'excessive_rainfall',
  'frost_risk',
  'spatial_gradient',
  'previous_crop_residue',
  'atypical_season',
  'drainage_issues',
  'other',
];

const Map<String, String> kInterpretationFactorLabels = {
  'low_pest_pressure': 'Low pest / disease pressure',
  'high_pest_pressure': 'High pest / disease pressure',
  'drought_stress': 'Drought stress',
  'excessive_rainfall': 'Excessive rainfall',
  'frost_risk': 'Frost risk',
  'spatial_gradient': 'Spatial gradient in the field',
  'previous_crop_residue': 'Previous crop residue effects',
  'atypical_season': 'Atypical season',
  'drainage_issues': 'Drainage issues',
  'other': 'Other',
};

const int _kOtherTextMaxLength = 200;

class InterpretationFactorsResult {
  const InterpretationFactorsResult({
    required this.selectedKeys,
    this.otherText,
    required this.wasAnswered,
  });

  /// Known factor keys selected by the researcher (not including 'other'
  /// when [otherText] is non-null — 'other' is expressed via [otherText]).
  final List<String> selectedKeys;

  /// Free-text description when 'other' was selected. null = not selected.
  final String? otherText;

  /// True when the column held a value (including [] = none selected).
  /// False only when the raw column value was null (unanswered/not asked).
  final bool wasAnswered;

  bool get hasOther => otherText != null;
  bool get noneSelected =>
      wasAnswered && selectedKeys.isEmpty && otherText == null;
}

class InterpretationFactorsCodec {
  /// Serializes [selectedKeys] + optional [otherText] to a JSON string.
  ///
  /// [otherText] is trimmed and clamped to [_kOtherTextMaxLength] chars.
  /// Passing empty [selectedKeys] with no [otherText] produces '[]'.
  static String serialize(List<String> selectedKeys, {String? otherText}) {
    final items = <dynamic>[...selectedKeys];
    if (otherText != null) {
      final trimmed = otherText.trim();
      if (trimmed.isNotEmpty) {
        items.add({
          'other': trimmed.length > _kOtherTextMaxLength
              ? trimmed.substring(0, _kOtherTextMaxLength)
              : trimmed,
        });
      }
    }
    return jsonEncode(items);
  }

  /// Parses [raw] into [InterpretationFactorsResult].
  ///
  /// Returns null when [raw] is null (unanswered/not asked).
  /// Returns a safe result (wasAnswered: true, selectedKeys: []) for
  /// malformed JSON — never throws.
  static InterpretationFactorsResult? parse(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const InterpretationFactorsResult(
          selectedKeys: [],
          wasAnswered: true,
        );
      }
      final keys = <String>[];
      String? otherText;
      for (final item in decoded) {
        if (item is String) {
          keys.add(item);
        } else if (item is Map) {
          final text = item['other'];
          if (text is String) otherText = text;
        }
      }
      return InterpretationFactorsResult(
        selectedKeys: List.unmodifiable(keys),
        otherText: otherText,
        wasAnswered: true,
      );
    } catch (_) {
      return const InterpretationFactorsResult(
        selectedKeys: [],
        wasAnswered: true,
      );
    }
  }
}
