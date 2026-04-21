import 'package:flutter/material.dart';

import 'unit_conversion.dart';

/// State mixin that wires a unit-selector dropdown/chip to
/// [UnitConversionEngine] so the displayed value is converted in place
/// when the user picks a different unit.
///
/// Usage (inside a `State`):
///   onChanged: (v) => switchUnit(
///     controller: _operatingPressureController,
///     currentUnit: _pressureUnit,
///     newUnit: v,
///     applyUnit: (u) => _pressureUnit = u,
///   );
///
/// Behaviour contract:
///   - No-op when [currentUnit] equals [newUnit].
///   - When either is null, only the unit state changes — nothing to convert.
///   - Convertible pairs (e.g. °C ↔ °F, PSI ↔ kPa, L/ha ↔ gal/ac) silently
///     update the controller to the converted numeric value, preserving
///     its meaning.
///   - Incompatible pairs (e.g. L/ha ↔ % v/v, anything ↔ oz/ac) leave
///     the value untouched and flash a snackbar asking the operator to
///     double-check — because we can't automatically rescale a number
///     across dimensional families without outside context (density,
///     mix concentration, etc.).
mixin UnitSwitchMixin<T extends StatefulWidget> on State<T> {
  void switchUnit({
    required TextEditingController controller,
    required String? currentUnit,
    required String? newUnit,
    required void Function(String?) applyUnit,
  }) {
    if (currentUnit == newUnit) return;

    if (currentUnit == null || newUnit == null) {
      setState(() => applyUnit(newUnit));
      return;
    }

    final parsed = double.tryParse(controller.text.trim());
    final result = UnitConversionEngine.convert(
      value: parsed,
      fromUnit: currentUnit,
      toUnit: newUnit,
    );

    setState(() {
      if (result.isConverted && result.convertedValue != null) {
        controller.text = formatConvertedNumber(result.convertedValue!);
      }
      applyUnit(newUnit);
    });

    // Only warn when the field actually holds a numeric value — an empty
    // field carries no risk.
    if (parsed == null) return;
    if (result.isIncompatible ||
        result.status == UnitConversionStatus.unknown) {
      _warnIncompatibleUnitChange(currentUnit, newUnit);
    }
  }

  void _warnIncompatibleUnitChange(String from, String to) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Unit changed from $from to $to — value kept as-is. '
            'Please verify it matches the new unit.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    });
  }
}
