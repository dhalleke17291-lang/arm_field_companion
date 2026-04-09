/// Stored values for wind direction (export / DB).
const List<String> kWeatherWindDirections = [
  'N',
  'NE',
  'E',
  'SE',
  'S',
  'SW',
  'W',
  'NW',
];

/// Stored values for cloud cover.
const List<String> kWeatherCloudCovers = [
  'clear',
  'partly_cloudy',
  'overcast',
];

/// Stored values for precipitation.
const List<String> kWeatherPrecipitations = [
  'none',
  'light',
  'moderate',
  'heavy',
];

/// Stored values for soil condition.
const List<String> kWeatherSoilConditions = [
  'dry',
  'moist',
  'wet',
  'saturated',
];

String weatherCloudCoverLabel(String value) {
  switch (value) {
    case 'clear':
      return 'Clear';
    case 'partly_cloudy':
      return 'Partly Cloudy';
    case 'overcast':
      return 'Overcast';
    default:
      return value;
  }
}

String weatherPrecipitationLabel(String value) {
  switch (value) {
    case 'none':
      return 'None';
    case 'light':
      return 'Light';
    case 'moderate':
      return 'Moderate';
    case 'heavy':
      return 'Heavy';
    default:
      return value;
  }
}

String weatherSoilLabel(String value) {
  switch (value) {
    case 'dry':
      return 'Dry';
    case 'moist':
      return 'Moist';
    case 'wet':
      return 'Wet';
    case 'saturated':
      return 'Saturated';
    default:
      return value;
  }
}
