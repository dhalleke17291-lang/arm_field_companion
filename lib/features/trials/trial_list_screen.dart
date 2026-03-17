import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_info.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/last_session_store.dart';
import '../../core/session_resume_store.dart';
import '../../core/plot_sort.dart';
import '../../core/session_walk_order_store.dart';
import '../../core/database/app_database.dart';
import '../../core/crop_icons.dart';
import '../../core/widgets/app_dialog.dart';
import '../about/about_screen.dart';
import '../protocol_import/protocol_import_screen.dart';
import 'usecases/create_trial_usecase.dart';
import 'trial_detail_screen.dart';
import '../sessions/usecases/start_or_continue_rating_usecase.dart';
import '../sessions/usecases/create_session_usecase.dart';
import '../ratings/rating_screen.dart';
// Spacing/padding refinements use AppDesignTokens. To reverse: revert trial_list_screen.dart, trial_detail_screen.dart, session_detail_screen.dart.

void _showAppInfoDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(AboutScreen.appName),
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
}

class TrialListScreen extends ConsumerStatefulWidget {
  const TrialListScreen({super.key});

  @override
  ConsumerState<TrialListScreen> createState() => _TrialListScreenState();
}

class _TrialListScreenState extends ConsumerState<TrialListScreen> {
  String _searchQuery = '';
  final _searchFocusNode = FocusNode();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trialsAsync = ref.watch(trialsStreamProvider);

    const g800 = Color(0xFF2D5A40);
    const g700 = Color(0xFF3D7A57);
    const bgWarm = Color(0xFFF4F1EB);
    return Scaffold(
      backgroundColor: bgWarm,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [g800, g700],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppDesignTokens.spacing16,
                    AppDesignTokens.spacing16,
                    AppDesignTokens.spacing16,
                    AppDesignTokens.spacing24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'My Trials',
                          style: AppDesignTokens.headerTitleStyle(
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.search, color: Colors.white),
                              tooltip: 'Search trials by name',
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
                                  'Export all trial data (closed sessions)',
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
                    trialsAsync.when(
                      loading: () =>
                          const SizedBox(height: AppDesignTokens.spacing12),
                      error: (_, __) =>
                          const SizedBox(height: AppDesignTokens.spacing12),
                      data: (trials) {
                        final active = trials
                            .where((t) => t.status.toLowerCase() == 'active')
                            .length;
                        return Padding(
                          padding: const EdgeInsets.only(
                              top: AppDesignTokens.spacing24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                      child: _summaryPill(context,
                                          '${trials.length}', 'Trials')),
                                  const SizedBox(
                                      width: AppDesignTokens.spacing12),
                                  Expanded(
                                      child: _summaryPill(
                                          context, '$active', 'Active')),
                                ],
                              ),
                              if (trials.isNotEmpty) ...[
                                const SizedBox(
                                    height: AppDesignTokens.spacing12),
                                TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: 'Search trials by name...',
                                    hintStyle: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.7),
                                        fontSize: 14),
                                    prefixIcon: const Icon(Icons.search,
                                        color: Colors.white70, size: 22),
                                    suffixIcon:
                                        _searchController.text.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear,
                                                    color: Colors.white70,
                                                    size: 20),
                                                onPressed: () {
                                                  setState(() {
                                                    _searchController.clear();
                                                    _searchQuery = '';
                                                  });
                                                },
                                              )
                                            : null,
                                    filled: true,
                                    fillColor:
                                        Colors.white.withValues(alpha: 0.15),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                  ),
                                  onChanged: (value) => setState(
                                      () => _searchQuery = value.trim()),
                                ),
                              ],
                            ],
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
            height: 20,
            decoration: const BoxDecoration(
              color: bgWarm,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Expanded(
            child: trialsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (trials) {
                if (trials.isEmpty) return _buildEmptyState(context);
                final filtered = _searchQuery.isEmpty
                    ? trials
                    : trials
                        .where((t) => t.name
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()))
                        .toList();
                if (filtered.isEmpty && _searchQuery.isNotEmpty) {
                  return _buildTrialList(context, ref, filtered,
                      noResultsMessage: 'No trials match "$_searchQuery"');
                }
                return _buildTrialList(context, ref, filtered);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTrialDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Trial'),
      ),
    );
  }

  Widget _summaryPill(BuildContext context, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppDesignTokens.spacing8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: Column(
        children: [
          Text(value,
              style: AppDesignTokens.headerTitleStyle(
                  fontSize: 20, color: Colors.white)),
          const SizedBox(height: 1),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            const Text(
              'No Trials Yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first field trial to begin collecting research data.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialList(
      BuildContext context, WidgetRef ref, List<Trial> trials,
      {String? noResultsMessage}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppDesignTokens.spacing16, 0,
          AppDesignTokens.spacing16, AppDesignTokens.spacing24),
      children: [
        _ContinueLastSessionSection(
          onNavigate: (trial, session) =>
              _navigateToRatingForSession(context, ref, trial, session),
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Recent Trials',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A6358),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: AppDesignTokens.spacing16),
        if (noResultsMessage != null)
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: AppDesignTokens.spacing16),
            child: Center(
              child: Text(
                noResultsMessage,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppDesignTokens.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...trials.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing12),
              child: _TrialCard(trial: t),
            ),
          ),
      ],
    );
  }

  Future<void> _showCreateTrialDialog(
      BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final cropController = TextEditingController();
    final locationController = TextEditingController();
    final seasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AppDialog(
        title: 'New Trial',
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              final result = await useCase.execute(CreateTrialInput(
                name: nameController.text,
                crop: cropController.text.isEmpty ? null : cropController.text,
                location: locationController.text.isEmpty
                    ? null
                    : locationController.text,
                season: seasonController.text.isEmpty
                    ? null
                    : seasonController.text,
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

/// Persistent "Continue Last Session" card (survives app restarts).
/// Isolate ref.watch(lastSessionContextProvider) so it disposes cleanly (avoids _dependents.isEmpty).
class _ContinueLastSessionSection extends ConsumerWidget {
  const _ContinueLastSessionSection({required this.onNavigate});

  final void Function(Trial trial, Session session) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastSessionAsync = ref.watch(lastSessionContextProvider);
    return lastSessionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (ctx) {
        if (ctx == null) return const SizedBox.shrink();
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
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppDesignTokens.spacing16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE8E2D8)),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.play_circle_filled,
                    color: Color(0xFF16A34A),
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppDesignTokens.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Continue Last Session',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF16A34A),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trial.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_formatSessionDateForCard(session.sessionDateLocal)} · ${session.name}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF8FA898)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrialCard extends StatelessWidget {
  final Trial trial;

  const _TrialCard({required this.trial});

  @override
  Widget build(BuildContext context) {
    final style = cropStyleFor(trial.crop);
    final metadata = [
      if (trial.crop != null) trial.crop!,
      if (trial.location != null) trial.location!,
      if (trial.season != null) trial.season!,
    ].join(' • ');
    final statusLower = trial.status.toLowerCase();
    final isActive = statusLower == 'active';
    final isDraft = statusLower == 'draft';
    final badgeBg = isActive
        ? const Color(0xFFE8F2EC)
        : isDraft
            ? const Color(0xFFFFF4DC)
            : const Color(0xFFEFF6FF);
    final badgeFg = isActive
        ? const Color(0xFF3D7A57)
        : isDraft
            ? const Color(0xFFC97A0A)
            : const Color(0xFF2563EB);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E2D8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D5A40).withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => TrialDetailScreen(trial: trial),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: style.lightColor,
                        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
                      ),
                      child: Icon(style.icon, color: style.color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  trial.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A2E20),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              if (trial.status.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    trial.status,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: badgeFg,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (metadata.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              metadata,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8FA898),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 18, color: Color(0xFF8FA898)),
                  ],
                ),
                const SizedBox(height: 10),
                _TrialQuickActions(trial: trial),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quick actions row under each trial card: Continue, Quick Rate, Details.
class _TrialQuickActions extends ConsumerWidget {
  final Trial trial;

  const _TrialQuickActions({required this.trial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openSessionAsync = ref.watch(openSessionProvider(trial.id));

    return openSessionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (openSession) {
        final hasOpenSession = openSession != null;
        return Row(
          children: [
            if (hasOpenSession)
              TextButton.icon(
                onPressed: () =>
                    _continueLastSession(context, ref, trial, openSession),
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: const Text('Continue Session'),
              ),
            if (!hasOpenSession)
              TextButton.icon(
                onPressed: () => _quickRate(context, ref, trial),
                icon: const Icon(Icons.flash_on, size: 18),
                label: const Text('Quick Rate'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _continueLastSession(
    BuildContext context,
    WidgetRef ref,
    Trial trial,
    Session session,
  ) async {
    await _navigateToRatingForSession(context, ref, trial, session);
  }

  Future<void> _quickRate(
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
          content: Text(result.errorMessage ?? 'Unable to start rating.'),
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
}
