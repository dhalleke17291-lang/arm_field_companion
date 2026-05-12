import 'dart:io';

import 'package:flutter/material.dart';
import '../design/app_design_tokens.dart';
import '../../features/photos/photo_repository.dart'
    show PhotoRepository, thumbnailPathFor;

/// Async-safe photo thumbnail that avoids synchronous file I/O on the
/// main thread. Prefers on-disk thumbnail when available, falls back to
/// original with cacheWidth sizing.
class PhotoThumbnail extends StatefulWidget {
  const PhotoThumbnail({
    super.key,
    required this.filePath,
    this.width = 80,
    this.height = 80,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  final String filePath;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final Widget? placeholder;

  @override
  State<PhotoThumbnail> createState() => _PhotoThumbnailState();
}

enum _ThumbState { checking, thumbnail, original, missing }

class _PhotoThumbnailState extends State<PhotoThumbnail> {
  _ThumbState _state = _ThumbState.checking;
  String? _resolvedPath;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(PhotoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _state = _ThumbState.checking;
      _resolvedPath = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final absolutePath =
        await PhotoRepository.resolvePhotoPath(widget.filePath);
    final thumbPath = thumbnailPathFor(absolutePath);
    final thumbExists = await File(thumbPath).exists();
    if (!mounted) return;
    if (thumbExists) {
      setState(() {
        _state = _ThumbState.thumbnail;
        _resolvedPath = thumbPath;
      });
      return;
    }
    final origExists = await File(absolutePath).exists();
    if (!mounted) return;
    setState(() {
      _state = origExists ? _ThumbState.original : _ThumbState.missing;
      _resolvedPath = origExists ? absolutePath : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);

    if (_state == _ThumbState.checking) {
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Container(color: AppDesignTokens.emptyBadgeBg),
        ),
      );
    }

    if (_state == _ThumbState.missing || _resolvedPath == null) {
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: widget.placeholder ??
              Container(
                color: AppDesignTokens.emptyBadgeBg,
                child: const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppDesignTokens.secondaryText,
                    size: 24,
                  ),
                ),
              ),
        ),
      );
    }

    // Thumbnail files are already small — no cacheWidth needed.
    // Original files: use cacheWidth to limit decode size.
    final useCacheSize = _state == _ThumbState.original;
    final cacheW = useCacheSize ? (widget.width * 2).toInt() : null;
    final cacheH = useCacheSize ? (widget.height * 2).toInt() : null;

    return ClipRRect(
      borderRadius: radius,
      child: Image.file(
        File(_resolvedPath!),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
      ),
    );
  }
}
