import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../photos/photo_viewer_screen.dart';

/// Photos tab for trial detail: photos grouped by session.
class PhotosTab extends ConsumerWidget {
  const PhotosTab({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(photosForTrialProvider(trial.id));
    final sessionsAsync = ref.watch(sessionsForTrialProvider(trial.id));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Photos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Open in full screen',
                icon: const Icon(Icons.fullscreen),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Photos')),
                        body: PhotosTab(trial: trial),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: photosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load photos: $e',
                    textAlign: TextAlign.center),
              ),
            ),
            data: (photos) {
              if (photos.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.photo_library_outlined,
                  title: 'No photos yet',
                  subtitle:
                      'Photos taken during sessions will appear here, grouped by session.',
                );
              }
              final sessions = sessionsAsync.valueOrNull ?? <Session>[];
              final sessionById = {for (var s in sessions) s.id: s};
              final bySession = <int, List<Photo>>{};
              for (final p in photos) {
                bySession.putIfAbsent(p.sessionId, () => []).add(p);
              }
              final sessionIds = bySession.keys.toList()..sort();
              return ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: sessionIds.length,
                itemBuilder: (context, i) {
                  final sessionId = sessionIds[i];
                  final sessionPhotos = bySession[sessionId]!;
                  final session = sessionById[sessionId];
                  final title = session?.name ?? 'Session $sessionId';
                  final subtitle = session?.sessionDateLocal ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppDesignTokens.spacing8),
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppDesignTokens.primaryText,
                            ),
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppDesignTokens.spacing8),
                            child: Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppDesignTokens.secondaryText,
                              ),
                            ),
                          ),
                        SizedBox(
                          height: 100,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: sessionPhotos.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, j) {
                              final p = sessionPhotos[j];
                              final file = File(p.filePath);
                              return InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => PhotoViewerScreen(
                                        photos: sessionPhotos,
                                        initialIndex: j,
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 88,
                                    height: 88,
                                    color: AppDesignTokens.borderCrisp,
                                    child: file.existsSync()
                                        ? Image.file(file, fit: BoxFit.cover, semanticLabel: 'Photo thumbnail', cacheWidth: 176, cacheHeight: 176)
                                        : const Center(
                                            child: Icon(Icons.broken_image,
                                                color: AppDesignTokens
                                                    .secondaryText),
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
