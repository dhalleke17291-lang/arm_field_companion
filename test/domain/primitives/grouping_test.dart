import 'package:arm_field_companion/domain/primitives/grouping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // groupBy
  // ---------------------------------------------------------------------------

  group('groupBy', () {
    test('empty list returns empty map', () {
      expect(groupBy<String, int>([], (s) => s.length), isEmpty);
    });

    test('single item produces one group', () {
      final result = groupBy(['hello'], (s) => s.length);
      expect(result, {5: ['hello']});
    });

    test('items sharing a key land in the same group', () {
      final result = groupBy(['a', 'b', 'cc', 'dd', 'eee'], (s) => s.length);
      expect(result[1], ['a', 'b']);
      expect(result[2], ['cc', 'dd']);
      expect(result[3], ['eee']);
    });

    test('insertion order within a group is preserved', () {
      final items = ['cat', 'dog', 'ant', 'bat'];
      final result = groupBy(items, (s) => s.length);
      expect(result[3], ['cat', 'dog', 'ant', 'bat']);
    });

    test('first-seen key order is preserved across groups', () {
      final items = ['a', 'bb', 'c', 'dd', 'e'];
      final result = groupBy(items, (s) => s.length);
      expect(result.keys.toList(), [1, 2]);
    });

    test('all items unique key — each group has one element', () {
      final result = groupBy([1, 2, 3], (n) => n);
      expect(result.length, 3);
      expect(result[1], [1]);
      expect(result[2], [2]);
      expect(result[3], [3]);
    });
  });

  // ---------------------------------------------------------------------------
  // groupSequential
  // ---------------------------------------------------------------------------

  group('groupSequential', () {
    test('empty list returns empty list', () {
      expect(groupSequential<int>([], (a, b) => a == b), isEmpty);
    });

    test('single item returns one group', () {
      expect(groupSequential([42], (a, b) => a == b), [
        [42]
      ]);
    });

    test('all same value — one group containing all items', () {
      final result = groupSequential([1, 1, 1, 1], (a, b) => a == b);
      expect(result, [
        [1, 1, 1, 1]
      ]);
    });

    test('all different values — each item in its own group', () {
      final result = groupSequential([1, 2, 3], (a, b) => a == b);
      expect(result, [
        [1],
        [2],
        [3],
      ]);
    });

    test('alternating values produce alternating single-item groups', () {
      final result = groupSequential([1, 2, 1, 2], (a, b) => a == b);
      expect(result.length, 4);
    });

    test('run boundary is detected at the correct position', () {
      final result = groupSequential([1, 1, 2, 2, 1], (a, b) => a == b);
      expect(result, [
        [1, 1],
        [2, 2],
        [1],
      ]);
    });

    test('insertion order within each run is preserved', () {
      final items = ['a', 'b', 'c', 'x', 'y'];
      // Group by first character.
      final result = groupSequential(
        items,
        (prev, curr) => prev[0] == curr[0],
      );
      // 'a','b','c' are different first chars → 5 separate groups
      expect(result.length, 5);
      expect(result[0], ['a']);
    });

    test('non-consecutive equal values are NOT merged', () {
      // 1 appears at positions 0 and 2 but they are not adjacent.
      final result = groupSequential([1, 2, 1], (a, b) => a == b);
      expect(result, [
        [1],
        [2],
        [1],
      ]);
    });
  });
}
