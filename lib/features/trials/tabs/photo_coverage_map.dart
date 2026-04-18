import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/plot_analysis_eligibility.dart';
import '../../../core/providers.dart';

/// 5.10 — Photo coverage map: plot layout grid overlaid with photo presence
/// per session. Solid fill = has photo, outline = no photo.
class PhotoCoverageMap extends ConsumerWidget {
  const PhotoCoverageMap({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(photosForTrialProvider(trial.id));
    final sessionsAsync = ref.watch(sessionsForTrialProvider(trial.id));
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final assignmentsAsync =
        ref.watch(assignmentsForTrialProvider(trial.id));
    final treatmentsAsync = ref.watch(treatmentsForTrialProvider(trial.id));

    return photosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (photos) {
        final sessions = sessionsAsync.valueOrNull ?? [];
        final plots = plotsAsync.valueOrNull ?? [];
        final assignments = assignmentsAsync.valueOrNull ?? [];
        final treatments = treatmentsAsync.valueOrNull ?? [];
        final dataPlots = plots.where(isAnalyzablePlot).toList();

        if (dataPlots.isEmpty) {
          return const Center(child: Text('No plots'));
        }

        final plotToTreatment = <int, int>{};
        for (final a in assignments) {
          if (a.treatmentId != null) plotToTreatment[a.plotId] = a.treatmentId!;
        }

        // Sessions that have photos
        final sessionIdsWithPhotos = <int>{};
        for (final p in photos) {
          sessionIdsWithPhotos.add(p.sessionId);
        }
        final sessionsWithPhotos = sessions
            .where((s) => sessionIdsWithPhotos.contains(s.id))
            .toList();

        // Include sessions without photos too (for the dropdown)
        final allSessions = sessions.toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

        if (allSessions.isEmpty) {
          return const Center(child: Text('No sessions'));
        }

        return _CoverageContent(
          photos: photos,
          sessions: allSessions,
          dataPlots: dataPlots,
          plotToTreatment: plotToTreatment,
          treatments: treatments,
          initialSessionId: sessionsWithPhotos.isNotEmpty
              ? sessionsWithPhotos.last.id
              : allSessions.last.id,
        );
      },
    );
  }
}

class _CoverageContent extends StatefulWidget {
  const _CoverageContent({
    required this.photos,
    required this.sessions,
    required this.dataPlots,
    required this.plotToTreatment,
    required this.treatments,
    required this.initialSessionId,
  });

  final List<Photo> photos;
  final List<Session> sessions;
  final List<Plot> dataPlots;
  final Map<int, int> plotToTreatment;
  final List<Treatment> treatments;
  final int initialSessionId;

  @override
  State<_CoverageContent> createState() => _CoverageContentState();
}

class _CoverageContentState extends State<_CoverageContent> {
  late int _selectedSessionId;

  @override
  void initState() {
    super.initState();
    _selectedSessionId = widget.initialSessionId;
  }

  @override
  Widget build(BuildContext context) {
    final sessionPhotoPks = <int>{};
    for (final p in widget.photos) {
      if (p.sessionId == _selectedSessionId) {
        sessionPhotoPks.add(p.plotPk);
      }
    }

    final coveredCount = widget.dataPlots
        .where((p) => sessionPhotoPks.contains(p.id))
        .length;
    final totalCount = widget.dataPlots.length;
    final pct = totalCount > 0
        ? (coveredCount / totalCount * 100).toStringAsFixed(0)
        : '0';

    // Group plots by rep
    final byRep = <int, List<Plot>>{};
    for (final p in widget.dataPlots) {
      byRep.putIfAbsent(p.rep ?? 0, () => []).add(p);
    }
    final sortedReps = byRep.keys.toList()..sort();

    // Treatment color palette
    final treatmentColors = <int, Color>{};
    var colorIdx = 0;
    for (final t in widget.treatments) {
      treatmentColors[t.id] =
          AppDesignTokens.treatmentPalette[
              colorIdx % AppDesignTokens.treatmentPalette.length];
      colorIdx++;
    }

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
        // Coverage count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            '$coveredCount/$totalCount plots photographed ($pct%)',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppDesignTokens.primaryText,
            ),
          ),
        ),
        // Grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final rep in sortedReps) ...[
                    if (rep > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, top: 8),
                        child: Text(
                          'Rep $rep',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppDesignTokens.secondaryText,
                          ),
                        ),
                      ),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final p in byRep[rep]!)
                          _PlotTile(
                            plotId: p.plotId,
                            hasPhoto: sessionPhotoPks.contains(p.id),
                            color: treatmentColors[
                                    widget.plotToTreatment[p.id]] ??
                                AppDesignTokens.secondaryText,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlotTile extends StatelessWidget {
  const _PlotTile({
    required this.plotId,
    required this.hasPhoto,
    required this.color,
  });

  final String plotId;
  final bool hasPhoto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: hasPhoto
            ? color.withValues(alpha: 0.2)
            : AppDesignTokens.emptyBadgeBg.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasPhoto ? color : color.withValues(alpha: 0.4),
          width: hasPhoto ? 2 : 1.5,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasPhoto)
              Icon(Icons.camera_alt, size: 12, color: color),
            Text(
              plotId,
              style: TextStyle(
                fontSize: 9,
                fontWeight: hasPhoto ? FontWeight.w700 : FontWeight.w400,
                color: hasPhoto ? color : AppDesignTokens.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
