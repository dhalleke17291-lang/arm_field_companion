part of '../trial_detail_screen.dart';

class OverviewDashboardCard extends StatelessWidget {
  const OverviewDashboardCard({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: _kOverviewDashboardCardMargin,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        side: const BorderSide(color: AppDesignTokens.borderCrisp),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing12,
          vertical: AppDesignTokens.spacing8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: _overviewDashboardCardTitleStyle()),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }
}

class OverviewPlotSummary extends ConsumerWidget {
  const OverviewPlotSummary({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final treatmentsAsync = ref.watch(treatmentsForTrialProvider(trial.id));
    final ratedAsync = ref.watch(ratedPlotsCountForTrialProvider(trial.id));
    final completionAsync =
        ref.watch(trialAssessmentCompletionProvider(trial.id));

    return OverviewDashboardCard(
      title: 'Plots',
      child: plotsAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (e, st) => Text(
          'Could not load plots',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        data: (plots) {
          final treatments = treatmentsAsync.value ?? [];
          final rated = ratedAsync.valueOrNull ?? 0;
          final dataPlotCount = plots.where((p) => !p.isGuardRow).length;
          final analyzableCount = plots.where(isAnalyzablePlot).length;
          final excludedFromData =
              (dataPlotCount - analyzableCount).clamp(0, dataPlotCount);
          final repCount = () {
            if (plots.isEmpty) return 0;
            final blocks = buildRepBasedLayout(plots);
            final repNumbers = <int>{};
            for (final block in blocks) {
              for (final row in block.repRows) {
                for (final p in row.plots) {
                  if (p.rep != null) repNumbers.add(p.rep!);
                }
              }
            }
            return repNumbers.length;
          }();
          final summaryLine =
              '$dataPlotCount data plots · ${treatments.length} treatments · $repCount reps';

          // Whole-trial coverage: rated plot-assessments / (nAssessments ×
          // analyzable plots). Labelled "coverage" because the metric is
          // non-monotonic — it honestly drops when scope expands (new
          // assessment or new plots). Denominator is surfaced in the
          // secondary line so a drop caused by scope growth is visible.
          final completionMap = completionAsync.valueOrNull;
          final nAssess = completionMap?.length ?? 0;
          double? trialCoverage;
          String? coveragePrimaryLine;
          String? coverageDetailLine;
          if (completionMap != null && nAssess > 0) {
            final completeAssess =
                completionMap.values.where((c) => c.isComplete).length;
            final sumPairs = completionMap.values
                .fold<int>(0, (s, c) => s + c.ratedPlotCount);
            final denomPairs = nAssess * analyzableCount;
            trialCoverage =
                denomPairs <= 0 ? 0.0 : (sumPairs / denomPairs).clamp(0.0, 1.0);
            final pct = (trialCoverage * 100).round();
            coveragePrimaryLine = '$pct% coverage';
            coverageDetailLine = nAssess == 1
                ? '$sumPairs of $denomPairs plot-assessments rated'
                : '$sumPairs of $denomPairs plot-assessments rated · $completeAssess of $nAssess assessments done';
          }

          final remaining = (analyzableCount - rated).clamp(0, analyzableCount);
          final ratedLine = analyzableCount <= 0
              ? '$rated rated · no analyzable plots'
              : '$rated rated · $remaining remaining · $analyzableCount analyzable';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                summaryLine,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              if (trialCoverage != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: trialCoverage,
                    backgroundColor: const Color(0xFFE8E5E0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      trialCoverage >= 1.0
                          ? AppDesignTokens.successFg
                          : AppDesignTokens.primary,
                    ),
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  coveragePrimaryLine!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  coverageDetailLine!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    color: AppDesignTokens.secondaryText.withValues(alpha: 0.9),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                ratedLine,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
              if (excludedFromData > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '$excludedFromData data plot${excludedFromData == 1 ? '' : 's'} excluded from analysis (not counted in progress).',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                    color: AppDesignTokens.secondaryText.withValues(alpha: 0.9),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => PlotsTab.openPlotLayoutView(context, trial),
                icon: const Icon(Icons.grid_view, size: 20),
                label: const Text('View Plot Layout'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class TrialInsightsCard extends ConsumerStatefulWidget {
  const TrialInsightsCard({super.key, required this.trialId});

  final int trialId;

  @override
  ConsumerState<TrialInsightsCard> createState() => _TrialInsightsCardState();
}

class _TrialInsightsCardState extends ConsumerState<TrialInsightsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final insightsAsync = ref.watch(trialInsightsProvider(widget.trialId));

    return insightsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (insights) {
        if (insights.isEmpty) return const SizedBox.shrink();
        final hasTrends =
            insights.any((i) => i.type == InsightType.treatmentTrend);
        return Card(
          margin: _kOverviewDashboardCardMargin,
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
            side: const BorderSide(color: AppDesignTokens.borderCrisp),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDesignTokens.spacing12,
              vertical: AppDesignTokens.spacing8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  borderRadius:
                      BorderRadius.circular(AppDesignTokens.radiusSmall),
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Trial insights',
                            style: _overviewDashboardCardTitleStyle(),
                          ),
                        ),
                        Text(
                          '${insights.length} insight${insights.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppDesignTokens.secondaryText,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 20,
                          color: AppDesignTokens.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                if (!_expanded) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Exploratory readouts available. Tap to review.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Early or developing readouts — not proof of treatment '
                    'effects. Not for final trial conclusions, registration, or '
                    'substitute for approved analysis software.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All insights here are exploratory. Labels like '
                    '"Developing" describe how much history the row has — not '
                    'that a trend is proven. Formal inference stays outside the app.',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.35,
                      color:
                          AppDesignTokens.secondaryText.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppDesignTokens.borderCrisp),
                  ..._buildGroupedInsights(insights),
                  if (hasTrends) ...[
                    const Divider(
                        height: 1, color: AppDesignTokens.borderCrisp),
                    const SizedBox(height: 6),
                    const Text(
                      'Treatment trends: arithmetic mean per treatment per session.',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static List<Widget> _buildGroupedInsights(List<TrialInsight> insights) {
    final groupMap = <String, List<TrialInsight>>{};
    for (final insight in insights) {
      if (insight.assessmentName != null) {
        groupMap.putIfAbsent(insight.assessmentName!, () => []).add(insight);
      }
    }
    final emitted = <String>{};
    final renderItems = <Widget>[];
    for (final insight in insights) {
      if (insight.assessmentName != null &&
          groupMap[insight.assessmentName!]!.length > 1) {
        final name = insight.assessmentName!;
        if (!emitted.contains(name)) {
          emitted.add(name);
          if (renderItems.isNotEmpty) {
            renderItems.add(
                const Divider(height: 1, color: AppDesignTokens.borderCrisp));
          }
          renderItems.add(_buildInsightGroup(groupMap[name]!));
        }
      } else {
        if (renderItems.isNotEmpty) {
          renderItems.add(
              const Divider(height: 1, color: AppDesignTokens.borderCrisp));
        }
        renderItems.add(InsightRow(insight: insight));
      }
    }
    return renderItems;
  }

  static Widget _buildInsightGroup(List<TrialInsight> group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(
            group.first.assessmentName!,
            style: AppDesignTokens.assessmentGroupHeaderStyle,
          ),
        ),
        for (int j = 0; j < group.length; j++) ...[
          if (j > 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Divider(height: 1, color: AppDesignTokens.borderCrisp),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: InsightRow(
              insight: group[j],
              titleOverride: group[j].treatmentName,
            ),
          ),
        ],
      ],
    );
  }
}

class OverviewTabBody extends ConsumerWidget {
  const OverviewTabBody({
    super.key,
    required this.trial,
    required this.onAttentionTap,
    required this.onOpenSessions,
  });

  final Trial trial;
  final void Function(AttentionItem item) onAttentionTap;
  final VoidCallback onOpenSessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(trialProvider(trial.id));

    return SingleChildScrollView(
      key: ValueKey<String>('overview_tab_${trial.id}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1 — Hero: resume work right now.
          CurrentSessionHero(
            trial: trial,
            onOpenSessions: onOpenSessions,
          ),
          // 1b — Trial identity + compact intent preview.
          TrialIdentitySummaryCard(trial: trial),
          // 2 — What needs attention (single source of truth = attention
          // provider; full readiness lives behind Review issues).
          NeedsAttentionCard(
            trial: trial,
            onAttentionTap: onAttentionTap,
          ),
          // 2b — Read-only execution summary (divergences + evidence coverage).
          ExecutionSummaryCard(trial: trial),
          // 2c — Researcher-authored notes, reasons, and captions.
          ResearcherContextCard(trial: trial),
          // 2c — Trial design summary.
          TrialDesignSummaryCard(trial: trial),
          // 3 — Physical structure & progress (incl. whole-trial %).
          OverviewPlotSummary(trial: trial),
          // 4 — Location / metadata.
          SiteDetailsCard(trial: trial),
          // 5 — Analytical insights (hidden when empty).
          TrialInsightsCard(trialId: trial.id),
          // 6 — Minor status text.
          const AutoBackupStatusLine(),
        ],
      ),
    );
  }
}

class ResearcherContextCard extends ConsumerWidget {
  const ResearcherContextCard({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextAsync = ref.watch(researcherContextEntriesProvider(trial.id));
    return contextAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (entries) {
        final visibleEntries = entries
            .where((entry) => entry.contextType != 'Trial intent answers')
            .toList();
        if (visibleEntries.isEmpty) return const SizedBox.shrink();
        final counts = <String, int>{};
        for (final entry in visibleEntries) {
          final label = _researcherContextTypeLabel(entry.contextType);
          counts[label] = (counts[label] ?? 0) + 1;
        }
        final countParts =
            counts.entries.take(4).map((e) => '${e.key} ${e.value}').toList();
        final previewEntries = visibleEntries.take(3).toList();

        return OverviewDashboardCard(
          title: 'Researcher Context',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${visibleEntries.length} note${visibleEntries.length == 1 ? '' : 's'} and reason${visibleEntries.length == 1 ? '' : 's'} captured',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              if (countParts.isNotEmpty) ...[
                const SizedBox(height: AppDesignTokens.spacing8),
                Wrap(
                  spacing: AppDesignTokens.spacing4,
                  runSpacing: AppDesignTokens.spacing4,
                  children: [
                    for (final part in countParts)
                      _OverviewMiniChip(
                        label: part,
                        bg: AppDesignTokens.successBg,
                        fg: AppDesignTokens.primary,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppDesignTokens.spacing8),
              for (var i = 0; i < previewEntries.length; i++) ...[
                _ResearcherContextPreviewRow(entry: previewEntries[i]),
                if (i != previewEntries.length - 1)
                  const SizedBox(height: AppDesignTokens.spacing8),
              ],
              if (visibleEntries.length > previewEntries.length) ...[
                const SizedBox(height: AppDesignTokens.spacing8),
                Text(
                  '+${visibleEntries.length - previewEntries.length} more captured for export context',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

String _researcherContextTypeLabel(String type) {
  return switch (type) {
    'Signal decision notes' => 'Review notes',
    _ => type,
  };
}

String _researcherContextTitleLabel(ResearcherContextEntry entry) {
  if (entry.contextType != 'Signal decision notes') return entry.title;
  final signalMatch =
      RegExp(r'^Signal\s+\d+\s+·\s+(.+)$').firstMatch(entry.title.trim());
  if (signalMatch == null) return 'Issue review';
  return 'Issue review · ${_researcherContextActionLabel(signalMatch.group(1)!)}';
}

String _researcherContextActionLabel(String value) {
  return switch (value.trim().toLowerCase()) {
    'confirm' => 'Confirmed',
    'investigate' => 'Needs follow-up',
    'defer' => 'Review later',
    'suppress' => 'Dismissed',
    're_rate' || 'rerate' => 'Corrected rating',
    _ => _researcherContextPlainLabel(value),
  };
}

String _researcherContextStatusLabel(String value) {
  return switch (value.trim().toLowerCase()) {
    'resolved' => 'Resolved',
    'open' => 'Needs review',
    'investigating' => 'Under review',
    'deferred' => 'Review later',
    'suppressed' => 'Dismissed',
    _ => _researcherContextPlainLabel(value),
  };
}

String _researcherContextPlainLabel(String value) {
  final words = value.trim().replaceAll('_', ' ').split(RegExp(r'\s+'));
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String? _researcherContextSessionLabel(String? detail) {
  if (detail == null) return null;
  final trimmed = detail.trim();
  if (trimmed.isEmpty) return null;
  final sessionMatch =
      RegExp(r'^\d{4}-\d{2}-\d{2}\s+(.+)$').firstMatch(trimmed);
  return sessionMatch?.group(1) ?? trimmed;
}

String _researcherContextMetaLabel(ResearcherContextEntry entry, String? date) {
  if (entry.contextType == 'Signal decision notes') {
    return [
      if (entry.detail != null) _researcherContextStatusLabel(entry.detail!),
      if (date != null) date,
    ].join(' · ');
  }

  if (entry.contextType == 'Amendment reasons') {
    return [
      'Amendment',
      if (_researcherContextSessionLabel(entry.detail) != null)
        _researcherContextSessionLabel(entry.detail)!,
    ].join(' · ');
  }

  return [
    _researcherContextTypeLabel(entry.contextType),
    if (entry.detail != null) entry.detail!,
    if (date != null) date,
  ].join(' · ');
}

class _ResearcherContextPreviewRow extends StatelessWidget {
  const _ResearcherContextPreviewRow({required this.entry});

  final ResearcherContextEntry entry;

  @override
  Widget build(BuildContext context) {
    final date = entry.occurredAt == null
        ? null
        : DateFormat('MMM d').format(entry.occurredAt!);
    final meta = _researcherContextMetaLabel(entry, date);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesignTokens.spacing8),
      decoration: BoxDecoration(
        color: AppDesignTokens.sectionHeaderBg,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
        border: Border.all(color: AppDesignTokens.borderCrisp),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _researcherContextTitleLabel(entry),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppDesignTokens.primaryText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          Text(
            entry.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppDesignTokens.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class ExecutionSummaryCard extends ConsumerWidget {
  const ExecutionSummaryCard({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final divergencesAsync = ref.watch(protocolDivergenceProvider(trial.id));
    final anchorsAsync = ref.watch(evidenceAnchorsProvider(trial.id));

    return divergencesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (divergences) => anchorsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (anchors) {
          final sessionAnchors = anchors
              .where((a) => a.eventType == EvidenceEventType.session)
              .toList();
          if (divergences.isEmpty && sessionAnchors.isEmpty) {
            return const SizedBox.shrink();
          }
          final withEvidence = sessionAnchors
              .where((a) =>
                  a.hasGps ||
                  a.hasWeather ||
                  a.photoIds.isNotEmpty ||
                  a.hasTimestamp)
              .length;
          return OverviewDashboardCard(
            title: 'Execution Summary',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ExecutionSummaryRow(
                  label: 'Protocol differences',
                  value: '${divergences.length}',
                ),
                const SizedBox(height: 4),
                ExecutionSummaryRow(
                  label: 'Sessions with evidence',
                  value: '$withEvidence/${sessionAnchors.length}',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ExecutionSummaryRow extends StatelessWidget {
  const ExecutionSummaryRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppDesignTokens.secondaryText,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppDesignTokens.secondaryText,
          ),
        ),
      ],
    );
  }
}

class CurrentSessionHero extends ConsumerWidget {
  const CurrentSessionHero({
    super.key,
    required this.trial,
    required this.onOpenSessions,
  });

  final Trial trial;
  final VoidCallback onOpenSessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsForTrialProvider(trial.id));
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final ratedAsync = ref.watch(ratedPlotsCountForTrialProvider(trial.id));

    return OverviewDashboardCard(
      title: 'Current Session',
      child: sessionsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Loading session…',
            style: TextStyle(
              fontSize: 12,
              color: AppDesignTokens.secondaryText,
            ),
          ),
        ),
        error: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Session data unavailable.',
            style: TextStyle(
              fontSize: 12,
              color: AppDesignTokens.secondaryText,
            ),
          ),
        ),
        data: (sessions) {
          final open = sessions.where(isSessionOpenForFieldWork).toList();
          final primary = open.isNotEmpty
              ? open.first
              : (sessions.isNotEmpty ? sessions.first : null);
          final isActive =
              primary != null && isSessionOpenForFieldWork(primary);

          // Status pill label + coloring.
          final String statusLabel;
          final Color statusFg;
          final Color statusBg;
          if (sessions.isEmpty) {
            statusLabel = 'Not started';
            statusFg = AppDesignTokens.emptyBadgeFg;
            statusBg = AppDesignTokens.emptyBadgeBg;
          } else if (isActive) {
            statusLabel = 'Active';
            statusFg = AppDesignTokens.openSessionBg;
            statusBg = AppDesignTokens.openSessionBgLight;
          } else {
            statusLabel = 'Closed';
            statusFg = AppDesignTokens.secondaryText;
            statusBg = AppDesignTokens.emptyBadgeBg;
          }

          // Plots rated progress (single line).
          final plots = plotsAsync.valueOrNull ?? const <Plot>[];
          final analyzable = plots.where(isAnalyzablePlot).length;
          final rated = ratedAsync.valueOrNull ?? 0;
          final progressValue =
              analyzable > 0 ? (rated / analyzable).clamp(0.0, 1.0) : 0.0;
          final progressLine = analyzable > 0
              ? '$rated of $analyzable plots rated'
              : 'No analyzable plots yet';

          // Secondary meta line: date + session label.
          final dateText = primary != null
              ? _formatSessionDateLocal(primary.sessionDateLocal)
              : null;
          final sessionLabel =
              primary != null ? _sessionDisplayLabel(primary) : null;

          // Primary CTA: one action only.
          final String ctaLabel;
          final IconData ctaIcon;
          final VoidCallback ctaAction;
          if (isActive) {
            ctaLabel = 'Continue Rating';
            ctaIcon = Icons.play_arrow_rounded;
            ctaAction = () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PlotQueueScreen(
                    trial: trial,
                    session: primary,
                  ),
                ),
              );
            };
          } else if (sessions.isEmpty) {
            ctaLabel = 'Start Session';
            ctaIcon = Icons.play_circle_outline_rounded;
            ctaAction = () => tryOpenCreateSessionScreen(
                  context: context,
                  ref: ref,
                  trial: trial,
                );
          } else {
            ctaLabel = 'Open Sessions';
            ctaIcon = Icons.folder_open_outlined;
            ctaAction = onOpenSessions;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusFg,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (dateText != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      dateText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppDesignTokens.primaryText,
                      ),
                    ),
                  ],
                  if (sessionLabel != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sessionLabel.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                          color: AppDesignTokens.primaryText
                              .withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                progressLine,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
              if (analyzable > 0) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: const Color(0xFFE8E5E0),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppDesignTokens.primary,
                    ),
                    minHeight: 5,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: ctaAction,
                icon: Icon(ctaIcon, size: 18),
                label: Text(ctaLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: AppDesignTokens.primary,
                  foregroundColor: AppDesignTokens.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class NeedsAttentionCard extends ConsumerWidget {
  const NeedsAttentionCard({
    super.key,
    required this.trial,
    required this.onAttentionTap,
  });

  final Trial trial;
  final void Function(AttentionItem item) onAttentionTap;

  static int _severityRank(AttentionSeverity s) => switch (s) {
        AttentionSeverity.high => 0,
        AttentionSeverity.medium => 1,
        AttentionSeverity.low => 2,
        AttentionSeverity.info => 3,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attentionAsync = ref.watch(trialAttentionProvider(trial.id));

    return attentionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        // All-clear state: title + subtle acknowledgement + the same
        // adaptive CTA (labelled "View readiness") so Overview always
        // has one entry point to the Trial Readiness dashboard.
        if (items.isEmpty) {
          return OverviewDashboardCard(
            title: 'Needs Attention',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'All clear — nothing needs attention right now.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color:
                        AppDesignTokens.secondaryText.withValues(alpha: 0.85),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _openCompletenessDashboard(context, trial),
                    icon: const Icon(Icons.fact_check_outlined, size: 16),
                    label: const Text('View readiness'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppDesignTokens.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final sorted = [...items]..sort((a, b) =>
            _severityRank(a.severity).compareTo(_severityRank(b.severity)));
        final top = sorted.take(3).toList();
        final remaining = items.length - top.length;
        final actionableCount =
            items.where((i) => i.severity != AttentionSeverity.info).length;

        return OverviewDashboardCard(
          title: 'Needs Attention',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                actionableCount == 0
                    ? 'No warnings'
                    : actionableCount == 1
                        ? '1 warning'
                        : '$actionableCount warnings',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              for (final item in top)
                AttentionRow(
                  item: item,
                  onTap: () => onAttentionTap(item),
                ),
              if (remaining > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDesignTokens.spacing16,
                    vertical: 6,
                  ),
                  child: Text(
                    '+$remaining more',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _openCompletenessDashboard(context, trial),
                  icon: const Icon(Icons.fact_check_outlined, size: 16),
                  label: const Text('Review issues'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppDesignTokens.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
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

class AutoBackupStatusLine extends ConsumerWidget {
  const AutoBackupStatusLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(autoBackupStatusProvider);
    return statusAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (status) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Icon(
              status.enabled
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              size: 14,
              color: status.enabled
                  ? AppDesignTokens.successFg
                  : AppDesignTokens.secondaryText,
            ),
            const SizedBox(width: 6),
            Text(
              status.label,
              style: TextStyle(
                fontSize: 11,
                color: status.enabled
                    ? AppDesignTokens.secondaryText
                    : AppDesignTokens.warningFg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttentionRow extends StatelessWidget {
  const AttentionRow({
    super.key,
    required this.item,
    required this.onTap,
  });

  final AttentionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.severity) {
      AttentionSeverity.high => AppDesignTokens.missedColor,
      AttentionSeverity.medium => AppDesignTokens.warningFg,
      AttentionSeverity.low => AppDesignTokens.secondaryText,
      AttentionSeverity.info => AppDesignTokens.primary,
    };
    final icon = switch (item.severity) {
      AttentionSeverity.high => Icons.error_outline,
      AttentionSeverity.medium => Icons.warning_amber_outlined,
      AttentionSeverity.low => Icons.info_outline,
      AttentionSeverity.info => Icons.check_circle_outline,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing16,
          vertical: 6,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  color: AppDesignTokens.primaryText,
                ),
              ),
            ),
            if (item.count != null) ...[
              const SizedBox(width: 8),
              Text(
                '${item.count}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
