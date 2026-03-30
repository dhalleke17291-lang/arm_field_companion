class ArmRatingShellResult {
  final bool success;
  final String? filePath;
  final String? warningMessage;
  final String? errorMessage;

  const ArmRatingShellResult._({
    required this.success,
    this.filePath,
    this.warningMessage,
    this.errorMessage,
  });

  factory ArmRatingShellResult.ok({
    required String filePath,
    String? warningMessage,
  }) =>
      ArmRatingShellResult._(
        success: true,
        filePath: filePath,
        warningMessage: warningMessage,
      );

  factory ArmRatingShellResult.failure(String message) => ArmRatingShellResult._(
        success: false,
        errorMessage: message,
      );
}
