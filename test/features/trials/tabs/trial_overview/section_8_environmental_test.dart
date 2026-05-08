import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/data/repositories/trial_environmental_repository.dart';
import 'package:arm_field_companion/data/services/weather_daily_fetch_service.dart';
import 'package:arm_field_companion/data/services/weather_daily_summary.dart';
import 'package:arm_field_companion/domain/relationships/evidence_anchors_provider.dart';
import 'package:arm_field_companion/domain/trial_cognition/environmental_window_evaluator.dart';
import 'package:arm_field_companion/features/trials/tabs/trial_overview/section_8_environmental.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Trial _trialNoGps({int id = 1}) => Trial(
      id: id,
      name: 'No-GPS Trial',
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      region: 'eppo_eu',
      isDeleted: false,
    );

Trial _trialWithGps({int id = 1}) => Trial(
      id: id,
      name: 'GPS Trial',
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      region: 'eppo_eu',
      isDeleted: false,
      latitude: 51.5,
      longitude: -0.1,
    );

const _summaryMeasured = EnvironmentalSeasonSummaryDto(
  totalPrecipitationMm: 42.5,
  totalFrostEvents: 1,
  totalExcessiveRainfallEvents: 0,
  daysWithData: 10,
  daysExpected: 14,
  overallConfidence: 'measured',
);

const _summaryUnavailable = EnvironmentalSeasonSummaryDto(
  totalPrecipitationMm: null,
  totalFrostEvents: 0,
  totalExcessiveRainfallEvents: 0,
  daysWithData: 0,
  daysExpected: 14,
  overallConfidence: 'unavailable',
);

TrialApplicationEvent _appEvent({
  String id = 'test-event-uuid',
  int? growthStageBbchAtApplication,
  String status = 'applied',
  double? capturedLatitude,
  double? capturedLongitude,
  DateTime? appliedAt,
}) =>
    TrialApplicationEvent(
      id: id,
      trialId: 1,
      applicationDate: DateTime(2026, 5, 3),
      status: status,
      createdAt: DateTime(2026, 5, 3),
      growthStageBbchAtApplication: growthStageBbchAtApplication,
      capturedLatitude: capturedLatitude,
      capturedLongitude: capturedLongitude,
      appliedAt: appliedAt,
    );

const _measuredWindow = EnvironmentalWindowDto(
  totalPrecipitationMm: 18.2,
  minTempC: 2.0,
  maxTempC: 14.5,
  frostFlagPresent: false,
  excessiveRainfallFlag: false,
  recordCount: 3,
  confidence: 'measured',
);

const _emptyWindow = EnvironmentalWindowDto(
  totalPrecipitationMm: null,
  minTempC: null,
  maxTempC: null,
  frostFlagPresent: false,
  excessiveRainfallFlag: false,
  recordCount: 0,
  confidence: 'unavailable',
);

const _zeroRainWindow = EnvironmentalWindowDto(
  totalPrecipitationMm: 0,
  minTempC: null,
  maxTempC: null,
  frostFlagPresent: false,
  excessiveRainfallFlag: false,
  recordCount: 1,
  confidence: 'measured',
);

const _nullRainWindow = EnvironmentalWindowDto(
  totalPrecipitationMm: null,
  minTempC: 5,
  maxTempC: null,
  frostFlagPresent: false,
  excessiveRainfallFlag: false,
  recordCount: 1,
  confidence: 'measured',
);

class _NoopDailyFetchService implements WeatherDailyFetchService {
  @override
  Future<WeatherDailySummary?> fetchDailySummary(
    double lat,
    double lng,
    DateTime date,
  ) async =>
      null;

  @override
  Future<List<WeatherDailyRecord>> fetchDailyRange(
    double lat,
    double lng,
    DateTime startDate,
    DateTime endDate,
  ) async =>
      const [];
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _wrap({
  required Trial trial,
  EnvironmentalSeasonSummaryDto summary = _summaryMeasured,
  List<TrialApplicationEvent> apps = const [],
  List<TrialEvidenceSummary> evidence = const [],
  Map<String, ApplicationEnvironmentalContextDto> contextByEventId = const {},
  EnvironmentalProvenanceDto? provenance,
}) {
  return ProviderScope(
    overrides: [
      environmentalEnsureTodayBackgroundEnabledProvider
          .overrideWithValue(false),
      evidenceAnchorsProvider(trial.id).overrideWith((_) async => evidence),
      trialEnvironmentalSummaryProvider(trial.id)
          .overrideWith((_) => Stream.value(summary)),
      trialEnvironmentalProvenanceProvider(trial.id)
          .overrideWith((_) => Stream.value(provenance)),
      trialApplicationsForTrialProvider(trial.id)
          .overrideWith((_) => Stream.value(apps)),
      for (final entry in contextByEventId.entries)
        applicationEnvironmentalContextProvider(
          ApplicationEnvironmentalRequest(
            trialId: trial.id,
            applicationEventId: entry.key,
          ),
        ).overrideWith((_) async => entry.value),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Section8Environmental(trial: trial),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Section8Environmental widget', () {
    testWidgets('S8-W1: no site GPS explains trial-site requirement',
        (tester) async {
      await tester.pumpWidget(_wrap(trial: _trialNoGps()));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Trial site coordinates are required for environmental evidence',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Rating/session GPS may exist for provenance',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'S8-W1b: field GPS without site GPS explains it is not linked as site',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          trial: _trialNoGps(),
          apps: [
            _appEvent(
              capturedLatitude: 51.5,
              capturedLongitude: -0.1,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Rating/application GPS exists, but trial site coordinates are not set',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'S8-W2: with GPS, no application events shows no-applications message',
        (tester) async {
      await tester.pumpWidget(
        _wrap(trial: _trialWithGps(), summary: _summaryMeasured, apps: []),
      );
      await tester.pumpAndSettle();

      expect(find.text('No application events recorded yet.'), findsOneWidget);
      // Season summary header should appear (data is available)
      expect(find.text('Measured'), findsOneWidget);
    });

    testWidgets(
        'S8-W3: unavailable season data shows compact unavailable state, not zero rows',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          trial: _trialWithGps(),
          summary: _summaryUnavailable,
          apps: [],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Environmental evidence not available yet.'),
        findsOneWidget,
      );
      // Must NOT render zero-value rows that look like real data
      expect(find.textContaining('Frost events'), findsNothing);
      expect(find.textContaining('Excessive rainfall events'), findsNothing);
    });

    testWidgets(
        'S8-W4: application row renders date, BBCH, and pre/post window values',
        (tester) async {
      final event = _appEvent(
        id: 'test-event-uuid',
        growthStageBbchAtApplication: 32,
      );
      await tester.pumpWidget(
        _wrap(
          trial: _trialWithGps(),
          summary: _summaryMeasured,
          apps: [event],
          contextByEventId: {
            'test-event-uuid': const ApplicationEnvironmentalContextDto(
              preWindow: _measuredWindow,
              postWindow: _emptyWindow,
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Application — May 3, 2026'), findsOneWidget);
      expect(find.text('BBCH 32'), findsOneWidget);
      expect(find.text('72h before'), findsOneWidget);
      expect(find.text('48h after'), findsOneWidget);
      // Pre-window has real data
      expect(find.textContaining('Rainfall: 18.2 mm'), findsOneWidget);
      expect(find.textContaining('Min temp: 2.0°C'), findsOneWidget);
      // Post-window has no records
      expect(
        find.textContaining(
          'No environmental records available for this window.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'S8-W5: pending application is not rendered as a factual window',
        (tester) async {
      final pending = _appEvent(
        id: 'pending-event-uuid',
        status: 'pending',
        growthStageBbchAtApplication: 32,
      );
      await tester.pumpWidget(
        _wrap(
          trial: _trialWithGps(),
          apps: [pending],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No confirmed application events recorded yet.'),
          findsOneWidget);
      expect(find.text('Planned applications are not shown until confirmed.'),
          findsOneWidget);
      expect(find.textContaining('Application — May 3, 2026'), findsNothing);
      expect(find.text('72h before'), findsNothing);
    });

    testWidgets(
        'S8-W6: applied application renders while pending application is withheld',
        (tester) async {
      final applied = _appEvent(id: 'applied-event-uuid');
      final pending = _appEvent(id: 'pending-event-uuid', status: 'pending');
      await tester.pumpWidget(
        _wrap(
          trial: _trialWithGps(),
          apps: [applied, pending],
          contextByEventId: {
            'applied-event-uuid': const ApplicationEnvironmentalContextDto(
              preWindow: _measuredWindow,
              postWindow: _emptyWindow,
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Application — May 3, 2026'), findsOneWidget);
      expect(
        find.text('1 planned application not shown until confirmed.'),
        findsOneWidget,
      );
      expect(find.text('72h before'), findsOneWidget);
    });

    testWidgets(
        'S8-W6b: duplicate same-day applied windows render once and keep BBCH row',
        (tester) async {
      // appliedAt differs per record — simulates real device data where each
      // "Mark as Applied" tap records a distinct timestamp.
      final apps = [
        _appEvent(id: 'same-day-1', appliedAt: DateTime(2026, 5, 3, 14, 23, 1)),
        _appEvent(
            id: 'same-day-2',
            growthStageBbchAtApplication: 32,
            appliedAt: DateTime(2026, 5, 3, 14, 23, 2)),
        _appEvent(
            id: 'same-day-3', appliedAt: DateTime(2026, 5, 3, 14, 24, 15)),
        _appEvent(id: 'same-day-4', appliedAt: DateTime(2026, 5, 3, 14, 25, 0)),
      ];

      await tester.pumpWidget(
        _wrap(
          trial: _trialWithGps(),
          apps: apps,
          contextByEventId: {
            'same-day-2': const ApplicationEnvironmentalContextDto(
              preWindow: _emptyWindow,
              postWindow: _emptyWindow,
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Application — May 3, 2026'), findsOneWidget);
      expect(find.text('BBCH 32'), findsOneWidget);
    });

    testWidgets('S8-W7: measured zero rainfall renders as 0.0 mm',
        (tester) async {
      final event = _appEvent(id: 'zero-rain-event');
      await tester.pumpWidget(
        _wrap(
          trial: _trialWithGps(),
          apps: [event],
          contextByEventId: {
            'zero-rain-event': const ApplicationEnvironmentalContextDto(
              preWindow: _zeroRainWindow,
              postWindow: _emptyWindow,
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Rainfall: 0.0 mm'), findsOneWidget);
    });

    testWidgets('S8-W8: null rainfall does not render as 0 mm', (tester) async {
      final event = _appEvent(id: 'null-rain-event');
      await tester.pumpWidget(
        _wrap(
          trial: _trialWithGps(),
          apps: [event],
          contextByEventId: {
            'null-rain-event': const ApplicationEnvironmentalContextDto(
              preWindow: _nullRainWindow,
              postWindow: _emptyWindow,
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Rainfall: 0'), findsNothing);
      expect(find.textContaining('Min temp: 5.0°C'), findsOneWidget);
    });

    testWidgets(
        'S8-W9: unavailable application context renders explicit message',
        (tester) async {
      final event = _appEvent(id: 'missing-event');
      await tester.pumpWidget(
        _wrap(
          trial: _trialWithGps(),
          apps: [event],
          contextByEventId: {
            'missing-event': const ApplicationEnvironmentalContextDto(
              preWindow: _emptyWindow,
              postWindow: _emptyWindow,
              unavailableReason: 'application event not found.',
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Application environmental context unavailable — application event not found.',
        ),
        findsOneWidget,
      );
      expect(find.text('72h before'), findsNothing);
    });
  });

  group('Section8Environmental provenance strip', () {
    testWidgets('S8-P1: dataSource present renders source label and confidence',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          trial: _trialWithGps(),
          provenance: const EnvironmentalProvenanceDto(
            dataSource: 'open_meteo',
            fetchedAtMs: null,
            overallConfidence: 'measured',
            isMultiSource: false,
            dominantCount: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Open-Meteo'), findsOneWidget);
      expect(find.textContaining('Confidence: High'), findsOneWidget);
      expect(find.textContaining('api.open-meteo.com'), findsOneWidget);
    });

    testWidgets('S8-P2: null dataSource renders Not recorded fallback',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          trial: _trialWithGps(),
          provenance: const EnvironmentalProvenanceDto(
            dataSource: null,
            fetchedAtMs: null,
            overallConfidence: null,
            isMultiSource: false,
            dominantCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Not recorded'), findsOneWidget);
    });

    testWidgets('S8-P3: recent fetchedAt renders relative time with "ago"',
        (tester) async {
      final twoHoursAgo = DateTime.now()
          .subtract(const Duration(hours: 2))
          .millisecondsSinceEpoch;

      await tester.pumpWidget(
        _wrap(
          trial: _trialWithGps(),
          provenance: EnvironmentalProvenanceDto(
            dataSource: 'open_meteo',
            fetchedAtMs: twoHoursAgo,
            overallConfidence: 'measured',
            isMultiSource: false,
            dominantCount: 3,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('ago'), findsOneWidget);
    });
  });

  group('provenance display', () {
    test('sourceDisplayName maps open_meteo to Open-Meteo', () {
      expect(environmentalSourceDisplayName('open_meteo'), 'Open-Meteo');
    });

    test('sourceDisplayName maps manual to Manual entry', () {
      expect(environmentalSourceDisplayName('manual'), 'Manual entry');
    });

    test('sourceDisplayName returns raw value for unknown source', () {
      expect(environmentalSourceDisplayName('station_x'), 'station_x');
    });

    test('sourceDomain returns api.open-meteo.com for open_meteo', () {
      expect(environmentalSourceDomain('open_meteo'), 'api.open-meteo.com');
    });

    test('sourceDomain returns null for manual', () {
      expect(environmentalSourceDomain('manual'), isNull);
    });

    test('formatCoordinate formats northern western correctly', () {
      expect(
        formatEnvironmentalCoordinate(46.2382, -63.1311),
        '46.2382°N, 63.1311°W',
      );
    });

    test('formatCoordinate formats southern eastern correctly', () {
      expect(
        formatEnvironmentalCoordinate(-46.2382, 63.1311),
        '46.2382°S, 63.1311°E',
      );
    });

    test('buildProvenanceText omits domain for manual entry', () {
      final text = buildEnvironmentalProvenanceText(
        const EnvironmentalProvenanceDto(
          dataSource: 'manual',
          fetchedAtMs: null,
          overallConfidence: 'measured',
          isMultiSource: false,
          dominantCount: 1,
        ),
      );

      expect(text, contains('Manual entry'));
      expect(text, isNot(contains('api.open-meteo.com')));
    });

    test('buildProvenanceText omits coordinates when null', () {
      final text = buildEnvironmentalProvenanceText(
        const EnvironmentalProvenanceDto(
          dataSource: 'open_meteo',
          fetchedAtMs: null,
          overallConfidence: 'measured',
          isMultiSource: false,
          dominantCount: 1,
        ),
      );

      expect(text, contains('Open-Meteo'));
      expect(text, isNot(contains('°N')));
    });

    test('confidenceLabel maps measured to High', () {
      expect(environmentalConfidenceLabel('measured'), 'High');
    });
  });

  group('applicationEnvironmentalContextProvider', () {
    test('missing application UUID returns unavailable, not today window',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          trialEnvironmentalRepositoryProvider.overrideWithValue(
            TrialEnvironmentalRepository(db, _NoopDailyFetchService()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        applicationEnvironmentalContextProvider(
          const ApplicationEnvironmentalRequest(
            trialId: 1,
            applicationEventId: 'missing-uuid',
          ),
        ).future,
      );

      expect(result.isUnavailable, isTrue);
      expect(result.unavailableReason, 'application event not found.');
      expect(result.preWindow.recordCount, 0);
      expect(result.postWindow.recordCount, 0);
    });

    test('trial/application mismatch returns unavailable', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final trialId = await db.into(db.trials).insert(
            TrialsCompanion.insert(name: 'Trial A'),
          );
      await db.into(db.trialApplicationEvents).insert(
            TrialApplicationEventsCompanion.insert(
              id: const drift.Value('app-in-other-trial'),
              trialId: trialId,
              applicationDate: DateTime(2026, 5, 3),
            ),
          );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          trialEnvironmentalRepositoryProvider.overrideWithValue(
            TrialEnvironmentalRepository(db, _NoopDailyFetchService()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        applicationEnvironmentalContextProvider(
          const ApplicationEnvironmentalRequest(
            trialId: 999,
            applicationEventId: 'app-in-other-trial',
          ),
        ).future,
      );

      expect(result.isUnavailable, isTrue);
      expect(
        result.unavailableReason,
        'application event does not belong to this trial.',
      );
    });
  });
}
