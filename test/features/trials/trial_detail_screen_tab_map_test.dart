import 'package:arm_field_companion/core/workspace/workspace_config.dart';
import 'package:arm_field_companion/features/trials/trial_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kTrialTabToStackIndex', () {
    test('STEP2-Map: covers every TrialTab value', () {
      expect(kTrialTabToStackIndex, hasLength(TrialTab.values.length));
    });

    test('STEP2-Map: each TrialTab maps to correct stack index', () {
      expect(kTrialTabToStackIndex[TrialTab.plots], 0);
      expect(kTrialTabToStackIndex[TrialTab.seeding], 1);
      expect(kTrialTabToStackIndex[TrialTab.applications], 2);
      expect(kTrialTabToStackIndex[TrialTab.assessments], 3);
      expect(kTrialTabToStackIndex[TrialTab.treatments], 4);
      expect(kTrialTabToStackIndex[TrialTab.photos], 5);
      expect(kTrialTabToStackIndex[TrialTab.timeline], 6);
    });
  });
}
