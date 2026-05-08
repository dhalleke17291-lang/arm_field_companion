import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/domain/trial_cognition/interpretation_factors_codec.dart';

void main() {
  group('InterpretationFactorsCodec.serialize', () {
    test('empty selectedKeys with no otherText produces []', () {
      final result = InterpretationFactorsCodec.serialize([]);
      expect(result, '[]');
      final decoded = jsonDecode(result) as List;
      expect(decoded, isEmpty);
    });

    test('single key serializes correctly', () {
      final result =
          InterpretationFactorsCodec.serialize(['drought_stress']);
      final decoded = jsonDecode(result) as List;
      expect(decoded, ['drought_stress']);
    });

    test('multiple keys serialize in order', () {
      final keys = ['low_pest_pressure', 'frost_risk', 'drainage_issues'];
      final result = InterpretationFactorsCodec.serialize(keys);
      final decoded = jsonDecode(result) as List;
      expect(decoded, keys);
    });

    test('other text is appended as {"other":"text"} object', () {
      final result = InterpretationFactorsCodec.serialize(
        ['drought_stress'],
        otherText: 'unusual soil compaction',
      );
      final decoded = jsonDecode(result) as List;
      expect(decoded.length, 2);
      expect(decoded[0], 'drought_stress');
      expect(decoded[1], {'other': 'unusual soil compaction'});
    });

    test('other text is trimmed', () {
      final result = InterpretationFactorsCodec.serialize(
        [],
        otherText: '  leading and trailing spaces  ',
      );
      final decoded = jsonDecode(result) as List;
      expect((decoded[0] as Map)['other'], 'leading and trailing spaces');
    });

    test('other text clamped to 200 characters', () {
      final longText = 'x' * 300;
      final result =
          InterpretationFactorsCodec.serialize([], otherText: longText);
      final decoded = jsonDecode(result) as List;
      expect((decoded[0] as Map)['other'], hasLength(200));
    });

    test('empty other text is not appended', () {
      final result =
          InterpretationFactorsCodec.serialize(['frost_risk'], otherText: '  ');
      final decoded = jsonDecode(result) as List;
      expect(decoded, ['frost_risk']);
    });
  });

  group('InterpretationFactorsCodec.parse', () {
    test('null input returns null (unanswered)', () {
      expect(InterpretationFactorsCodec.parse(null), isNull);
    });

    test('empty array returns wasAnswered=true, no keys', () {
      final result = InterpretationFactorsCodec.parse('[]');
      expect(result, isNotNull);
      expect(result!.wasAnswered, isTrue);
      expect(result.selectedKeys, isEmpty);
      expect(result.otherText, isNull);
      expect(result.noneSelected, isTrue);
    });

    test('parses array of string keys', () {
      final json = jsonEncode(['drought_stress', 'frost_risk']);
      final result = InterpretationFactorsCodec.parse(json);
      expect(result!.selectedKeys, ['drought_stress', 'frost_risk']);
      expect(result.wasAnswered, isTrue);
    });

    test('parses other object from array', () {
      final json = jsonEncode([
        'drainage_issues',
        {'other': 'hedgerow shading on east side'},
      ]);
      final result = InterpretationFactorsCodec.parse(json);
      expect(result!.selectedKeys, ['drainage_issues']);
      expect(result.otherText, 'hedgerow shading on east side');
      expect(result.hasOther, isTrue);
    });

    test('round-trip serialize → parse preserves data', () {
      const keys = ['low_pest_pressure', 'atypical_season'];
      const other = 'unexpected hail event';
      final serialized =
          InterpretationFactorsCodec.serialize(keys, otherText: other);
      final result = InterpretationFactorsCodec.parse(serialized)!;
      expect(result.selectedKeys, keys);
      expect(result.otherText, other);
      expect(result.wasAnswered, isTrue);
    });

    test('malformed JSON returns safe result, never throws', () {
      final result =
          InterpretationFactorsCodec.parse('not valid json {{}}}}');
      expect(result, isNotNull);
      expect(result!.wasAnswered, isTrue);
      expect(result.selectedKeys, isEmpty);
      expect(result.otherText, isNull);
    });

    test('non-list JSON returns safe result', () {
      final result = InterpretationFactorsCodec.parse('{"key":"value"}');
      expect(result, isNotNull);
      expect(result!.selectedKeys, isEmpty);
      expect(result.wasAnswered, isTrue);
    });

    test('noneSelected is false when keys are present', () {
      final result = InterpretationFactorsCodec.parse(
          jsonEncode(['drought_stress']));
      expect(result!.noneSelected, isFalse);
    });
  });

  group('kInterpretationFactorKeys', () {
    test('contains exactly 10 keys including other', () {
      expect(kInterpretationFactorKeys, hasLength(10));
      expect(kInterpretationFactorKeys.contains('other'), isTrue);
    });

    test('kInterpretationFactorLabels covers all keys', () {
      for (final key in kInterpretationFactorKeys) {
        expect(kInterpretationFactorLabels.containsKey(key), isTrue,
            reason: 'Missing label for $key');
      }
    });
  });
}
