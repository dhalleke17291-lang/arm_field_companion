import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/models/compatibility_profile_payload.dart';
import '../domain/models/import_snapshot_payload.dart';

/// Inserts ARM import metadata rows only ([ImportSnapshots], [CompatibilityProfiles], trial flags).
class ArmImportPersistenceRepository {
  ArmImportPersistenceRepository(this._db);

  final AppDatabase _db;

  Future<bool> existsByChecksum(String checksum) async {
    final query = _db.select(_db.importSnapshots)
      ..where((s) => s.rawFileChecksum.equals(checksum))
      ..limit(1);

    final result = await query.get();
    return result.isNotEmpty;
  }

  Future<List<int>> getTrialIdsByChecksum(String checksum) async {
    final query = _db.select(_db.importSnapshots)
      ..where((s) => s.rawFileChecksum.equals(checksum));

    final rows = await query.get();
    return rows.map((r) => r.trialId).toSet().toList();
  }

  /// Latest [CompatibilityProfiles] row for [trialId] by descending [CompatibilityProfiles.id].
  Future<CompatibilityProfile?> getLatestCompatibilityProfileForTrial(
    int trialId,
  ) async {
    final query = _db.select(_db.compatibilityProfiles)
      ..where((p) => p.trialId.equals(trialId))
      ..orderBy([(p) => OrderingTerm.desc(p.id)])
      ..limit(1);

    return query.getSingleOrNull();
  }

  Future<String?> getLatestExportConfidenceForTrial(int trialId) async {
    final row = await getLatestCompatibilityProfileForTrial(trialId);
    return row?.exportConfidence;
  }

  Future<String?> getLatestExportBlockReasonForTrial(int trialId) async {
    final row = await getLatestCompatibilityProfileForTrial(trialId);
    return row?.exportBlockReason;
  }

  Future<int> insertImportSnapshot(
    ImportSnapshotPayload payload, {
    required int trialId,
  }) async {
    final now = DateTime.now().toUtc();
    return _db.into(_db.importSnapshots).insert(
          ImportSnapshotsCompanion.insert(
            trialId: trialId,
            sourceFile: payload.sourceFile,
            sourceRoute: payload.sourceRoute,
            armVersion: Value(payload.armVersion),
            rawHeaders: jsonEncode(payload.rawHeaders),
            columnOrder: jsonEncode(payload.columnOrder),
            rowTypePatterns: jsonEncode(payload.rowTypePatterns),
            plotCount: payload.plotCount,
            treatmentCount: payload.treatmentCount,
            assessmentCount: payload.assessmentCount,
            identityColumns: jsonEncode(payload.identityColumns),
            assessmentTokens: jsonEncode(payload.assessmentTokens),
            treatmentTokens: jsonEncode(payload.treatmentTokens),
            plotTokens: jsonEncode(payload.plotTokens),
            unknownPatterns: jsonEncode(payload.unknownPatterns),
            hasSubsamples: Value(payload.hasSubsamples),
            hasMultiApplication: Value(payload.hasMultiApplication),
            hasSparseData: Value(payload.hasSparseData),
            hasRepeatedCodes: Value(payload.hasRepeatedCodes),
            rawFileChecksum: payload.rawFileChecksum,
            capturedAt: now,
          ),
        );
  }

  Future<int> insertCompatibilityProfile(
    CompatibilityProfilePayload payload, {
    required int trialId,
    required int snapshotId,
  }) async {
    final now = DateTime.now().toUtc();
    return _db.into(_db.compatibilityProfiles).insert(
          CompatibilityProfilesCompanion.insert(
            trialId: trialId,
            snapshotId: snapshotId,
            exportRoute: payload.exportRoute,
            columnMap: jsonEncode(payload.columnMap),
            plotMap: jsonEncode(payload.plotMap),
            treatmentMap: jsonEncode(payload.treatmentMap),
            dataStartRow: payload.dataStartRow,
            headerEndRow: payload.headerEndRow,
            identityRowMarkers: jsonEncode(payload.identityRowMarkers),
            columnOrderOnExport: jsonEncode(payload.columnOrderOnExport),
            identityFieldOrder: jsonEncode(payload.identityFieldOrder),
            knownUnsupported: jsonEncode(payload.knownUnsupported),
            exportConfidence: payload.exportConfidence.name,
            exportBlockReason: Value(payload.exportBlockReason),
            createdAt: now,
          ),
        );
  }

  Future<void> markTrialAsArmLinked({
    required int trialId,
    required String sourceFile,
    required String? armVersion,
  }) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.trials)..where((t) => t.id.equals(trialId))).write(
          TrialsCompanion(
            isArmLinked: const Value(true),
            armImportedAt: Value(now),
            armSourceFile: Value(sourceFile),
            armVersion: Value(armVersion),
            updatedAt: Value(now),
          ),
        );
  }
}
