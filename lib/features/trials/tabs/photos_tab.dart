import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/widgets/photo_thumbnail.dart';
import '../../../core/plot_display.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../photos/photo_viewer_screen.dart';
import 'photo_before_after.dart';
import 'photo_coverage_map.dart';
import 'photo_treatment_comparison.dart';

enum _PhotoViewMode { timeline, treatment, application, coverage }

void _pushPhotosFullScreen(BuildContext context, Trial trial) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Photos')),
        body: SafeArea(top: false, child: PhotosTab(trial: trial)),
      ),
    ),
  );
}

/// Photos tab for trial detail: session view (default) + plot timeline view.
class PhotosTab extends ConsumerStatefulWidget {
  const PhotosTab({super.key, required this.trial});

  final Trial trial;

  @override
  ConsumerState<PhotosTab> createState() => _PhotosTabState();
}

class _PhotosTabState extends ConsumerState<PhotosTab> {
  _PhotoViewMode _viewMode = _PhotoViewMode.timeline;
  int? _selectedPlotPk;

  @override
  Widget build(BuildContext context) {
    final photosAsync = ref.watch(photosForTrialProvider(widget.trial.id));
    final sessionsAsync = ref.watch(sessionsForTrialProvider(widget.trial.id));
    final plotsAsync = ref.watch(plotsForTrialProvider(widget.trial.id));

    return Column(
      children: [
        // View mode toggle
        _buildViewModeChips(),
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
              if (photos.isEmpty && _viewMode != _PhotoViewMode.coverage) {
                return _buildEmptyState(context);
              }

              switch (_viewMode) {
                case _PhotoViewMode.timeline:
                  return _buildTimelineView(photos, sessionsAsync, plotsAsync);
                case _PhotoViewMode.treatment:
                  return PhotoTreatmentComparison(trial: widget.trial);
                case _PhotoViewMode.application:
                  return PhotoBeforeAfter(trial: widget.trial);
                case _PhotoViewMode.coverage:
                  return PhotoCoverageMap(trial: widget.trial);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildViewModeChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppDesignTokens.borderCrisp)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ViewChip(
              label: 'Timeline',
              selected: _viewMode == _PhotoViewMode.timeline,
              onTap: () => setState(() => _viewMode = _PhotoViewMode.timeline),
            ),
            const SizedBox(width: 6),
            _ViewChip(
              label: 'Treatment',
              selected: _viewMode == _PhotoViewMode.treatment,
              onTap: () => setState(() => _viewMode = _PhotoViewMode.treatment),
            ),
            const SizedBox(width: 6),
            _ViewChip(
              label: 'Application',
              selected: _viewMode == _PhotoViewMode.application,
              onTap: () =>
                  setState(() => _viewMode = _PhotoViewMode.application),
            ),
            const SizedBox(width: 6),
            _ViewChip(
              label: 'Coverage',
              selected: _viewMode == _PhotoViewMode.coverage,
              onTap: () => setState(() => _viewMode = _PhotoViewMode.coverage),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineView(
    List<Photo> photos,
    AsyncValue<List<Session>> sessionsAsync,
    AsyncValue<List<Plot>> plotsAsync,
  ) {
    final sessions = sessionsAsync.valueOrNull ?? <Session>[];
    final plots = plotsAsync.valueOrNull ?? <Plot>[];

    final plotPksWithPhotos = <int>{};
    for (final p in photos) {
      plotPksWithPhotos.add(p.plotPk);
    }
    final plotsWithPhotos = plots
        .where((p) => plotPksWithPhotos.contains(p.id))
        .toList()
      ..sort((a, b) => a.plotId.compareTo(b.plotId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (plotsWithPhotos.length > 1)
          _buildPlotChips(plotsWithPhotos, plots),
        Expanded(
          child: _selectedPlotPk != null
              ? _PlotPhotoTimeline(
                  trial: widget.trial,
                  plotPk: _selectedPlotPk!,
                  sessions: sessions,
                  plots: plots,
                )
              : _buildSessionView(context, photos, sessions, plots),
        ),
      ],
    );
  }

  Widget _buildPlotChips(List<Plot> plotsWithPhotos, List<Plot> allPlots) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ViewChip(
              label: 'All sessions',
              selected: _selectedPlotPk == null,
              onTap: () => setState(() => _selectedPlotPk = null),
            ),
            const SizedBox(width: 6),
            for (final plot in plotsWithPhotos) ...[
              _ViewChip(
                label: getDisplayPlotLabel(plot, allPlots),
                selected: _selectedPlotPk == plot.id,
                onTap: () => setState(() => _selectedPlotPk = plot.id),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppDesignTokens.primaryText,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              const Icon(Icons.photo_library_outlined,
                  size: 18, color: AppDesignTokens.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Photos', style: titleStyle,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                tooltip: 'Full screen',
                icon: const Icon(Icons.fullscreen),
                onPressed: () =>
                    _pushPhotosFullScreen(context, widget.trial),
                style:
                    IconButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
        ),
        const Expanded(
          child: AppEmptyState(
            icon: Icons.photo_library_outlined,
            title: 'No photos yet',
            subtitle:
                'Photos taken during sessions will appear here, grouped by session.',
          ),
        ),
      ],
    );
  }

  Widget _buildSessionView(BuildContext context, List<Photo> photos,
      List<Session> sessions, List<Plot> plots) {
    final sessionById = {for (var s in sessions) s.id: s};
    final bySession = <int, List<Photo>>{};
    for (final p in photos) {
      bySession.putIfAbsent(p.sessionId, () => []).add(p);
    }
    final sessionIds = bySession.keys.toList()..sort();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppDesignTokens.spacing8),
                          child: Text(title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppDesignTokens.primaryText,
                              )),
                        ),
                        if (subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppDesignTokens.spacing8),
                            child: Text(subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppDesignTokens.secondaryText,
                                )),
                          ),
                      ],
                    ),
                  ),
                  if (i == 0)
                    IconButton(
                      tooltip: 'Full screen',
                      icon: const Icon(Icons.fullscreen),
                      onPressed: () =>
                          _pushPhotosFullScreen(context, widget.trial),
                      style: IconButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                    ),
                ],
              ),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: sessionPhotos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, j) =>
                      _PhotoTile(
                        photo: sessionPhotos[j],
                        allPhotos: sessionPhotos,
                        index: j,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Plot photo timeline — vertical chronological view for one plot
// ---------------------------------------------------------------------------

class _PlotPhotoTimeline extends ConsumerWidget {
  const _PlotPhotoTimeline({
    required this.trial,
    required this.plotPk,
    required this.sessions,
    required this.plots,
  });

  final Trial trial;
  final int plotPk;
  final List<Session> sessions;
  final List<Plot> plots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(
      photosForPlotAllSessionsProvider(
          (trialId: trial.id, plotPk: plotPk)),
    );
    final sessionById = {for (final s in sessions) s.id: s};
    final plot = plots.where((p) => p.id == plotPk).firstOrNull;
    final plotLabel =
        plot != null ? getDisplayPlotLabel(plot, plots) : 'Plot';

    return photosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (photos) {
        if (photos.isEmpty) {
          return Center(
            child: Text('No photos for $plotLabel',
                style: const TextStyle(color: AppDesignTokens.secondaryText)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: photos.length,
          itemBuilder: (context, i) {
            final photo = photos[i];
            final session = sessionById[photo.sessionId];
            final timing = session != null
                ? ref
                    .watch(sessionTimingContextProvider(session.id))
                    .valueOrNull
                : null;

            final dateLine = session?.sessionDateLocal ?? '';
            final timingLine =
                timing != null && !timing.isEmpty ? timing.displayLine : null;
            final valueStr = photo.ratingValue != null
                ? '${photo.ratingValue!.round()}%'
                : null;
            final timeStr =
                DateFormat('HH:mm').format(photo.createdAt);

            final isLast = i == photos.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vertical rail
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppDesignTokens.primary,
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: AppDesignTokens.borderCrisp,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Content card
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _TimelinePhotoCard(
                        photo: photo,
                        allPhotos: photos,
                        index: i,
                        dateLine: dateLine,
                        timingLine: timingLine,
                        valueStr: valueStr,
                        timeStr: timeStr,
                        sessionName: session?.name,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TimelinePhotoCard extends StatelessWidget {
  const _TimelinePhotoCard({
    required this.photo,
    required this.allPhotos,
    required this.index,
    required this.dateLine,
    this.timingLine,
    this.valueStr,
    required this.timeStr,
    this.sessionName,
  });

  final Photo photo;
  final List<Photo> allPhotos;
  final int index;
  final String dateLine;
  final String? timingLine;
  final String? valueStr;
  final String timeStr;
  final String? sessionName;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              PhotoViewerScreen(photos: allPhotos, initialIndex: index),
        ),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppDesignTokens.borderCrisp),
          color: Colors.white,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo thumbnail
            PhotoThumbnail(
              filePath: photo.filePath,
              width: 88,
              height: 88,
              borderRadius: 9,
            ),
            // Metadata
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Session name + date
                    if (sessionName != null)
                      Text(
                        sessionName!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppDesignTokens.primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      '$dateLine · $timeStr',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                    // DAT / BBCH
                    if (timingLine != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        timingLine!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppDesignTokens.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    // Rating value
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
                          'Rated $valueStr',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppDesignTokens.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.allPhotos,
    required this.index,
  });

  final Photo photo;
  final List<Photo> allPhotos;
  final int index;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PhotoViewerScreen(
              photos: allPhotos, initialIndex: index),
        ),
      ),
      child: SizedBox(
        width: 88,
        height: 88,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PhotoThumbnail(
              filePath: photo.filePath,
              width: 88,
              height: 88,
              borderRadius: 10,
            ),
            if (photo.ratingValue != null)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        AppDesignTokens.primary.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${photo.ratingValue!.round()}%',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewChip extends StatelessWidget {
  const _ViewChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppDesignTokens.primary
              : AppDesignTokens.backgroundSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppDesignTokens.primary
                : AppDesignTokens.borderCrisp,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppDesignTokens.primaryText,
          ),
        ),
      ),
    );
  }
}
