import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/trials/tabs/plots_tab.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

TrialApplicationEvent _event(
  String id, {
  required int? treatmentId,
  required String status,
}) {
  return TrialApplicationEvent(
    id: id,
    trialId: 1,
    treatmentId: treatmentId,
    applicationDate: DateTime(2026, 1, 1),
    status: status,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  // ─── buildTreatmentAppState ────────────────────────────────────────────────

  group('buildTreatmentAppState', () {
    test('1 — returns empty map for empty event list', () {
      expect(buildTreatmentAppState([]), isEmpty);
    });

    test('2 — single pending event maps treatment to "pending"', () {
      final result = buildTreatmentAppState([
        _event('e1', treatmentId: 10, status: 'pending'),
      ]);
      expect(result, {10: 'pending'});
    });

    test('3 — single applied event maps treatment to "applied"', () {
      final result = buildTreatmentAppState([
        _event('e1', treatmentId: 10, status: 'applied'),
      ]);
      expect(result, {10: 'applied'});
    });

    test('4 — applied wins when pending comes first for same treatmentId', () {
      final result = buildTreatmentAppState([
        _event('e1', treatmentId: 10, status: 'pending'),
        _event('e2', treatmentId: 10, status: 'applied'),
      ]);
      expect(result[10], 'applied');
    });

    test('5 — applied is not overwritten by a later pending event', () {
      final result = buildTreatmentAppState([
        _event('e1', treatmentId: 10, status: 'applied'),
        _event('e2', treatmentId: 10, status: 'pending'),
      ]);
      expect(result[10], 'applied');
    });

    test('6 — events with null treatmentId are skipped', () {
      final result = buildTreatmentAppState([
        _event('e1', treatmentId: null, status: 'applied'),
      ]);
      expect(result, isEmpty);
    });

    test('7 — distinct treatment IDs are tracked independently', () {
      final result = buildTreatmentAppState([
        _event('e1', treatmentId: 10, status: 'pending'),
        _event('e2', treatmentId: 11, status: 'applied'),
      ]);
      expect(result[10], 'pending');
      expect(result[11], 'applied');
    });
  });
}
