import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../export/csv_export_service.dart';

/// Whether the trial handoff ZIP should include `weather.csv`.
bool trialZipShouldIncludeWeatherCsv(List<WeatherSnapshot> snapshots) =>
    snapshots.isNotEmpty;

/// Normalizes [Session.sessionDateLocal] to `yyyy-MM-dd` for export.
String weatherExportSessionDateYyyyMmDd(String sessionDateLocal) {
  if (sessionDateLocal.length >= 10) {
    return sessionDateLocal.substring(0, 10);
  }
  final space = sessionDateLocal.indexOf(' ');
  if (space > 0) return sessionDateLocal.substring(0, space);
  final t = sessionDateLocal.indexOf('T');
  if (t > 0) return sessionDateLocal.substring(0, t);
  return sessionDateLocal;
}

final DateFormat _recordedAtLocalFormat = DateFormat('yyyy-MM-dd HH:mm');

/// CSV for trial ZIP: one row per weather snapshot.
String buildWeatherExportCsv({
  required List<WeatherSnapshot> snapshots,
  required Map<int, Session> sessionsById,
}) {
  const headers = [
    'session_date',
    'session_status',
    'recorded_at',
    'temperature',
    'temp_unit',
    'humidity_pct',
    'wind_speed',
    'wind_unit',
    'wind_direction',
    'cloud_cover',
    'precipitation',
    'soil_condition',
    'notes',
    'crop_stage_bbch',
  ];
  final rows = <List<String>>[];
  for (final w in snapshots) {
    final session = sessionsById[w.parentId];
    final sessionDate = session != null
        ? weatherExportSessionDateYyyyMmDd(session.sessionDateLocal)
        : '';
    final sessionStatus = session != null ? session.status : '';
    final recordedLocal =
        DateTime.fromMillisecondsSinceEpoch(w.recordedAt, isUtc: true)
            .toLocal();
    final recordedStr = _recordedAtLocalFormat.format(recordedLocal);
    rows.add([
      sessionDate,
      sessionStatus,
      recordedStr,
      w.temperature != null ? w.temperature.toString() : '',
      w.temperatureUnit,
      w.humidity != null ? w.humidity.toString() : '',
      w.windSpeed != null ? w.windSpeed.toString() : '',
      w.windSpeedUnit,
      w.windDirection ?? '',
      w.cloudCover ?? '',
      w.precipitation ?? '',
      w.soilCondition ?? '',
      w.notes ?? '',
      session?.cropStageBbch != null ? session!.cropStageBbch.toString() : '',
    ]);
  }
  return CsvExportService.buildCsv(headers, rows);
}
