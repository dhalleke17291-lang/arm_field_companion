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
    // Splash uses Future.delayed(2200ms) then navigates; must let timer complete
    // so no pending timer when test ends.
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(); // process navigation
    await tester.pump(const Duration(milliseconds: 100)); // transition
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}