import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/domain/trial_cognition/environmental_window_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

int _dayMs(DateTime date) {
  final utc = date.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day).millisecondsSinceEpoch;
}

TrialEnvironmentalRecord _record({
  required DateTime date,
  double? minTemp,
  double? maxTemp,
  double? precip,
  String confidence = 'measured',
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return TrialEnvironmentalRecord(
    id: 0,
    trialId: 1,
    recordDate: _dayMs(date),
    siteLatitude: 51.5,
    siteLongitude: -0.1,
    dailyMinTempC: minTemp,
    dailyMaxTempC: maxTemp,
    dailyPrecipitationMm: precip,
    weatherFlags: null,
    dataSource: 'test',
    fetchedAt: now,
    confidence: confidence,
    createdAt: now,
  );
}

void main() {
  // ── Pre-application window ─────────────────────────────────────────────────

  group('computePreApplicationWindow', () {
    test('EWE-1: sums precipitation correctly across records in window',
        () {
      final appDate = DateTime(2026, 4, 10);
      final records = [
        _record(date: DateTime(2026, 4, 7), precip: 3.0),
        _record(date: DateTime(2026, 4, 8), precip: 5.0),
        _record(date: DateTime(2026, 4, 9), precip: 2.0),
      ];

      final result =
          computePreApplicationWindow(records, appDate, windowHours: 72);

      expect(result.recordCount, 3);
      expect(result.totalPrecipitationMm, closeTo(10.0, 0.001));
    });

    test('EWE-2: excludes records outside the window', () {
      final appDate = DateTime(2026, 4, 10);
      final records = [
        _record(date: DateTime(2026, 4, 6), precip: 99.0), // outside 72h
        _record(date: DateTime(2026, 4, 8), precip: 2.0),
        _record(date: DateTime(2026, 4, 10), precip: 1.0), // app day excluded
      ];

      final result =
          computePreApplicationWindow(records, appDate, windowHours: 72);

      expect(result.recordCount, 1);
      expect(result.totalPrecipitationMm, closeTo(2.0, 0.001));
    });

    test('EWE-3: frost flag detected when min temp is below zero', () {
      final appDate = DateTime(2026, 4, 10);
      final records = [
        _record(date: DateTime(2026, 4, 9), minTemp: -3.0, maxTemp: 5.0),
      ];

      final result =
          computePreApplicationWindow(records, appDate, windowHours: 72);

      expect(result.frostFlagPresent, isTrue);
    });

    test('EWE-4: frost flag absent when all min temps are non-negative', () {
      final appDate = DateTime(2026, 4, 10);
      final records = [
        _record(date: DateTime(2026, 4, 9), minTemp: 2.0, maxTemp: 18.0),
      ];

      final result =
          computePreApplicationWindow(records, appDate, windowHours: 72);

      expect(result.frostFlagPresent, isFalse);
    });

    test('EWE-5: empty records return cannot-evaluate confidence', () {
      final result = computePreApplicationWindow(
          [], DateTime(2026, 4, 10),
          windowHours: 72);

      expect(result.recordCount, 0);
      expect(result.confidence, 'unavailable');
      expect(result.totalPrecipitationMm, isNull);
      expect(result.frostFlagPresent, isFalse);
    });

    test('EWE-6: excessive rainfall flag set when total >= 10 mm', () {
      final appDate = DateTime(2026, 4, 10);
      final records = [
        _record(date: DateTime(2026, 4, 8), precip: 6.0),
        _record(date: DateTime(2026, 4, 9), precip: 5.0),
      ];

      final result =
          computePreApplicationWindow(records, appDate, windowHours: 72);

      expect(result.excessiveRainfallFlag, isTrue);
    });

    test('EWE-7: confidence degrades to worst record in window', () {
      final appDate = DateTime(2026, 4, 10);
      final records = [
        _record(date: DateTime(2026, 4, 8), confidence: 'measured'),
        _record(date: DateTime(2026, 4, 9), confidence: 'unavailable'),
      ];

      final result =
          computePreApplicationWindow(records, appDate, windowHours: 72);

      expect(result.confidence, 'unavailable');
    });
  });

  // ── Post-application window ────────────────────────────────────────────────

  group('computePostApplicationWindow', () {
    test('EWE-8: includes application day in post-window', () {
      final appDate = DateTime(2026, 4, 10);
      final records = [
        _record(date: DateTime(2026, 4, 10), precip: 4.0), // app day included
        _record(date: DateTime(2026, 4, 11), precip: 3.0),
        _record(date: DateTime(2026, 4, 12), precip: 99.0), // outside 48h
      ];

      final result =
          computePostApplicationWindow(records, appDate, windowHours: 48);

      expect(result.recordCount, 2);
      expect(result.totalPrecipitationMm, closeTo(7.0, 0.001));
    });
  });

  // ── Season summary ─────────────────────────────────────────────────────────

  group('computeSeasonSummary', () {
    test('EWE-9: counts frost events correctly', () {
      final records = [
        _record(date: DateTime(2026, 4, 1), minTemp: -2.0),
        _record(date: DateTime(2026, 4, 2), minTemp: 5.0),
        _record(date: DateTime(2026, 4, 3), minTemp: -1.0),
      ];

      final result = computeSeasonSummary(
        records,
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 3),
      );

      expect(result.totalFrostEvents, 2);
      expect(result.daysWithData, 3);
    });

    test('EWE-10: empty records return unavailable confidence', () {
      final result = computeSeasonSummary(
        [],
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 30),
      );

      expect(result.overallConfidence, 'unavailable');
      expect(result.daysWithData, 0);
      expect(result.daysExpected, 30);
      expect(result.totalPrecipitationMm, isNull);
    });

    test('EWE-11: daysExpected equals the inclusive date range length', () {
      final result = computeSeasonSummary(
        [],
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 10),
      );

      expect(result.daysExpected, 10);
    });

    test('EWE-12: totalPrecipitationMm sums across all in-range records',
        () {
      final records = [
        _record(date: DateTime(2026, 4, 1), precip: 5.0),
        _record(date: DateTime(2026, 4, 2), precip: 8.0),
        _record(date: DateTime(2026, 5, 1), precip: 99.0), // out of range
      ];

      final result = computeSeasonSummary(
        records,
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 30),
      );

      expect(result.totalPrecipitationMm, closeTo(13.0, 0.001));
      expect(result.daysWithData, 2);
    });
  });
}
