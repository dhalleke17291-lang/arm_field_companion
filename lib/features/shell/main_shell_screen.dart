import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/last_session_store.dart';
import '../../core/plot_sort.dart';
import '../../core/providers.dart';
import '../../core/session_resume_store.dart';
import '../../core/session_state.dart';
import '../../core/session_walk_order_store.dart';
import '../backup/backup_passphrase_store.dart';
import '../more/more_screen.dart';
import '../ratings/rating_screen.dart';
import '../sessions/usecases/start_or_continue_rating_usecase.dart';
import '../worklog/work_log_screen.dart';
import '../trials/trials_hub_screen.dart';
import 'shell_providers.dart';

/// Bottom nav: Home | Work Log | More. Used after splash when user is signed in.
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _currentIndex = 0;
  bool _initialTabResolved = false;
  bool _passphraseCheckDone = false;

  static const int _workLogTabIndex = 1;

  static const _tabs = [
    _NavItem(
        label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home),
    _NavItem(
        label: 'Sessions',
        icon: Icons.play_circle_outline,
        selectedIcon: Icons.play_circle),
    _NavItem(
        label: 'More', icon: Icons.more_horiz, selectedIcon: Icons.more_horiz),
  ];

  @override
  Widget build(BuildContext context) {
    // On first build, start on Work Log if any open session exists.
    if (!_initialTabResolved) {
      _initialTabResolved = true;
      final openIds = ref.read(openTrialIdsForFieldWorkProvider).valueOrNull;
      if (openIds != null && openIds.isNotEmpty) {
        _currentIndex = _workLogTabIndex;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _resumeRatingIfNeeded());
      }
    }
    if (!_passphraseCheckDone) {
      _passphraseCheckDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _promptPassphraseIfNeeded();
      });
    }
    return _buildScaffold(context);
  }

  Future<void> _resumeRatingIfNeeded() async {
    if (!mounted) return;
    final openIds = ref.read(openTrialIdsForFieldWorkProvider).valueOrNull;
    if (openIds == null || openIds.isEmpty) return;

    final sessionRepo = ref.read(sessionRepositoryProvider);
    Session? latestSession;
    for (final trialId in openIds) {
      final session = await sessionRepo.getOpenSession(trialId);
      if (session == null || !isSessionOpenForFieldWork(session)) continue;
      if (latestSession == null ||
          session.startedAt.isAfter(latestSession.startedAt)) {
        latestSession = session;
      }
    }
    if (latestSession == null || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final store = SessionWalkOrderStore(prefs);
    final walkOrder = store.getMode(latestSession.id);
    final customIds = walkOrder == WalkOrderMode.custom
        ? store.getCustomOrder(latestSession.id)
        : null;
    final useCase = ref.read(startOrContinueRatingUseCaseProvider);
    final result = await useCase.execute(StartOrContinueRatingInput(
      sessionId: latestSession.id,
      walkOrderMode: walkOrder,
      customPlotIds: customIds,
    ));
    if (!mounted) return;
    if (!result.success ||
        result.trial == null ||
        result.session == null ||
        result.allPlotsSerpentine == null ||
        result.assessments == null ||
        result.startPlotIndex == null) {
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
    if (!mounted) return;
    Navigator.push(
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
    );
  }

  Future<void> _promptPassphraseIfNeeded() async {
    if (!mounted) return;
    final store = BackupPassphraseStore();
    final hasCached = await store.hasCached();
    if (hasCached || !mounted) return;

    final controller = TextEditingController();
    final confirmController = TextEditingController();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          var error = '';
          return AlertDialog(
            title: const Text('Set up backup passphrase'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your data is valuable. Set a passphrase to enable '
                  'automatic encrypted backups after every session.\n\n'
                  'Without this, photos and ratings cannot be recovered '
                  'if your phone is lost or the app is reinstalled.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppDesignTokens.secondaryText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Passphrase',
                    hintText: 'At least 6 characters',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm passphrase',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(error,
                      style: const TextStyle(
                          color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Skip for now'),
              ),
              FilledButton(
                onPressed: () async {
                  final pass = controller.text;
                  final confirm = confirmController.text;
                  if (pass.length < 6) {
                    setDialogState(() =>
                        error = 'Passphrase must be at least 6 characters');
                    return;
                  }
                  if (pass != confirm) {
                    setDialogState(
                        () => error = 'Passphrases do not match');
                    return;
                  }
                  await store.save(pass);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Backup passphrase saved. Auto-backup is now active.'),
                        backgroundColor: AppDesignTokens.successBg,
                      ),
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppDesignTokens.primary,
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          TrialsHubScreen(),
          WorkLogScreen(),
          MoreScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppDesignTokens.cardSurface,
          border: Border(
            top: BorderSide(color: AppDesignTokens.borderCrisp),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDesignTokens.spacing8,
              horizontal: AppDesignTokens.spacing16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (int i) {
                final item = _tabs[i];
                final selected = _currentIndex == i;
                return InkWell(
                  onTap: () {
                    if (i == _workLogTabIndex) {
                      ref.invalidate(allActiveSessionsProvider);
                    }
                    if (i == 0) {
                      ref.read(homeTabResetProvider.notifier).state++;
                    }
                    setState(() => _currentIndex = i);
                  },
                  borderRadius:
                      BorderRadius.circular(AppDesignTokens.radiusSmall),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDesignTokens.spacing16,
                      vertical: AppDesignTokens.spacing12,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected ? item.selectedIcon : item.icon,
                          size: 26,
                          color: selected
                              ? AppDesignTokens.primary
                              : AppDesignTokens.primaryText,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                            color: selected
                                ? AppDesignTokens.primary
                                : AppDesignTokens.primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
