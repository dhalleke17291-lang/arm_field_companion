import 'package:arm_field_companion/features/assessments/assessment_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expectedCategories = [
    'Herbicide Efficacy',
    'Fungicide Efficacy',
    'Insecticide Efficacy',
    'Crop Safety',
    'Crop Growth',
    'Yield & Harvest',
    'Growth Regulator',
    'Seed & Establishment',
  ];

  test('library has 73 entries, unique ids, valid fields', () {
    expect(AssessmentLibrary.entries.length, 73);
    final ids = AssessmentLibrary.entries.map((e) => e.id).toSet();
    expect(ids.length, 73);
    for (final e in AssessmentLibrary.entries) {
      expect(e.name.trim().isNotEmpty, true);
      expect(e.category.trim().isNotEmpty, true);
      expect(e.unit.trim().isNotEmpty, true);
      expect(e.description.trim().isNotEmpty, true);
      expect(e.scaleMin < e.scaleMax, true);
    }
  });

  test('categories match expected eight in display order', () {
    expect(AssessmentLibrary.categories, expectedCategories);
    for (final e in AssessmentLibrary.entries) {
      expect(expectedCategories.contains(e.category), true);
    }
  });

  test('byCategory counts for herbicide and fungicide', () {
    expect(
      AssessmentLibrary.byCategory('Fungicide Efficacy').length,
      10,
    );
    expect(
      AssessmentLibrary.byCategory('Herbicide Efficacy').length,
      8,
    );
  });

  test('search is case-insensitive and filters by name or description', () {
    final weed = AssessmentLibrary.search('weed');
    expect(weed.every((e) {
      final n = e.name.toLowerCase();
      final d = e.description.toLowerCase();
      return n.contains('weed') || d.contains('weed');
    }), true);

    final upper = AssessmentLibrary.search('WEED');
    expect(upper.length, weed.length);

    expect(AssessmentLibrary.search('xyznonexistent'), isEmpty);
  });

  test('curatedLibraryInstructionTag round-trip', () {
    expect(
      curatedLibraryInstructionTag('herb_weed_control'),
      'librarySourceId:herb_weed_control',
    );
    final from = curatedLibraryIdsFromInstructionOverrides([
      'librarySourceId:a',
      null,
      'other',
      'librarySourceId:b',
    ]);
    expect(from, {'a', 'b'});
  });
}
