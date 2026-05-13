import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/features/ratings/widgets/rating_photo_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const params = PhotosForPlotParams(trialId: 1, plotPk: 10, sessionId: 20);

  Photo photo({String? caption}) {
    return Photo(
      id: 1,
      trialId: params.trialId,
      plotPk: params.plotPk,
      sessionId: params.sessionId,
      filePath: 'missing.jpg',
      tempPath: null,
      status: 'final',
      caption: caption,
      createdAt: DateTime(2026, 5, 11, 10, 30),
      assessmentId: 5,
      ratingValue: 22,
      isDeleted: false,
      deletedAt: null,
      deletedBy: null,
    );
  }

  Future<void> pumpStrip(
    WidgetTester tester, {
    required List<Photo> photos,
    void Function(Photo)? onCaptionTap,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photosForPlotProvider(params).overrideWith(
            (_) => Stream.value(photos),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RatingPhotoStrip(
              trialId: params.trialId,
              plotPk: params.plotPk,
              sessionId: params.sessionId,
              onCapture: () {},
              onPhotoTap: (_) {},
              onCaptionTap: onCaptionTap ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('RatingPhotoStrip captions', () {
    testWidgets('RPS-1: renders caption tile below photo thumbnail',
        (tester) async {
      await pumpStrip(
        tester,
        photos: [photo(caption: 'Shows uneven disease pressure.')],
      );

      expect(find.text('Add photo'), findsOneWidget);
      expect(find.text('Shows uneven disease pressure.'), findsOneWidget);
      expect(find.textContaining('10:30'), findsOneWidget);
    });

    testWidgets('RPS-2: tapping caption tile calls caption callback',
        (tester) async {
      Photo? tapped;
      await pumpStrip(
        tester,
        photos: [photo()],
        onCaptionTap: (photo) => tapped = photo,
      );

      await tester.tap(
        find.text('Add caption — why this photo matters (optional)'),
      );

      expect(tapped?.id, 1);
    });
  });
}
