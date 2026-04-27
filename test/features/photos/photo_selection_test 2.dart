import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/trials/tabs/photo_treatment_comparison.dart';
import 'package:flutter_test/flutter_test.dart';

Photo _fakePhoto({
  required int id,
  required int plotPk,
  required int sessionId,
  double? ratingValue,
  DateTime? createdAt,
}) {
  return Photo(
    id: id,
    trialId: 1,
    plotPk: plotPk,
    sessionId: sessionId,
    filePath: '/fake/$id.jpg',
    tempPath: null,
    status: 'final',
    caption: null,
    assessmentId: null,
    ratingValue: ratingValue,
    createdAt: createdAt ?? DateTime(2026, 4, 15, 10, id),
    isDeleted: false,
    deletedAt: null,
    deletedBy: null,
  );
}

void main() {
  group('selectRepresentativePhoto', () {
    test('empty list returns no photo basis', () {
      final result = selectRepresentativePhoto([], 'CHK');
      expect(result.photo, isNull);
      expect(result.basis, contains('No photo'));
      expect(result.range, isNull);
    });

    test('single photo returns it with count basis', () {
      final photo = _fakePhoto(id: 1, plotPk: 101, sessionId: 1, ratingValue: 45);
      final result = selectRepresentativePhoto([photo], 'TRT2');
      expect(result.photo, photo);
      expect(result.basis, contains('1 photo'));
      expect(result.basis, contains('TRT2'));
      expect(result.basis, contains('rating-anchored'));
    });

    test('single photo without value — no anchored note', () {
      final photo = _fakePhoto(id: 1, plotPk: 101, sessionId: 1);
      final result = selectRepresentativePhoto([photo], 'TRT2');
      expect(result.photo, photo);
      expect(result.basis, isNot(contains('rating-anchored')));
    });

    test('prefers anchored photo at median plot', () {
      final photos = [
        _fakePhoto(id: 1, plotPk: 101, sessionId: 1, ratingValue: 30),
        _fakePhoto(id: 2, plotPk: 102, sessionId: 1, ratingValue: 50),
        _fakePhoto(id: 3, plotPk: 103, sessionId: 1, ratingValue: 70),
      ];
      final result = selectRepresentativePhoto(photos, 'TRT2');
      expect(result.photo!.plotPk, 102);
      expect(result.basis, contains('median value'));
      expect(result.basis, contains('rating-anchored'));
    });

    test('falls back to most recent when no anchored photos', () {
      final photos = [
        _fakePhoto(id: 1, plotPk: 101, sessionId: 1,
            createdAt: DateTime(2026, 4, 15, 10, 0)),
        _fakePhoto(id: 2, plotPk: 102, sessionId: 1,
            createdAt: DateTime(2026, 4, 15, 11, 0)),
      ];
      final result = selectRepresentativePhoto(photos, 'TRT2');
      expect(result.photo!.id, 2);
      expect(result.basis, contains('most recent'));
    });

    test('range computed from anchored values', () {
      final photos = [
        _fakePhoto(id: 1, plotPk: 101, sessionId: 1, ratingValue: 30),
        _fakePhoto(id: 2, plotPk: 102, sessionId: 1, ratingValue: 50),
        _fakePhoto(id: 3, plotPk: 103, sessionId: 1, ratingValue: 70),
      ];
      final result = selectRepresentativePhoto(photos, 'TRT2');
      expect(result.range, isNotNull);
      expect(result.range, contains('30'));
      expect(result.range, contains('70'));
      expect(result.range, contains('3 plots'));
    });

    test('no range with single anchored photo', () {
      final photos = [
        _fakePhoto(id: 1, plotPk: 101, sessionId: 1, ratingValue: 50),
      ];
      final result = selectRepresentativePhoto(photos, 'TRT2');
      expect(result.range, isNull);
    });

    test('basis text always contains plot number or selection method', () {
      final photos = [
        _fakePhoto(id: 1, plotPk: 101, sessionId: 1, ratingValue: 40),
        _fakePhoto(id: 2, plotPk: 102, sessionId: 1, ratingValue: 60),
      ];
      final result = selectRepresentativePhoto(photos, 'TRT2');
      expect(result.basis, contains('plot'));
    });
  });
}
