import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/features/photos/photo_repository.dart';

void main() {
  group('PhotoRepository.resolvePhotoPath', () {
    // Inject a fake docs directory so tests don't hit path_provider.
    final fakeDocsDir = Directory('/fake/docs');

    test('legacy absolute path — extracts filename and rejoins with current docs dir',
        () async {
      const legacy =
          '/var/mobile/Containers/Data/Application/SOME-UUID/Documents/photos/photo_abc123.jpg';

      final result = await PhotoRepository.resolvePhotoPath(
        legacy,
        docsDir: fakeDocsDir,
      );

      expect(result, equals('/fake/docs/photos/photo_abc123.jpg'));
    });

    test('filename-only — joins directly with docs/photos dir', () async {
      const filename = 'photo_abc123.jpg';

      final result = await PhotoRepository.resolvePhotoPath(
        filename,
        docsDir: fakeDocsDir,
      );

      expect(result, equals('/fake/docs/photos/photo_abc123.jpg'));
    });

    test('photos/ prefixed path — strips prefix via basename and rejoins correctly',
        () async {
      const prefixed = 'photos/photo_abc123.jpg';

      final result = await PhotoRepository.resolvePhotoPath(
        prefixed,
        docsDir: fakeDocsDir,
      );

      // basename strips 'photos/' prefix; result is rejoined under docs/photos.
      expect(result, equals('/fake/docs/photos/photo_abc123.jpg'));
    });

    test('legacy absolute path with UUID variant — still resolves to same filename',
        () async {
      const legacyA =
          '/var/mobile/Containers/Data/Application/AAA-111/Documents/photos/trial_001_P101_S2.jpg';
      const legacyB =
          '/var/mobile/Containers/Data/Application/BBB-222/Documents/photos/trial_001_P101_S2.jpg';

      final resultA = await PhotoRepository.resolvePhotoPath(
        legacyA,
        docsDir: fakeDocsDir,
      );
      final resultB = await PhotoRepository.resolvePhotoPath(
        legacyB,
        docsDir: fakeDocsDir,
      );

      // Different UUIDs in stored path both resolve to the same output.
      expect(resultA, equals(resultB));
      expect(resultA, equals('/fake/docs/photos/trial_001_P101_S2.jpg'));
    });
  });
}
