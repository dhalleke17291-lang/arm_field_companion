import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/sessions/session_export_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Session session({DateTime? endedAt}) => Session(
        id: 1,
        trialId: 1,
        name: 'S',
        startedAt: DateTime.utc(2026, 1, 1),
        endedAt: endedAt,
        sessionDateLocal: '2026-01-01',
        status: 'open',
        isDeleted: false,
      );

  test('isSessionXmlExportAvailable is false until session has endedAt', () {
    expect(isSessionXmlExportAvailable(session()), false);
    expect(
      isSessionXmlExportAvailable(session(endedAt: DateTime.utc(2026, 1, 2))),
      true,
    );
  });
}
