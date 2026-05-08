import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/domain/trial_cognition/regulatory_context_value.dart';

void main() {
  group('RegulatoryContextValue', () {
    test('all contains exactly four keys', () {
      expect(RegulatoryContextValue.all, hasLength(4));
    });

    test('labelFor returns correct label for each known key', () {
      expect(
        RegulatoryContextValue.labelFor(RegulatoryContextValue.registration),
        'Registration / regulatory submission',
      );
      expect(
        RegulatoryContextValue.labelFor(RegulatoryContextValue.internalResearch),
        'Internal research / product positioning',
      );
      expect(
        RegulatoryContextValue.labelFor(RegulatoryContextValue.academic),
        'Academic / extension / on-farm',
      );
      expect(
        RegulatoryContextValue.labelFor(RegulatoryContextValue.undetermined),
        'Not yet determined',
      );
    });

    test('labelFor returns null for null input', () {
      expect(RegulatoryContextValue.labelFor(null), isNull);
    });

    test('labelFor returns null for unknown/legacy free-text value', () {
      expect(
        RegulatoryContextValue.labelFor('PMRA or regulatory submission likely'),
        isNull,
      );
      expect(RegulatoryContextValue.labelFor('some_unknown_key'), isNull);
    });

    test('isKnown returns true for all canonical values', () {
      for (final v in RegulatoryContextValue.all) {
        expect(RegulatoryContextValue.isKnown(v), isTrue,
            reason: '$v should be known');
      }
    });

    test('isKnown returns false for null and unknown values', () {
      expect(RegulatoryContextValue.isKnown(null), isFalse);
      expect(RegulatoryContextValue.isKnown(''), isFalse);
      expect(
        RegulatoryContextValue.isKnown('Internal research or market positioning'),
        isFalse,
      );
    });

    test('canonical constant strings match expected raw values', () {
      expect(RegulatoryContextValue.registration, 'registration');
      expect(RegulatoryContextValue.internalResearch, 'internal_research');
      expect(RegulatoryContextValue.academic, 'academic');
      expect(RegulatoryContextValue.undetermined, 'undetermined');
    });
  });
}
