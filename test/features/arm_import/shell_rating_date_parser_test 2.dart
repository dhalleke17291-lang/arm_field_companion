import 'package:arm_field_companion/features/arm_import/data/shell_rating_date_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses yyyy-MM-dd verbatim', () {
    final r = tryParseShellRatingDate('2026-04-02');
    expect(r?.canonicalYyyyMmDd, '2026-04-02');
    expect(r?.startedAtUtc, DateTime.utc(2026, 4, 2));
  });

  test('parses d-Mmm-yy (ARM export style)', () {
    final r = tryParseShellRatingDate('2-Apr-26');
    expect(r?.canonicalYyyyMmDd, '2026-04-02');
    expect(r?.startedAtUtc, DateTime.utc(2026, 4, 2));
  });

  test('parses d-Mmm-yyyy', () {
    final r = tryParseShellRatingDate('14-May-2026');
    expect(r?.canonicalYyyyMmDd, '2026-05-14');
    expect(r?.startedAtUtc, DateTime.utc(2026, 5, 14));
  });

  test('returns null for unrecognised text', () {
    expect(tryParseShellRatingDate(''), isNull);
    expect(tryParseShellRatingDate('soon'), isNull);
    expect(tryParseShellRatingDate('32-Jan-26'), isNull);
  });
}
