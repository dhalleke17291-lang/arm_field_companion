import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:arm_field_companion/features/weather/weather_capture_form.dart';
import 'package:arm_field_companion/features/weather/weather_capture_validation.dart'
    show
        validateWeatherHumidity,
        validateWeatherTemperature,
        validateWeatherWindSpeed;
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Trial trial;
  late Session session;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'current_user_id': 1});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.users).insert(
          UsersCompanion.insert(displayName: 'Tester'),
        );
    final trialId = await TrialRepository(db).createTrial(
      name: 'T',
      workspaceType: 'efficacy',
    );
    trial = await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
        .getSingle();
    final sid = await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            trialId: trialId,
            name: 'S1',
            sessionDateLocal: '2026-04-01',
            startedAt: drift.Value(DateTime.utc(2026, 4, 1)),
          ),
        );
    session = await (db.select(db.sessions)..where((s) => s.id.equals(sid)))
        .getSingle();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpForm(
    WidgetTester tester, {
    WeatherSnapshot? initial,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 2200)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: WeatherCaptureForm(
                  trial: trial,
                  session: session,
                  initialSnapshot: initial,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('renders all field sections', (tester) async {
    await pumpForm(tester);
    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text('Humidity'), findsOneWidget);
    expect(find.text('Wind Speed'), findsOneWidget);
    expect(find.text('Wind Direction'), findsOneWidget);
    expect(find.text('Cloud Cover'), findsOneWidget);
    expect(find.text('Precipitation'), findsOneWidget);
    expect(find.text('Soil Condition'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.byKey(const Key('weather_button_save')), findsOneWidget);
  });

  test('temperature validation rejects out of range °C', () {
    expect(validateWeatherTemperature(100, 'C'), isNotNull);
    expect(validateWeatherTemperature(-60, 'C'), isNotNull);
    expect(validateWeatherTemperature(20, 'C'), isNull);
  });

  test('humidity validation rejects out of range', () {
    expect(validateWeatherHumidity(101), isNotNull);
    expect(validateWeatherHumidity(-1), isNotNull);
    expect(validateWeatherHumidity(50), isNull);
  });

  test('wind speed validation rejects out of range', () {
    expect(validateWeatherWindSpeed(201), isNotNull);
    expect(validateWeatherWindSpeed(-0.1), isNotNull);
    expect(validateWeatherWindSpeed(10), isNull);
  });

}
