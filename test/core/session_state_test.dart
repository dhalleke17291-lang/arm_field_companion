import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/session_state.dart';
import 'package:flutter_test/flutter_test.dart';

Session _session({
  required DateTime? endedAt,
  String status = kSessionStatusOpen,
}) {
  return Session(
    id: 1,
    trialId: 1,
    name: 'S',
    startedAt: DateTime(2026, 1, 1),
    endedAt: endedAt,
    sessionDateLocal: '2026-01-01',
    status: status,
  );
}

void main() {
  group('isSessionOpenForFieldWork', () {
    test('open when endedAt null and status open', () {
      expect(isSessionOpenForFieldWork(_session(endedAt: null)), true);
    });
    test('closed when endedAt set', () {
      expect(
        isSessionOpenForFieldWork(_session(endedAt: DateTime.now())),
        false,
      );
    });
    test('closed when status is closed even if endedAt null', () {
      expect(
        isSessionOpenForFieldWork(
          _session(endedAt: null, status: kSessionStatusClosed),
        ),
        false,
      );
    });
  });
}
