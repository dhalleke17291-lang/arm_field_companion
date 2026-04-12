import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/protocol_import/protocol_import_usecase.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds protocol CSV rows as List<Map<String, dynamic>>.
List<Map<String, dynamic>> buildProtocolRows({
  String? trialName,
  String? crop,
  List<({String code, String name, String? description})> treatments = const [],
  List<({String plotId, int? rep, String? treatmentCode})> plots = const [],
}) {
  final rows = <Map<String, dynamic>>[];
  if (trialName != null) {
    rows.add({
      'section': 'TRIAL',
      'trial_name': trialName,
      'crop': crop,
    });
  }
  for (final t in treatments) {
    rows.add({
      'section': 'TREATMENT',
      'code': t.code,
      'name': t.name,
      'description': t.description,
    });
  }
  for (final p in plots) {
    rows.add({
      'section': 'PLOT',
      'plot_id': p.plotId,
      'rep': p.rep?.toString(),
      'treatment_code': p.treatmentCode,
    });
  }
  return rows;
}

void main() {
  group('analyzeProtocolFile — pure parsing (no DB)', () {
    late ProtocolImportUseCase useCase;

    setUp(() {
      // analyzeProtocolFile is pure — repositories are unused.
      // We still need valid constructor args, so use a throwaway DB.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      useCase = ProtocolImportUseCase(
        db,
        TrialRepository(db),
        TreatmentRepository(db),
        PlotRepository(db),
        AssignmentRepository(db),
      );
    });

    test('empty rows returns mustFix', () {
      final result = useCase.analyzeProtocolFile([]);
      expect(result.trialSection.mustFix, isNotEmpty);
      expect(result.canProceed, false);
    });

    test('missing section column returns mustFix', () {
      final result = useCase.analyzeProtocolFile([
        {'name': 'test', 'value': '1'},
      ]);
      expect(result.trialSection.mustFix, isNotEmpty);
      expect(result.trialSection.mustFix.first, contains('section'));
    });

    test('detects "type" as alternative section column', () {
      final result = useCase.analyzeProtocolFile([
        {'type': 'TRIAL', 'trial_name': 'My Trial'},
      ]);
      expect(result.trialSection.matchedCount, 1);
      expect(result.trialSection.mustFix, isEmpty);
    });

    test('parses valid trial section', () {
      final result = useCase.analyzeProtocolFile(buildProtocolRows(
        trialName: 'Spring Wheat 2026',
        crop: 'Wheat',
      ));
      expect(result.trialSection.matchedCount, 1);
      expect(result.trialSection.canProceed, true);
      expect(result.normalizedTrial!['trial_name'], 'Spring Wheat 2026');
      expect(result.normalizedTrial!['crop'], 'Wheat');
    });

    test('rejects missing trial_name', () {
      final result = useCase.analyzeProtocolFile([
        {'section': 'TRIAL', 'crop': 'Corn'},
      ]);
      expect(result.trialSection.mustFix.first, contains('trial_name'));
    });

    test('rejects multiple TRIAL rows', () {
      final result = useCase.analyzeProtocolFile([
        {'section': 'TRIAL', 'trial_name': 'A'},
        {'section': 'TRIAL', 'trial_name': 'B'},
      ]);
      expect(result.trialSection.mustFix.first, contains('exactly one'));
    });

    test('ignores TRIAL section when existingTrialId provided', () {
      final result = useCase.analyzeProtocolFile([
        {'section': 'TRIAL', 'trial_name': 'Ignored'},
        {'section': 'TREATMENT', 'code': 'T1', 'name': 'Treatment 1'},
      ], existingTrialId: 42);
      expect(result.trialSection.autoHandled, isNotEmpty);
      expect(result.normalizedTrial, isNull);
    });

    test('parses valid treatment section', () {
      final result = useCase.analyzeProtocolFile(buildProtocolRows(
        trialName: 'T',
        treatments: [
          (code: 'UTC', name: 'Untreated Check', description: null),
          (code: 'T1', name: 'Fungicide A', description: 'Active ingredient X'),
        ],
      ));
      expect(result.treatmentSection.matchedCount, 2);
      expect(result.normalizedTreatments.length, 2);
      expect(result.normalizedTreatments[0]['code'], 'UTC');
      expect(result.normalizedTreatments[1]['description'],
          'Active ingredient X');
    });

    test('rejects treatment without code', () {
      final result = useCase.analyzeProtocolFile([
        {'section': 'TRIAL', 'trial_name': 'T'},
        {'section': 'TREATMENT', 'name': 'No Code'},
      ]);
      expect(result.treatmentSection.mustFix.first, contains('code'));
    });

    test('rejects treatment without name', () {
      final result = useCase.analyzeProtocolFile([
        {'section': 'TRIAL', 'trial_name': 'T'},
        {'section': 'TREATMENT', 'code': 'X'},
      ]);
      expect(result.treatmentSection.mustFix.first, contains('name'));
    });

    test('rejects duplicate treatment codes', () {
      final result = useCase.analyzeProtocolFile(buildProtocolRows(
        trialName: 'T',
        treatments: [
          (code: 'A', name: 'First', description: null),
          (code: 'A', name: 'Duplicate', description: null),
        ],
      ));
      expect(result.treatmentSection.mustFix.first, contains('duplicate'));
    });

    test('parses valid plot section', () {
      final result = useCase.analyzeProtocolFile(buildProtocolRows(
        trialName: 'T',
        plots: [
          (plotId: '101', rep: 1, treatmentCode: null),
          (plotId: '102', rep: 1, treatmentCode: null),
          (plotId: '201', rep: 2, treatmentCode: null),
        ],
      ));
      expect(result.plotSection.matchedCount, 3);
      expect(result.normalizedPlots.length, 3);
      expect(result.normalizedPlots[0]['plot_id'], '101');
      expect(result.normalizedPlots[0]['rep'], 1);
    });

    test('rejects plot without plot_id', () {
      final result = useCase.analyzeProtocolFile([
        {'section': 'TRIAL', 'trial_name': 'T'},
        {'section': 'PLOT', 'rep': '1'},
      ]);
      expect(result.plotSection.mustFix.first, contains('plot_id'));
    });

    test('rejects duplicate plot_id', () {
      final result = useCase.analyzeProtocolFile(buildProtocolRows(
        trialName: 'T',
        plots: [
          (plotId: '101', rep: 1, treatmentCode: null),
          (plotId: '101', rep: 2, treatmentCode: null),
        ],
      ));
      expect(result.plotSection.mustFix.first, contains('duplicate'));
    });

    test('validates plot treatment_code references', () {
      final result = useCase.analyzeProtocolFile(buildProtocolRows(
        trialName: 'T',
        treatments: [
          (code: 'T1', name: 'Treatment 1', description: null),
        ],
        plots: [
          (plotId: '101', rep: 1, treatmentCode: 'T1'),
          (plotId: '102', rep: 1, treatmentCode: 'MISSING'),
        ],
      ));
      expect(result.assignmentSection.matchedCount, 1);
      expect(result.assignmentSection.mustFix.first, contains('MISSING'));
    });

    test('auto-assigns plot_sort_index when missing', () {
      final result = useCase.analyzeProtocolFile(buildProtocolRows(
        trialName: 'T',
        plots: [
          (plotId: '101', rep: null, treatmentCode: null),
          (plotId: '102', rep: null, treatmentCode: null),
        ],
      ));
      expect(result.normalizedPlots[0]['plot_sort_index'], 1);
      expect(result.normalizedPlots[1]['plot_sort_index'], 2);
    });

    test('canProceed true for valid complete protocol', () {
      final result = useCase.analyzeProtocolFile(buildProtocolRows(
        trialName: 'Complete Trial',
        crop: 'Corn',
        treatments: [
          (code: 'UTC', name: 'Untreated', description: null),
          (code: 'T1', name: 'Fungicide', description: null),
        ],
        plots: [
          (plotId: '101', rep: 1, treatmentCode: 'UTC'),
          (plotId: '102', rep: 1, treatmentCode: 'T1'),
          (plotId: '201', rep: 2, treatmentCode: 'UTC'),
          (plotId: '202', rep: 2, treatmentCode: 'T1'),
        ],
      ));
      expect(result.canProceed, true);
      expect(result.trialSection.matchedCount, 1);
      expect(result.treatmentSection.matchedCount, 2);
      expect(result.plotSection.matchedCount, 4);
      expect(result.assignmentSection.matchedCount, 4);
      expect(result.assignmentSection.mustFix, isEmpty);
    });
  });

  group('execute — integration (real DB)', () {
    late AppDatabase db;
    late ProtocolImportUseCase useCase;
    late TrialRepository trialRepo;
    late TreatmentRepository trtRepo;
    late PlotRepository plotRepo;
    late AssignmentRepository assignRepo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      trialRepo = TrialRepository(db);
      trtRepo = TreatmentRepository(db, AssignmentRepository(db));
      plotRepo = PlotRepository(db);
      assignRepo = AssignmentRepository(db);
      useCase = ProtocolImportUseCase(
          db, trialRepo, trtRepo, plotRepo, assignRepo);
    });

    tearDown(() async {
      await db.close();
    });

    test('creates trial with treatments, plots, and assignments', () async {
      final review = useCase.analyzeProtocolFile(buildProtocolRows(
        trialName: 'Integration Test',
        crop: 'Barley',
        treatments: [
          (code: 'UTC', name: 'Untreated', description: null),
          (code: 'T1', name: 'Herbicide X', description: 'Test product'),
        ],
        plots: [
          (plotId: '101', rep: 1, treatmentCode: 'UTC'),
          (plotId: '102', rep: 1, treatmentCode: 'T1'),
          (plotId: '201', rep: 2, treatmentCode: 'UTC'),
          (plotId: '202', rep: 2, treatmentCode: 'T1'),
        ],
      ));
      expect(review.canProceed, true);

      final result = await useCase.execute(
        review: review,
        existingTrialId: null,
      );
      expect(result.success, true);
      expect(result.trialId, isNotNull);
      expect(result.treatmentsImported, 2);
      expect(result.plotsImported, 4);

      // Verify trial created
      final trial = await trialRepo.getTrialById(result.trialId!);
      expect(trial, isNotNull);
      expect(trial!.name, 'Integration Test');
      expect(trial.crop, 'Barley');

      // Verify treatments
      final treatments = await trtRepo.getTreatmentsForTrial(result.trialId!);
      expect(treatments.length, 2);

      // Verify plots
      final plots = await plotRepo.getPlotsForTrial(result.trialId!);
      expect(plots.length, 4);

      // Verify assignments
      final assignments = await assignRepo.getForTrial(result.trialId!);
      expect(assignments.length, 4);
    });

    test('adds to existing trial (no new trial created)', () async {
      final existingId = await trialRepo.createTrial(name: 'Existing');

      final review = useCase.analyzeProtocolFile(buildProtocolRows(
        trialName: 'Ignored',
        treatments: [
          (code: 'X', name: 'New Treatment', description: null),
        ],
        plots: [
          (plotId: '301', rep: 1, treatmentCode: 'X'),
        ],
      ), existingTrialId: existingId);

      final result = await useCase.execute(
        review: review,
        existingTrialId: existingId,
      );
      expect(result.success, true);
      expect(result.trialId, existingId);
      expect(result.treatmentsImported, 1);
      expect(result.plotsImported, 1);
    });

    test('rejects when review has mustFix errors', () async {
      final review = useCase.analyzeProtocolFile([]);
      final result = await useCase.execute(
        review: review,
        existingTrialId: null,
      );
      expect(result.success, false);
      expect(result.errorMessage, contains('errors'));
    });

    test('rejects when protocol is locked', () async {
      final review = useCase.analyzeProtocolFile(buildProtocolRows(
        trialName: 'Blocked',
        treatments: [
          (code: 'A', name: 'T', description: null),
        ],
      ));

      final result = await useCase.execute(
        review: review,
        existingTrialId: null,
        isProtocolLocked: true,
      );
      expect(result.success, false);
      expect(result.errorMessage, contains('locked'));
    });

    test('rejects import to ARM-linked trial', () async {
      final trialId = await trialRepo.createTrial(name: 'ARM Trial');
      await (db.update(db.trials)..where((t) => t.id.equals(trialId)))
          .write(const TrialsCompanion(isArmLinked: Value(true)));

      final review = useCase.analyzeProtocolFile(buildProtocolRows(
        treatments: [
          (code: 'A', name: 'T', description: null),
        ],
      ), existingTrialId: trialId);

      final result = await useCase.execute(
        review: review,
        existingTrialId: trialId,
      );
      expect(result.success, false);
    });

    test('handles treatments only (no plots)', () async {
      final review = useCase.analyzeProtocolFile(buildProtocolRows(
        trialName: 'Treatments Only',
        treatments: [
          (code: 'A', name: 'Alpha', description: null),
          (code: 'B', name: 'Beta', description: null),
        ],
      ));

      final result = await useCase.execute(
        review: review,
        existingTrialId: null,
      );
      expect(result.success, true);
      expect(result.treatmentsImported, 2);
      expect(result.plotsImported, 0);
    });
  });
}
