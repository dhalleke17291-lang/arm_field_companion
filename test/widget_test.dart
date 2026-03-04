import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const ArmFieldCompanionApp());
    expect(find.text('ARM Field Companion'), findsOneWidget);
  });
}
