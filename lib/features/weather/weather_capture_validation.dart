/// Returns an error message if [value] is out of range; null if valid or null.
String? validateWeatherTemperature(double? value, String unitCOrF) {
  if (value == null) return null;
  if (unitCOrF == 'C') {
    if (value < -50 || value > 60) {
      return 'Temperature must be between -50 and 60 °C.';
    }
  } else {
    if (value < -58 || value > 140) {
      return 'Temperature must be between -58 and 140 °F.';
    }
  }
  return null;
}

String? validateWeatherHumidity(double? value) {
  if (value == null) return null;
  if (value < 0 || value > 100) {
    return 'Humidity must be between 0 and 100%.';
  }
  return null;
}

String? validateWeatherWindSpeed(double? value) {
  if (value == null) return null;
  if (value < 0 || value > 200) {
    return 'Wind speed must be between 0 and 200.';
  }
  return null;
}
