import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../../core/database/app_database.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<Photo> photos;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _fileName(String path) => path.split('/').isNotEmpty ? path.split('/').last : path;

  void _showPathDialog(Photo p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Photo file'),
        content: SelectableText(p.filePath),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EB),
      appBar: const GradientScreenHeader(title: 'Photos'),
      body: PageView.builder(
        controller: _controller,
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final p = photos[index];
          final file = File(p.filePath);

          return Column(
            children: [
              Expanded(
                child: Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: file.existsSync()
                        ? Image.file(file, fit: BoxFit.contain)
                        : Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'File missing:\n${p.filePath}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${index + 1}/${photos.length}  •  ${_fileName(p.filePath)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => _showPathDialog(p),
                      tooltip: 'Show file path',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
