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

    test('same severity: tier sorted by type then label; trialId rotates', () {
      // plotsUnassigned (enum index) sorts before setupIncomplete
      final plots = _item(AttentionType.plotsUnassigned, AttentionSeverity.high,
          label: 'plots line');
      final setup = _item(AttentionType.setupIncomplete, AttentionSeverity.high,
          label: 'setup line');
      expect(
        portfolioPrimaryAttentionLine([setup, plots], trialId: 0)?.label,
        'plots line',
      );
      expect(
        portfolioPrimaryAttentionLine([setup, plots], trialId: 1)?.label,
        'setup line',
      );
    });

    test('ignores openSession when choosing primary', () {
      final open = _item(AttentionType.openSession, AttentionSeverity.high);
      final medium = _item(
          AttentionType.plotsPartiallyRated, AttentionSeverity.medium);
      expect(portfolioPrimaryAttentionLine([open, medium]), same(medium));
    });
  });

  group('portfolioPrimaryAttentionLineDeduped', () {
    test('second trial picks different label when available', () {
      final used = <String>{};
      final seeding = _item(
          AttentionType.seedingMissing, AttentionSeverity.high, label: 'Seeding');
      final plots = _item(
          AttentionType.plotsPartiallyRated, AttentionSeverity.medium,
          label: 'Plots');
      expect(
        portfolioPrimaryAttentionLineDeduped([seeding], 1, used)?.label,
        'Seeding',
      );
      expect(used, contains('Seeding'));
      final second = portfolioPrimaryAttentionLineDeduped(
        [seeding, plots],
        2,
        used,
      );
      expect(second?.label, 'Plots');
    });

    test('falls through to lower severity when top label already used', () {
      final used = <String>{'Only high'};
      final high = _item(AttentionType.setupIncomplete, AttentionSeverity.high,
          label: 'Only high');
      final medium = _item(
          AttentionType.plotsPartiallyRated, AttentionSeverity.medium,
          label: 'Medium line');
      expect(
        portfolioPrimaryAttentionLineDeduped([high, medium], 0, used)?.label,
        'Medium line',
      );
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

    test('info items are excluded: mix of warning and info counts only warnings', () {
      final warning = _item(AttentionType.seedingMissing, AttentionSeverity.medium);
      final warning2 = _item(AttentionType.plotsPartiallyRated, AttentionSeverity.high);
      final info = _item(AttentionType.dataCollectionComplete, AttentionSeverity.info);
      // 1 warning + info: only 1 actionable, n=1 → 0 additional
      expect(portfolioAdditionalAttentionCount([warning, info]), 0);
      // 2 warnings + info: n=2 → 1 additional
      expect(portfolioAdditionalAttentionCount([warning, warning2, info]), 1);
    });

    test('only info items: count is 0', () {
      expect(
        portfolioAdditionalAttentionCount([
          _item(AttentionType.dataCollectionComplete, AttentionSeverity.info),
          _item(AttentionType.statisticalAnalysisPending, AttentionSeverity.info),
        ]),
        0,
      );
    });
  });
}
