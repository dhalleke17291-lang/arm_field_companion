import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/trial_state.dart';
import 'package:flutter_test/flutter_test.dart';

Trial _trial({
  required int id,
  required String status,
  bool isArmLinked = false,
  String workspaceType = 'efficacy',
}) {
  final now = DateTime.utc(2020, 1, 1);
  return Trial(
    id: id,
    name: 'Test',
    status: status,
    workspaceType: workspaceType,
    createdAt: now,
    updatedAt: now,
    isDeleted: false,
    isArmLinked: isArmLinked,
  );
}

void main() {
  group('canEditProtocol', () {
    test('draft non-ARM trial is editable', () {
      expect(canEditProtocol(_trial(id: 1, status: kTrialStatusDraft)), true);
    });

    test('active non-ARM trial is not editable', () {
      expect(canEditProtocol(_trial(id: 1, status: kTrialStatusActive)), false);
    });

    test('ARM-linked draft trial is not editable', () {
      expect(
        canEditProtocol(_trial(
          id: 1,
          status: kTrialStatusDraft,
          isArmLinked: true,
        )),
        false,
      );
    });
  });

  group('protocolEditBlockedMessage', () {
    test('ARM-linked uses fixed ARM message', () {
      final m = protocolEditBlockedMessage(_trial(
        id: 1,
        status: kTrialStatusDraft,
        isArmLinked: true,
      ));
      expect(m, getArmProtocolLockMessage());
      expect(m, kArmProtocolStructureLockMessage);
    });
  });

  group('canEditTrialStructure', () {
    test('standalone Active without session data is editable', () {
      final t = _trial(
        id: 1,
        status: kTrialStatusActive,
        workspaceType: 'standalone',
      );
      expect(canEditTrialStructure(t, hasSessionData: false), true);
    });

    test('standalone Active with session data is not editable', () {
      final t = _trial(
        id: 1,
        status: kTrialStatusActive,
        workspaceType: 'standalone',
      );
      expect(canEditTrialStructure(t, hasSessionData: true), false);
    });

    test('standalone Closed is not editable', () {
      final t = _trial(
        id: 1,
        status: kTrialStatusClosed,
        workspaceType: 'standalone',
      );
      expect(canEditTrialStructure(t, hasSessionData: false), false);
    });

    test('non-standalone Active is not editable', () {
      final t = _trial(id: 1, status: kTrialStatusActive);
      expect(canEditTrialStructure(t, hasSessionData: false), false);
    });

    test('ARM Active is not editable', () {
      final t = _trial(
        id: 1,
        status: kTrialStatusActive,
        workspaceType: 'standalone',
        isArmLinked: true,
      );
      expect(canEditTrialStructure(t, hasSessionData: false), false);
    });
  });

  group('canEditAssignmentsForTrial', () {
    test('standalone Active without session data allows assignments', () {
      final t = _trial(
        id: 1,
        status: kTrialStatusActive,
        workspaceType: 'standalone',
      );
      expect(canEditAssignmentsForTrial(t, hasSessionData: false), true);
    });

    test('efficacy draft with session data blocks assignments', () {
      final t = _trial(id: 1, status: kTrialStatusDraft);
      expect(canEditAssignmentsForTrial(t, hasSessionData: true), false);
    });
  });

  group('structureEditBlockedMessage', () {
    test('standalone Active with session data uses data-collection message', () {
      final t = _trial(
        id: 1,
        status: kTrialStatusActive,
        workspaceType: 'standalone',
      );
      expect(
        structureEditBlockedMessage(t, hasSessionData: true),
        kStructureLockedDataCollectionStartedUserMessage,
      );
    });
  });

  group('allowedNextTrialStatusesForTrial', () {
    test('standalone draft skips Ready', () {
      final t = _trial(id: 1, status: kTrialStatusDraft, workspaceType: 'standalone');
      expect(allowedNextTrialStatusesForTrial(kTrialStatusDraft, t),
          [kTrialStatusActive]);
    });

    test('standalone active goes to Closed', () {
      final t = _trial(id: 1, status: kTrialStatusActive, workspaceType: 'standalone');
      expect(allowedNextTrialStatusesForTrial(kTrialStatusActive, t),
          [kTrialStatusClosed]);
    });

    test('efficacy draft still uses Ready', () {
      final t = _trial(id: 1, status: kTrialStatusDraft, workspaceType: 'efficacy');
      expect(allowedNextTrialStatusesForTrial(kTrialStatusDraft, t),
          [kTrialStatusReady]);
    });
  });
}
