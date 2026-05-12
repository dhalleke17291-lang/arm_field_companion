import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/photo_thumbnail.dart';

class RatingPhotoStrip extends ConsumerWidget {
  const RatingPhotoStrip({
    super.key,
    required this.trialId,
    required this.plotPk,
    required this.sessionId,
    required this.onCapture,
    required this.onPhotoTap,
  });

  final int trialId;
  final int plotPk;
  final int sessionId;
  final VoidCallback onCapture;
  final void Function(Photo) onPhotoTap;

  static const double _tileSize = 72.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final photosAsync = ref.watch(
      photosForPlotProvider(
        PhotosForPlotParams(
          trialId: trialId,
          plotPk: plotPk,
          sessionId: sessionId,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text(
              'PHOTOS — tap camera to add',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                letterSpacing: 0.3,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE8E5E0)),
          const SizedBox(height: 8),
          photosAsync.when(
            loading: () => SizedBox(
              height: _tileSize + 24,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [_buildCameraTile(context)],
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Photo load error: $e',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.error),
              ),
            ),
            data: (photos) => SizedBox(
              height: _tileSize + 24,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCameraTile(context),
                    for (var i = 0; i < photos.length; i++) ...[
                      const SizedBox(width: 8),
                      _buildPhotoTile(context, photos[i], i + 1, photos.length),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraTile(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onCapture,
        child: Container(
          width: _tileSize,
          height: _tileSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined,
                  size: 28, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(
                'Add photo',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoTile(
    BuildContext context,
    Photo photo,
    int index,
    int totalCount,
  ) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('HH:mm').format(photo.createdAt);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onPhotoTap(photo),
        child: Container(
          width: _tileSize,
          height: _tileSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppDesignTokens.borderCrisp),
            color: theme.colorScheme.surfaceContainerLow,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PhotoThumbnail(
                filePath: photo.filePath,
                width: _tileSize,
                height: _tileSize,
                borderRadius: 7,
              ),
              Positioned(
                left: 4,
                top: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.scrim.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$index/$totalCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.scrim.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    timeStr,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (photo.ratingValue != null)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.primary.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${photo.ratingValue!.round()}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
