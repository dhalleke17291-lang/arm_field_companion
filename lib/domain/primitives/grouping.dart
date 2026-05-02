/// Pure grouping utilities for arbitrary item lists.
///
/// No DB imports, no Riverpod, no domain-specific types.
library;

/// Groups [items] by the key returned by [keySelector].
///
/// Insertion order is preserved within each group and for first-seen keys.
Map<K, List<T>> groupBy<T, K>(
  List<T> items,
  K Function(T) keySelector,
) {
  final result = <K, List<T>>{};
  for (final item in items) {
    result.putIfAbsent(keySelector(item), () => <T>[]).add(item);
  }
  return result;
}

/// Groups consecutive [items] into runs where adjacent pairs satisfy
/// [sameGroup]. A new group starts whenever [sameGroup] returns false.
///
/// Returns an empty list when [items] is empty.
List<List<T>> groupSequential<T>(
  List<T> items,
  bool Function(T previous, T current) sameGroup,
) {
  if (items.isEmpty) return [];
  final result = <List<T>>[[items.first]];
  for (var i = 1; i < items.length; i++) {
    if (sameGroup(items[i - 1], items[i])) {
      result.last.add(items[i]);
    } else {
      result.add([items[i]]);
    }
  }
  return result;
}
