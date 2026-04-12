import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/ui/field_note_timestamp_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatFieldNoteContextLine uses session name when map provided', () {
    final note = Note(
      id: 1,
      trialId: 1,
      plotPk: null,
      sessionId: 15,
      content: 'x',
      createdAt: DateTime.utc(2026, 4, 10),
      raterName: null,
      updatedAt: null,
      updatedBy: null,
      isDeleted: false,
      deletedAt: null,
      deletedBy: null,
    );
    final line = formatFieldNoteContextLine(
      note,
      plotIdByPk: const {},
      sessionIdToName: {15: 'SESSION 1'},
      includeSession: true,
    );
    expect(line, 'SESSION 1');
  });

  test('formatFieldNoteContextLine falls back to Session #id when unknown', () {
    final note = Note(
      id: 1,
      trialId: 1,
      plotPk: null,
      sessionId: 99,
      content: 'x',
      createdAt: DateTime.utc(2026, 4, 10),
      raterName: null,
      updatedAt: null,
      updatedBy: null,
      isDeleted: false,
      deletedAt: null,
      deletedBy: null,
    );
    final line = formatFieldNoteContextLine(
      note,
      plotIdByPk: const {},
      sessionIdToName: const {},
      includeSession: true,
    );
    expect(line, 'Session #99');
  });
}
