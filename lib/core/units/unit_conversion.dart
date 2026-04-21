/// Pure unit-conversion helpers used by UI forms when the user toggles a
/// unit after a value has already been entered/auto-filled.
///
/// Behaviour contract (applies to every family below):
///   - Returns `null` if the input value is `null`, or if either unit is
///     unknown / not representable in this family.
///   - Returns the value unchanged when [from] and [to] normalise to the
///     same unit (e.g. "°C" vs "C" vs "celsius").
///   - Returns a [UnitConversionResult.incompatible] result from the
///     higher-level [UnitConversionEngine.convert] helper when the two
///     units do exist but belong to different dimensional classes
///     (e.g. "L/ha" ↔ "% v/v" for adjuvant rates — these depend on water
///     volume and cannot be auto-converted safely).
///
/// All functions are pure — no Flutter, no I/O, no time — so they are
/// trivially testable in `test/core/units/`.
library;

/// Families of values whose units this engine knows how to convert.
enum UnitFamily {
  temperature,
  speed,
  pressure,
  area,
  volumePerArea,
  massPerArea,
  length,
}

/// Outcome of a conversion request via [UnitConversionEngine.convert].
class UnitConversionResult {
  const UnitConversionResult._({
    required this.status,
    this.convertedValue,
    this.family,
  });

  /// Value was converted successfully (including no-op same-unit case).
  factory UnitConversionResult.converted(double value, UnitFamily family) =>
      UnitConversionResult._(
        status: UnitConversionStatus.converted,
        convertedValue: value,
        family: family,
      );

  /// The two units are both known but belong to dimensionally-incompatible
  /// families (e.g. `L/ha` ↔ `% v/v`). Callers should warn the user and
  /// leave the raw value alone.
  factory UnitConversionResult.incompatible() => const UnitConversionResult._(
        status: UnitConversionStatus.incompatible,
      );

  /// Either the source or target unit string isn't recognised, or the
  /// input value is null. Callers should leave the raw value alone.
  factory UnitConversionResult.unknown() => const UnitConversionResult._(
        status: UnitConversionStatus.unknown,
      );

  final UnitConversionStatus status;
  final double? convertedValue;
  final UnitFamily? family;

  bool get isConverted => status == UnitConversionStatus.converted;
  bool get isIncompatible => status == UnitConversionStatus.incompatible;
}

enum UnitConversionStatus { converted, incompatible, unknown }

/// High-level entry point that tries every known family and reports
/// whether conversion succeeded, was incompatible, or involved an
/// unrecognised unit.
class UnitConversionEngine {
  const UnitConversionEngine._();

  static UnitConversionResult convert({
    required double? value,
    required String? fromUnit,
    required String? toUnit,
  }) {
    if (value == null || fromUnit == null || toUnit == null) {
      return UnitConversionResult.unknown();
    }

    final fromFamily = _familyOf(fromUnit);
    final toFamily = _familyOf(toUnit);

    if (fromFamily == null || toFamily == null) {
      return UnitConversionResult.unknown();
    }
    if (fromFamily != toFamily) {
      return UnitConversionResult.incompatible();
    }

    final double? out;
    switch (fromFamily) {
      case UnitFamily.temperature:
        out = UnitConversion.temperature(value, fromUnit, toUnit);
      case UnitFamily.speed:
        out = UnitConversion.speed(value, fromUnit, toUnit);
      case UnitFamily.pressure:
        out = UnitConversion.pressure(value, fromUnit, toUnit);
      case UnitFamily.area:
        out = UnitConversion.area(value, fromUnit, toUnit);
      case UnitFamily.volumePerArea:
        out = UnitConversion.volumePerArea(value, fromUnit, toUnit);
      case UnitFamily.massPerArea:
        out = UnitConversion.massPerArea(value, fromUnit, toUnit);
      case UnitFamily.length:
        out = UnitConversion.length(value, fromUnit, toUnit);
    }

    if (out == null) return UnitConversionResult.unknown();
    return UnitConversionResult.converted(out, fromFamily);
  }

  static UnitFamily? _familyOf(String u) {
    if (UnitConversion._tempKey(u) != null) return UnitFamily.temperature;
    if (UnitConversion._speedKey(u) != null) return UnitFamily.speed;
    if (UnitConversion._pressureKey(u) != null) return UnitFamily.pressure;
    if (UnitConversion._areaKey(u) != null) return UnitFamily.area;
    if (UnitConversion._volPerAreaKey(u) != null) {
      return UnitFamily.volumePerArea;
    }
    if (UnitConversion._massPerAreaKey(u) != null) {
      return UnitFamily.massPerArea;
    }
    if (UnitConversion._lengthKey(u) != null) return UnitFamily.length;
    return null;
  }
}

/// Low-level conversion primitives. Prefer [UnitConversionEngine.convert]
/// unless you already know the family you're dealing with.
class UnitConversion {
  const UnitConversion._();

  // ======= Temperature (°C ↔ °F) =======
  static double? temperature(double? value, String? from, String? to) {
    if (value == null || from == null || to == null) return null;
    final f = _tempKey(from);
    final t = _tempKey(to);
    if (f == null || t == null) return null;
    if (f == t) return value;
    if (f == 'C' && t == 'F') return value * 9 / 5 + 32;
    if (f == 'F' && t == 'C') return (value - 32) * 5 / 9;
    return null;
  }

  static String? _tempKey(String u) {
    final s = u.toUpperCase().replaceAll('°', '').trim();
    if (s == 'C' || s == 'CELSIUS') return 'C';
    if (s == 'F' || s == 'FAHRENHEIT') return 'F';
    return null;
  }

  // ======= Speed (km/h, mph, m/s) =======
  // Source: international mile definition (1 mi = 1.609344 km exactly).
  static const double _kmhPerMph = 1.609344;

  static double? speed(double? value, String? from, String? to) {
    if (value == null || from == null || to == null) return null;
    final fk = _speedKey(from);
    final tk = _speedKey(to);
    if (fk == null || tk == null) return null;
    if (fk == tk) return value;

    double? kmh;
    if (fk == 'km/h') kmh = value;
    if (fk == 'mph') kmh = value * _kmhPerMph;
    if (fk == 'm/s') kmh = value * 3.6;
    if (kmh == null) return null;

    if (tk == 'km/h') return kmh;
    if (tk == 'mph') return kmh / _kmhPerMph;
    if (tk == 'm/s') return kmh / 3.6;
    return null;
  }

  static String? _speedKey(String u) {
    final s = u.toLowerCase().replaceAll(' ', '').trim();
    if (s == 'km/h' || s == 'kph' || s == 'kmh') return 'km/h';
    if (s == 'mph' || s == 'mi/h') return 'mph';
    if (s == 'm/s' || s == 'mps') return 'm/s';
    return null;
  }

  // ======= Pressure (PSI, kPa, bar) =======
  // 1 bar = 100 kPa exactly; 1 PSI ≈ 6.8947572932 kPa.
  static const double _kpaPerPsi = 6.8947572932;
  static const double _kpaPerBar = 100.0;

  static double? pressure(double? value, String? from, String? to) {
    if (value == null || from == null || to == null) return null;
    final fk = _pressureKey(from);
    final tk = _pressureKey(to);
    if (fk == null || tk == null) return null;
    if (fk == tk) return value;

    double? kpa;
    if (fk == 'psi') kpa = value * _kpaPerPsi;
    if (fk == 'kpa') kpa = value;
    if (fk == 'bar') kpa = value * _kpaPerBar;
    if (kpa == null) return null;

    if (tk == 'psi') return kpa / _kpaPerPsi;
    if (tk == 'kpa') return kpa;
    if (tk == 'bar') return kpa / _kpaPerBar;
    return null;
  }

  static String? _pressureKey(String u) {
    final s = u.toLowerCase().replaceAll(' ', '').trim();
    if (s == 'psi') return 'psi';
    if (s == 'kpa') return 'kpa';
    if (s == 'bar') return 'bar';
    return null;
  }

  // ======= Area (ha, ac, m²) =======
  // 1 ac = 0.40468564224 ha (international acre, exact to 11 dp).
  static const double _haPerAc = 0.40468564224;
  static const double _m2PerHa = 10000.0;

  static double? area(double? value, String? from, String? to) {
    if (value == null || from == null || to == null) return null;
    final fk = _areaKey(from);
    final tk = _areaKey(to);
    if (fk == null || tk == null) return null;
    if (fk == tk) return value;

    double? ha;
    if (fk == 'ha') ha = value;
    if (fk == 'ac') ha = value * _haPerAc;
    if (fk == 'm2') ha = value / _m2PerHa;
    if (ha == null) return null;

    if (tk == 'ha') return ha;
    if (tk == 'ac') return ha / _haPerAc;
    if (tk == 'm2') return ha * _m2PerHa;
    return null;
  }

  static String? _areaKey(String u) {
    final s = u.toLowerCase().replaceAll(' ', '').replaceAll('²', '2').trim();
    if (s == 'ha' || s == 'hectare' || s == 'hectares') return 'ha';
    if (s == 'ac' || s == 'acre' || s == 'acres') return 'ac';
    if (s == 'm2' || s == 'sqm' || s == 'squaremetre' || s == 'squaremetres') {
      return 'm2';
    }
    return null;
  }

  // ======= Volume per area (spray/application rate) =======
  // Uses US liquid gallon: 1 US gal = 3.785411784 L.
  //   (1 gal/ac) × 3.785411784 L/gal × (1/0.40468564224) ac/ha
  //   ≈ 9.353965696 L/ha
  static const double _lPerHaPerGalPerAc = 9.353965696;

  static double? volumePerArea(double? value, String? from, String? to) {
    if (value == null || from == null || to == null) return null;
    final fk = _volPerAreaKey(from);
    final tk = _volPerAreaKey(to);
    if (fk == null || tk == null) return null;
    if (fk == tk) return value;

    // normalise to L/ha
    double? lha;
    if (fk == 'l/ha') lha = value;
    if (fk == 'ml/ha') lha = value / 1000.0;
    if (fk == 'gal/ac') lha = value * _lPerHaPerGalPerAc;
    if (lha == null) return null;

    if (tk == 'l/ha') return lha;
    if (tk == 'ml/ha') return lha * 1000.0;
    if (tk == 'gal/ac') return lha / _lPerHaPerGalPerAc;
    return null;
  }

  static String? _volPerAreaKey(String u) {
    final s = u.toLowerCase().replaceAll(' ', '').trim();
    if (s == 'l/ha' || s == 'lha' || s == 'litres/ha' || s == 'liters/ha') {
      return 'l/ha';
    }
    if (s == 'ml/ha' ||
        s == 'millilitres/ha' ||
        s == 'milliliters/ha') {
      return 'ml/ha';
    }
    if (s == 'gal/ac' ||
        s == 'gallons/ac' ||
        s == 'gpa' ||
        s == 'gallon/acre' ||
        s == 'gallons/acre') {
      return 'gal/ac';
    }
    return null;
  }

  // ======= Mass per area (dry product rate) =======
  // Exact: 1 kg = 1 000 g.
  static double? massPerArea(double? value, String? from, String? to) {
    if (value == null || from == null || to == null) return null;
    final fk = _massPerAreaKey(from);
    final tk = _massPerAreaKey(to);
    if (fk == null || tk == null) return null;
    if (fk == tk) return value;

    // normalise to kg/ha
    double? kgha;
    if (fk == 'kg/ha') kgha = value;
    if (fk == 'g/ha') kgha = value / 1000.0;
    if (kgha == null) return null;

    if (tk == 'kg/ha') return kgha;
    if (tk == 'g/ha') return kgha * 1000.0;
    return null;
  }

  static String? _massPerAreaKey(String u) {
    final s = u.toLowerCase().replaceAll(' ', '').trim();
    if (s == 'kg/ha' || s == 'kilograms/ha' || s == 'kilogram/ha') {
      return 'kg/ha';
    }
    if (s == 'g/ha' || s == 'grams/ha' || s == 'gram/ha') return 'g/ha';
    return null;
  }

  // ======= Length (mm, cm, m, in, ft) =======
  // Exact: 1 in = 2.54 cm, 1 ft = 30.48 cm.
  static double? length(double? value, String? from, String? to) {
    if (value == null || from == null || to == null) return null;
    final fk = _lengthKey(from);
    final tk = _lengthKey(to);
    if (fk == null || tk == null) return null;
    if (fk == tk) return value;

    double? cm;
    if (fk == 'mm') cm = value / 10.0;
    if (fk == 'cm') cm = value;
    if (fk == 'm') cm = value * 100.0;
    if (fk == 'in') cm = value * 2.54;
    if (fk == 'ft') cm = value * 30.48;
    if (cm == null) return null;

    if (tk == 'mm') return cm * 10.0;
    if (tk == 'cm') return cm;
    if (tk == 'm') return cm / 100.0;
    if (tk == 'in') return cm / 2.54;
    if (tk == 'ft') return cm / 30.48;
    return null;
  }

  static String? _lengthKey(String u) {
    final s = u.toLowerCase().replaceAll(' ', '').trim();
    if (s == 'mm' || s == 'millimetre' || s == 'millimetres') return 'mm';
    if (s == 'cm' || s == 'centimetre' || s == 'centimetres') return 'cm';
    if (s == 'm' || s == 'metre' || s == 'metres') return 'm';
    if (s == 'in' ||
        s == 'inch' ||
        s == 'inches' ||
        s == '"') {
      return 'in';
    }
    if (s == 'ft' || s == 'foot' || s == 'feet') return 'ft';
    return null;
  }
}

/// Render a converted double for a text field: at most [maxDecimals] places,
/// trailing zeros and bare decimal point removed.
/// Examples:
///   formatConvertedNumber(68.0)       -> "68"
///   formatConvertedNumber(68.444)     -> "68.4"
///   formatConvertedNumber(68.476)     -> "68.5"
///   formatConvertedNumber(0.12, maxDecimals: 2) -> "0.12"
String formatConvertedNumber(double value, {int maxDecimals = 1}) {
  if (value.isNaN || value.isInfinite) return '';
  final rounded = value.toStringAsFixed(maxDecimals);
  if (!rounded.contains('.')) return rounded;
  return rounded
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}
