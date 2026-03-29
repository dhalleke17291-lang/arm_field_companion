import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/trial_state.dart';
import 'package:flutter_test/flutter_test.dart';

Trial _trial({
  required int id,
  required String status,
  bool isArmLinked = false,
}) {
  final now = DateTime.utc(2020, 1, 1);
  return Trial(
    id: id,
    name: 'Test',
    status: status,
    workspaceType: 'efficacy',
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
}
