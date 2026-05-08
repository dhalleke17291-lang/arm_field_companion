import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/features/trials/tabs/applications_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Trial _trial() => Trial(
      id: 1,
      name: 'App Tab Smoke Trial',
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      region: 'eppo_eu',
      isDeleted: false,
    );

Widget _wrap(double width, double height) => MediaQuery(
      data: MediaQueryData(size: Size(width, height)),
      child: ProviderScope(
        overrides: [
          trialApplicationsForTrialProvider(1).overrideWith(
            (ref) => Stream.value(const <TrialApplicationEvent>[]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: ApplicationsTab(trial: _trial())),
        ),
      ),
    );

void main() {
  group('ApplicationsTab responsive smoke', () {
    testWidgets('phone (390×844): no layout exceptions', (tester) async {
      await tester.pumpWidget(_wrap(390, 844));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tablet (834×1194): no layout exceptions', (tester) async {
      await tester.pumpWidget(_wrap(834, 1194));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('large tablet (1024×1366): no layout exceptions', (tester) async {
      await tester.pumpWidget(_wrap(1024, 1366));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });
}
