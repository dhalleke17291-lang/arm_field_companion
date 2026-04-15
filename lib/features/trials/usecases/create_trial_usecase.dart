import '../trial_repository.dart';
import '../../../core/database/app_database.dart';

class CreateTrialUseCase {
  final TrialRepository _trialRepository;

  CreateTrialUseCase(this._trialRepository);

  Future<CreateTrialResult> execute(CreateTrialInput input) async {
    try {
      // Validate trial name
      if (input.name.trim().isEmpty) {
        return CreateTrialResult.failure('Trial name must not be empty');
      }

      // Check for duplicate name (case-insensitive)
      if (await _trialRepository.trialNameExists(input.name.trim())) {
        return CreateTrialResult.failure(
          'A trial named \'${input.name.trim()}\' already exists. '
          'Choose a different name.',
        );
      }

      final trialId = await _trialRepository.createTrial(
        name: input.name.trim(),
        crop: input.crop,
        location: input.location,
        season: input.season,
        workspaceType: input.workspaceType,
      );

      final trial = await _trialRepository.getTrialById(trialId);
      if (trial == null) {
        return CreateTrialResult.failure('Failed to retrieve created trial');
      }

      return CreateTrialResult.success(trial);
    } on DuplicateTrialException catch (e) {
      return CreateTrialResult.failure(e.toString());
    } catch (e) {
      return CreateTrialResult.failure('Failed to create trial: $e');
    }
  }
}

class CreateTrialInput {
  final String name;
  final String? crop;
  final String? location;
  final String? season;
  final String workspaceType;

  const CreateTrialInput({
    required this.name,
    this.crop,
    this.location,
    this.season,
    this.workspaceType = 'efficacy',
  });
}

class CreateTrialResult {
  final bool success;
  final Trial? trial;
  final String? errorMessage;

  const CreateTrialResult._({
    required this.success,
    this.trial,
    this.errorMessage,
  });

  factory CreateTrialResult.success(Trial trial) =>
      CreateTrialResult._(success: true, trial: trial);

  factory CreateTrialResult.failure(String message) =>
      CreateTrialResult._(success: false, errorMessage: message);
}
