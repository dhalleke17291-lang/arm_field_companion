import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/arm/arm_column_mapping_repository.dart';
import 'package:arm_field_companion/data/repositories/assessment_definition_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/domain/ratings/rating_integrity_guard.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_assessment_definition_resolver.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_csv_parser.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_persistence_repository.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_report_builder.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_snapshot_service.dart';
import 'package:arm_field_companion/features/arm_import/data/compatibility_profile_builder.dart';
import 'package:arm_field_companion/features/arm_import/usecases/arm_import_usecase.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/ratings/usecases/save_rating_usecase.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/data/repositories/application_product_repository.dart';
import 'package:arm_field_companion/data/repositories/application_repository.dart';
import 'package:arm_field_companion/data/repositories/seeding_repository.dart';
import 'package:arm_field_companion/data/repositories/notes_repository.dart';
import 'package:arm_field_companion/data/repositories/weather_snapshot_repository.dart';
import 'package:arm_field_companion/features/export/export_trial_usecase.dart';
import 'package:arm_field_companion/features/photos/photo_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';

/// Shared ARM import use case factory for stress tests (same wiring as arm_import_usecase_test).
ArmImportUseCase stressArmImportUseCase(AppDatabase db) {
  return ArmImportUseCase(
    db,
    TrialRepository(db),
    TreatmentRepository(db),
    PlotRepository(db),
    AssignmentRepository(db),
    ArmAssessmentDefinitionResolver(AssessmentDefinitionRepository(db)),
    TrialAssessmentRepository(db),
    SessionRepository(db),
    SaveRatingUseCase(
      RatingRepository(db),
      RatingIntegrityGuard(
        PlotRepository(db),
        SessionRepository(db),
        TreatmentRepository(db, AssignmentRepository(db)),
      ),
    ),
    ArmCsvParser(),
    ArmImportSnapshotService(),
    CompatibilityProfileBuilder(),
    ArmImportPersistenceRepository(db),
    ArmImportReportBuilder(),
    ArmColumnMappingRepository(db),
  );
}

/// [ExportTrialUseCase] with the same repository wiring as export_trial_usecase_test.
ExportTrialUseCase exportStressTrialUseCase(AppDatabase db) {
  return ExportTrialUseCase(
    db: db,
    trialRepository: TrialRepository(db),
    plotRepository: PlotRepository(db),
    treatmentRepository: TreatmentRepository(db),
    applicationRepository: ApplicationRepository(db),
    applicationProductRepository: ApplicationProductRepository(db),
    seedingRepository: SeedingRepository(db),
    sessionRepository: SessionRepository(db),
    ratingRepository: RatingRepository(db),
    assignmentRepository: AssignmentRepository(db),
    photoRepository: PhotoRepository(db),
    weatherSnapshotRepository: WeatherSnapshotRepository(db),
    notesRepository: NotesRepository(db),
    armImportPersistenceRepository: ArmImportPersistenceRepository(db),
  );
}
