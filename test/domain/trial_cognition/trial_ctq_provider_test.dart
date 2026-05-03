import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/ctq_factor_definition_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_purpose_repository.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_ctq_dto.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Mirrors _computeTrialCtqDto from providers.dart.
TrialCtqDto computeCtqDto(int trialId, List<CtqFactorDefinition> factors) {
  if (factors.isEmpty) {
    return TrialCtqDto(
      trialId: trialId,
      ctqItems: const [],
      blockerCount: 0,
      warningCount: 0,
      reviewCount: 0,
      satisfiedCount: 0,
      overallStatus: 'unknown',
    );
  }
  final items = factors
      .map(
        (f) => TrialCtqItemDto(
          factorKey: f.factorKey,
          label: f.factorLabel,
          importance: f.importance,
          status: 'unknown',
          evidenceSummary: 'Not evaluated.',
          reason: 'Evidence evaluation not yet run.',
          source: f.source,
        ),
      )
      .toList();
  return TrialCtqDto(
    trialId: trialId,
    ctqItems: items,
    blockerCount: 0,
    warningCount: 0,
    reviewCount: 0,
    satisfiedCount: 0,
    overallStatus: 'unknown',
  );
}

void main() {
  late AppDatabase db;
  late CtqFactorDefinitionRepository ctqRepo;
  late TrialRepository trialRepo;
  late TrialPurposeRepository purposeRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ctqRepo = CtqFactorDefinitionRepository(db);
    trialRepo = TrialRepository(db);
    purposeRepo = TrialPurposeRepository(db);
  });

  tearDown(() async => db.close());

  Future<({int trialId, int purposeId})> makeTrialAndPurpose() async {
    final trialId =
        await trialRepo.createTrial(name: 'T${DateTime.now().microsecondsSinceEpoch}');
    final purposeId =
        await purposeRepo.createInitialTrialPurpose(trialId: trialId);
    return (trialId: trialId, purposeId: purposeId);
  }

  test('returns unknown overall status when no factors defined', () async {
    final ctx = await makeTrialAndPurpose();
    final factors = await ctqRepo.watchCtqFactorsForTrial(ctx.trialId).first;
    final dto = computeCtqDto(ctx.trialId, factors);
    expect(dto.overallStatus, 'unknown');
    expect(dto.ctqItems, isEmpty);
    expect(dto.blockerCount, 0);
  });

  test('returns unknown item statuses for all seeded factors (foundation layer)', () async {
    final ctx = await makeTrialAndPurpose();
    await ctqRepo.seedDefaultCtqFactorsForPurpose(
      trialId: ctx.trialId,
      trialPurposeId: ctx.purposeId,
    );
    final factors = await ctqRepo.watchCtqFactorsForTrial(ctx.trialId).first;
    final dto = computeCtqDto(ctx.trialId, factors);
    expect(dto.ctqItems.length, kCtqDefaultFactorKeys.length);
    expect(dto.ctqItems.every((i) => i.status == 'unknown'), true);
    expect(dto.overallStatus, 'unknown');
    expect(dto.satisfiedCount, 0);
  });

  test('missing/satisfied/review_needed are representable via TrialCtqItemDto', () {
    const item = TrialCtqItemDto(
      factorKey: 'plot_completeness',
      label: 'Plot Completeness',
      importance: 'critical',
      status: 'missing',
      evidenceSummary: '0 of 16 plots rated.',
      reason: 'No ratings recorded.',
      source: 'system',
    );
    expect(item.isBlocked, false);
    expect(item.isSatisfied, false);
    expect(item.needsReview, false);

    const satisfied = TrialCtqItemDto(
      factorKey: 'plot_completeness',
      label: 'Plot Completeness',
      importance: 'critical',
      status: 'satisfied',
      evidenceSummary: '16/16 plots rated.',
      reason: 'Full coverage.',
      source: 'system',
    );
    expect(satisfied.isSatisfied, true);
  });
}
