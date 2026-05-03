import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/protocol_document_reference_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProtocolDocumentReferenceRepository repo;
  late TrialRepository trialRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ProtocolDocumentReferenceRepository(db);
    trialRepo = TrialRepository(db);
  });

  tearDown(() async => db.close());

  Future<int> makeTrial() =>
      trialRepo.createTrial(name: 'T${DateTime.now().microsecondsSinceEpoch}');

  test('add and retrieve protocol document reference', () async {
    final trialId = await makeTrial();
    final id = await repo.addProtocolDocumentReference(
      trialId: trialId,
      documentLabel: 'Study Plan v2',
      documentType: 'protocol',
      externalReference: 'ARM-SP-2026-001',
      source: 'user',
    );
    expect(id, greaterThan(0));
    final refs =
        await repo.watchProtocolDocumentReferencesForTrial(trialId).first;
    expect(refs.length, 1);
    expect(refs.first.documentLabel, 'Study Plan v2');
    expect(refs.first.externalReference, 'ARM-SP-2026-001');
  });

  test('multiple references are all returned for the trial', () async {
    final trialId = await makeTrial();
    await repo.addProtocolDocumentReference(
      trialId: trialId,
      documentLabel: 'Protocol v1',
      documentType: 'protocol',
      source: 'user',
    );
    await repo.addProtocolDocumentReference(
      trialId: trialId,
      documentLabel: 'Amendment 1',
      documentType: 'amendment',
      source: 'user',
    );
    final refs =
        await repo.watchProtocolDocumentReferencesForTrial(trialId).first;
    expect(refs.length, 2);
  });
}
