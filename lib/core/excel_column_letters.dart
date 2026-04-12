// Excel-style column labels (A, B, …, Z, AA, AB, …) ↔ 0-based column indices.
//
// Used by ARM shell parsing, rating shell export, and XML cell injection.

/// 0-based column index → letters (e.g. 0→A, 25→Z, 26→AA).
String columnIndexToLettersZeroBased(int colIdx) {
  if (colIdx < 0) {
    throw ArgumentError.value(colIdx, 'colIdx', 'must be non-negative');
  }
  var n = colIdx + 1;
  var result = '';
  while (n > 0) {
    n--;
    result = String.fromCharCode(65 + n % 26) + result;
    n ~/= 26;
  }
  return result;
}

/// Letters → 0-based column index. Uppercase + trim. Invalid → null.
///
/// Examples: A→0, Z→25, AA→26, AB→27, AZ→51, BA→52.
int? columnLettersToIndexZeroBased(String letters) {
  final s = letters.trim().toUpperCase();
  if (s.isEmpty) return null;
  for (var i = 0; i < s.length; i++) {
    final u = s.codeUnitAt(i);
    if (u < 65 || u > 90) return null;
  }
  var result = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i) - 64;
    result = result * 26 + c;
  }
  return result - 1;
}
