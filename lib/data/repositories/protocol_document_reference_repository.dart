import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

class ProtocolDocumentReferenceRepository {
  ProtocolDocumentReferenceRepository(this._db);

  final AppDatabase _db;

  Future<int> addProtocolDocumentReference({
    required int trialId,
    required String documentLabel,
    required String documentType,
    String? storageUri,
    String? externalReference,
    required String source,
    DateTime? uploadedAt,
    String? uploadedBy,
    String? notes,
  }) {
    return _db.into(_db.protocolDocumentReferences).insert(
          ProtocolDocumentReferencesCompanion.insert(
            trialId: trialId,
            documentLabel: documentLabel,
            documentType: documentType,
            storageUri: Value(storageUri),
            externalReference: Value(externalReference),
            source: source,
            uploadedAt: Value(uploadedAt),
            uploadedBy: Value(uploadedBy),
            notes: Value(notes),
          ),
        );
  }

  Stream<List<ProtocolDocumentReference>>
      watchProtocolDocumentReferencesForTrial(int trialId) {
    return (_db.select(_db.protocolDocumentReferences)
          ..where((r) => r.trialId.equals(trialId))
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .watch();
  }
}
