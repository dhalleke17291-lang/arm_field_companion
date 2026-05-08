/// Canonical values for trial_purposes.regulatory_context.
///
/// The DB column stores the raw key (e.g. 'registration'). Use [labelFor] to
/// convert to a human-readable label for display.
abstract class RegulatoryContextValue {
  static const String registration = 'registration';
  static const String internalResearch = 'internal_research';
  static const String academic = 'academic';
  static const String undetermined = 'undetermined';

  static const List<String> all = [
    registration,
    internalResearch,
    academic,
    undetermined,
  ];

  static const Map<String, String> labels = {
    registration: 'Registration / regulatory submission',
    internalResearch: 'Internal research / product positioning',
    academic: 'Academic / extension / on-farm',
    undetermined: 'Not yet determined',
  };

  /// Human-readable label for [value], or null if [value] is not a known key.
  /// Legacy free-text values stored before B1 will return null.
  static String? labelFor(String? value) =>
      value == null ? null : labels[value];

  static bool isKnown(String? value) =>
      value != null && labels.containsKey(value);
}
