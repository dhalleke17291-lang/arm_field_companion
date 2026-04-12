/// Thrown when a rating-related operation violates data integrity rules.
class RatingIntegrityException implements Exception {
  RatingIntegrityException(this.message, {this.code = 'unspecified'});

  final String message;

  /// Stable machine-readable code (e.g. for logging or tests).
  final String code;

  @override
  String toString() => 'Rating integrity violation: $message';
}
