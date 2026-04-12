import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/features/derived/domain/derived_calc.dart';

void main() {
  group('derived_calc', () {
    test('sessionProgressFraction returns 0 when total is 0', () {
      expect(sessionProgressFraction(0, 0), 0.0);
      expect(sessionProgressFraction(5, 0), 0.0);
    });
    test('sessionProgressFraction returns 0–1 and clamps rated count', () {
      expect(sessionProgressFraction(0, 10), 0.0);
      expect(sessionProgressFraction(5, 10), 0.5);
      expect(sessionProgressFraction(10, 10), 1.0);
      expect(sessionProgressFraction(15, 10), 1.0);
    });
    test('sessionProgressPct returns 0–100', () {
      expect(sessionProgressPct(5, 10), 50.0);
      expect(sessionProgressPct(1, 4), 25.0);
    });
    test('trialSessionsClosedFraction returns 0 when total is 0', () {
      expect(trialSessionsClosedFraction(0, 0), 0.0);
    });
    test('trialSessionsClosedFraction returns 0–1', () {
      expect(trialSessionsClosedFraction(2, 4), 0.5);
      expect(trialSessionsClosedFraction(4, 4), 1.0);
    });
  });
}
