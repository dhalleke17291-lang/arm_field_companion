/// Parses ARM Plot Data "Rating Date" cell values into a canonical
/// `yyyy-MM-dd` string for [Sessions.sessionDateLocal] and a
/// calendar [DateTime] (UTC midnight) for [Sessions.startedAt].
///
/// Shells may use ISO dates (`2026-04-02`) or ARM's `d-Mmm-yy` form
/// (`2-Apr-26`). Unrecognised strings return null — callers keep the
/// raw trimmed text for [sessionDateLocal] and omit [startedAt]
/// override.
({String canonicalYyyyMmDd, DateTime startedAtUtc})? tryParseShellRatingDate(
  String raw,
) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
  if (iso != null) {
    final y = int.parse(iso.group(1)!);
    final mo = int.parse(iso.group(2)!);
    final d = int.parse(iso.group(3)!);
    final dt = DateTime.utc(y, mo, d);
    if (dt.year != y || dt.month != mo || dt.day != d) return null;
    final canon =
        '${y.toString().padLeft(4, '0')}-${mo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
    return (canonicalYyyyMmDd: canon, startedAtUtc: dt);
  }

  const monthMap = <String, int>{
    'Jan': 1,
    'Feb': 2,
    'Mar': 3,
    'Apr': 4,
    'May': 5,
    'Jun': 6,
    'Jul': 7,
    'Aug': 8,
    'Sep': 9,
    'Oct': 10,
    'Nov': 11,
    'Dec': 12,
  };

  final parts = s.split('-');
  if (parts.length == 3) {
    final day = int.tryParse(parts[0]);
    final month = monthMap[parts[1]];
    final yRaw = parts[2];
    int? year;
    if (yRaw.length == 2) {
      final ys = int.tryParse(yRaw);
      if (ys != null) year = 2000 + ys;
    } else if (yRaw.length == 4) {
      year = int.tryParse(yRaw);
    }
    if (day != null && month != null && year != null) {
      final dt = DateTime.utc(year, month, day);
      if (dt.year != year || dt.month != month || dt.day != day) {
        return null;
      }
      final canon =
          '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      return (canonicalYyyyMmDd: canon, startedAtUtc: dt);
    }
  }

  return null;
}
