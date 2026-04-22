import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:drift/drift.dart';

/// Upserts [arm_trial_metadata] for integration tests (Phase 0b — trial ARM fields live here).
Future<void> upsertArmTrialMetadataForTest(
  AppDatabase db, {
  required int trialId,
  bool isArmLinked = true,
  DateTime? armImportedAt,
  String? armSourceFile,
  String? armVersion,
  int? armImportSessionId,
  String? armLinkedShellPath,
  DateTime? armLinkedShellAt,
  String? shellInternalPath,
}) async {
  await db.into(db.armTrialMetadata).insertOnConflictUpdate(
        ArmTrialMetadataCompanion(
          trialId: Value(trialId),
          isArmLinked: Value(isArmLinked),
          armImportedAt: armImportedAt != null
              ? Value(armImportedAt)
              : const Value.absent(),
          armSourceFile: armSourceFile != null
              ? Value(armSourceFile)
              : const Value.absent(),
          armVersion:
              armVersion != null ? Value(armVersion) : const Value.absent(),
          armImportSessionId: armImportSessionId != null
              ? Value(armImportSessionId)
              : const Value.absent(),
          armLinkedShellPath: armLinkedShellPath != null
              ? Value(armLinkedShellPath)
              : const Value.absent(),
          armLinkedShellAt: armLinkedShellAt != null
              ? Value(armLinkedShellAt)
              : const Value.absent(),
          shellInternalPath: shellInternalPath != null
              ? Value(shellInternalPath)
              : const Value.absent(),
        ),
      );
}
