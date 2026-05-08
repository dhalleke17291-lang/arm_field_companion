import 'package:arm_field_companion/core/design/app_design_tokens.dart';
import 'package:arm_field_companion/shared/layout/responsive_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResponsiveLayout breakpoints', () {
    test('compact: width below 600', () {
      const r = ResponsiveLayout(599);
      expect(r.isCompact, isTrue);
      expect(r.isMedium, isFalse);
      expect(r.isExpanded, isFalse);
    });

    test('medium: 600 … 1023', () {
      const r620 = ResponsiveLayout(620);
      expect(r620.isCompact, isFalse);
      expect(r620.isMedium, isTrue);
      expect(r620.isExpanded, isFalse);

      const r900 = ResponsiveLayout(900);
      expect(r900.isMedium, isTrue);
      expect(r900.isExpanded, isFalse);
    });

    test('expanded: width >= 1024', () {
      const r = ResponsiveLayout(1024);
      expect(r.isCompact, isFalse);
      expect(r.isMedium, isFalse);
      expect(r.isExpanded, isTrue);
    });
  });

  group('ResponsiveLayout widths & padding', () {
    test('maxContentWidth: phone unbounded tablet bounded', () {
      expect(
        const ResponsiveLayout(380).maxContentWidth,
        double.infinity,
      );
      expect(
        const ResponsiveLayout(800).maxContentWidth,
        760,
      );
      expect(
        const ResponsiveLayout(1200).maxContentWidth,
        980,
      );
    });

    test('horizontalPagePadding: phone stays 0 (no unintended phone inset)',
        () {
      expect(const ResponsiveLayout(400).horizontalPagePadding, 0);
    });

    test('horizontalPagePadding tablet uses tokens', () {
      expect(
        const ResponsiveLayout(800).horizontalPagePadding,
        AppDesignTokens.spacing16,
      );
      expect(
        const ResponsiveLayout(1200).horizontalPagePadding,
        AppDesignTokens.spacing24,
      );
    });

    test('clampedReadableWidth respects viewport minus gutters', () {
      const r = ResponsiveLayout(800);
      expect(r.clampedReadableWidth(800), closeTo(760, 1e-6));
      const narrow = ResponsiveLayout(800);
      expect(narrow.clampedReadableWidth(700), closeTo(700 - 32, 1e-6));
    });

    test('shouldUseTwoPaneLayout only on wide layouts', () {
      expect(const ResponsiveLayout(380).shouldUseTwoPaneLayout, isFalse);
      expect(const ResponsiveLayout(700).shouldUseTwoPaneLayout, isFalse);
      expect(const ResponsiveLayout(900).shouldUseTwoPaneLayout, isTrue);
    });
  });
}
