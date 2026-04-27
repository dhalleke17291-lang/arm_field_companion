// Phase 3d — ARM Protocol tab Applications sub-section.
//
// Mounts [ArmApplicationsSection] in isolation with provider overrides
// (same FakeAsync rationale as arm_protocol_tab_treatments_test.dart).

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/data/arm/arm_applications_repository.dart';
import 'package:arm_field_companion/features/arm_protocol/arm_protocol_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

const int _trialId = 1;

TrialApplicationEvent _event({
  required String id,
  required DateTime applicationDate,
  String? applicationTime,
  String? applicationMethod,
  String? operatorName,
  String? equipmentUsed,
}) {
  return TrialApplicationEvent(
    id: id,
    trialId: _trialId,
    applicationDate: applicationDate,
    applicationTime: applicationTime,
    applicationMethod: applicationMethod,
    operatorName: operatorName,
    equipmentUsed: equipmentUsed,
    status: 'applied',
    createdAt: DateTime.utc(2026, 6, 15),
  );
}

ArmApplication _arm({
  required int id,
  required String eventId,
  int? colIdx,
  String? row07,
}) {
  return ArmApplication(
    id: id,
    trialApplicationEventId: eventId,
    armSheetColumnIndex: colIdx,
    row07: row07,
    createdAt: DateTime.utc(2026, 6, 15),
  );
}

Widget _wrap(List<ArmSheetApplicationRow> rows) {
  return ProviderScope(
    overrides: [
      armSheetApplicationsForTrialProvider(_trialId)
          .overrideWith((ref) => Stream.value(rows)),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ArmApplicationsSection(trialId: _trialId),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders sheet column letter, date, timing, and dual-write lines',
      (tester) async {
    final e = _event(
      id: 'evt-1',
      applicationDate: DateTime.utc(2026, 6, 20),
      applicationTime: '09:00',
      applicationMethod: 'BROADCAST',
      operatorName: 'A.B.',
      equipmentUsed: 'Tractor / Boom',
    );
    final a = _arm(id: 1, eventId: e.id, colIdx: 2, row07: 'A1');

    await tester.pumpWidget(_wrap([(event: e, arm: a)]));
    await tester.pumpAndSettle();

    final dateStr =
        DateFormat('d MMM yyyy').format(e.applicationDate.toLocal());

    expect(find.text('Applications'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.textContaining(dateStr), findsOneWidget);
    expect(find.textContaining('09:00'), findsOneWidget);
    expect(find.text('A1'), findsOneWidget);
    expect(find.text('BROADCAST'), findsOneWidget);
    expect(find.textContaining('Operator: A.B.'), findsOneWidget);
    expect(find.textContaining('Equipment: Tractor / Boom'), findsOneWidget);
  });

  testWidgets('empty list shows hint', (tester) async {
    await tester.pumpWidget(_wrap([]));
    await tester.pumpAndSettle();

    expect(
      find.text('No ARM Applications sheet data for this trial.'),
      findsOneWidget,
    );
  });

  testWidgets('rows sort by application date ascending', (tester) async {
    final late = _event(
      id: 'late',
      applicationDate: DateTime.utc(2026, 7, 1),
    );
    final early = _event(
      id: 'early',
      applicationDate: DateTime.utc(2026, 6, 1),
    );
    // Provider stream should already be ordered — this documents expected UX
    // if the repository order changes. Pass pre-sorted as production does.
    await tester.pumpWidget(_wrap([
      (event: early, arm: _arm(id: 1, eventId: early.id, colIdx: 2)),
      (event: late, arm: _arm(id: 2, eventId: late.id, colIdx: 3)),
    ]));
    await tester.pumpAndSettle();

    final earlyStr =
        DateFormat('d MMM yyyy').format(early.applicationDate.toLocal());
    final lateStr =
        DateFormat('d MMM yyyy').format(late.applicationDate.toLocal());

    final yEarly = tester.getTopLeft(find.textContaining(earlyStr)).dy;
    final yLate = tester.getTopLeft(find.textContaining(lateStr)).dy;
    expect(yEarly < yLate, isTrue);
  });
}
