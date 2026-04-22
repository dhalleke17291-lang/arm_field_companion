import '../models/trial_insight.dart';

/// Enforces `docs/INSIGHT_VOICE_SPEC.md` at unit-test time.
///
/// Not used at runtime — verdict strings are built by `InsightVoice` and
/// validated here in tests. Returns a list of human-readable rule violations
/// for the given string. Empty list = string passes the spec.
class VoiceSpecCheck {
  VoiceSpecCheck._();

  /// Forbidden tokens in any verdict string (spec §7).
  ///
  /// Case-insensitive word-boundary match. "detected/identified/flagged" are
  /// banned in verdict strings but allowed in low-level technical copy — so
  /// this checker is only run against verdicts.
  static const List<String> _forbiddenWords = [
    'we',
    'our',
    'us',
    'great',
    'awesome',
    'impressive',
    'insightful',
    'powerful',
    'detected',
    'identified',
    'flagged',
    'several',
    'a few',
  ];

  /// Forbidden multi-word phrases (spec §7).
  static const List<String> _forbiddenPhrases = [
    'may potentially',
    'could possibly',
    'looks like maybe',
  ];

  /// Preliminary-tier openers (spec §5).
  static const List<String> _preliminaryOpeners = [
    'Early signal — ',
    'Tentative — ',
    'Too soon to confirm — ',
  ];

  /// Moderate-tier openers (spec §5).
  static const List<String> _moderateOpeners = [
    'So far: ',
    'So far, ',
    'Based on ',
  ];

  /// Validates a verdict string against the voice spec. Returns the list of
  /// rule violations; empty means the string is spec-compliant.
  static List<String> validate(String verdict, InsightConfidence tier) {
    final violations = <String>[];

    if (verdict.isEmpty) {
      violations.add('empty string');
      return violations;
    }

    // §2 length
    final words = verdict.trim().split(RegExp(r'\s+'));
    if (words.length < 4) {
      violations.add('too short: ${words.length} words (min 4)');
    }
    if (words.length > 16) {
      violations.add('too long: ${words.length} words (hard cap 16)');
    }

    // §7 no exclamation
    if (verdict.contains('!')) {
      violations.add('contains "!"');
    }

    // §7 no emoji. Only ASCII and em dash (U+2014) are permitted.
    if (!_isAllowedUnicode(verdict)) {
      violations.add('contains disallowed non-ASCII character (emoji?)');
    }

    final lower = verdict.toLowerCase();

    // §7 forbidden words (word-boundary)
    for (final w in _forbiddenWords) {
      final pattern = RegExp(r'\b' + RegExp.escape(w) + r'\b');
      if (pattern.hasMatch(lower)) {
        violations.add('contains forbidden word: "$w"');
      }
    }

    // §7 forbidden phrases
    for (final p in _forbiddenPhrases) {
      if (lower.contains(p)) {
        violations.add('contains forbidden phrase: "$p"');
      }
    }

    // §5 tier rules
    switch (tier) {
      case InsightConfidence.preliminary:
        if (!_preliminaryOpeners.any(verdict.startsWith)) {
          violations.add(
              'preliminary tier must start with a hedge opener (${_preliminaryOpeners.join(" | ")})');
        }
        break;
      case InsightConfidence.moderate:
        if (!_moderateOpeners.any(verdict.startsWith)) {
          violations.add(
              'moderate tier must start with a named-limit opener (${_moderateOpeners.join(" | ")})');
        }
        break;
      case InsightConfidence.established:
        if (_preliminaryOpeners.any(verdict.startsWith) ||
            _moderateOpeners.any(verdict.startsWith)) {
          violations.add(
              'established tier must not use a hedge opener (spec §5)');
        }
        break;
    }

    return violations;
  }

  /// Em dash (`—`, U+2014) is allowed in verdict strings because the spec's
  /// preliminary opener uses it. No other non-ASCII characters are allowed.
  static bool _isAllowedUnicode(String s) {
    for (final rune in s.runes) {
      if (rune < 0x80) continue;
      if (rune == 0x2014) continue; // em dash
      return false;
    }
    return true;
  }
}
