import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ArmFieldCompanionApp(),
      ),
    );

    // Advance past splash delay (2.5s) + a bit extra.
    await tester.pump(const Duration(milliseconds: 3000));

    // Pump a few frames to let navigation/build complete without waiting forever.
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
