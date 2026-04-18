import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/widgets/photo_thumbnail.dart';
import '../../../core/providers.dart';
import '../../photos/photo_viewer_screen.dart';

/// 5.8 — Treatment photo comparison: one representative photo per treatment
/// at a selected session/timing. Tap to expand and see all plots.
class PhotoTreatmentComparison extends ConsumerWidget {
  const PhotoTreatmentComparison({
    super.key,
    required this.trial,
    this.initialSessionId,
  });

  final Trial trial;
  final int? initialSessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(photosForTrialProvider(trial.id));
    final sessionsAsync = ref.watch(sessionsForTrialProvider(trial.id));
    final treatmentsAsync = ref.watch(treatmentsForTrialProvider(trial.id));
    final assignmentsAsync =
        ref.watch(assignmentsForTrialProvider(trial.id));

    return photosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (photos) {
        if (photos.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No photos yet. Tap the camera icon on the rating screen to link photos to your ratings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppDesignTokens.secondaryText),
              ),
            ),
          );
        }

        final sessions = sessionsAsync.valueOrNull ?? [];
        final treatments = treatmentsAsync.valueOrNull ?? [];
        final assignments = assignmentsAsync.valueOrNull ?? [];

        if (treatments.isEmpty || sessions.isEmpty) {
          return const Center(child: Text('No treatments or sessions'));
        }

        final plotToTreatment = <int, int>{};
        for (final a in assignments) {
          if (a.treatmentId != null) {
            plotToTreatment[a.plotId] = a.treatmentId!;
          }
        }

        final sessionIdsWithPhotos = <int>{};
        for (final p in photos) {
          sessionIdsWithPhotos.add(p.sessionId);
        }
        final sessionsWithPhotos = sessions
            .where((s) => sessionIdsWithPhotos.contains(s.id))
            .toList();

        if (sessionsWithPhotos.isEmpty) {
          return const Center(child: Text('No sessions with photos'));
        }

        return _ComparisonContent(
          trial: trial,
          photos: photos,
          sessions: sessionsWithPhotos,
          treatments: treatments,
          plotToTreatment: plotToTreatment,
          initialSessionId: initialSessionId,
        );
      },
    );
  }
}

class _ComparisonContent extends StatefulWidget {
  const _ComparisonContent({
    required this.trial,
    required this.photos,
    required this.sessions,
    required this.treatments,
    required this.plotToTreatment,
    this.initialSessionId,
  });

  final Trial trial;
  final List<Photo> photos;
  final List<Session> sessions;
  final List<Treatment> treatments;
  final Map<int, int> plotToTreatment;
  final int? initialSessionId;

  @override
  State<_ComparisonContent> createState() => _ComparisonContentState();
}

class _ComparisonContentState extends State<_ComparisonContent> {
  late int _selectedSessionId;

  @override
  void initState() {
    super.initState();
    _selectedSessionId = widget.initialSessionId ??
        widget.sessions.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final sessionPhotos = widget.photos
        .where((p) => p.sessionId == _selectedSessionId)
        .toList();

    final photosByTreatment = <int, List<Photo>>{};
    for (final p in sessionPhotos) {
      final tid = widget.plotToTreatment[p.plotPk];
      if (tid != null) {
        photosByTreatment.putIfAbsent(tid, () => []).add(p);
      }
    }

    final sortedTreatments = widget.treatments.toList()
      ..sort((a, b) => a.code.compareTo(b.code));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Session selector
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: DropdownButtonFormField<int>(
            initialValue: _selectedSessionId,
            decoration: const InputDecoration(
              labelText: 'Session',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            items: [
              for (final s in widget.sessions)
                DropdownMenuItem(
                  value: s.id,
                  child: Text(
                    '${s.name} · ${s.sessionDateLocal}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _selectedSessionId = v);
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: sortedTreatments.length,
            itemBuilder: (context, i) {
              final t = sortedTreatments[i];
              final tPhotos = photosByTreatment[t.id] ?? [];
              return _TreatmentPhotoCard(
                treatment: t,
                photos: tPhotos,
                allSessionPhotos: sessionPhotos,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Selects a representative photo for a treatment group.
/// Returns (photo, plotPk, selectionBasis, rangeText).
({Photo? photo, String basis, String? range}) selectRepresentativePhoto(
  List<Photo> photos,
  String treatmentCode,
) {
  if (photos.isEmpty) {
    return (photo: null, basis: 'No photo available for $treatmentCode', range: null);
  }
  if (photos.length == 1) {
    final p = photos.first;
    final anchored = p.ratingValue != null;
    return (
      photo: p,
      basis: 'Only 1 photo available for $treatmentCode${anchored ? ', rating-anchored' : ''}',
      range: null,
    );
  }

  // Compute median from all anchored values
  final anchored = photos.where((p) => p.ratingValue != null).toList();
  if (anchored.isEmpty) {
    // No anchored photos — pick most recent
    final sorted = photos.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return (
      photo: sorted.first,
      basis: '${photos.length} photos, no rating-anchored — showing most recent',
      range: null,
    );
  }

  anchored.sort((a, b) => a.ratingValue!.compareTo(b.ratingValue!));
  final medianIdx = anchored.length ~/ 2;
  final median = anchored[medianIdx];

  // Range context
  String? range;
  if (anchored.length >= 2) {
    final low = anchored.first.ratingValue!.round();
    final high = anchored.last.ratingValue!.round();
    range = 'Range across ${anchored.length} plots: $low–$high%';
  }

  // Prefer plot with rating-anchored photo closest to median
  final plotPk = median.plotPk;
  // Within that plot, prefer anchored photo
  final plotPhotos = photos.where((p) => p.plotPk == plotPk).toList();
  final plotAnchored = plotPhotos.where((p) => p.ratingValue != null).toList();
  Photo selected;
  String anchorNote;
  if (plotAnchored.isNotEmpty) {
    selected = plotAnchored.first;
    anchorNote = 'rating-anchored photo';
  } else {
    plotPhotos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    selected = plotPhotos.first;
    anchorNote = 'most recent photo (no rating-anchored photo available)';
  }

  return (
    photo: selected,
    basis: 'Showing plot ${_plotPkLabel(plotPk, photos)}, median value for $treatmentCode, $anchorNote',
    range: range,
  );
}

String _plotPkLabel(int plotPk, List<Photo> photos) {
  return '$plotPk';
}

class _TreatmentPhotoCard extends StatefulWidget {
  const _TreatmentPhotoCard({
    required this.treatment,
    required this.photos,
    required this.allSessionPhotos,
  });

  final Treatment treatment;
  final List<Photo> photos;
  final List<Photo> allSessionPhotos;

  @override
  State<_TreatmentPhotoCard> createState() => _TreatmentPhotoCardState();
}

class _TreatmentPhotoCardState extends State<_TreatmentPhotoCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final selection = selectRepresentativePhoto(
      widget.photos,
      widget.treatment.code,
    );
    final representative = selection.photo;
    final valueStr = representative?.ratingValue != null
        ? '${representative!.ratingValue!.round()}%'
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppDesignTokens.borderCrisp),
      ),
      child: InkWell(
        onTap: widget.photos.length > 1
            ? () => setState(() => _expanded = !_expanded)
            : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo or placeholder
                  _PhotoThumbnail(
                    photo: representative,
                    photos: widget.photos.isNotEmpty
                        ? widget.photos
                        : widget.allSessionPhotos,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.treatment.code} — ${widget.treatment.name}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppDesignTokens.primaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (valueStr != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppDesignTokens.primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              valueStr,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppDesignTokens.primary,
                              ),
                            ),
                          ),
                        ],
                        if (selection.range != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            selection.range!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppDesignTokens.secondaryText,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          selection.basis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppDesignTokens.secondaryText,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        if (widget.photos.length > 1) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                _expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 14,
                                color: AppDesignTokens.primary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                _expanded
                                    ? 'Collapse'
                                    : 'Tap to see all ${widget.photos.length} plots',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppDesignTokens.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              // Expanded: all plots sorted by value
              if (_expanded && widget.photos.length > 1) ...[
                const SizedBox(height: 8),
                const Divider(
                    height: 1, color: AppDesignTokens.borderCrisp),
                const SizedBox(height: 8),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.photos.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final sorted = widget.photos.toList()
                        ..sort((a, b) {
                          final va = a.ratingValue ?? double.infinity;
                          final vb = b.ratingValue ?? double.infinity;
                          return va.compareTo(vb);
                        });
                      final p = sorted[i];
                      return _ExpandedPlotTile(
                        photo: p,
                        allPhotos: sorted,
                        index: i,
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedPlotTile extends StatelessWidget {
  const _ExpandedPlotTile({
    required this.photo,
    required this.allPhotos,
    required this.index,
  });

  final Photo photo;
  final List<Photo> allPhotos;
  final int index;

  @override
  Widget build(BuildContext context) {
    final valStr = photo.ratingValue != null
        ? '${photo.ratingValue!.round()}%'
        : '—';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              PhotoViewerScreen(photos: allPhotos, initialIndex: index),
        ),
      ),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhotoThumbnail(
              filePath: photo.filePath,
              width: 72,
              height: 72,
              borderRadius: 8,
            ),
            const SizedBox(height: 2),
            Text(
              valStr,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({
    this.photo,
    required this.photos,
  });

  final Photo? photo;
  final List<Photo> photos;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: photo != null
          ? () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PhotoViewerScreen(
                    photos: photos,
                    initialIndex: photos.indexOf(photo!).clamp(0, photos.length - 1),
                  ),
                ),
              )
          : null,
      borderRadius: BorderRadius.circular(8),
      child: photo != null
          ? PhotoThumbnail(
              filePath: photo!.filePath,
              width: 80,
              height: 80,
              borderRadius: 8,
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 80,
                child: Container(
                  color: AppDesignTokens.emptyBadgeBg,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: AppDesignTokens.secondaryText,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
