import 'package:arm_field_companion/features/derived/trial_attention_service.dart';
import 'package:arm_field_companion/features/trials/portfolio_attention_preview.dart';
import 'package:flutter_test/flutter_test.dart';

AttentionItem _item(
  AttentionType type,
  AttentionSeverity severity, {
  String label = 'label',
}) =>
    AttentionItem(type: type, label: label, severity: severity);

void main() {
  group('portfolioPrimaryAttentionLine', () {
    test('null and empty return null', () {
      expect(portfolioPrimaryAttentionLine(null), isNull);
      expect(portfolioPrimaryAttentionLine([]), isNull);
    });

    test('only openSession items returns null', () {
      expect(
        portfolioPrimaryAttentionLine([
          _item(AttentionType.openSession, AttentionSeverity.medium,
              label: 'Open'),
        ]),
        isNull,
      );
      expect(
        portfolioPrimaryAttentionLine([
          _item(AttentionType.openSession, AttentionSeverity.high),
          _item(AttentionType.openSession, AttentionSeverity.low),
        ]),
        isNull,
      );
    });

    test('picks highest severity among non-open items', () {
      final high = _item(AttentionType.setupIncomplete, AttentionSeverity.high,
          label: 'setup');
      final medium = _item(
          AttentionType.plotsPartiallyRated, AttentionSeverity.medium,
          label: 'plots');
      expect(
        portfolioPrimaryAttentionLine([medium, high]),
        same(high),
      );
      expect(
        portfolioPrimaryAttentionLine([high, medium]),
        same(high),
      );
    });

    test('severity order: high > medium > low > info', () {
      final info = _item(AttentionType.noSessionsYet, AttentionSeverity.info);
      final low =
          _item(AttentionType.seedingPending, AttentionSeverity.low, label: 'l');
      final medium =
          _item(AttentionType.applicationsPending, AttentionSeverity.medium);
      final high = _item(AttentionType.setupIncomplete, AttentionSeverity.high);

      expect(
        portfolioPrimaryAttentionLine([info, low, medium, high]),
        same(high),
      );
      expect(
        portfolioPrimaryAttentionLine([info, low, medium]),
        same(medium),
      );
      expect(
        portfolioPrimaryAttentionLine([info, low]),
        same(low),
      );
      expect(
        portfolioPrimaryAttentionLine([info]),
        same(info),
      );
    });

    test('same severity: first matching item in list order', () {
      final a = _item(AttentionType.setupIncomplete, AttentionSeverity.high,
          label: 'first');
      final b = _item(AttentionType.plotsUnassigned, AttentionSeverity.high,
          label: 'second');
      expect(portfolioPrimaryAttentionLine([a, b]), same(a));
      expect(portfolioPrimaryAttentionLine([b, a]), same(b));
    });

    test('ignores openSession when choosing primary', () {
      final open = _item(AttentionType.openSession, AttentionSeverity.high);
      final medium = _item(
          AttentionType.plotsPartiallyRated, AttentionSeverity.medium);
      expect(portfolioPrimaryAttentionLine([open, medium]), same(medium));
    });
  });

  group('portfolioAdditionalAttentionCount', () {
    test('null and empty return 0', () {
      expect(portfolioAdditionalAttentionCount(null), 0);
      expect(portfolioAdditionalAttentionCount([]), 0);
    });

    test('only openSession items: 0 additional', () {
      expect(
        portfolioAdditionalAttentionCount([
          _item(AttentionType.openSession, AttentionSeverity.medium),
        ]),
        0,
      );
      expect(
        portfolioAdditionalAttentionCount([
          _item(AttentionType.openSession, AttentionSeverity.high),
          _item(AttentionType.openSession, AttentionSeverity.low),
        ]),
        0,
      );
    });

    test('one non-open item: 0 additional', () {
      expect(
        portfolioAdditionalAttentionCount([
          _item(AttentionType.setupIncomplete, AttentionSeverity.high),
        ]),
        0,
      );
    });

    test('N non-open items yield N - 1 additional', () {
      final a = _item(AttentionType.setupIncomplete, AttentionSeverity.high);
      final b = _item(AttentionType.plotsPartiallyRated, AttentionSeverity.medium);
      final c =
          _item(AttentionType.statisticalAnalysisPending, AttentionSeverity.low);
      expect(portfolioAdditionalAttentionCount([a, b]), 1);
      expect(portfolioAdditionalAttentionCount([a, b, c]), 2);
    });

    test('openSession does not count toward non-open total', () {
      final open = _item(AttentionType.openSession, AttentionSeverity.medium);
      final a = _item(AttentionType.setupIncomplete, AttentionSeverity.high);
      final b = _item(AttentionType.plotsPartiallyRated, AttentionSeverity.medium);
      expect(portfolioAdditionalAttentionCount([open, a, b]), 1);
    });
  });
}
