import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/trials/tabs/application_sheet_content.dart';

TrialApplicationEvent _event({
  String id = 'e1',
  String? growthStageCode,
  String? plotsTreated,
  String? notes,
  int? growthStageBbchAtApplication,
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
}
