import 'package:flutter/material.dart';

/// Shared form styling for trial tabs — inputs, dropdowns, section labels,
/// expansion tiles, multi-select cards, and action buttons.
/// Use across assessments, applications, seeding, treatments.
class FormStyles {
  FormStyles._();

  static const Color _border = Color(0xFFE0DDD6);
  static const Color _focused = Color(0xFF2D5A40);
  static const Color _sectionLabel = Color(0xFF9E9E9E);
  static const Color _title = Color(0xFF333333);
  static const Color _selectedBg = Color(0xFFE8F5EE);
  static const Color _selectedBorder = Color(0xFF2D5A40);
  static const Color _unselectedBorder = Color(0xFFE0DDD6);

  static const double _radius = 8;
  static const EdgeInsets _contentPadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 14);

  /// Standard outlined input decoration for TextField and DropdownButtonFormField.
  static InputDecoration inputDecoration({
    String? hintText,
    String? labelText,
    Widget? suffixIcon,
    String? suffixText,
    bool? alignLabelWithHint,
    bool isDense = false,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radius),
      borderSide: const BorderSide(color: _border, width: 1),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radius),
      borderSide: const BorderSide(color: _focused, width: 1.5),
    );
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      border: border,
      enabledBorder: border,
      focusedBorder: focusedBorder,
      contentPadding: isDense
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 10)
          : _contentPadding,
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
      suffixText: suffixText,
      alignLabelWithHint: alignLabelWithHint,
    );
  }

  /// Section label style (e.g. "CORE", "PLOTS TREATED").
  static const TextStyle sectionLabelStyle = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w700,
    color: _sectionLabel,
    letterSpacing: 0.6,
  );

  static const EdgeInsets sectionLabelPadding =
      EdgeInsets.only(top: 14, bottom: 6);

  /// Expansion tile title style.
  static const TextStyle expansionTitleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: _title,
  );

  /// Multi-select card: selected state.
  static BoxDecoration selectedCardDecoration = BoxDecoration(
    color: _selectedBg,
    borderRadius: BorderRadius.circular(_radius),
    border: Border.all(color: _selectedBorder, width: 1),
  );

  /// Multi-select card: unselected state.
  static BoxDecoration unselectedCardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(_radius),
    border: Border.all(color: _unselectedBorder, width: 1),
  );

  static const double fieldSpacing = 10;
  static const double sectionSpacing = 14;

  /// Form bottom sheets: horizontal padding for scroll body (matches app standard).
  static const double formSheetHorizontalPadding = 24;

  /// Vertical gap between consecutive fields in form bottom sheets.
  static const double formSheetFieldSpacing = 16;

  /// Vertical gap before a new section (after expansion tiles, major blocks).
  static const double formSheetSectionSpacing = 24;

  /// Primary green for Save button.
  static const Color primaryButton = Color(0xFF2D5A40);

  static const double buttonHeight = 48;
  static const double buttonRadius = 8;
}
