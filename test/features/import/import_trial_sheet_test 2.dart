import 'package:arm_field_companion/features/import/ui/import_trial_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'ImportTrialSheet shows exactly two import options — '
    'Rating Shell and Link Rating Sheet (no "Import from CSV")',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (parentContext) => Scaffold(
                body: ImportTrialSheet(parentContext: parentContext),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Import Rating Shell'), findsOneWidget);
      expect(find.text('Link Rating Sheet'), findsOneWidget);
      expect(find.text('Import from CSV'), findsNothing);
    },
  );
}
