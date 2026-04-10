import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/trials/standalone/trial_creation_wizard.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TrialCreationWizard shows identity step', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: TrialCreationWizard(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New Standalone Trial'), findsOneWidget);
    expect(find.text('Study design'), findsOneWidget);
    expect(find.text('RCBD'), findsOneWidget);
  });
}
