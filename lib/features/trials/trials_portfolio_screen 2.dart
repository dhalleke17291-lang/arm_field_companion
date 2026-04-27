import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/session_state.dart';
import '../../core/trial_state.dart' show
    effectiveTrialStatusForListDisplay,
    kTrialStatusActive,
    kTrialStatusArchived,
    kTrialStatusClosed,
    kTrialStatusDraft,
    kTrialStatusReady,
    labelForTrialStatus,
    trialIsListedAsActive;
import '../../core/workspace/workspace_filter.dart';
import '../derived/trial_attention_provider.dart';
import '../derived/trial_attention_service.dart';
import 'portfolio_attention_preview.dart';
import 'trial_detail_screen.dart';
import 'trials_portfolio_provider.dart';

/// Segment for Portfolio filters (All / Custom / Protocol). Used for defaults when
/// opening from hub vs module lists.
enum PortfolioWorkspaceSegment { all, custom, protocol }

String _formatLastActivity(DateTime? at) {
  if (at == null) return 'No sessions yet';
  final d = DateTime.now().difference(at);
  if (d.inDays >= 30) return '${d.inDays ~/ 30} mo ago';
  if (d.inDays >= 1) return '${d.inDays}d ago';
  if (d.inHours >= 1) return '${d.inHours}h ago';
  if (d.inMinutes >= 1) return '${d.inMinutes}m ago';
  return 'Just now';
}

/// Status chip on portfolio tiles — tinted fills so Active reads “on,” not disabled grey.
({Color bg, Color fg}) _portfolioStatusChipColors(String statusLower) {
  switch (statusLower) {
    case kTrialStatusActive:
      return (bg: AppDesignTokens.successBg, fg: AppDesignTokens.successFg);
    case kTrialStatusReady:
      return (bg: const Color(0xFFDBEAFE), fg: const Color(0xFF1E40AF));
    case kTrialStatusDraft:
      return (bg: AppDesignTokens.warningBg, fg: AppDesignTokens.warningFg);
    case kTrialStatusClosed:
      return (bg: AppDesignTokens.emptyBadgeBg, fg: AppDesignTokens.secondaryText);
    case kTrialStatusArchived:
      return (bg: AppDesignTokens.emptyBadgeBg, fg: AppDesignTokens.emptyBadgeFg);
    default:
      return (bg: AppDesignTokens.sectionHeaderBg, fg: AppDesignTokens.primaryText);
  }
}

List<Trial> _workspaceFilter(List<Trial> all, PortfolioWorkspaceSegment w) {
  switch (w) {
    case PortfolioWorkspaceSegment.all:
      return all;
    case PortfolioWorkspaceSegment.custom:
      return all.where((t) => isStandalone(t.workspaceType)).toList();
    case PortfolioWorkspaceSegment.protocol:
      return all.where((t) => isProtocol(t.workspaceType)).toList();
  }
}

/// Cross-trial overview: open work first, then recent session activity.
class TrialsPortfolioScreen extends ConsumerStatefulWidget {
  const TrialsPortfolioScreen({
    super.key,
    this.initialWorkspace = PortfolioWorkspaceSegment.all,
  });

  /// Default segment; user can still switch to any segment in the UI.
  final PortfolioWorkspaceSegment initialWorkspace;

  @override
  ConsumerState<TrialsPortfolioScreen> createState() =>
      _TrialsPortfolioScreenState();
}

class _TrialsPortfolioScreenState extends ConsumerState<TrialsPortfolioScreen> {
  late PortfolioWorkspaceSegment _workspace;
  bool _activeOnly = true;

  @override
  void initState() {
    super.initState();
    _workspace = widget.initialWorkspace;
  }

  @override
  Widget build(BuildContext context) {
    final trialsAsync = ref.watch(trialsStreamProvider);
    final openIdsAsync = ref.watch(openTrialIdsForFieldWorkProvider);
    final lastByTrialAsync = ref.watch(portfolioLastSessionByTrialProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: AppBar(
        title: const Text('Portfolio'),
      ),
      body: trialsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF2D5A40)),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allTrials) {
          final openIds = openIdsAsync.valueOrNull ?? <int>{};
          final lastByTrial = lastByTrialAsync.valueOrNull ?? <int, DateTime>{};

          var filtered = _workspaceFilter(allTrials, _workspace);
          if (_activeOnly) {
            filtered = filtered
                .where(
                  (t) => trialIsListedAsActive(
                    trialStatus: t.status,
                    hasOpenFieldSession: openIds.contains(t.id),
                  ),
                )
                .toList();
          }
          filtered.sort((a, b) {
            final oa = openIds.contains(a.id);
            final ob = openIds.contains(b.id);
            if (oa != ob) return oa ? -1 : 1;
            final ta = lastByTrial[a.id];
            final tb = lastByTrial[b.id];
            if (ta == null && tb == null) {
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            }
            if (ta == null) return 1;
            if (tb == null) return -1;
            final c = tb.compareTo(ta);
            if (c != 0) return c;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  'Open field sessions first, then most recent session. '
                  'Use filters to narrow Custom vs Protocol.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<PortfolioWorkspaceSegment>(
                  segments: const [
                    ButtonSegment(
                      value: PortfolioWorkspaceSegment.all,
                      label: Text('All'),
                    ),
                    ButtonSegment(
                      value: PortfolioWorkspaceSegment.custom,
                      label: Text('Custom'),
                    ),
                    ButtonSegment(
                      value: PortfolioWorkspaceSegment.protocol,
                      label: Text('Protocol'),
                    ),
                  ],
                  selected: {_workspace},
                  onSelectionChanged: (s) {
                    setState(() => _workspace = s.first);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: FilterChip(
                  label: const Text('Active trials only'),
                  selected: _activeOnly,
                  onSelected: (v) => setState(() => _activeOnly = v),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFF2D5A40),
                  onRefresh: () async {
                    ref.invalidate(portfolioLastSessionByTrialProvider);
                    ref.invalidate(trialsStreamProvider);
                    await ref.read(portfolioLastSessionByTrialProvider.future);
                  },
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 48),
                            Center(
                              child: Text(
                                'No trials match these filters.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        )
                      : _PortfolioTrialList(
                          trials: filtered,
                          lastByTrial: lastByTrial,
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

/// Builds the scrollable list with cross-trial attention label de-duplication.
class _PortfolioTrialList extends ConsumerWidget {
  const _PortfolioTrialList({
    required this.trials,
    required this.lastByTrial,
  });

  final List<Trial> trials;
  final Map<int, DateTime> lastByTrial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usedLabels = <String>{};
    final primaryByTrialId = <int, AttentionItem?>{};
    for (final t in trials) {
      final items = ref.watch(trialAttentionProvider(t.id)).valueOrNull;
      primaryByTrialId[t.id] =
          portfolioPrimaryAttentionLineDeduped(items, t.id, usedLabels);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: trials.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final trial = trials[i];
        return _PortfolioTrialTile(
          trial: trial,
          lastSessionAt: lastByTrial[trial.id],
          primaryAttention: primaryByTrialId[trial.id],
        );
      },
    );
  }
}

class _PortfolioTrialTile extends ConsumerWidget {
  const _PortfolioTrialTile({
    required this.trial,
    required this.lastSessionAt,
    required this.primaryAttention,
  });

  final Trial trial;
  final DateTime? lastSessionAt;
  final AttentionItem? primaryAttention;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openAsync = ref.watch(openSessionProvider(trial.id));
    final openSession = openAsync.valueOrNull;
    final hasOpenField =
        openSession != null && isSessionOpenForFieldWork(openSession);
    final displayStatus = effectiveTrialStatusForListDisplay(
      trialStatus: trial.status,
      hasOpenFieldSession: hasOpenField,
    );
    final attentionAsync = ref.watch(trialAttentionProvider(trial.id));
    final attentionItems = attentionAsync.valueOrNull;
    final primary = primaryAttention;
    final extraAttention = portfolioAdditionalAttentionCount(attentionItems);
    final attentionPreview = primary == null
        ? null
        : extraAttention > 0
            ? '${primary.label} · +$extraAttention more'
            : primary.label;
    final subtitleParts = <String>[
      _formatLastActivity(lastSessionAt),
      if (hasOpenField) 'Open session',
      if (attentionPreview != null) attentionPreview,
    ];

    final chipColors = _portfolioStatusChipColors(displayStatus.toLowerCase());
    final isActive = displayStatus.toLowerCase() == kTrialStatusActive;
    final accentColor = isActive
        ? AppDesignTokens.primaryGreen
        : AppDesignTokens.borderCrisp;

    return Material(
      color: AppDesignTokens.cardSurface,
      elevation: isActive ? 2 : 0,
      shadowColor: isActive
          ? AppDesignTokens.primaryGreen.withValues(alpha: 0.15)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive
              ? AppDesignTokens.primaryGreen.withValues(alpha: 0.3)
              : AppDesignTokens.borderCrisp,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => TrialDetailScreen(trial: trial),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              width: 4,
              height: 64,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trial.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              height: 1.25,
                              color: isActive
                                  ? AppDesignTokens.primaryText
                                  : AppDesignTokens.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitleParts.join(' · '),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: AppDesignTokens.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: chipColors.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: isActive
                            ? Border.all(
                                color: AppDesignTokens.primaryGreen
                                    .withValues(alpha: 0.3))
                            : null,
                      ),
                      child: Text(
                        labelForTrialStatus(displayStatus.toLowerCase()),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: chipColors.fg,
                        ),
                      ),
                    ),
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
