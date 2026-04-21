import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/core/units/unit_conversion.dart';

/// Helper: assert [actual] is within [tolerance] of [expected].
void expectClose(double actual, double expected,
    {double tolerance = 0.01, String? reason}) {
  expect(
    (actual - expected).abs() < tolerance,
    isTrue,
    reason:
        'expected $expected ± $tolerance, got $actual${reason == null ? '' : ' ($reason)'}',
  );
}

void main() {
  group('Temperature', () {
    test('°C → °F and back round-trips exactly at freezing/boiling', () {
      expect(UnitConversion.temperature(0, 'C', 'F'), 32.0);
      expect(UnitConversion.temperature(100, 'C', 'F'), 212.0);
      expect(UnitConversion.temperature(32, 'F', 'C'), 0.0);
      expect(UnitConversion.temperature(212, 'F', 'C'), 100.0);
    });

    test('accepts "°C" / "°F" / "celsius" / "fahrenheit" spellings', () {
      expectClose(UnitConversion.temperature(20, '°C', '°F')!, 68.0);
      expectClose(UnitConversion.temperature(20, 'celsius', 'fahrenheit')!,
          68.0);
    });

    test('same unit returns input unchanged', () {
      expect(UnitConversion.temperature(20.5, 'C', 'C'), 20.5);
    });

    test('null / unknown unit returns null', () {
      expect(UnitConversion.temperature(null, 'C', 'F'), isNull);
      expect(UnitConversion.temperature(20, 'K', 'F'), isNull);
    });
  });

  group('Speed', () {
    test('km/h ↔ mph uses exact international mile factor', () {
      expectClose(UnitConversion.speed(100, 'km/h', 'mph')!, 62.1371);
      expectClose(UnitConversion.speed(60, 'mph', 'km/h')!, 96.5606);
    });

    test('m/s round-trip', () {
      expectClose(UnitConversion.speed(10, 'm/s', 'km/h')!, 36.0);
      expectClose(UnitConversion.speed(36, 'km/h', 'm/s')!, 10.0);
    });

    test('unknown unit -> null', () {
      expect(UnitConversion.speed(10, 'knots', 'km/h'), isNull);
    });
  });

  group('Pressure', () {
    test('PSI ↔ kPa known landmark (40 psi ≈ 275.79 kPa)', () {
      expectClose(UnitConversion.pressure(40, 'psi', 'kpa')!, 275.79,
          tolerance: 0.05);
      expectClose(UnitConversion.pressure(275.79, 'kpa', 'psi')!, 40.0,
          tolerance: 0.01);
    });

    test('bar ↔ kPa exact (1 bar = 100 kPa)', () {
      expect(UnitConversion.pressure(1, 'bar', 'kpa'), 100.0);
      expect(UnitConversion.pressure(100, 'kpa', 'bar'), 1.0);
    });

    test('bar ↔ PSI (1 bar ≈ 14.5038 psi)', () {
      expectClose(UnitConversion.pressure(1, 'bar', 'psi')!, 14.5038,
          tolerance: 0.001);
    });
  });

  group('Area', () {
    test('ha ↔ ac known landmark (1 ha ≈ 2.47105 ac)', () {
      expectClose(UnitConversion.area(1, 'ha', 'ac')!, 2.47105,
          tolerance: 0.0001);
      expectClose(UnitConversion.area(2.47105, 'ac', 'ha')!, 1.0,
          tolerance: 0.0001);
    });

    test('ha ↔ m² exact (1 ha = 10 000 m²)', () {
      expect(UnitConversion.area(1, 'ha', 'm²'), 10000.0);
      expect(UnitConversion.area(10000, 'm²', 'ha'), 1.0);
    });
  });

  group('Volume per area (spray rate)', () {
    test('gal/ac ↔ L/ha known landmark (20 gal/ac ≈ 187.08 L/ha)', () {
      expectClose(UnitConversion.volumePerArea(20, 'gal/ac', 'L/ha')!, 187.08,
          tolerance: 0.05);
      expectClose(UnitConversion.volumePerArea(187.08, 'L/ha', 'gal/ac')!, 20.0,
          tolerance: 0.01);
    });

    test('L/ha ↔ mL/ha exact (factor 1000)', () {
      expect(UnitConversion.volumePerArea(1, 'L/ha', 'mL/ha'), 1000.0);
      expect(UnitConversion.volumePerArea(500, 'mL/ha', 'L/ha'), 0.5);
    });

    test('round-trip stability on 100 L/ha', () {
      final gal = UnitConversion.volumePerArea(100, 'L/ha', 'gal/ac')!;
      final back = UnitConversion.volumePerArea(gal, 'gal/ac', 'L/ha')!;
      expectClose(back, 100.0, tolerance: 1e-9);
    });
  });

  group('Length', () {
    test('in ↔ cm exact (2.54 cm / inch)', () {
      expect(UnitConversion.length(1, 'in', 'cm'), 2.54);
      expect(UnitConversion.length(2.54, 'cm', 'in'), 1.0);
    });

    test('cm ↔ mm / m scaling is exact', () {
      expect(UnitConversion.length(5, 'cm', 'mm'), 50.0);
      expect(UnitConversion.length(100, 'cm', 'm'), 1.0);
    });
  });

  group('Mass per area', () {
    test('kg/ha ↔ g/ha exact (factor 1000)', () {
      expect(UnitConversion.massPerArea(1, 'kg/ha', 'g/ha'), 1000.0);
      expect(UnitConversion.massPerArea(250, 'g/ha', 'kg/ha'), 0.25);
    });

    test('kg/ha → L/ha is incompatible (needs density)', () {
      final r = UnitConversionEngine.convert(
          value: 1, fromUnit: 'kg/ha', toUnit: 'L/ha');
      expect(r.isIncompatible, isTrue);
    });
  });

  group('UnitConversionEngine.convert', () {
    test('returns converted for same-family pairs', () {
      final r = UnitConversionEngine.convert(
          value: 20, fromUnit: 'C', toUnit: 'F');
      expect(r.isConverted, isTrue);
      expectClose(r.convertedValue!, 68.0);
      expect(r.family, UnitFamily.temperature);
    });

    test('returns incompatible for cross-family pairs', () {
      final r = UnitConversionEngine.convert(
          value: 10, fromUnit: 'L/ha', toUnit: 'kPa');
      expect(r.isIncompatible, isTrue);
      expect(r.convertedValue, isNull);
    });

    test('returns unknown for unrecognised unit strings', () {
      final r = UnitConversionEngine.convert(
          value: 10, fromUnit: 'moons', toUnit: 'kPa');
      expect(r.status, UnitConversionStatus.unknown);
    });

    test('null value -> unknown (caller leaves field alone)', () {
      final r = UnitConversionEngine.convert(
          value: null, fromUnit: 'C', toUnit: 'F');
      expect(r.status, UnitConversionStatus.unknown);
    });

    test('same-unit round trip is a no-op', () {
      final r = UnitConversionEngine.convert(
          value: 42.5, fromUnit: 'km/h', toUnit: 'km/h');
      expect(r.convertedValue, 42.5);
    });
  });

  group('formatConvertedNumber', () {
    test('trims trailing zeros', () {
      expect(formatConvertedNumber(68.0), '68');
      expect(formatConvertedNumber(68.10), '68.1');
    });

    test('respects maxDecimals', () {
      expect(formatConvertedNumber(0.1234567, maxDecimals: 2), '0.12');
      expect(formatConvertedNumber(0.999, maxDecimals: 2), '1');
    });

    test('handles NaN / infinity gracefully', () {
      expect(formatConvertedNumber(double.nan), '');
      expect(formatConvertedNumber(double.infinity), '');
    });
  });
}
