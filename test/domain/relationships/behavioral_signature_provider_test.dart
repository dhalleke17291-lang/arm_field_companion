import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/relationships/behavioral_signature_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer(AppDatabase db) => ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

Future<int> _createTrial(AppDatabase db) =>
    db.into(db.trials).insert(TrialsCompanion.insert(name: 'T'));

Future<int> _createSession(AppDatabase db, int trialId) =>
    db.into(db.sessions).insert(
          SessionsCompanion.insert(
            trialId: trialId,
            name: 'S',
            sessionDateLocal: '2026-06-01',
          ),
        );

Future<int> _createAssessment(AppDatabase db, int trialId) =>
    db.into(db.assessments).insert(
          AssessmentsCompanion.insert(trialId: trialId, name: 'A'),
        );

// Each call creates a fresh plot so that multiple is_current=true records in
// the same session never share the same unique key.
Future<int> _insertRecord(
  AppDatabase db,
  int trialId,
  int sessionId,
  int assessmentId, {
  DateTime? createdAt,
  String? confidence,
  bool amended = false,
  int? previousId,
  bool isCurrent = true,
  bool isDeleted = false,
  DateTime? lastEditedAt,
}) async {
  final plotPk = await db
      .into(db.plots)
      .insert(PlotsCompanion.insert(trialId: trialId, plotId: 'P'));
  return db.into(db.ratingRecords).insert(
        RatingRecordsCompanion.insert(
          trialId: trialId,
          plotPk: plotPk,
          assessmentId: assessmentId,
          sessionId: sessionId,
          createdAt:
              createdAt != null ? Value(createdAt) : const Value.absent(),
          confidence:
              confidence != null ? Value(confidence) : const Value.absent(),
          amended: Value(amended),
          previousId:
              previousId != null ? Value(previousId) : const Value.absent(),
          isCurrent: Value(isCurrent),
          isDeleted: Value(isDeleted),
          lastEditedAt: lastEditedAt != null
              ? Value(lastEditedAt)
              : const Value.absent(),
        ),
      );
}

Future<List<BehavioralSignal>> _run(ProviderContainer c, int sessionId) =>
    c.read(behavioralSignatureProvider(sessionId).future);

BehavioralSignal? _find(
        List<BehavioralSignal> signals, BehavioralSignalType t) =>
    signals.where((s) => s.type == t).isEmpty
        ? null
        : signals.firstWhere((s) => s.type == t);

// Base timestamp for deterministic gap arithmetic.
final _base = DateTime.utc(2026, 6, 1, 8, 0, 0);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int trialId;
  late int sessionId;
  late int assessmentId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = _makeContainer(db);
    trialId = await _createTrial(db);
    sessionId = await _createSession(db, trialId);
    assessmentId = await _createAssessment(db, trialId);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // ── Zero records ──────────────────────────────────────────────────────────

  group('0 records', () {
    test('returns [] when session has no rating records', () async {
      final result = await _run(container, sessionId);
      expect(result, isEmpty);
    });
  });

  // ── editFrequency — the only signal when records < 4 ─────────────────────

  group('1–3 records → editFrequency only', () {
    test('1 record emits only editFrequency', () async {
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base);
      final result = await _run(container, sessionId);
      expect(result, hasLength(1));
      expect(result.first.type, BehavioralSignalType.editFrequency);
    });

    test('2 records emit only editFrequency', () async {
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base);
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base.add(const Duration(seconds: 60)));
      final result = await _run(container, sessionId);
      expect(result.map((s) => s.type).toSet(),
          equals({BehavioralSignalType.editFrequency}));
    });

    test('3 records emit only editFrequency', () async {
      for (var i = 0; i < 3; i++) {
        await _insertRecord(db, trialId, sessionId, assessmentId,
            createdAt: _base.add(Duration(seconds: i * 60)));
      }
      final result = await _run(container, sessionId);
      expect(result.map((s) => s.type).toSet(),
          equals({BehavioralSignalType.editFrequency}));
    });
  });

  // ── paceChange ────────────────────────────────────────────────────────────

  group('paceChange', () {
    test('4+ records emit paceChange', () async {
      for (var i = 0; i < 4; i++) {
        await _insertRecord(db, trialId, sessionId, assessmentId,
            createdAt: _base.add(Duration(seconds: i * 30)));
      }
      final result = await _run(container, sessionId);
      expect(_find(result, BehavioralSignalType.paceChange), isNotNull);
    });

    test('pace speeding up gives negative value', () async {
      // 4 records → 3 gaps [100s, (discarded), 10s]
      // early mean = 100, late mean = 10, delta = -90
      final times = [
        _base,
        _base.add(const Duration(seconds: 100)),
        _base.add(const Duration(seconds: 110)),
        _base.add(const Duration(seconds: 120)),
      ];
      for (final t in times) {
        await _insertRecord(db, trialId, sessionId, assessmentId,
            createdAt: t);
      }
      final result = await _run(container, sessionId);
      final pace = _find(result, BehavioralSignalType.paceChange)!;
      expect(pace.value, lessThan(0));
    });

    test('pace slowing down gives positive value', () async {
      // 4 records → 3 gaps [10s, (discarded), 100s]
      // early mean = 10, late mean = 100, delta = +90
      final times = [
        _base,
        _base.add(const Duration(seconds: 10)),
        _base.add(const Duration(seconds: 15)),
        _base.add(const Duration(seconds: 115)),
      ];
      for (final t in times) {
        await _insertRecord(db, trialId, sessionId, assessmentId,
            createdAt: t);
      }
      final result = await _run(container, sessionId);
      final pace = _find(result, BehavioralSignalType.paceChange)!;
      expect(pace.value, greaterThan(0));
    });

    test('equal timestamps give 0.0', () async {
      for (var i = 0; i < 4; i++) {
        await _insertRecord(db, trialId, sessionId, assessmentId,
            createdAt: _base);
      }
      final result = await _run(container, sessionId);
      final pace = _find(result, BehavioralSignalType.paceChange)!;
      expect(pace.value, equals(0.0));
    });
  });

  // ── confidenceTrend ───────────────────────────────────────────────────────

  group('confidenceTrend', () {
    test('positive trend when confidence rises over session', () async {
      // uncertain(0.0), uncertain(0.0) → certain(1.0), certain(1.0)
      // early mean = 0.0, late mean = 1.0, delta = +1.0
      final confidences = ['uncertain', 'uncertain', 'certain', 'certain'];
      for (var i = 0; i < 4; i++) {
        await _insertRecord(db, trialId, sessionId, assessmentId,
            createdAt: _base.add(Duration(seconds: i)),
            confidence: confidences[i]);
      }
      final result = await _run(container, sessionId);
      final trend = _find(result, BehavioralSignalType.confidenceTrend)!;
      expect(trend.value, greaterThan(0));
    });

    test('negative trend when confidence drops over session', () async {
      // certain(1.0), certain(1.0) → uncertain(0.0), uncertain(0.0)
      // early mean = 1.0, late mean = 0.0, delta = -1.0
      final confidences = ['certain', 'certain', 'uncertain', 'uncertain'];
      for (var i = 0; i < 4; i++) {
        await _insertRecord(db, trialId, sessionId, assessmentId,
            createdAt: _base.add(Duration(seconds: i)),
            confidence: confidences[i]);
      }
      final result = await _run(container, sessionId);
      final trend = _find(result, BehavioralSignalType.confidenceTrend)!;
      expect(trend.value, lessThan(0));
    });

    test('zero trend when confidence is uniform', () async {
      for (var i = 0; i < 4; i++) {
        await _insertRecord(db, trialId, sessionId, assessmentId,
            createdAt: _base.add(Duration(seconds: i)),
            confidence: 'estimated');
      }
      final result = await _run(container, sessionId);
      final trend = _find(result, BehavioralSignalType.confidenceTrend)!;
      expect(trend.value, equals(0.0));
    });

    test('null confidence records are excluded from calculation', () async {
      // 2 null, then 2 certain + 2 uncertain — only 4 non-null values used
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base.add(const Duration(seconds: 0)));
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base.add(const Duration(seconds: 1)));
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base.add(const Duration(seconds: 2)),
          confidence: 'certain');
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base.add(const Duration(seconds: 3)),
          confidence: 'certain');
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base.add(const Duration(seconds: 4)),
          confidence: 'uncertain');
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base.add(const Duration(seconds: 5)),
          confidence: 'uncertain');
      final result = await _run(container, sessionId);
      // Null records ignored; 4 usable → trend should be present
      expect(_find(result, BehavioralSignalType.confidenceTrend), isNotNull);
    });

    test('unknown confidence strings are excluded', () async {
      // 4 records, all with unknown string → 0 usable → no confidenceTrend
      for (var i = 0; i < 4; i++) {
        await _insertRecord(db, trialId, sessionId, assessmentId,
            createdAt: _base.add(Duration(seconds: i)),
            confidence: 'HIGH');
      }
      final result = await _run(container, sessionId);
      expect(_find(result, BehavioralSignalType.confidenceTrend), isNull);
    });

    test('fewer than 4 usable confidence values → confidenceTrend omitted',
        () async {
      // 4 records but only 3 have valid confidence
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base.add(const Duration(seconds: 0)),
          confidence: 'certain');
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base.add(const Duration(seconds: 1)),
          confidence: 'certain');
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base.add(const Duration(seconds: 2)),
          confidence: 'uncertain');
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base.add(const Duration(seconds: 3)));
      final result = await _run(container, sessionId);
      expect(_find(result, BehavioralSignalType.confidenceTrend), isNull);
    });
  });

  // ── editFrequency counts ──────────────────────────────────────────────────

  group('editFrequency', () {
    test('zero edits = 0.0', () async {
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base);
      final result = await _run(container, sessionId);
      final edit = _find(result, BehavioralSignalType.editFrequency)!;
      expect(edit.value, equals(0.0));
    });

    test('amended == true counts as edit', () async {
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base, amended: true);
      final result = await _run(container, sessionId);
      final edit = _find(result, BehavioralSignalType.editFrequency)!;
      expect(edit.value, equals(1.0));
    });

    test('previousId != null counts as edit', () async {
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base, previousId: 999);
      final result = await _run(container, sessionId);
      final edit = _find(result, BehavioralSignalType.editFrequency)!;
      expect(edit.value, equals(1.0));
    });

    test('amended + previousId on same record counts as 1, not 2', () async {
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base, amended: true, previousId: 999);
      final result = await _run(container, sessionId);
      final edit = _find(result, BehavioralSignalType.editFrequency)!;
      expect(edit.value, equals(1.0));
    });

    test('lastEditedAt alone does not count as edit', () async {
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base, lastEditedAt: _base.add(const Duration(hours: 1)));
      final result = await _run(container, sessionId);
      final edit = _find(result, BehavioralSignalType.editFrequency)!;
      expect(edit.value, equals(0.0));
    });

    test('multiple edits across records counted correctly', () async {
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base); // not an edit
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base.add(const Duration(seconds: 1)),
          amended: true); // edit
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base.add(const Duration(seconds: 2)),
          previousId: 999); // edit
      final result = await _run(container, sessionId);
      final edit = _find(result, BehavioralSignalType.editFrequency)!;
      expect(edit.value, equals(2.0));
    });
  });

  // ── Filtering: isCurrent and isDeleted ────────────────────────────────────

  group('only current non-deleted records included', () {
    test('deleted records are excluded from all signals', () async {
      // 3 active + 1 deleted → not enough for paceChange (needs 4 active)
      for (var i = 0; i < 3; i++) {
        await _insertRecord(db, trialId, sessionId, assessmentId,
            createdAt: _base.add(Duration(seconds: i * 30)));
      }
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base.add(const Duration(seconds: 90)),
          isDeleted: true);

      final result = await _run(container, sessionId);
      expect(_find(result, BehavioralSignalType.paceChange), isNull);
    });

    test('non-current records are excluded from all signals', () async {
      // 3 active + 1 not-current → not enough for paceChange
      for (var i = 0; i < 3; i++) {
        await _insertRecord(db, trialId, sessionId, assessmentId,
            createdAt: _base.add(Duration(seconds: i * 30)));
      }
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base.add(const Duration(seconds: 90)),
          isCurrent: false);

      final result = await _run(container, sessionId);
      expect(_find(result, BehavioralSignalType.paceChange), isNull);
    });

    test('deleted record with amended=true does not inflate editFrequency',
        () async {
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base, isDeleted: true, amended: true);
      // Session has no active records → returns []
      final result = await _run(container, sessionId);
      expect(result, isEmpty);
    });

    test('non-current amended record does not inflate editFrequency', () async {
      // 1 active (not amended) + 1 non-current (amended)
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base);
      await _insertRecord(db, trialId, sessionId, assessmentId,
          createdAt: _base.add(const Duration(seconds: 1)),
          isCurrent: false,
          amended: true);
      final result = await _run(container, sessionId);
      final edit = _find(result, BehavioralSignalType.editFrequency)!;
      expect(edit.value, equals(0.0));
    });
  });
}
