import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/trials/tabs/application_sheet_content.dart';

TrialApplicationEvent _event({
  String id = 'e1',
  String? growthStageCode,
  String? plotsTreated,
  String? notes,
  int? growthStageBbchAtApplication,
  String? operatorName,
}) =>
    TrialApplicationEvent(
      id: id,
      trialId: 1,
      applicationDate: DateTime(2026, 6, 15),
      status: 'pending',
      growthStageCode: growthStageCode,
      plotsTreated: plotsTreated,
      notes: notes,
      growthStageBbchAtApplication: growthStageBbchAtApplication,
      operatorName: operatorName,
      createdAt: DateTime(2026, 6, 1),
    );

void main() {
  group('computeApplicationCoverageTimingInitiallyExpanded', () {
    test('false for null event', () {
      expect(computeApplicationCoverageTimingInitiallyExpanded(null), isFalse);
    });

    test('true when numeric BBCH-at-application exists', () {
      expect(
        computeApplicationCoverageTimingInitiallyExpanded(
          _event(growthStageBbchAtApplication: 42),
        ),
        isTrue,
      );
    });

    test('true when growth stage free-text exists', () {
      expect(
        computeApplicationCoverageTimingInitiallyExpanded(
          _event(growthStageCode: 'VT4'),
        ),
        isTrue,
      );
    });

    test('true when plots treated string exists', () {
      expect(
        computeApplicationCoverageTimingInitiallyExpanded(
          _event(plotsTreated: '101,102'),
        ),
        isTrue,
      );
    });

    test('true when notes exist', () {
      expect(
        computeApplicationCoverageTimingInitiallyExpanded(
          _event(notes: 'Windy.'),
        ),
        isTrue,
      );
    });

    test('false when event has none of expansion triggers', () {
      expect(computeApplicationCoverageTimingInitiallyExpanded(_event()), isFalse);
    });
  });

  // Widget-level IME: verify manually on Android (application sheet uses a
  // fixed-height modal + scroll controller, not DraggableScrollableSheet).

  group('annotationCorrections (CWR)', () {
    test('CWR-7: all null→value fills → empty list (no correction)', () {
      // Existing event has null BBCH and null operator.
      final existing = _event();
      const companion = TrialApplicationEventsCompanion(
        growthStageBbchAtApplication: Value(32),
        operatorName: Value('J. Smith'),
      );

      final result = annotationCorrections(companion, existing);
      expect(result, isEmpty);
    });

    test(
        'CWR-8: prior BBCH=32, new BBCH=29 → correction entry with correct '
        'label and old/new values', () {
      final existing = _event(growthStageBbchAtApplication: 32);
      const companion = TrialApplicationEventsCompanion(
        growthStageBbchAtApplication: Value(29),
      );

      final result = annotationCorrections(companion, existing);
      expect(result.length, 1);
      expect(result[0].field, 'growthStageBbchAtApplication');
      expect(result[0].label, 'BBCH at application');
      expect(result[0].oldVal, '32');
      expect(result[0].newVal, '29');
    });
  });
}
