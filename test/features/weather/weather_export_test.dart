import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/weather_snapshot_repository.dart';
import 'package:arm_field_companion/features/weather/weather_export_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildWeatherExportCsv', () {
    test('headers and row formatting', () {
      final session = Session(
        id: 7,
        trialId: 1,
        name: 'S',
        startedAt: DateTime.utc(2026, 6, 15, 14),
        endedAt: null,
        sessionDateLocal: '2026-06-15',
        raterName: null,
        createdByUserId: null,
        status: 'open',
        isDeleted: false,
        deletedAt: null,
        deletedBy: null,
        cropStageBbch: 40,
      );
      final recordedUtc =
          DateTime.utc(2026, 6, 15, 18, 30).millisecondsSinceEpoch;
      final snap = WeatherSnapshot(
        id: 1,
        uuid: 'x',
        trialId: 1,
        parentType: kWeatherParentTypeRatingSession,
        parentId: 7,
        source: 'manual',
        temperature: 20,
        temperatureUnit: 'C',
        humidity: 50,
        windSpeed: 10,
        windSpeedUnit: 'km/h',
        windDirection: 'NE',
        cloudCover: 'partly_cloudy',
        precipitation: 'none',
        soilCondition: 'moist',
        notes: 'Calm',
        recordedAt: recordedUtc,
        createdAt: recordedUtc,
        modifiedAt: recordedUtc,
        createdBy: 'U',
      );
      final csv = buildWeatherExportCsv(
        snapshots: [snap],
        sessionsById: {7: session},
      );
      expect(
        csv.startsWith(
            'session_date,session_status,recorded_at,temperature,'),
        isTrue,
      );
      expect(csv.contains('crop_stage_bbch'), isTrue);
      final lines = csv.split('\n').where((l) => l.isNotEmpty).toList();
      expect(lines.length, greaterThanOrEqualTo(2));
      expect(lines[1].endsWith(',40'), isTrue);
      expect(csv.contains(',open,'), isTrue);
      expect(csv.contains('2026-06-15'), isTrue);
      expect(csv.contains('20'), isTrue);
      expect(csv.contains('C'), isTrue);
      expect(csv.contains('50'), isTrue);
      expect(csv.contains('NE'), isTrue);
      expect(csv.contains('partly_cloudy'), isTrue);
      expect(csv.contains('Calm'), isTrue);
    });

    test('empty optional fields become empty cells', () {
      final session = Session(
        id: 1,
        trialId: 1,
        name: 'S',
        startedAt: DateTime.utc(2026, 1, 1),
        endedAt: null,
        sessionDateLocal: '2026-01-01',
        raterName: null,
        createdByUserId: null,
        status: 'open',
        isDeleted: false,
        deletedAt: null,
        deletedBy: null,
        cropStageBbch: null,
      );
      final t = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
      final snap = WeatherSnapshot(
        id: 1,
        uuid: 'y',
        trialId: 1,
        parentType: kWeatherParentTypeRatingSession,
        parentId: 1,
        source: 'manual',
        temperature: null,
        temperatureUnit: 'C',
        humidity: null,
        windSpeed: null,
        windSpeedUnit: 'km/h',
        windDirection: null,
        cloudCover: null,
        precipitation: null,
        soilCondition: null,
        notes: null,
        recordedAt: t,
        createdAt: t,
        modifiedAt: t,
        createdBy: 'U',
      );
      final dataLine = buildWeatherExportCsv(
        snapshots: [snap],
        sessionsById: {1: session},
      ).split('\n')[1];
      expect(dataLine.startsWith('2026-01-01,open,'), isTrue);
      expect(dataLine.contains(',,C,'), isTrue);
      expect(dataLine.endsWith(','), isTrue);
    });
  });

  group('trialZipShouldIncludeWeatherCsv', () {
    test('false when no snapshots', () {
      expect(trialZipShouldIncludeWeatherCsv([]), isFalse);
    });

    test('true when at least one snapshot', () {
      final t = DateTime.utc(2026).millisecondsSinceEpoch;
      expect(
        trialZipShouldIncludeWeatherCsv([
          WeatherSnapshot(
            id: 1,
            uuid: 'z',
            trialId: 1,
            parentType: kWeatherParentTypeRatingSession,
            parentId: 1,
            source: 'manual',
            temperature: null,
            temperatureUnit: 'C',
            humidity: null,
            windSpeed: null,
            windSpeedUnit: 'km/h',
            windDirection: null,
            cloudCover: null,
            precipitation: null,
            soilCondition: null,
            notes: null,
            recordedAt: t,
            createdAt: t,
            modifiedAt: t,
            createdBy: 'U',
          ),
        ]),
        isTrue,
      );
    });
  });

  test('weatherExportSessionDateYyyyMmDd trims datetime strings', () {
    expect(weatherExportSessionDateYyyyMmDd('2026-03-04 10:00'), '2026-03-04');
  });
}
