import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/sessions/session_timing_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sessionStart = DateTime.utc(2026, 5, 25, 12);

  SeedingEvent completedSeeding(DateTime date) => SeedingEvent(
        id: 'se',
        trialId: 1,
        seedingDate: date,
        status: 'completed',
        createdAt: date,
      );

  TrialApplicationEvent applied(DateTime date) => TrialApplicationEvent(
        id: 'app-${date.millisecondsSinceEpoch}',
        trialId: 1,
        applicationDate: date,
        status: 'applied',
        createdAt: date,
      );

  group('buildSessionTimingContext', () {
    test('DAS from completed seeding', () {
      final seedingDate = DateTime.utc(2026, 5, 1);
      final ctx = buildSessionTimingContext(
        sessionStartedAt: sessionStart,
        cropStageBbch: null,
        seeding: completedSeeding(seedingDate),
        applications: const [],
      );
      expect(ctx.daysAfterSeeding, sessionStart.difference(seedingDate).inDays);
      expect(ctx.daysAfterFirstApp, isNull);
    });

    test('no DAS when seeding not completed', () {
      final ctx = buildSessionTimingContext(
        sessionStartedAt: sessionStart,
        cropStageBbch: null,
        seeding: SeedingEvent(
          id: 'x',
          trialId: 1,
          seedingDate: DateTime.utc(2026, 5, 1),
          status: 'pending',
          createdAt: DateTime.utc(2026, 5, 1),
        ),
        applications: const [],
      );
      expect(ctx.daysAfterSeeding, isNull);
    });

    test('DAT from first applied application only', () {
      final first = DateTime.utc(2026, 5, 10);
      final second = DateTime.utc(2026, 5, 15);
      final ctx = buildSessionTimingContext(
        sessionStartedAt: sessionStart,
        cropStageBbch: null,
        seeding: null,
        applications: [
          applied(second),
          applied(first),
        ],
      );
      expect(ctx.daysAfterFirstApp, sessionStart.difference(first).inDays);
      expect(ctx.daysAfterLastApp, sessionStart.difference(second).inDays);
    });

    test('ignores non-applied applications for DAT', () {
      final appliedDate = DateTime.utc(2026, 5, 10);
      final ctx = buildSessionTimingContext(
        sessionStartedAt: sessionStart,
        cropStageBbch: null,
        seeding: null,
        applications: [
          TrialApplicationEvent(
            id: 'p',
            trialId: 1,
            applicationDate: DateTime.utc(2026, 5, 5),
            status: 'pending',
            createdAt: DateTime.utc(2026, 5, 5),
          ),
          applied(appliedDate),
        ],
      );
      expect(ctx.daysAfterFirstApp, sessionStart.difference(appliedDate).inDays);
    });
  });

  group('SessionTimingContext.displayLine', () {
    test('formats all parts', () {
      const ctx = SessionTimingContext(
        daysAfterSeeding: 21,
        daysAfterFirstApp: 14,
        cropStageBbch: 32,
      );
      expect(ctx.displayLine, 'BBCH 32 · 14 DAT · 21 DAS');
    });

    test('partial data', () {
      expect(
        const SessionTimingContext(cropStageBbch: 10).displayLine,
        'BBCH 10',
      );
      expect(
        const SessionTimingContext(daysAfterSeeding: 5).displayLine,
        '5 DAS',
      );
      expect(
        const SessionTimingContext(daysAfterFirstApp: 7).displayLine,
        '7 DAT',
      );
    });

    test('empty when all null', () {
      expect(const SessionTimingContext().displayLine, '');
    });
  });

  group('validateCropStageBbchInput', () {
    test('accepts blank', () {
      expect(validateCropStageBbchInput(''), isNull);
      expect(validateCropStageBbchInput('  '), isNull);
    });

    test('rejects out of range', () {
      expect(validateCropStageBbchInput('-1'), isNotNull);
      expect(validateCropStageBbchInput('100'), isNotNull);
    });
  });
}
