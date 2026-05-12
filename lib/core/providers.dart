// ARCHITECTURE RULE: Use case return types
// New use cases must return domain result types (e.g. SaveRatingResult),
// never raw Drift row types (e.g. RatingRecord, Session, Trial).
// Existing use cases that return Drift rows are documented technical debt:
// - SaveRatingUseCase (RatingRecord)
// - CreateSessionUseCase (Session)
// - CreateTrialUseCase (Trial)
// - StartOrContinueRatingUseCase (Trial, Session, List<Plot>, List<Assessment>)
// - ApplyCorrectionUseCase (RatingCorrection)
// - SavePhotoUseCase (Photo)
// These will be migrated to domain types when their consumers are next modified.

export 'providers/infrastructure_providers.dart';
export 'providers/cognition_providers.dart';
export 'providers/trial_providers.dart';
export 'providers/session_providers.dart';
export 'providers/photo_providers.dart';
export 'providers/arm_providers.dart';
export 'providers/export_providers.dart';
export 'providers/auth_providers.dart';
export 'providers/guide_providers.dart';
