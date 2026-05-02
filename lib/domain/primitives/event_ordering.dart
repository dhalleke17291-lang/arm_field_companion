/// Pure ordering utilities for time-sequenced event lists.
///
/// No DB imports, no Riverpod, no domain-specific types.
library;

/// Returns a new list sorted by the timestamp returned by [getTimestamp],
/// ascending. Stable — equal timestamps preserve their relative input order.
List<T> sortByTimestamp<T>(
  List<T> items,
  DateTime Function(T) getTimestamp,
) {
  final copy = List<T>.of(items);
  copy.sort((a, b) => getTimestamp(a).compareTo(getTimestamp(b)));
  return copy;
}

/// Returns items whose timestamp falls within [[start], [end]] inclusive.
/// Preserves the relative order of the input list.
List<T> filterByTimeRange<T>(
  List<T> items,
  DateTime Function(T) getTimestamp,
  DateTime start,
  DateTime end,
) {
  return items.where((item) {
    final t = getTimestamp(item);
    return !t.isBefore(start) && !t.isAfter(end);
  }).toList();
}
