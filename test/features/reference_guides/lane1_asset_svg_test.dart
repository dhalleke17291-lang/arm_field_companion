import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const lane1AssetPaths = [
    'assets/reference_guides/lane1/wheat_disease_severity.svg',
    'assets/reference_guides/lane1/canola_disease_severity.svg',
    'assets/reference_guides/lane1/weed_cover_percent.svg',
    'assets/reference_guides/lane1/crop_injury_categorical.svg',
    'assets/reference_guides/lane1/stand_coverage_percent.svg',
  ];

  for (final path in lane1AssetPaths) {
    testWidgets('SvgPicture.asset loads $path', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 340,
                height: 160,
                child: SvgPicture.asset(path, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SvgPicture), findsOneWidget);
    });
  }
}
