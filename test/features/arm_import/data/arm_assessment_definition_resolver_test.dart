import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/assessment_definition_repository.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_assessment_definition_resolver.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/assessment_token.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late AssessmentDefinitionRepository definitions;
  late ArmAssessmentDefinitionResolver resolver;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    definitions = AssessmentDefinitionRepository(db);
    resolver = ArmAssessmentDefinitionResolver(definitions);
  });

  tearDown(() async {
    await db.close();
  });

  test('unique assessmentKeys resolve once each', () async {
    const t1 = AssessmentToken(
      rawHeader: 'H1',
      armCode: 'ZZ_UNIQUE_A',
      timingCode: 'T1',
      unit: '%',
      columnIndex: 3,
    );
    const t2 = AssessmentToken(
      rawHeader: 'H2',
      armCode: 'ZZ_UNIQUE_B',
      timingCode: 'T1',
      unit: '%',
      columnIndex: 4,
    );

    final r = await resolver.resolveAll(
      trialId: 1,
      assessments: [t1, t2],
    );

    expect(r.assessmentKeyToDefinitionId.length, 2);
    expect(
      r.assessmentKeyToDefinitionId[t1.assessmentKey],
      isNot(r.assessmentKeyToDefinitionId[t2.assessmentKey]),
    );

    final rows = (await db.select(db.assessmentDefinitions).get())
        .where((d) => d.code.startsWith('ARM_ZZ_UNIQUE'))
        .toList();
    expect(rows.length, 2);
    final pct = rows.firstWhere((d) => d.unit == '%');
    expect(pct.scaleMin, 0);
    expect(pct.scaleMax, 100);
  });

  test('duplicate assessmentKeys do not create duplicate definitions', () async {
    const t1 = AssessmentToken(
      rawHeader: 'H',
      armCode: 'ZZ_DUP_ONE',
      timingCode: 'T1',
      unit: '%',
      columnIndex: 3,
    );
    const t2 = AssessmentToken(
      rawHeader: 'H2',
      armCode: 'ZZ_DUP_ONE',
      timingCode: 'T1',
      unit: '%',
      columnIndex: 4,
    );

    final r = await resolver.resolveAll(
      trialId: 1,
      assessments: [t1, t2],
    );

    expect(r.assessmentKeyToDefinitionId.length, 1);

    final rows = await (db.select(db.assessmentDefinitions)
          ..where((d) => d.code.equals(
                ArmAssessmentDefinitionResolver.definitionCodeForAssessmentKey(
                  t1.assessmentKey,
                ),
              )))
        .get();
    expect(rows.length, 1);
  });

  test('empty armCode produces warning and unknown pattern', () async {
    const t = AssessmentToken(
      rawHeader: 'bad',
      armCode: '   ',
      timingCode: 'T1',
      unit: '%',
      columnIndex: 3,
    );

    final r = await resolver.resolveAll(
      trialId: 1,
      assessments: [t],
    );

    expect(r.assessmentKeyToDefinitionId, isEmpty);
    expect(r.warnings, isNotEmpty);
    expect(r.unknownPatterns, isNotEmpty);
    expect(r.unknownPatterns.first.type, 'assessment_definition');
  });
}
