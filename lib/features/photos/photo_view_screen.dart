import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import 'photo_repository.dart';

/// Full-screen single photo viewer with filename bar and long-press delete.
class PhotoViewScreen extends StatefulWidget {
  final Photo photo;
  final VoidCallback? onDelete;

  const PhotoViewScreen({
    super.key,
    required this.photo,
    this.onDelete,
  });

  @override
  State<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<PhotoViewScreen> {
  File? _file;
  bool _exists = false;

  static String _fileName(String filePath) {
    final parts = filePath.split('/');
    return parts.isNotEmpty ? parts.last : filePath;
  }

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final absolutePath =
        await PhotoRepository.resolvePhotoPath(widget.photo.filePath);
    final file = File(absolutePath);
    final exists = await file.exists();
    if (!mounted) return;
    setState(() {
      _file = file;
      _exists = exists;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = _file;
    final exists = _exists;
    final fileName = _fileName(widget.photo.filePath);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: theme.colorScheme.onSurface,
          size: 24,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          iconSize: 24,
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Text(
          fileName,
          style: AppDesignTokens.headerTitleStyle(
            fontSize: 17,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.3,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: exists && file != null
                ? GestureDetector(
                    onLongPress: () => _confirmDelete(context),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Image.file(
                        file,
                        fit: BoxFit.contain,
                        semanticLabel: 'Plot photo',
                        cacheWidth: 1200,
                      ),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        file == null ? '' : 'File not found',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.92,
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          fileName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.onDelete != null)
                        TextButton.icon(
                          onPressed: () => _confirmDelete(context),
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: theme.colorScheme.error,
                          ),
                          label: Text(
                            'Delete',
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text(
          'This photo will be removed from the record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted && widget.onDelete != null) {
      widget.onDelete!();
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }
}
