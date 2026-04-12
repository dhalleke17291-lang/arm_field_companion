/// Shared constants for assessment result direction metadata.
/// Used for internal reporting/analysis; not exported to ARM.
class AssessmentResultDirection {
  AssessmentResultDirection._();

  static const String higherBetter = 'higherBetter';
  static const String lowerBetter = 'lowerBetter';
  static const String neutral = 'neutral';

  static const List<String> values = [higherBetter, lowerBetter, neutral];
}

/// Type-safe result direction for the statistics layer.
/// Use this in new code. [AssessmentResultDirection] string constants
/// remain for backward compatibility with existing UI and export code.
enum ResultDirection {
  higherIsBetter,
  lowerIsBetter,
  neutral;

  /// Convert from legacy [AssessmentResultDirection] string constant.
  static ResultDirection fromString(String value) => switch (value) {
        AssessmentResultDirection.higherBetter => ResultDirection.higherIsBetter,
        AssessmentResultDirection.lowerBetter  => ResultDirection.lowerIsBetter,
        _                                      => ResultDirection.neutral,
      };
}
