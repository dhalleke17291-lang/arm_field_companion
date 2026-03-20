/// Shared constants for assessment result direction metadata.
/// Used for internal reporting/analysis; not exported to ARM.
class AssessmentResultDirection {
  AssessmentResultDirection._();

  static const String higherBetter = 'higherBetter';
  static const String lowerBetter = 'lowerBetter';
  static const String neutral = 'neutral';

  static const List<String> values = [higherBetter, lowerBetter, neutral];
}
