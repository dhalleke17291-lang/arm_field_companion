import 'dart:convert';

import 'package:drift/drift.dart';

import 'database/app_database.dart';
import 'widgets/app_standard_widgets.dart';

/// Resolves the operational source/state for seeding or application_plan audit events.
/// Used to show Prefilled from Protocol / Manual / Recorded badge.
OperationalSource operationalSourceFromAuditEvent(AuditEvent e) {
  final meta = e.metadata;
  if (meta == null || meta.trim().isEmpty) {
    return OperationalSource.manual;
  }
  try {
    final map = jsonDecode(meta) as Map<String, dynamic>?;
    if (map == null) return OperationalSource.manual;
    if (map['executionStatus'] == 'recorded') {
      return OperationalSource.recorded;
    }
    if (map['source'] == 'protocol_import') {
      return OperationalSource.prefilledFromProtocol;
    }
  } catch (_) {}
  return OperationalSource.manual;
}

/// Updates an audit event's metadata to set executionStatus to 'recorded'.
/// Call after user confirms the activity was executed in the field.
Future<void> markAuditEventAsRecorded(AppDatabase db, AuditEvent e) async {
  final meta = e.metadata;
  Map<String, dynamic> map = <String, dynamic>{};
  if (meta != null && meta.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(meta);
      if (decoded is Map<String, dynamic>) {
        map = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
  }
  map['executionStatus'] = 'recorded';
  await (db.update(db.auditEvents)..where((a) => a.id.equals(e.id)))
      .write(AuditEventsCompanion(metadata: Value(jsonEncode(map))));
}
