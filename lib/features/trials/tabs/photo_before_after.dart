import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';
import '../../photos/photo_viewer_screen.dart';
import 'photo_treatment_comparison.dart';

/// 5.9 — Before-and-after application pairs with application selector
/// and expandable drill-down.
class PhotoBeforeAfter extends ConsumerWidget {
  const PhotoBeforeAfter({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(photosForTrialProvider(trial.id));
    final sessionsAsync = ref.watch(sessionsForTrialProvider(trial.id));
    final applicationsAsync =
        ref.watch(trialApplicationsForTrialProvider(trial.id));
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
        final applications = applicationsAsync.valueOrNull ?? [];
        final treatments = treatmentsAsync.valueOrNull ?? [];
        final assignments = assignmentsAsync.valueOrNull ?? [];

        final appliedApps = applications
            .where((a) => a.status == 'applied')
            .toList()
          ..sort((a, b) => b.applicationDate.compareTo(a.applicationDate));

        if (appliedApps.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No applied applications. Mark an application as applied to see before/after pairs.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppDesignTokens.secondaryText),
              ),
            ),
          );
        }

        final plotToTreatment = <int, int>{};
        for (final a in assignments) {
          if (a.treatmentId != null) plotToTreatment[a.plotId] = a.treatmentId!;
        }

        final sortedSessions = sessions.toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

        return _BeforeAfterContent(
          photos: photos,
          sessions: sortedSessions,
          applications: appliedApps,
          treatments: treatments,
          plotToTreatment: plotToTreatment,
        );
      },
    );
  }
}

class _BeforeAfterContent extends StatefulWidget {
  const _BeforeAfterContent({
    required this.photos,
    required this.sessions,
    required this.applications,
    required this.treatments,
    required this.plotToTreatment,
  });

  final List<Photo> photos;
  final List<Session> sessions;
  final List<TrialApplicationEvent> applications;
  final List<Treatment> treatments;
  final Map<int, int> plotToTreatment;

  @override
  State<_BeforeAfterContent> createState() => _BeforeAfterContentState();
}

class _BeforeAfterContentState extends State<_BeforeAfterContent> {
  late String _selectedAppId;

  @override
  void initState() {
    super.initState();
    _selectedAppId = widget.applications.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.applications.firstWhere((a) => a.id == _selectedAppId,
        orElse: () => widget.applications.first);
    final appDate = app.applicationDate;
    // Find pre/post sessions
    Session? preSess;
    Session? postSess;
    for (final s in widget.sessions) {
      if (s.startedAt.isBefore(appDate)) {
        preSess = s;
      } else if (postSess == null) {
        postSess = s;
      }
    }

    final prePhotos = preSess != null
        ? widget.photos.where((p) => p.sessionId == preSess!.id).toList()
        : <Photo>[];
    final postPhotos = postSess != null
        ? widget.photos.where((p) => p.sessionId == postSess!.id).toList()
        : <Photo>[];

    // Treatments with photos in either session
    final treatmentIds = <int>{};
    for (final p in [...prePhotos, ...postPhotos]) {
      final tid = widget.plotToTreatment[p.plotPk];
      if (tid != null) treatmentIds.add(tid);
    }
    final sortedTreatments = widget.treatments
        .where((t) => treatmentIds.contains(t.id))
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Application selector
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedAppId,
            decoration: const InputDecoration(
              labelText: 'Application',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            items: [
              for (final a in widget.applications)
                DropdownMenuItem(
                  value: a.id,
                  child: Text(
                    '${a.productName ?? 'Application'} · ${DateFormat('MMM d, yyyy').format(a.applicationDate)}',
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _selectedAppId = v);
            },
          ),
        ),
        // Pair cards
        Expanded(
          child: sortedTreatments.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      prePhotos.isEmpty && postPhotos.isEmpty
                          ? 'No paired photos available — requires photos from both a pre-application and post-application session.'
                          : 'No treatment-linked photos for this application.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppDesignTokens.secondaryText,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: sortedTreatments.length,
                  itemBuilder: (context, i) {
                    final t = sortedTreatments[i];
                    return _BeforeAfterPairCard(
                      treatment: t,
                      preSession: preSess,
                      postSession: postSess,
                      prePhotos: prePhotos
                          .where((p) =>
                              widget.plotToTreatment[p.plotPk] == t.id)
                          .toList(),
                      postPhotos: postPhotos
                          .where((p) =>
                              widget.plotToTreatment[p.plotPk] == t.id)
                          .toList(),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _BeforeAfterPairCard extends StatefulWidget {
  const _BeforeAfterPairCard({
    required this.treatment,
    this.preSession,
    this.postSession,
    required this.prePhotos,
    required this.postPhotos,
  });

  final Treatment treatment;
  final Session? preSession;
  final Session? postSession;
  final List<Photo> prePhotos;
  final List<Photo> postPhotos;

  @override
  State<_BeforeAfterPairCard> createState() => _BeforeAfterPairCardState();
}

class _BeforeAfterPairCardState extends State<_BeforeAfterPairCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final preSel = selectRepresentativePhoto(
        widget.prePhotos, widget.treatment.code);
    final postSel = selectRepresentativePhoto(
        widget.postPhotos, widget.treatment.code);
    final hasMultiple =
        widget.prePhotos.length > 1 || widget.postPhotos.length > 1;

    final preLabel = widget.preSession != null
        ? 'Pre · ${widget.preSession!.sessionDateLocal}'
        : 'Pre-application';
    final postLabel = widget.postSession != null
        ? 'Post · ${widget.postSession!.sessionDateLocal}'
        : 'Post · not yet captured';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppDesignTokens.borderCrisp),
      ),
      child: InkWell(
        onTap: hasMultiple
            ? () => setState(() => _expanded = !_expanded)
            : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.treatment.code,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.primaryText,
                    ),
                  ),
                  if (hasMultiple) ...[
                    const Spacer(),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: AppDesignTokens.primary,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _PairSide(
                      label: preLabel,
                      photo: preSel.photo,
                      allPhotos: widget.prePhotos,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward,
                        size: 16, color: AppDesignTokens.secondaryText),
                  ),
                  Expanded(
                    child: _PairSide(
                      label: postLabel,
                      photo: postSel.photo,
                      allPhotos: widget.postPhotos,
                    ),
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                const Divider(
                    height: 1, color: AppDesignTokens.borderCrisp),
                const SizedBox(height: 6),
                const Text('Pre-application:',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppDesignTokens.secondaryText)),
                const SizedBox(height: 4),
                _ExpandedPhotoRow(photos: widget.prePhotos),
                const SizedBox(height: 8),
                const Text('Post-application:',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppDesignTokens.secondaryText)),
                const SizedBox(height: 4),
                _ExpandedPhotoRow(photos: widget.postPhotos),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PairSide extends StatelessWidget {
  const _PairSide({
    required this.label,
    this.photo,
    required this.allPhotos,
  });

  final String label;
  final Photo? photo;
  final List<Photo> allPhotos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: photo != null && allPhotos.isNotEmpty
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PhotoViewerScreen(
                        photos: allPhotos,
                        initialIndex:
                            allPhotos.indexOf(photo!).clamp(0, allPhotos.length - 1),
                      ),
                    ),
                  )
              : null,
          borderRadius: BorderRadius.circular(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 1,
              child: photo != null && File(photo!.filePath).existsSync()
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(photo!.filePath),
                            fit: BoxFit.cover,
                            cacheWidth: 200,
                            cacheHeight: 200),
                        if (photo!.ratingValue != null)
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppDesignTokens.primary
                                    .withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${photo!.ratingValue!.round()}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Container(
                      color: AppDesignTokens.emptyBadgeBg,
                      child: const Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            color: AppDesignTokens.secondaryText, size: 28),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppDesignTokens.secondaryText,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ExpandedPhotoRow extends StatelessWidget {
  const _ExpandedPhotoRow({required this.photos});

  final List<Photo> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const Text('No photos',
          style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: AppDesignTokens.secondaryText));
    }
    final sorted = photos.toList()
      ..sort((a, b) {
        final va = a.ratingValue ?? double.infinity;
        final vb = b.ratingValue ?? double.infinity;
        return va.compareTo(vb);
      });
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final p = sorted[i];
          final file = File(p.filePath);
          final val = p.ratingValue != null
              ? '${p.ratingValue!.round()}%'
              : '—';
          return InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => PhotoViewerScreen(
                    photos: sorted, initialIndex: i),
              ),
            ),
            child: SizedBox(
              width: 60,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: file.existsSync()
                          ? Image.file(file,
                              fit: BoxFit.cover,
                              cacheWidth: 120,
                              cacheHeight: 120)
                          : Container(
                              color: AppDesignTokens.emptyBadgeBg,
                              child: const Icon(Icons.broken_image,
                                  size: 16,
                                  color: AppDesignTokens.secondaryText)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(val,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppDesignTokens.primaryText)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
