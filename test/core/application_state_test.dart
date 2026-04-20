import 'package:arm_field_companion/core/application_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('allowedNextAppStatuses', () {
    test('pending allows applied and cancelled', () {
      expect(
        allowedNextAppStatuses(kAppStatusPending),
        containsAll([kAppStatusApplied, kAppStatusCancelled]),
      );
    });

    test('applied allows closed and cancelled', () {
      expect(
        allowedNextAppStatuses(kAppStatusApplied),
        containsAll([kAppStatusClosed, kAppStatusCancelled]),
      );
    });

    test('closed is terminal', () {
      expect(allowedNextAppStatuses(kAppStatusClosed), isEmpty);
    });

    test('cancelled is terminal', () {
      expect(allowedNextAppStatuses(kAppStatusCancelled), isEmpty);
    });

    test('null returns empty', () {
      expect(allowedNextAppStatuses(null), isEmpty);
    });

    test('unknown status returns empty', () {
      expect(allowedNextAppStatuses('bogus'), isEmpty);
    });
  });

  group('assertValidApplicationTransition', () {
    test('valid transitions do not throw', () {
      expect(
        () => assertValidApplicationTransition(kAppStatusPending, kAppStatusApplied),
        returnsNormally,
      );
      expect(
        () => assertValidApplicationTransition(kAppStatusPending, kAppStatusCancelled),
        returnsNormally,
      );
      expect(
        () => assertValidApplicationTransition(kAppStatusApplied, kAppStatusClosed),
        returnsNormally,
      );
      expect(
        () => assertValidApplicationTransition(kAppStatusApplied, kAppStatusCancelled),
        returnsNormally,
      );
    });

    test('invalid transitions throw typed exception', () {
      expect(
        () => assertValidApplicationTransition(kAppStatusPending, kAppStatusClosed),
        throwsA(isA<InvalidApplicationTransitionException>()),
      );
      expect(
        () => assertValidApplicationTransition(kAppStatusClosed, kAppStatusApplied),
        throwsA(isA<InvalidApplicationTransitionException>()),
      );
      expect(
        () => assertValidApplicationTransition(kAppStatusCancelled, kAppStatusApplied),
        throwsA(isA<InvalidApplicationTransitionException>()),
      );
    });
  });

  group('labelForAppStatus', () {
    test('returns correct labels', () {
      expect(labelForAppStatus(kAppStatusPending), 'Pending');
      expect(labelForAppStatus(kAppStatusApplied), 'Applied');
      expect(labelForAppStatus(kAppStatusClosed), 'Closed');
      expect(labelForAppStatus(kAppStatusCancelled), 'Cancelled');
    });

    test('null returns Pending', () {
      expect(labelForAppStatus(null), 'Pending');
    });
  });
}
