import 'package:arm_field_companion/shared/layout/responsive_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResponsiveLayout breakpoints', () {
    test('width 390 is compact', () {
      const rl = ResponsiveLayout(390);
      expect(rl.isCompact, isTrue);
      expect(rl.isMedium, isFalse);
      expect(rl.isExpanded, isFalse);
    });

    test('width 600 is medium', () {
      const rl = ResponsiveLayout(600);
      expect(rl.isCompact, isFalse);
      expect(rl.isMedium, isTrue);
      expect(rl.isExpanded, isFalse);
    });

    test('width 834 is medium', () {
      expect(const ResponsiveLayout(834).isMedium, isTrue);
    });

    test('width 1024 is expanded', () {
      const rl = ResponsiveLayout(1024);
      expect(rl.isCompact, isFalse);
      expect(rl.isMedium, isFalse);
      expect(rl.isExpanded, isTrue);
    });

    test('compact maxContentWidth is infinite', () {
      expect(const ResponsiveLayout(390).maxContentWidth, equals(double.infinity));
    });

    test('medium maxContentWidth is 760', () {
      expect(const ResponsiveLayout(834).maxContentWidth, equals(760));
    });

    test('expanded maxContentWidth is 980', () {
      expect(const ResponsiveLayout(1024).maxContentWidth, equals(980));
    });

    test('compact modalSheetMaxWidth is infinite', () {
      expect(const ResponsiveLayout(390).modalSheetMaxWidth, equals(double.infinity));
    });

    test('medium modalSheetMaxWidth is 560', () {
      expect(const ResponsiveLayout(834).modalSheetMaxWidth, equals(560));
    });

    test('expanded modalSheetMaxWidth is 640', () {
      expect(const ResponsiveLayout(1024).modalSheetMaxWidth, equals(640));
    });

    test('compact horizontalPagePadding is 0', () {
      expect(const ResponsiveLayout(390).horizontalPagePadding, equals(0));
    });

    test('medium horizontalPagePadding is 16', () {
      expect(const ResponsiveLayout(834).horizontalPagePadding, equals(16));
    });

    test('expanded horizontalPagePadding is 24', () {
      expect(const ResponsiveLayout(1024).horizontalPagePadding, equals(24));
    });

    test('compact shouldUseTwoPaneLayout is false', () {
      expect(const ResponsiveLayout(390).shouldUseTwoPaneLayout, isFalse);
    });

    test('width 840 shouldUseTwoPaneLayout is true', () {
      expect(const ResponsiveLayout(840).shouldUseTwoPaneLayout, isTrue);
    });
  });
}
