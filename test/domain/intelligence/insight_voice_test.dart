import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/domain/intelligence/insight_voice.dart';
import 'package:arm_field_companion/domain/intelligence/voice_spec_check.dart';
import 'package:arm_field_companion/domain/models/trial_insight.dart';

/// Asserts the produced verdict string passes the voice spec for its tier.
/// Uses the shared [VoiceSpecCheck] validator (spec §13).
void _assertPasses(String? verdict, InsightConfidence tier) {
  expect(verdict, isNotNull, reason: 'verdict should not be null for test');
  final violations = VoiceSpecCheck.validate(verdict!, tier);
  expect(
    violations,
    isEmpty,
    reason: 'voice spec violations for "$verdict" at $tier:\n'
        '- ${violations.join("\n- ")}',
  );
}

void main() {
  group('VoiceSpecCheck self-test', () {
    test('blocks emoji', () {
      final v = VoiceSpecCheck.validate(
        'Treatments are separating 🌱 clearly.',
        InsightConfidence.established,
      );
      expect(v, contains(contains('non-ASCII')));
    });

    test('blocks exclamation', () {
      final v = VoiceSpecCheck.validate(
        'Treatments are separating clearly!',
        InsightConfidence.established,
      );
      expect(v, contains(contains('"!"')));
    });

    test('blocks marketing words', () {
      final v = VoiceSpecCheck.validate(
        'Great separation across treatments detected.',
        InsightConfidence.established,
      );
      expect(v, contains(contains('"great"')));
      expect(v, contains(contains('"detected"')));
    });

    test('blocks over-qualification phrases', () {
      final v = VoiceSpecCheck.validate(
        'This may potentially indicate rep drift.',
        InsightConfidence.established,
      );
      expect(v, contains(contains('"may potentially"')));
    });

    test('requires hedge opener at preliminary tier', () {
      final v = VoiceSpecCheck.validate(
        'Treatments are separating clearly.',
        InsightConfidence.preliminary,
      );
      expect(v, contains(contains('preliminary tier')));
    });

    test('rejects hedge opener at established tier', () {
      final v = VoiceSpecCheck.validate(
        'Early signal — treatments are separating clearly.',
        InsightConfidence.established,
      );
      expect(v, contains(contains('established tier')));
    });

    test('enforces hard cap of 16 words', () {
      const long =
          'One two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen.';
      final v = VoiceSpecCheck.validate(long, InsightConfidence.established);
      expect(v, contains(contains('too long')));
    });

    test('accepts a compliant established verdict', () {
      final v = VoiceSpecCheck.validate(
        'Treatments are separating clearly.',
        InsightConfidence.established,
      );
      expect(v, isEmpty);
    });
  });

  group('InsightVoice.separationVerdict', () {
    test('emits "no differences" when effect size is tiny', () {
      final s = InsightVoice.separationVerdict(
        effectSize: 2,
        separationTrend: 'stable',
        tier: InsightConfidence.established,
      );
      expect(s, 'Treatments are not separating yet.');
      _assertPasses(s, InsightConfidence.established);
    });

    test('emits clear-separation call at large positive effect + stable trend',
        () {
      final s = InsightVoice.separationVerdict(
        effectSize: 30,
        separationTrend: 'stable',
        tier: InsightConfidence.established,
      );
      expect(s, 'Treatments are separating clearly.');
      _assertPasses(s, InsightConfidence.established);
    });

    test('notes narrowing when trend is collapsing', () {
      final s = InsightVoice.separationVerdict(
        effectSize: 25,
        separationTrend: 'collapsing',
        tier: InsightConfidence.moderate,
      );
      expect(s, startsWith('So far:'));
      _assertPasses(s, InsightConfidence.moderate);
    });

    test('uses preliminary hedge opener at preliminary tier', () {
      final s = InsightVoice.separationVerdict(
        effectSize: 10,
        separationTrend: 'increasing',
        tier: InsightConfidence.preliminary,
      );
      expect(s, startsWith('Early signal — '));
      _assertPasses(s, InsightConfidence.preliminary);
    });

    test('returns null when best-minus-check is negative (unusual)', () {
      final s = InsightVoice.separationVerdict(
        effectSize: -12,
        separationTrend: 'stable',
        tier: InsightConfidence.established,
      );
      expect(s, isNull);
    });
  });

  group('InsightVoice.trendVerdict', () {
    test('returns null below the delta floor', () {
      final s = InsightVoice.trendVerdict(
        treatmentCode: 'T1',
        delta: 2,
        tier: InsightConfidence.established,
      );
      expect(s, isNull);
    });

    test('calls "trending up" on positive delta above floor', () {
      final s = InsightVoice.trendVerdict(
        treatmentCode: 'T1',
        delta: 12,
        tier: InsightConfidence.established,
      );
      expect(s, 'Treatment T1 response is trending up.');
      _assertPasses(s, InsightConfidence.established);
    });

    test('calls "trending down" on negative delta', () {
      final s = InsightVoice.trendVerdict(
        treatmentCode: 'T2',
        delta: -8,
        tier: InsightConfidence.moderate,
      );
      expect(s, 'So far: Treatment T2 response is trending down.');
      _assertPasses(s, InsightConfidence.moderate);
    });

    test('returns null on empty treatment code', () {
      final s = InsightVoice.trendVerdict(
        treatmentCode: '   ',
        delta: 20,
        tier: InsightConfidence.established,
      );
      expect(s, isNull);
    });
  });

  group('InsightVoice.driftVerdict', () {
    test('returns null when no outlier reps', () {
      final s = InsightVoice.driftVerdict(
        outlierReps: const [],
        tier: InsightConfidence.established,
      );
      expect(s, isNull);
    });

    test('calls single outlier rep by number', () {
      final s = InsightVoice.driftVerdict(
        outlierReps: const [3],
        tier: InsightConfidence.established,
      );
      expect(s, 'Rep 3 is drifting; verify consistency next session.');
      _assertPasses(s, InsightConfidence.established);
    });

    test('lists multiple outlier reps in order', () {
      final s = InsightVoice.driftVerdict(
        outlierReps: const [4, 1],
        tier: InsightConfidence.moderate,
      );
      expect(s, 'So far: Reps 1, 4 are drifting from the trial mean; verify consistency.');
      _assertPasses(s, InsightConfidence.moderate);
    });

    test('applies preliminary hedge opener', () {
      final s = InsightVoice.driftVerdict(
        outlierReps: const [2],
        tier: InsightConfidence.preliminary,
      );
      expect(s, startsWith('Early signal — '));
      _assertPasses(s, InsightConfidence.preliminary);
    });
  });
}
