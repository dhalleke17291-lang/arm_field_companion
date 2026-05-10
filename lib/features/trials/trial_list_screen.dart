import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/export_guard.dart';
import '../../core/widgets/loading_error_widgets.dart';
import '../../core/providers.dart';
import '../../core/last_session_store.dart';
import '../../core/session_resume_store.dart';
import '../../core/plot_sort.dart';
import '../../core/session_walk_order_store.dart';
import '../../core/trial_state.dart';
import '../../core/database/app_database.dart';
import '../import/ui/import_trial_sheet.dart';
import 'standalone/trial_creation_wizard.dart';
import '../derived/trial_attention_provider.dart';
import '../derived/trial_attention_service.dart';
import 'trial_detail_screen.dart';
import 'widgets/trial_card.dart';
import '../sessions/usecases/start_or_continue_rating_usecase.dart';
import '../sessions/create_session_screen.dart';
import '../ratings/rating_screen.dart';
import '../ratings/rating_scale_map.dart';
import '../about/about_screen.dart';

/// Workspace filter for trial list. Client-side only; no repository changes.
enum TrialListFilter {
  all,
  standaloneOnly,
  protocolOnly,
}

enum _TrialListStatusFilter { all, active, closed, archived }

enum _TrialListSortMode { newestCreated, oldestCreated, nameAz, nameZa }

/// Matches [_TrialListStatusFilter.active] row visibility (draft / ready / active / open session).
bool _trialMatchesActiveListFilter(
  Trial t,
  Set<int> trialIdsWithOpenFieldSession,
) {
  final s = t.status.trim().toLowerCase();
  if (s == kTrialStatusClosed || s == kTrialStatusArchived) {
    return false;
  }
  if (s == kTrialStatusDraft ||
      s == kTrialStatusReady ||
      s == kTrialStatusActive) {
    return true;
  }
  return trialIdsWithOpenFieldSession.contains(t.id);
}

/// Client-side only: search → status filter → sort. Assumes [trials] already filtered by provider.
List<Trial> _deriveDisplayedTrials({
  required List<Trial> trials,
  required String searchQuery,
  required _TrialListStatusFilter statusFilter,
  required _TrialListSortMode sortMode,
  required Set<int> trialIdsWithOpenFieldSession,
}) {
  var list = trials;
  final q = searchQuery.trim().toLowerCase();
  Iterable<Trial> afterSearch = list;
  if (q.isNotEmpty) {
    afterSearch = list.where((t) {
      bool fieldContains(String? s) => s != null && s.toLowerCase().contains(q);
      return t.name.toLowerCase().contains(q) ||
          fieldContains(t.crop) ||
          fieldContains(t.location) ||
          fieldContains(t.season) ||
          t.status.toLowerCase().contains(q);
    });
  }
  var filtered = afterSearch.toList();
  switch (statusFilter) {
    case _TrialListStatusFilter.all:
      break;
    case _TrialListStatusFilter.active:
      filtered = filtered
          .where((t) => _trialMatchesActiveListFilter(
                t,
                trialIdsWithOpenFieldSession,
              ))
          .toList();
      break;
    case _TrialListStatusFilter.closed:
      filtered = filtered
          .where((t) => t.status.trim().toLowerCase() == kTrialStatusClosed)
          .toList();
      break;
    case _TrialListStatusFilter.archived:
      filtered = filtered
          .where((t) => t.status.trim().toLowerCase() == kTrialStatusArchived)
          .toList();
      break;
  }
  int cmpNameCi(Trial a, Trial b) {
    final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  }

  switch (sortMode) {
    case _TrialListSortMode.newestCreated:
      filtered.sort((a, b) {
        final c = b.createdAt.compareTo(a.createdAt);
        if (c != 0) return c;
        return b.id.compareTo(a.id);
      });
      break;
    case _TrialListSortMode.oldestCreated:
      filtered.sort((a, b) {
        final c = a.createdAt.compareTo(b.createdAt);
        if (c != 0) return c;
        return a.id.compareTo(b.id);
      });
      break;
    case _TrialListSortMode.nameAz:
      filtered.sort(cmpNameCi);
      break;
    case _TrialListSortMode.nameZa:
      filtered.sort((a, b) => cmpNameCi(b, a));
      break;
  }
  return filtered;
}

Future<void> _quickRateFromList(
  BuildContext context,
  WidgetRef ref,
  Trial trial,
) async {
  // Pre-flight: prevent opening an empty assessment list in CreateSessionScreen.
  final legacy = await ref.read(assessmentsForTrialProvider(trial.id).future);
  if (legacy.isEmpty) {
    final trialPairs = await ref
        .read(trialAssessmentsWithDefinitionsForTrialProvider(trial.id).future);
    if (trialPairs.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Add assessments to the trial first. Open trial → Assessments.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
  }
  if (!context.mounted) return;
  final session = await Navigator.push<Session?>(
    context,
    MaterialPageRoute<Session?>(
      builder: (_) => CreateSessionScreen(trial: trial),
    ),
  );
  if (!context.mounted || session == null) return;
  await _navigateToRatingForSession(context, ref, trial, session);
}

String _sortModeLabel(_TrialListSortMode m) {
  switch (m) {
    case _TrialListSortMode.newestCreated:
      return 'Newest created';
    case _TrialListSortMode.oldestCreated:
      return 'Oldest created';
    case _TrialListSortMode.nameAz:
      return 'Name A–Z';
    case _TrialListSortMode.nameZa:
      return 'Name Z–A';
  }
}

/// Shared navigation to rating for a given open session (used by Continue Session and Continue Last Session card).
Future<void> _navigateToRatingForSession(
  BuildContext context,
  WidgetRef ref,
  Trial trial,
  Session session,
) async {
  final useCase = ref.read(startOrContinueRatingUseCaseProvider);
  final prefs = await SharedPreferences.getInstance();
  final store = SessionWalkOrderStore(prefs);
  final walkOrder = store.getMode(session.id);
  final customIds = walkOrder == WalkOrderMode.custom
      ? store.getCustomOrder(session.id)
      : null;
  final result = await useCase.execute(StartOrContinueRatingInput(
    sessionId: session.id,
    walkOrderMode: walkOrder,
    customPlotIds: customIds,
  ));
  if (!context.mounted) return;
  if (!result.success ||
      result.trial == null ||
      result.session == null ||
      result.allPlotsSerpentine == null ||
      result.assessments == null ||
      result.startPlotIndex == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.errorMessage ??
            'Unable to continue session for this trial.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  final resolvedTrial = result.trial!;
  final resolvedSession = result.session!;
  final plots = result.allPlotsSerpentine!;
  final assessments = result.assessments!;
  int startIndex = result.startPlotIndex!;
  int? initialAssessmentIndex;
  final pos = SessionResumeStore(prefs).getPosition(resolvedSession.id);
  if (pos != null) {
    final resolved = pos.resolveResumeStart(
      plots: plots,
      fallbackStartIndex: startIndex,
      assessmentCount: assessments.length,
    );
    startIndex = resolved.$1;
    initialAssessmentIndex = resolved.$2;
  }
  LastSessionStore(prefs).save(resolvedTrial.id, resolvedSession.id);
  if (!context.mounted) return;
  final scaleMap = buildRatingScaleMap(
    trialAssessments: ref
            .read(trialAssessmentsForTrialProvider(resolvedTrial.id))
            .valueOrNull ??
        <TrialAssessment>[],
    definitions: ref.read(assessmentDefinitionsProvider).valueOrNull ??
        <AssessmentDefinition>[],
    trialIdForLog: resolvedTrial.id,
  );
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (_) => RatingScreen(
        trial: resolvedTrial,
        session: resolvedSession,
        plot: plots[startIndex],
        assessments: assessments,
        allPlots: plots,
        currentPlotIndex: startIndex,
        initialAssessmentIndex: initialAssessmentIndex,
        scaleMap: scaleMap,
      ),
    ),
    (route) => route.isFirst,
  );
}

Future<void> _exportAllTrials(BuildContext context, WidgetRef ref) async {
  final trials = ref.read(trialsStreamProvider).value ?? [];
  if (trials.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No trials to export')),
      );
    }
    return;
  }
  final guard = ref.read(exportGuardProvider);
  final ran = await guard.runExclusive(() async {
    final useCase = ref.read(exportTrialClosedSessionsUsecaseProvider);
    final user = await ref.read(currentUserProvider.future);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting all trials...')),
    );
    final files = <XFile>[];
    int exportedCount = 0;
    for (final trial in trials) {
      if (!context.mounted) return;
      final result = await useCase.execute(
        trialId: trial.id,
        trialName: trial.name,
        exportedByDisplayName: user?.displayName,
      );
      if (result.success && result.filePath != null) {
        files.add(XFile(result.filePath!));
        exportedCount += result.sessionCount;
      }
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No closed sessions to export. Close sessions first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    try {
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        files,
        text:
            'Agnexis – ${files.length} trial export(s), $exportedCount session(s)',
        sharePositionOrigin: box == null
            ? const Rect.fromLTWH(0, 0, 100, 100)
            : box.localToGlobal(Offset.zero) & box.size,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Exported ${files.length} trial(s), $exportedCount session(s)')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Export failed — please try again. If the problem persists, check trial data for missing or incomplete records.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  });
  if (!ran && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(ExportGuard.busyMessage)),
    );
  }
}

class TrialListScreen extends ConsumerStatefulWidget {
  const TrialListScreen({
    super.key,
    this.workspaceFilter = TrialListFilter.all,
    this.titleOverride,
    this.onBackTap,
  });

  final TrialListFilter workspaceFilter;
  final String? titleOverride;
  final VoidCallback? onBackTap;

  @override
  ConsumerState<TrialListScreen> createState() => _TrialListScreenState();
}

class _TrialListScreenState extends ConsumerState<TrialListScreen> {
  String _searchQuery = '';
  final _searchFocusNode = FocusNode();
  final _searchController = TextEditingController();
  _TrialListStatusFilter _statusFilter = _TrialListStatusFilter.all;
  _TrialListSortMode _sortMode = _TrialListSortMode.newestCreated;

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trialsAsync = switch (widget.workspaceFilter) {
      TrialListFilter.standaloneOnly => ref.watch(customTrialsProvider),
      TrialListFilter.protocolOnly => ref.watch(protocolTrialsProvider),
      TrialListFilter.all => ref.watch(trialsStreamProvider),
    };
    final openTrialIds =
        ref.watch(openTrialIdsForFieldWorkProvider).valueOrNull ?? <int>{};

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppDesignTokens.primary,
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppDesignTokens.spacing16,
                    12, AppDesignTokens.spacing16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1: title + grouped toolbar (search lives in field only)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.onBackTap != null)
                                IconButton(
                                  padding: const EdgeInsets.only(right: 4),
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                  icon: const Icon(Icons.arrow_back,
                                      color: Colors.white),
                                  tooltip: 'Back',
                                  onPressed: widget.onBackTap,
                                ),
                              Flexible(
                                child: Text(
                                  widget.titleOverride ?? 'My Trials',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppDesignTokens.headerTitleStyle(
                                    fontSize: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _TrialListToolbarActions(
                          onExport: () => _exportAllTrials(context, ref),
                          onOpenImportSheet: () =>
                              ImportTrialSheet.show(context),
                          onAbout: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AboutScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Row 2: compact stat chips (when trials exist)
                    trialsAsync.when(
                      loading: () => const SizedBox(height: 6),
                      error: (e, __) => AppErrorHint(error: e),
                      data: (trials) {
                        if (trials.isEmpty) {
                          return const SizedBox(height: 6);
                        }
                        final activeCount = trials
                            .where((t) => _trialMatchesActiveListFilter(
                                  t,
                                  openTrialIds,
                                ))
                            .length;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              _CompactCountPill(
                                value: '${trials.length}',
                                label: 'Trials',
                              ),
                              const SizedBox(width: 8),
                              _CompactCountPill(
                                value: '$activeCount',
                                label: 'Active',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // Row 3: search field (shared for Custom and Protocol Trials)
                    trialsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, __) => AppErrorHint(error: e),
                      data: (trials) {
                        if (trials.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            style: const TextStyle(
                              color: AppDesignTokens.primaryText,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(
                                Icons.search,
                                size: 22,
                                color: AppDesignTokens.secondaryText,
                              ),
                              hintText: 'Search trials',
                              hintStyle: TextStyle(
                                color: AppDesignTokens.secondaryText
                                    .withValues(alpha: 0.85),
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear,
                                        color: AppDesignTokens.secondaryText,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                          _searchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                            onChanged: (value) =>
                                setState(() => _searchQuery = value.trim()),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            height: 8,
            decoration: const BoxDecoration(
              color: AppDesignTokens.backgroundSurface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
          ),
          Expanded(
            child: trialsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (trials) {
                if (trials.isEmpty) {
                  return _buildEmptyState(
                    context,
                    widget.workspaceFilter,
                  );
                }
                final displayed = _deriveDisplayedTrials(
                  trials: trials,
                  searchQuery: _searchQuery,
                  statusFilter: _statusFilter,
                  sortMode: _sortMode,
                  trialIdsWithOpenFieldSession: openTrialIds,
                );
                String? noResultsMessage;
                if (displayed.isEmpty) {
                  if (_searchQuery.trim().isNotEmpty) {
                    noResultsMessage = 'No trials match "$_searchQuery"';
                  } else if (_statusFilter != _TrialListStatusFilter.all) {
                    noResultsMessage = 'No trials match this filter.';
                  } else {
                    noResultsMessage =
                        _emptyListMessage(widget.workspaceFilter);
                  }
                }
                return _buildTrialList(
                  context,
                  ref,
                  displayed,
                  sortMode: _sortMode,
                  onSortChanged: (m) => setState(() => _sortMode = m),
                  noResultsMessage: noResultsMessage,
                  filterChipsRow: _buildFilterChipsRow(),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton:
          widget.workspaceFilter == TrialListFilter.protocolOnly
              ? null
              : FloatingActionButton(
                  heroTag: 'new_custom_trial',
                  onPressed: () => _openStandaloneTrialWizard(context),
                  backgroundColor: AppDesignTokens.primary,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
    );
  }

  Widget _buildFilterChipsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatusFilterChip(_TrialListStatusFilter.all, 'All'),
          const SizedBox(width: 6),
          _buildStatusFilterChip(_TrialListStatusFilter.active, 'Active'),
          const SizedBox(width: 6),
          _buildStatusFilterChip(_TrialListStatusFilter.closed, 'Closed'),
          const SizedBox(width: 6),
          _buildStatusFilterChip(_TrialListStatusFilter.archived, 'Archived'),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(_TrialListStatusFilter value, String label) {
    final selected = _statusFilter == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _statusFilter = value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppDesignTokens.primary
                : AppDesignTokens.cardSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppDesignTokens.primary
                  : AppDesignTokens.borderCrisp,
              width: 1,
            ),
            boxShadow: selected
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected
                  ? AppDesignTokens.onPrimary
                  : AppDesignTokens.secondaryText,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  /// Empty state when no trials exist. Message varies by workspace filter.
  Widget _buildEmptyState(
    BuildContext context,
    TrialListFilter filter,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final (String title, String subtitle) = switch (filter) {
      TrialListFilter.standaloneOnly => (
          'No trials yet',
          'Create your first custom trial to begin',
        ),
      TrialListFilter.protocolOnly => (
          'No trials yet',
          'Import a protocol CSV to add your first protocol trial.',
        ),
      TrialListFilter.all => (
          'No trials yet',
          'Create your first field trial to begin collecting research data.',
        ),
    };
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDesignTokens.spacing16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.energy_savings_leaf,
                size: 48,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Message when filtered list is empty (trials exist but none match filter).
  String _emptyListMessage(TrialListFilter filter) {
    return switch (filter) {
      TrialListFilter.standaloneOnly => 'No custom trials in this view.',
      TrialListFilter.protocolOnly => 'No protocol trials in this view.',
      TrialListFilter.all => 'No trials to show.',
    };
  }

  Widget _buildTrialList(
    BuildContext context,
    WidgetRef ref,
    List<Trial> trials, {
    required _TrialListSortMode sortMode,
    required ValueChanged<_TrialListSortMode> onSortChanged,
    String? noResultsMessage,
    required Widget filterChipsRow,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppDesignTokens.spacing16, 0,
          AppDesignTokens.spacing16, AppDesignTokens.spacing24),
      children: [
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: AppDesignTokens.bgWarm,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppDesignTokens.borderCrisp),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Trials',
                        style: AppDesignTokens.bodyCrispStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppDesignTokens.secondaryText,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    PopupMenuButton<_TrialListSortMode>(
                      tooltip: 'Sort: ${_sortModeLabel(sortMode)}',
                      onSelected: onSortChanged,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, right: 4),
                        child: Icon(
                          Icons.sort,
                          size: 20,
                          color:
                              AppDesignTokens.primary.withValues(alpha: 0.85),
                        ),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _TrialListSortMode.newestCreated,
                          child: Text(
                              _sortModeLabel(_TrialListSortMode.newestCreated)),
                        ),
                        PopupMenuItem(
                          value: _TrialListSortMode.oldestCreated,
                          child: Text(
                              _sortModeLabel(_TrialListSortMode.oldestCreated)),
                        ),
                        PopupMenuItem(
                          value: _TrialListSortMode.nameAz,
                          child:
                              Text(_sortModeLabel(_TrialListSortMode.nameAz)),
                        ),
                        PopupMenuItem(
                          value: _TrialListSortMode.nameZa,
                          child:
                              Text(_sortModeLabel(_TrialListSortMode.nameZa)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              filterChipsRow,
            ],
          ),
        ),
        if (noResultsMessage == null && trials.isNotEmpty)
          const SizedBox(height: AppDesignTokens.spacing12),
        if (noResultsMessage != null)
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: AppDesignTokens.spacing16),
            child: Center(
              child: Text(
                noResultsMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ) ??
                    const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...List.generate(
            trials.length,
            (i) {
              final t = trials[i];
              final attentionAsync = ref.watch(trialAttentionProvider(t.id));
              final topUrgent = attentionAsync.valueOrNull
                  ?.where(
                    (item) =>
                        item.severity == AttentionSeverity.high &&
                        item.type != AttentionType.openSession,
                  )
                  .firstOrNull;
              final attentionSummary = (t.status == kTrialStatusDraft ||
                      t.status == kTrialStatusReady ||
                      t.status == kTrialStatusActive)
                  ? topUrgent?.label
                  : null;
              return Padding(
                padding:
                    const EdgeInsets.only(bottom: AppDesignTokens.spacing12),
                child: TrialCard(
                  trial: t,
                  index: i + 1,
                  totalCount: trials.length,
                  attentionSummary: attentionSummary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => TrialDetailScreen(trial: t),
                    ),
                  ),
                  onQuickRate: () => _quickRateFromList(context, ref, t),
                  onResume: (session) =>
                      _navigateToRatingForSession(context, ref, t, session),
                ),
              );
            },
          ),
      ],
    );
  }

  /// Opens [TrialCreationWizard] for new standalone trials.
  void _openStandaloneTrialWizard(BuildContext context) {
    assert(
      widget.workspaceFilter != TrialListFilter.protocolOnly,
      'Protocol list uses Import Trial sheet, not manual create FAB',
    );
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const TrialCreationWizard(),
      ),
    );
  }
}

/// Compact stat pill for header: value + label (e.g. "12" / "Trials").
/// Grouped header actions: export, optional unified Import sheet, about.
class _TrialListToolbarActions extends StatelessWidget {
  const _TrialListToolbarActions({
    required this.onExport,
    required this.onOpenImportSheet,
    required this.onAbout,
  });

  final VoidCallback onExport;
  final VoidCallback onOpenImportSheet;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    Widget sep() => Container(
          width: 1,
          height: 22,
          color: Colors.white.withValues(alpha: 0.28),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TrialListToolbarIcon(
            icon: Icons.file_upload_outlined,
            tooltip: 'Export closed sessions (ZIP per trial)',
            onPressed: onExport,
          ),
          sep(),
          _TrialListToolbarIcon(
            icon: Icons.download_outlined,
            tooltip: 'Import',
            onPressed: onOpenImportSheet,
          ),
          sep(),
          _TrialListToolbarIcon(
            icon: Icons.info_outline,
            tooltip: 'About',
            onPressed: onAbout,
          ),
        ],
      ),
    );
  }
}

class _TrialListToolbarIcon extends StatelessWidget {
  const _TrialListToolbarIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: Colors.white, size: 22),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

class _CompactCountPill extends StatelessWidget {
  final String value;
  final String label;

  const _CompactCountPill({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
