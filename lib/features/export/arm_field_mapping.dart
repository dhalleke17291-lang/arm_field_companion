/// ARM-aligned column header mapping.
///
/// IMPORTANT: This is ARM-aligned, not ARM-guaranteed.
/// Validate against your exact ARM installation before using for import.
/// Update [targetVersion] and maps when targeting a different ARM release.
class ArmFieldMapping {
  /// Set this to the exact ARM version in use at the receiving end.
  /// Example: 'ARM 2025.5' or 'ARM-aligned — version unconfirmed'
  static const String targetVersion = 'Import-aligned — version unconfirmed';

  /// Keys = exact current app CSV header strings (from observations export)
  /// Values = ARM-aligned field codes
  static const Map<String, String> observationHeaders = {
    'plot_label': 'PLOTNO',
    'rep': 'REPNO',
    'treatment_code': 'TRTNO',
    'treatment_name': 'TRTNAME',
    'session_date': 'OBSDATE',
    'rater_name': 'RATER',
    'assessment_name': 'TRAIT',
    'assessment_type': 'METHOD',
    'rating_time': 'TIMING',
    'unit': 'UNIT',
    'value': 'VALUE',
    'confidence': 'CONFIDENCE',
    'rating_method': 'METHOD',
    'photo_files': 'PHOTOFILES',
    'trial_id': 'TRIALID',
    'trial_name': 'TRIALNAME',
    'session_name': 'SESSIONNAME',
    'plot_id': 'PLOTID',
    'plot_position': 'PLOTPOSITION',
    'amended': 'AMENDED',
    'original_value': 'ORIGINALVALUE',
    'amendment_reason': 'AMENDMENTREASON',
    'amended_by': 'AMENDEDBY',
    'amended_at': 'AMENDEDAT',
    'days_after_seeding': 'DAYS_AFTER_SEEDING',
    'days_after_first_application': 'DAYS_AFTER_FIRST_APP',
    'export_timestamp': 'EXPORT_TIMESTAMP',
  };

  /// Keys = exact current app CSV header strings (from applications export)
  static const Map<String, String> applicationHeaders = {
    'date': 'APPDATE',
    'product_name': 'PRODNAME',
    'rate': 'APPRATE',
    'rate_unit': 'RATEUNIT',
    'water_volume_lha': 'WATERVOL',
    'growth_stage': 'GROWTHSTAGE',
    'operator_name': 'OPERATOR',
    'equipment': 'EQUIPMENT',
    'wind_speed': 'WINDSPEED',
    'wind_direction': 'WINDDIR',
    'temperature_c': 'TEMPERATURE',
    'humidity_pct': 'HUMIDITY',
    'notes': 'NOTES',
    'days_after_seeding': 'DAYS_AFTER_SEEDING',
    'export_timestamp': 'EXPORT_TIMESTAMP',
  };

  /// Keys = exact current app CSV header strings (from seeding export)
  static const Map<String, String> seedingHeaders = {
    'seeding_date': 'SEEDDATE',
    'operator_name': 'OPERATOR',
    'seed_lot_number': 'SEEDLOT',
    'seeding_rate': 'SEEDRATE',
    'seeding_rate_unit': 'SEEDRATEUNIT',
    'seeding_depth_cm': 'SEEDDEPTH',
    'row_spacing_cm': 'ROWSPACING',
    'equipment_used': 'EQUIPMENT',
    'notes': 'NOTES',
    'export_timestamp': 'EXPORT_TIMESTAMP',
  };

  /// Keys = exact current app CSV header strings (from plot_assignments export)
  static const Map<String, String> plotHeaders = {
    'plot_label': 'PLOTNO',
    'rep': 'REPNO',
    'column': 'COLNO',
    'treatment_code': 'TRTNO',
    'treatment_name': 'TRTNAME',
    'trial_id': 'TRIALID',
    'plot_id': 'PLOTID',
    'plot_length_m': 'PLOT_LENGTH_M',
    'plot_width_m': 'PLOT_WIDTH_M',
    'plot_area_m2': 'PLOT_AREA_M2',
    'harvest_length_m': 'HARVEST_LENGTH_M',
    'harvest_width_m': 'HARVEST_WIDTH_M',
    'harvest_area_m2': 'HARVEST_AREA_M2',
    'plot_direction': 'PLOT_DIRECTION',
    'soil_series': 'SOIL_SERIES',
    'plot_notes': 'PLOT_NOTES',
    'is_guard': 'IS_GUARD',
    'export_timestamp': 'EXPORT_TIMESTAMP',
  };

  /// Keys = exact current app CSV header strings (from treatments export)
  static const Map<String, String> treatmentHeaders = {
    'treatment_code': 'TRTNO',
    'treatment_name': 'TRTNAME',
    'component_name': 'COMPONENTNAME',
    'active_ingredient': 'ACTIVEINGREDIENT',
    'rate': 'RATE',
    'rate_unit': 'RATEUNIT',
    'formulation': 'FORMULATION',
    'export_timestamp': 'EXPORT_TIMESTAMP',
  };

  /// Keys = exact current app CSV header strings (from sessions export)
  static const Map<String, String> sessionHeaders = {
    'session_name': 'COLNAME',
    'session_date': 'COLDATE',
    'rater_name': 'RATER',
    'status': 'STATUS',
    'plot_count_rated': 'PLOT_COUNT_RATED',
    'notes': 'NOTES',
    'export_timestamp': 'EXPORT_TIMESTAMP',
  };

  /// Returns the mapped ARM code if found, otherwise returns original unchanged.
  static String map(String original, Map<String, String> mapping) {
    return mapping[original] ?? original;
  }

  /// Human-readable mapping rows for the arm_mapping.csv handoff file.
  /// Each entry: [app_column, arm_field, arm_meaning, units, notes]
  static const List<List<String>> mappingGuide = [
    ['plot_label', 'PLOTNO', 'Plot number', '', 'Matches import plot number in trial structure'],
    ['rep', 'REPNO', 'Replicate number', '', ''],
    ['treatment_code', 'TRTNO', 'Treatment number', '', 'Numeric code e.g. T1=1, T2=2'],
    ['treatment_name', 'TRTNAME', 'Treatment name', '', ''],
    ['session_date', 'OBSDATE', 'Rating date', '', 'Format YYYYMMDD'],
    ['rater_name', 'RATER', 'Rater name', '', 'Person who recorded the rating'],
    ['assessment_name', 'TRAIT', 'Trait/assessment', '', 'e.g. Disease severity, Plant height'],
    ['value', 'VALUE', 'Observation value', '', 'Numeric or text depending on trait'],
    ['unit', 'UNIT', 'Unit of measurement', '', 'e.g. %, cm, count'],
    ['rating_method', 'METHOD', 'Observation method', '', 'Recorded / Missing / Not observed / N/A'],
    ['confidence', 'CONFIDENCE', 'Rating confidence', '', 'Certain / Uncertain / Estimated'],
    ['assessment_type', 'METHOD', 'Assessment type', '', 'e.g. Visual rating, Measured'],
    ['rating_time', 'TIMING', 'Assessment timing', '', 'e.g. 7DAT, BBCH65'],
    ['photo_files', 'PHOTOFILES', 'Photo filenames', '', 'Pipe-separated list of photo filenames'],
  ];
}
