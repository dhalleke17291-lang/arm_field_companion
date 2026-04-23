// Phase 2c — ARM Protocol tab's Treatments sub-section renders the rows
// written by Phase 2b.
//
// Mounts [ArmTreatmentsSection] in isolation with static provider
// overrides. We avoid mounting the full [ArmProtocolTab] because its
// Drift `watch()` streams schedule teardown timers that the FakeAsync
// zone in `testWidgets` cannot drain, producing a "Timer still pending"
// failure after the widget tree is disposed. The end-to-end import +
// DB-write path is already covered by
// `test/features/arm_import/import_arm_rating_shell_treatments_sheet_test.dart`.

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/features/arm_protocol/arm_protocol_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const int _trialId = 1;

Treatment _trt({
  required int id,
  required String code,
  required String name,
  required String typeCode,
}) {
  return Treatment(
    id: id,
    trialId: _trialId,
    code: code,
    name: name,
    treatmentType: typeCode,
    isDeleted: false,
  );
}

ArmTreatmentMetadataData _aam({
  required int treatmentId,
  required String typeCode,
  double? formConc,
  String? formConcUnit,
  String? formType,
  required int sortOrder,
}) {
  return ArmTreatmentMetadataData(
    id: treatmentId,
    treatmentId: treatmentId,
    armTypeCode: typeCode,
    formConc: formConc,
    formConcUnit: formConcUnit,
    formType: formType,
    armRowSortOrder: sortOrder,
    createdAt: DateTime.utc(2026, 4, 22),
  );
}

TreatmentComponent _component({
  required int treatmentId,
  required String productName,
  required double rate,
  required String rateUnit,
  required int sortOrder,
  required int componentId,
}) {
  return TreatmentComponent(
    id: componentId,
    treatmentId: treatmentId,
    trialId: _trialId,
    productName: productName,
    rate: rate,
    rateUnit: rateUnit,
    sortOrder: sortOrder,
    isTestProduct: true,
    isDeleted: false,
  );
}

/// Fixture modelled on AgQuest_RatingShell.xlsx's Treatments sheet (4
/// rows: CHK + FUNG APRON + HERB ATTACK + INS BLADE) after slice 2b
/// import.
({
  List<Treatment> treatments,
  Map<int, ArmTreatmentMetadataData> aamMap,
  Map<int, List<TreatmentComponent>> componentsMap,
}) _fixtureEquivalent() {
  final t1 = _trt(id: 1, code: '1', name: 'Treatment 1', typeCode: 'CHK');
  final t2 = _trt(id: 2, code: '2', name: 'APRON', typeCode: 'FUNG');
  final t3 = _trt(id: 3, code: '3', name: 'ATTACK', typeCode: 'HERB');
  final t4 = _trt(id: 4, code: '4', name: 'BLADE', typeCode: 'INS');

  return (
    treatments: [t1, t2, t3, t4],
    aamMap: {
      t1.id: _aam(treatmentId: t1.id, typeCode: 'CHK', sortOrder: 0),
      t2.id: _aam(
        treatmentId: t2.id,
        typeCode: 'FUNG',
        formConc: 25,
        formConcUnit: '%W/W',
        formType: 'W',
        sortOrder: 1,
      ),
      t3.id: _aam(
        treatmentId: t3.id,
        typeCode: 'HERB',
        formConc: 480,
        formConcUnit: '%W/V',
        formType: 'SC',
        sortOrder: 2,
      ),
      t4.id: _aam(
        treatmentId: t4.id,
        typeCode: 'INS',
        formConc: 100,
        formConcUnit: 'G/L',
        formType: 'EC',
        sortOrder: 3,
      ),
    },
    componentsMap: {
      t2.id: [
        _component(
          componentId: 1,
          treatmentId: t2.id,
          productName: 'APRON',
          rate: 5,
          rateUnit: '% w/v',
          sortOrder: 1,
        ),
      ],
      t3.id: [
        _component(
          componentId: 2,
          treatmentId: t3.id,
          productName: 'ATTACK',
          rate: 0.5,
          rateUnit: '% w/v',
          sortOrder: 2,
        ),
      ],
      t4.id: [
        _component(
          componentId: 3,
          treatmentId: t4.id,
          productName: 'BLADE',
          rate: 1,
          rateUnit: '% w/v',
          sortOrder: 3,
        ),
      ],
    },
  );
}

Widget _wrap({
  required List<Treatment> treatments,
  required Map<int, ArmTreatmentMetadataData> aamMap,
  required Map<int, List<TreatmentComponent>> componentsMap,
}) {
  return ProviderScope(
    overrides: [
      treatmentsForTrialProvider(_trialId)
          .overrideWith((ref) => Stream.value(treatments)),
      armTreatmentMetadataMapForTrialProvider(_trialId)
          .overrideWith((ref) async => aamMap),
      treatmentComponentsByTreatmentForTrialProvider(_trialId)
          .overrideWith((ref) async => componentsMap),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ArmTreatmentsSection(trialId: _trialId),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders one row per ARM-tagged treatment', (tester) async {
    final f = _fixtureEquivalent();
    await tester.pumpWidget(_wrap(
      treatments: f.treatments,
      aamMap: f.aamMap,
      componentsMap: f.componentsMap,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Treatments'), findsOneWidget);
    expect(find.text('APRON'), findsOneWidget);
    expect(find.text('ATTACK'), findsOneWidget);
    expect(find.text('BLADE'), findsOneWidget);
    expect(find.text('Treatment 1'), findsOneWidget,
        reason: 'CHK row keeps the default name (blank in sheet)');
  });

  testWidgets('CHK chip renders and non-CHK rows show formulation subtitle',
      (tester) async {
    final f = _fixtureEquivalent();
    await tester.pumpWidget(_wrap(
      treatments: f.treatments,
      aamMap: f.aamMap,
      componentsMap: f.componentsMap,
    ));
    await tester.pumpAndSettle();

    expect(find.text('CHK'), findsOneWidget);
    expect(find.text('FUNG'), findsOneWidget);
    expect(find.text('HERB'), findsOneWidget);
    expect(find.text('INS'), findsOneWidget);

    expect(find.text('5 % w/v • 25 %W/W • W'), findsOneWidget);
    expect(find.text('0.5 % w/v • 480 %W/V • SC'), findsOneWidget);
    expect(find.text('1 % w/v • 100 G/L • EC'), findsOneWidget);
  });

  testWidgets('rows appear in Treatments-sheet order (armRowSortOrder)',
      (tester) async {
    final f = _fixtureEquivalent();
    // Pass treatments in reverse list order to prove ordering is
    // driven by armRowSortOrder, not list-input order.
    await tester.pumpWidget(_wrap(
      treatments: f.treatments.reversed.toList(),
      aamMap: f.aamMap,
      componentsMap: f.componentsMap,
    ));
    await tester.pumpAndSettle();

    final yChk = tester.getTopLeft(find.text('Treatment 1')).dy;
    final yApron = tester.getTopLeft(find.text('APRON')).dy;
    final yAttack = tester.getTopLeft(find.text('ATTACK')).dy;
    final yBlade = tester.getTopLeft(find.text('BLADE')).dy;

    expect(yChk < yApron, isTrue,
        reason: 'CHK (armRowSortOrder 0) must render above APRON (1)');
    expect(yApron < yAttack, isTrue,
        reason: 'APRON (1) must render above ATTACK (2)');
    expect(yAttack < yBlade, isTrue,
        reason: 'ATTACK (2) must render above BLADE (3)');
  });

  testWidgets('ARM-linked trial with no AAM rows shows the empty hint',
      (tester) async {
    // Simulates a pre-Phase-2b ARM trial or an ARM shell without a
    // Treatments sheet: treatments exist but none have an AAM row.
    final f = _fixtureEquivalent();
    await tester.pumpWidget(_wrap(
      treatments: f.treatments,
      aamMap: const {},
      componentsMap: const {},
    ));
    await tester.pumpAndSettle();

    expect(
      find.text('No ARM Treatments sheet data for this trial.'),
      findsOneWidget,
    );
  });
}
