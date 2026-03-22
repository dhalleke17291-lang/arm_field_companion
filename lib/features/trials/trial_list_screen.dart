import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_info.dart';
import '../../core/config/app_info.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/export_guard.dart';
import '../../core/providers.dart';
import '../../core/last_session_store.dart';
import '../../core/session_resume_store.dart';
import '../../core/plot_sort.dart';
import '../../core/session_walk_order_store.dart';
import '../../core/database/app_database.dart';
import '../../core/workspace/workspace_config.dart';
import '../../core/workspace/workspace_filter.dart';
import '../../core/widgets/app_dialog.dart';
import '../about/about_screen.dart';
import '../protocol_import/protocol_import_screen.dart';
import 'usecases/create_trial_usecase.dart';
import 'trial_detail_screen.dart';
import 'widgets/trial_card.dart';
import '../sessions/usecases/start_or_continue_rating_usecase.dart';
import '../sessions/usecases/create_session_usecase.dart';
import '../ratings/rating_screen.dart';
// Spacing/padding refinements use AppDesignTokens. To reverse: revert trial_list_screen.dart, trial_detail_screen.dart, session_detail_screen.dart.

/// Workspace filter for trial list. Client-side only; no repository changes.
enum TrialListFilter {
  all,
  standaloneOnly,
  protocolOnly,
}

enum _TrialListStatusFilter { all, active, draft, closed, archived }

enum _TrialListSortMode { newestCreated, oldestCreated, nameAz, nameZa }

/// Client-side only: search → status filter → sort. Assumes [trials] already filtered by provider.
List<Trial> _deriveDisplayedTrials({
  required List<Trial> trials,
  required String searchQuery,
  required _TrialListStatusFilter statusFilter,
  required _TrialListSortMode sortMode,
}) {
  var list = trials;
  final q = searchQuery.trim().toLowerCase();
  Iterable<Trial> afterSearch = list;
  if (q.isNotEmpty) {
    afterSearch = list.where((t) {
      bool fieldContains(String? s) =>
          s != null && s.toLowerCase().contains(q);
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
          .where((t) => t.status.toLowerCase() == 'active')
          .toList();
      break;
    case _TrialListStatusFilter.draft:
      filtered =
          filtered.where((t) => t.status.toLowerCase() == 'draft').toList();
      break;
    case _TrialListStatusFilter.closed:
      filtered =
          filtered.where((t) => t.status.toLowerCase() == 'closed').toList();
      break;
    case _TrialListStatusFilter.archived:
      filtered = filtered
          .where((t) => t.status.toLowerCase() == 'archived')
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
  final dateStr =
      '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

  List<int> assessmentIds;
  final legacy = await ref.read(assessmentsForTrialProvider(trial.id).future);
  if (legacy.isNotEmpty) {
    assessmentIds = legacy.map((a) => a.id).toList();
  } else {
    final trialPairs = await ref.read(
        trialAssessmentsWithDefinitionsForTrialProvider(trial.id).future);
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
    final trialRepo = ref.read(trialAssessmentRepositoryProvider);
    assessmentIds =
        await trialRepo.getOrCreateLegacyAssessmentIdsForTrialAssessments(
      trial.id,
      trialPairs.map((p) => p.$1.id).toList(),
    );
    if (assessmentIds.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not resolve assessments for this trial.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
  }

  final createUseCase = ref.read(createSessionUseCaseProvider);
  final createResult = await createUseCase.execute(CreateSessionInput(
    trialId: trial.id,
    name: '$dateStr Quick',
    sessionDateLocal: dateStr,
    assessmentIds: assessmentIds,
  ));

  if (!context.mounted) return;
  if (!createResult.success || createResult.session == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(createResult.errorMessage ?? 'Could not create session.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  final session = createResult.session!;
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

void _showAppInfoDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(AppInfo.appName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ignore: prefer_const_constructors - string is not constant (kAppVersion)
          Text('Version $kAppVersion', style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            AboutScreen.developerCredit,
            style: TextStyle(
                fontSize: 13,
                color:
                    Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.8)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
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
  final customIds = walkOrder == WalkOrderMode.custom ? store.getCustomOrder(session.id) : null;
  final result = await useCase.execute(
      StartOrContinueRatingInput(
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
  if (pos != null && pos.$1 >= 0 && pos.$1 < plots.length) {
    startIndex = pos.$1;
    initialAssessmentIndex = pos.$2.clamp(0, assessments.length - 1);
  }
  LastSessionStore(prefs).save(resolvedTrial.id, resolvedSession.id);
  if (!context.mounted) return;
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
          'Ag-Quest Field Companion – ${files.length} trial export(s), $exportedCount session(s)',
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
        SnackBar(
            content: Text('Export failed: $e'), backgroundColor: Colors.red),
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

    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppDesignTokens.primary,
                  AppDesignTokens.primaryLight,
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppDesignTokens.spacing16,
                    10,
                    AppDesignTokens.spacing16,
                    10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1: title + actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.onBackTap != null)
                              IconButton(
                                icon: const Icon(Icons.arrow_back,
                                    color: Colors.white),
                                tooltip: 'Back',
                                onPressed: widget.onBackTap,
                              ),
                            Text(
                              widget.titleOverride ?? 'My Trials',
                              style: AppDesignTokens.headerTitleStyle(
                                fontSize: 20,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.search, color: Colors.white),
                              tooltip: 'Search trials',
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                                _searchFocusNode.requestFocus();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.file_upload_outlined,
                                  color: Colors.white),
                              tooltip:
                                  'Export closed sessions (ZIP per trial)',
                              onPressed: () => _exportAllTrials(context, ref),
                            ),
                            IconButton(
                              icon: const Icon(Icons.file_download_outlined,
                                  color: Colors.white),
                              tooltip: 'Import Protocol',
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const ProtocolImportScreen())),
                            ),
                            IconButton(
                              icon: const Icon(Icons.info_outline,
                                  color: Colors.white),
                              tooltip: 'About',
                              onPressed: () => _showAppInfoDialog(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Row 2: compact stat chips (when trials exist)
                    trialsAsync.when(
                      loading: () => const SizedBox(height: 6),
                      error: (_, __) => const SizedBox(height: 6),
                      data: (trials) {
                        if (trials.isEmpty) {
                          return const SizedBox(height: 6);
                        }
                        final activeCount = trials
                            .where((t) => t.status.toLowerCase() == 'active')
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
                      error: (_, __) => const SizedBox.shrink(),
                      data: (trials) {
                        if (trials.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              prefixIcon: Icon(
                                Icons.search,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              hintText: 'Search trials',
                              hintStyle: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
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
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
          ),
          Expanded(
            child: trialsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (trials) {
                if (trials.isEmpty) return _buildEmptyState(context, widget.workspaceFilter);
                final displayed = _deriveDisplayedTrials(
                  trials: trials,
                  searchQuery: _searchQuery,
                  statusFilter: _statusFilter,
                  sortMode: _sortMode,
                );
                String? noResultsMessage;
                if (displayed.isEmpty) {
                  if (_searchQuery.trim().isNotEmpty) {
                    noResultsMessage =
                        'No trials match "$_searchQuery"';
                  } else if (_statusFilter != _TrialListStatusFilter.all) {
                    noResultsMessage = 'No trials match this filter.';
                  } else {
                    noResultsMessage = _emptyListMessage(widget.workspaceFilter);
                  }
                }
                return _buildTrialList(
                    context,
                    ref,
                    displayed,
                    sortMode: _sortMode,
                    onSortChanged: (m) =>
                        setState(() => _sortMode = m),
                    noResultsMessage: noResultsMessage,
                    filterChipsRow: _buildFilterChipsRow(),
                  );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FilledButton.tonalIcon(
        onPressed: () => _showCreateTrialDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Trial'),
      ),
    );
  }

  Widget _buildFilterChipsRow() {
    return Padding(
      padding: const EdgeInsets.only(
        left: 0,
        right: 0,
        top: 4,
        bottom: 6,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatusFilterChip(
                _TrialListStatusFilter.all, 'All'),
            const SizedBox(width: 4),
            _buildStatusFilterChip(
                _TrialListStatusFilter.active, 'Active'),
            const SizedBox(width: 4),
            _buildStatusFilterChip(
                _TrialListStatusFilter.draft, 'Draft'),
            const SizedBox(width: 4),
            _buildStatusFilterChip(
                _TrialListStatusFilter.closed, 'Closed'),
            const SizedBox(width: 4),
            _buildStatusFilterChip(
                _TrialListStatusFilter.archived, 'Archived'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilterChip(_TrialListStatusFilter value, String label) {
    final selected = _statusFilter == value;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _statusFilter = value),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.12)
                : scheme.surfaceContainerHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.25)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: selected
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  /// Empty state when no trials exist. Message varies by workspace filter.
  Widget _buildEmptyState(BuildContext context, TrialListFilter filter) {
    final scheme = Theme.of(context).colorScheme;
    final (String title, String subtitle) = switch (filter) {
      TrialListFilter.standaloneOnly => (
          'No trials yet',
          'Create your first custom trial to begin',
        ),
      TrialListFilter.protocolOnly => (
          'No trials yet',
          'Create your first protocol trial to begin',
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
        _ContinueLastSessionSection(
          onNavigate: (trial, session) =>
              _navigateToRatingForSession(context, ref, trial, session),
          workspaceFilter: widget.workspaceFilter,
        ),
        // Section header: quiet label + sort
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Trials',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                      ) ??
                      TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    size: 18,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.8),
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _TrialListSortMode.newestCreated,
                    child: Text(_sortModeLabel(_TrialListSortMode.newestCreated)),
                  ),
                  PopupMenuItem(
                    value: _TrialListSortMode.oldestCreated,
                    child: Text(_sortModeLabel(_TrialListSortMode.oldestCreated)),
                  ),
                  PopupMenuItem(
                    value: _TrialListSortMode.nameAz,
                    child: Text(_sortModeLabel(_TrialListSortMode.nameAz)),
                  ),
                  PopupMenuItem(
                    value: _TrialListSortMode.nameZa,
                    child: Text(_sortModeLabel(_TrialListSortMode.nameZa)),
                  ),
                ],
              ),
            ],
          ),
        ),
        filterChipsRow,
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
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: TrialCard(
                  trial: t,
                  index: i + 1,
                  totalCount: trials.length,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => TrialDetailScreen(trial: t),
                    ),
                  ),
                  onContinueSession: (Session session) =>
                      _navigateToRatingForSession(context, ref, t, session),
                  onQuickRate: () => _quickRateFromList(context, ref, t),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTrialTypeOption(
    BuildContext context,
    String title,
    String description,
    bool selected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : const Color(0xFFE8E2D8),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected
                    ? theme.colorScheme.primary
                    : const Color(0xFF1A2E20),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolSubtypeChip(
    BuildContext context,
    WorkspaceType type,
    bool selected,
    VoidCallback onSelected,
  ) {
    final config = WorkspaceConfig.forType(type);
    return ChoiceChip(
      label: Text(config.displayName),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }

  Future<void> _showCreateTrialDialog(
      BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final cropController = TextEditingController();
    final locationController = TextEditingController();
    final seasonController = TextEditingController();
    bool isCustomTrial = false;
    WorkspaceType selectedProtocolSubtype = WorkspaceType.efficacy;

    await showDialog(
      context: context,
      builder: (context) => AppDialog(
        title: 'New Trial',
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatefulBuilder(
              builder: (context, setLocalState) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trial type',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTrialTypeOption(
                          context,
                          'Custom Trials',
                          'Flexible, user-defined trials without strict protocol structure',
                          isCustomTrial,
                          () => setLocalState(() => isCustomTrial = true),
                        ),
                        _buildTrialTypeOption(
                          context,
                          'Protocol Trials',
                          'Structured trials based on standardized protocols (ARM-compatible)',
                          !isCustomTrial,
                          () =>
                              setLocalState(() => isCustomTrial = false),
                        ),
                      ],
                    ),
                    if (!isCustomTrial) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final type
                                in [WorkspaceType.variety, WorkspaceType.efficacy, WorkspaceType.glp])
                              _buildProtocolSubtypeChip(
                                context,
                                type,
                                selectedProtocolSubtype == type,
                                () => setLocalState(
                                    () => selectedProtocolSubtype = type),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Trial Name *',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cropController,
              decoration: const InputDecoration(
                labelText: 'Crop',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: seasonController,
              decoration: const InputDecoration(
                labelText: 'Season',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final useCase = ref.read(createTrialUseCaseProvider);
              final workspaceType = isCustomTrial
                  ? WorkspaceType.standalone
                  : selectedProtocolSubtype;
              final result = await useCase.execute(CreateTrialInput(
                name: nameController.text,
                crop: cropController.text.isEmpty ? null : cropController.text,
                location: locationController.text.isEmpty
                    ? null
                    : locationController.text,
                season: seasonController.text.isEmpty
                    ? null
                    : seasonController.text,
                workspaceType: workspaceType.name,
              ));

              if (context.mounted) {
                Navigator.pop(context);
                if (result.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Trial "${result.trial?.name}" created'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.errorMessage ?? 'Error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

/// Format session date for card subtitle (e.g. "11 Mar 2026").
String _formatSessionDateForCard(String sessionDateLocal) {
  final d = DateTime.tryParse('$sessionDateLocal 12:00:00');
  if (d == null) return sessionDateLocal;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final month = d.month >= 1 && d.month <= 12 ? months[d.month - 1] : '';
  return '${d.day} $month ${d.year}';
}

/// Client-side: does [trial] match [workspaceFilter]? Uses same helpers as providers.
bool _trialMatchesWorkspaceFilter(Trial trial, TrialListFilter workspaceFilter) {
  switch (workspaceFilter) {
    case TrialListFilter.all:
      return true;
    case TrialListFilter.standaloneOnly:
      return isStandalone(trial.workspaceType);
    case TrialListFilter.protocolOnly:
      return isProtocol(trial.workspaceType);
  }
}

/// Persistent "Continue Last Session" card (survives app restarts).
/// Isolate ref.watch(lastSessionContextProvider) so it disposes cleanly (avoids _dependents.isEmpty).
/// Respects [workspaceFilter]: only shows when last session's trial matches the filter.
class _ContinueLastSessionSection extends ConsumerWidget {
  const _ContinueLastSessionSection({
    required this.onNavigate,
    required this.workspaceFilter,
  });

  final void Function(Trial trial, Session session) onNavigate;
  final TrialListFilter workspaceFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastSessionAsync = ref.watch(lastSessionContextProvider);
    return lastSessionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (ctx) {
        if (ctx == null) return const SizedBox.shrink();
        if (!_trialMatchesWorkspaceFilter(ctx.trial, workspaceFilter)) {
          return const SizedBox.shrink();
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ContinueLastSessionCard(
              trial: ctx.trial,
              session: ctx.session,
              onTap: () => onNavigate(ctx.trial, ctx.session),
            ),
            const SizedBox(height: AppDesignTokens.spacing16),
          ],
        );
      },
    );
  }
}

class _ContinueLastSessionCard extends StatelessWidget {
  final Trial trial;
  final Session session;
  final VoidCallback onTap;

  const _ContinueLastSessionCard({
    required this.trial,
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE8E2D8)),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.play_circle_filled,
                    color: Color(0xFF16A34A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Continue Last Session',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF16A34A),
                          letterSpacing: 0.35,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trial.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_formatSessionDateForCard(session.sessionDateLocal)} · ${session.name}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF8FA898), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact stat pill for header: value + label (e.g. "12" / "Trials").
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

