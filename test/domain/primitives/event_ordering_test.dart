import 'package:arm_field_companion/domain/primitives/event_ordering.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _E = ({String id, DateTime ts});

DateTime _d(int secondsFromEpoch) =>
    DateTime.fromMillisecondsSinceEpoch(secondsFromEpoch * 1000, isUtc: true);

void main() {
  // ---------------------------------------------------------------------------
  // sortByTimestamp
  // ---------------------------------------------------------------------------

  group('sortByTimestamp', () {
    test('empty list returns empty list', () {
      expect(sortByTimestamp<_E>([], (e) => e.ts), isEmpty);
    });

    test('single item returns single-item list', () {
      final item = (id: 'a', ts: _d(1));
      expect(sortByTimestamp([item], (e) => e.ts), [item]);
    });

    test('already-sorted list is unchanged', () {
      final items = [
        (id: 'a', ts: _d(1)),
        (id: 'b', ts: _d(2)),
        (id: 'c', ts: _d(3)),
      ];
      final sorted = sortByTimestamp(items, (e) => e.ts);
      expect(sorted.map((e) => e.id).toList(), ['a', 'b', 'c']);
    });

    test('reverses a reverse-sorted list', () {
      final items = [
        (id: 'c', ts: _d(3)),
        (id: 'b', ts: _d(2)),
        (id: 'a', ts: _d(1)),
      ];
      final sorted = sortByTimestamp(items, (e) => e.ts);
      expect(sorted.map((e) => e.id).toList(), ['a', 'b', 'c']);
    });

    test('does not mutate the original list', () {
      final items = [
        (id: 'b', ts: _d(2)),
        (id: 'a', ts: _d(1)),
      ];
      sortByTimestamp(items, (e) => e.ts);
      expect(items.first.id, 'b');
    });

    test('equal timestamps preserve insertion order (stable sort)', () {
      final t = _d(5);
      final items = [
        (id: 'first', ts: t),
        (id: 'second', ts: t),
        (id: 'third', ts: t),
      ];
      final sorted = sortByTimestamp(items, (e) => e.ts);
      expect(sorted.map((e) => e.id).toList(), ['first', 'second', 'third']);
    });
  });

  // ---------------------------------------------------------------------------
  // filterByTimeRange
  // ---------------------------------------------------------------------------

  group('filterByTimeRange', () {
    test('empty list returns empty list', () {
      expect(
        filterByTimeRange<_E>([], (e) => e.ts, _d(0), _d(10)),
        isEmpty,
      );
    });

    test('range includes boundary timestamps (inclusive)', () {
      final start = _d(2);
      final end = _d(4);
      final items = [
        (id: 'before', ts: _d(1)),
        (id: 'start', ts: _d(2)),
        (id: 'mid', ts: _d(3)),
        (id: 'end', ts: _d(4)),
        (id: 'after', ts: _d(5)),
      ];
      final result = filterByTimeRange(items, (e) => e.ts, start, end);
      expect(result.map((e) => e.id).toList(), ['start', 'mid', 'end']);
    });

    test('no items in range returns empty list', () {
      final items = [
        (id: 'a', ts: _d(1)),
        (id: 'b', ts: _d(10)),
      ];
      final result = filterByTimeRange(items, (e) => e.ts, _d(4), _d(6));
      expect(result, isEmpty);
    });

    test('all items in range returns all items', () {
      final items = [
        (id: 'a', ts: _d(2)),
        (id: 'b', ts: _d(3)),
      ];
      final result = filterByTimeRange(items, (e) => e.ts, _d(1), _d(10));
      expect(result, hasLength(2));
    });

    test('preserves relative order of original list (not re-sorted)', () {
      final items = [
        (id: 'c', ts: _d(3)),
        (id: 'a', ts: _d(1)),
        (id: 'b', ts: _d(2)),
      ];
      final result = filterByTimeRange(items, (e) => e.ts, _d(1), _d(3));
      expect(result.map((e) => e.id).toList(), ['c', 'a', 'b']);
    });

    test('single item exactly at start of range is included', () {
      final item = (id: 'x', ts: _d(5));
      final result = filterByTimeRange([item], (e) => e.ts, _d(5), _d(5));
      expect(result, [item]);
    });
  });
}
