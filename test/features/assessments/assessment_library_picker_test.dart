import 'package:arm_field_companion/features/assessments/assessment_library.dart';
import 'package:arm_field_companion/features/assessments/assessment_library_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders search bar and category chips', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AssessmentLibraryPicker(),
      ),
    );
    expect(find.byKey(const ValueKey('assessment-library-search')), findsOneWidget);
    expect(find.byKey(const ValueKey('assessment-library-cat-all')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('assessment-library-cat-Fungicide Efficacy')),
      findsOneWidget,
    );
  });

  testWidgets('filtering by category hides other categories', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AssessmentLibraryPicker(),
      ),
    );
    expect(find.text('% weed control'), findsWidgets);
    await tester.tap(
      find.byKey(const ValueKey('assessment-library-cat-Fungicide Efficacy')),
    );
    await tester.pumpAndSettle();
    expect(find.text('% weed control'), findsNothing);
    expect(find.text('% disease severity'), findsWidgets);
  });

  testWidgets('search narrows the list', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AssessmentLibraryPicker(),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('assessment-library-search')),
      'Fusarium',
    );
    await tester.pumpAndSettle();
    expect(find.text('% head blight'), findsWidgets);
    expect(find.text('% weed control'), findsNothing);
  });

  testWidgets('multi-select and Done returns selected entries', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    List<LibraryAssessment>? popped;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        home: Scaffold(
          body: TextButton(
            onPressed: () async {
              popped = await AssessmentLibraryPicker.open(
                navKey.currentContext!,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('assessment-library-row-herb_weed_control')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('assessment-library-row-herb_weed_cover')),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('assessment-library-done')));
    await tester.pumpAndSettle();

    expect(popped, isNotNull);
    expect(popped!.length, 2);
    final ids = popped!.map((e) => e.id).toSet();
    expect(ids.contains('herb_weed_control'), true);
    expect(ids.contains('herb_weed_cover'), true);
  });
}
