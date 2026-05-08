import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/domain/trial_cognition/readiness_criteria_codec.dart';

void main() {
  final kSetAt = DateTime.utc(2026, 5, 5, 12, 0, 0);

  group('ReadinessCriteriaCodec.serialize', () {
    test('serializes all fields', () {
      final dto = ReadinessCriteriaDto(
        minEfficacyPercent: 80,
        efficacyAt: 'primary_endpoint_only',
        phytotoxicityThresholdPercent: 10,
        setBy: 'researcher',
        setAt: kSetAt,
      );
      final json = ReadinessCriteriaCodec.serialize(dto);
      final map = jsonDecode(json) as Map<String, dynamic>;

      expect(map['min_efficacy_percent'], 80.0);
      expect(map['efficacy_at'], 'primary_endpoint_only');
      expect(map['phytotoxicity_threshold_percent'], 10.0);
      expect(map['set_by'], 'researcher');
      expect(map['set_at'], kSetAt.toIso8601String());
    });

    test('omits null optional fields', () {
      final dto = ReadinessCriteriaDto(
        setBy: 'researcher',
        setAt: kSetAt,
      );
      final json = ReadinessCriteriaCodec.serialize(dto);
      final map = jsonDecode(json) as Map<String, dynamic>;

      expect(map.containsKey('min_efficacy_percent'), isFalse);
      expect(map.containsKey('efficacy_at'), isFalse);
      expect(map.containsKey('phytotoxicity_threshold_percent'), isFalse);
      expect(map['set_by'], 'researcher');
    });

    test('set_at is serialized as UTC ISO string', () {
      final dto = ReadinessCriteriaDto(
        setBy: 'researcher',
        setAt: DateTime(2026, 5, 5, 14, 30).toUtc(),
      );
      final json = ReadinessCriteriaCodec.serialize(dto);
      final map = jsonDecode(json) as Map<String, dynamic>;
      expect(map['set_at'], contains('2026-05-05'));
    });
  });

  group('ReadinessCriteriaCodec.parse', () {
    test('null input returns null (criteria not set)', () {
      expect(ReadinessCriteriaCodec.parse(null), isNull);
    });

    test('parses full object correctly', () {
      final json = jsonEncode({
        'min_efficacy_percent': 80.0,
        'efficacy_at': 'primary_endpoint_only',
        'phytotoxicity_threshold_percent': 10.0,
        'set_by': 'researcher',
        'set_at': '2026-05-05T12:00:00.000Z',
      });
      final dto = ReadinessCriteriaCodec.parse(json)!;

      expect(dto.minEfficacyPercent, 80.0);
      expect(dto.efficacyAt, 'primary_endpoint_only');
      expect(dto.phytotoxicityThresholdPercent, 10.0);
      expect(dto.setBy, 'researcher');
      expect(dto.setAt.year, 2026);
    });

    test('parses object with only required fields', () {
      final json = jsonEncode({
        'set_by': 'researcher',
        'set_at': '2026-05-05T12:00:00.000Z',
      });
      final dto = ReadinessCriteriaCodec.parse(json)!;

      expect(dto.minEfficacyPercent, isNull);
      expect(dto.efficacyAt, isNull);
      expect(dto.phytotoxicityThresholdPercent, isNull);
      expect(dto.setBy, 'researcher');
    });

    test('round-trip serialize → parse preserves values', () {
      final original = ReadinessCriteriaDto(
        minEfficacyPercent: 75,
        efficacyAt: 'all_endpoints',
        phytotoxicityThresholdPercent: 5,
        setBy: 'researcher',
        setAt: kSetAt,
      );
      final parsed =
          ReadinessCriteriaCodec.parse(ReadinessCriteriaCodec.serialize(original))!;

      expect(parsed.minEfficacyPercent, original.minEfficacyPercent);
      expect(parsed.efficacyAt, original.efficacyAt);
      expect(parsed.phytotoxicityThresholdPercent,
          original.phytotoxicityThresholdPercent);
      expect(parsed.setBy, original.setBy);
      expect(parsed.setAt.millisecondsSinceEpoch,
          original.setAt.millisecondsSinceEpoch);
    });

    test('malformed JSON returns null, never throws', () {
      expect(ReadinessCriteriaCodec.parse('not json at all'), isNull);
      expect(ReadinessCriteriaCodec.parse('{bad: json}'), isNull);
    });

    test('missing required set_by returns null', () {
      final json = jsonEncode({'set_at': '2026-05-05T12:00:00.000Z'});
      expect(ReadinessCriteriaCodec.parse(json), isNull);
    });

    test('missing required set_at returns null', () {
      final json = jsonEncode({'set_by': 'researcher'});
      expect(ReadinessCriteriaCodec.parse(json), isNull);
    });

    test('invalid set_at timestamp returns null', () {
      final json = jsonEncode({'set_by': 'researcher', 'set_at': 'not-a-date'});
      expect(ReadinessCriteriaCodec.parse(json), isNull);
    });

    test('non-object JSON returns null', () {
      expect(ReadinessCriteriaCodec.parse('[1,2,3]'), isNull);
      expect(ReadinessCriteriaCodec.parse('"a string"'), isNull);
    });
  });
}
