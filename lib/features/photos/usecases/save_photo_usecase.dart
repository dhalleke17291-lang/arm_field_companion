import 'dart:io';
import '../photo_repository.dart';
import '../../../core/database/app_database.dart';

class SavePhotoUseCase {
  final PhotoRepository _photoRepository;

  SavePhotoUseCase(this._photoRepository);

  Future<SavePhotoResult> execute(SavePhotoInput input) async {
    try {
      // Verify temp file exists before attempting pipeline
      final tempFile = File(input.tempPath);
      if (!await tempFile.exists()) {
        return SavePhotoResult.failure(
            'Temp file not found: ${input.tempPath}');
      }

      final photo = await _photoRepository.savePhoto(
        trialId: input.trialId,
        plotPk: input.plotPk,
        sessionId: input.sessionId,
        tempPath: input.tempPath,
        finalPath: input.finalPath,
        caption: input.caption,
        raterName: input.raterName,
        performedByUserId: input.performedByUserId,
      );

      return SavePhotoResult.success(photo);
    } catch (e) {
      return SavePhotoResult.failure('Failed to save photo: $e');
    }
  }
}

class SavePhotoInput {
  final int trialId;
  final int plotPk;
  final int sessionId;
  final String tempPath;
  final String finalPath;
  final String? caption;
  final String? raterName;
  final int? performedByUserId;

  const SavePhotoInput({
    required this.trialId,
    required this.plotPk,
    required this.sessionId,
    required this.tempPath,
    required this.finalPath,
    this.caption,
    this.raterName,
    this.performedByUserId,
  });
}

class SavePhotoResult {
  final bool success;
  final Photo? photo;
  final String? errorMessage;

  const SavePhotoResult._({
    required this.success,
    this.photo,
    this.errorMessage,
  });

  factory SavePhotoResult.success(Photo photo) =>
      SavePhotoResult._(success: true, photo: photo);

  factory SavePhotoResult.failure(String message) =>
      SavePhotoResult._(success: false, errorMessage: message);
}
