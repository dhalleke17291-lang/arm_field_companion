import 'dart:ui' show ColorFilter, ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/last_session_store.dart';
import '../../core/plot_sort.dart';
import '../../core/providers.dart';
import '../../core/session_resume_store.dart';
import '../../core/session_walk_order_store.dart';
import '../ratings/rating_screen.dart';
import '../sessions/usecases/start_or_continue_rating_usecase.dart';
import '../shell/shell_providers.dart';
import 'trial_list_screen.dart';
import 'trials_hub_providers.dart';

/// Soothing light-mode palette inspired by ag research references.
class _HubPalette {
  _HubPalette._();
  static const Color background    = AppDesignTokens.backgroundSurface;
  static const Color textPrimary   = AppDesignTokens.primaryText;
  static const Color textSecondary = AppDesignTokens.secondaryText;
  static const Color accentGreen   = AppDesignTokens.primary;
  static const Color accentAmber   = Color(0xFFB8860B); // no token equivalent
  static const Color mutedGrey     = AppDesignTokens.emptyBadgeFg;
}

/// Top-level Trials Hub: Custom Trials vs Protocol Trials.
/// Switches between hub view and embedded filtered TrialListScreen.
class TrialsHubScreen extends ConsumerStatefulWidget {
  const TrialsHubScreen({super.key});

  @override
  ConsumerState<TrialsHubScreen> createState() => _TrialsHubScreenState();
}

enum _HubView { hub, customList, protocolList }

class _TrialsHubScreenState extends ConsumerState<TrialsHubScreen>
    with SingleTickerProviderStateMixin {
  _HubView _view = _HubView.hub;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(homeTabResetProvider, (_, __) {
      if (mounted) setState(() => _view = _HubView.hub);
    });
    if (_view == _HubView.hub) {
      return _buildHubView();
    }
    final isCustom = _view == _HubView.customList;
    return TrialListScreen(
      workspaceFilter: isCustom
          ? TrialListFilter.standaloneOnly
          : TrialListFilter.protocolOnly,
      titleOverride: isCustom ? 'Custom Trials' : 'Protocol Trials',
      onBackTap: () => setState(() => _view = _HubView.hub),
    );
  }

  String _timeGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning — select a trial type to begin';
    if (h < 17) return 'Good afternoon — select a trial type to begin';
    return 'Good evening — select a trial type to begin';
  }

  /// Hub footer total line — matches trial list “N Trials” (includes Draft / Ready).
  static String _trialTotalLabel(int count) =>
      count == 1 ? '1 Trial' : '$count Trials';

  Widget _buildHubView() {
    final statsAsync = ref.watch(trialsHubStatsProvider);
    final stats = statsAsync.valueOrNull ?? TrialsHubStats.zero;

    return Scaffold(
      backgroundColor: _HubPalette.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppDesignTokens.spacing24,
                  AppDesignTokens.spacing24,
                  AppDesignTokens.spacing24,
                  AppDesignTokens.spacing32 + AppDesignTokens.spacing8,
                ),
                child: Column(
                  children: [
                    _ContinueSessionCard(ref: ref),
                    _AgTrialCard(
                      title: 'Custom Trials',
                      subtitle: 'Design your own experiments',
                      description:
                          'Flexible, user-defined trials without strict protocol structure',
                      icon: Icons.science_outlined,
                      imageAsset: 'assets/images/trials/custom_trials_field.jpg',
                      accentColor: _HubPalette.accentGreen,
                      topBadgeLeft: 'CUSTOM PLOT',
                      topBadgeRight: stats.customCropCount == 1
                          ? '1 Crop'
                          : '${stats.customCropCount} Crops',
                      footerStats: [
                        _trialTotalLabel(stats.customTrialCount),
                        '${stats.customActiveCount} Active',
                        '${stats.customCompleteCount} Complete',
                      ],
                      footerDotColor: _HubPalette.accentGreen,
                      onTap: () =>
                          setState(() => _view = _HubView.customList),
                    ),
                    const SizedBox(height: AppDesignTokens.spacing24),
                    _AgTrialCard(
                      title: 'Protocol Trials',
                      subtitle: 'Pre-validated methodologies',
                      description:
                          'Structured trials based on standardized protocols',
                      descriptionFootnote: '(Import compatible)',
                      icon: Icons.assignment_outlined,
                      imageAsset:
                          'assets/images/trials/protocol_trials_greenhouse.jpg',
                      accentColor: _HubPalette.accentAmber,
                      topBadgeLeft: 'STANDARDIZED',
                      topBadgeRight: stats.protocolTrialCount == 1
                          ? '1 Protocol'
                          : '${stats.protocolTrialCount} Protocols',
                      footerStats: [
                        _trialTotalLabel(stats.protocolTrialCount),
                        '${stats.protocolActiveCount} Active',
                        '${stats.protocolCompleteCount} Complete',
                      ],
                      footerDotColor: _HubPalette.accentAmber,
                      onTap: () =>
                          setState(() => _view = _HubView.protocolList),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: _HubPalette.accentGreen,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDesignTokens.spacing24,
            28,
            AppDesignTokens.spacing24,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trials',
                          style: AppDesignTokens.headerTitleStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'AG RESEARCH PLATFORM',
                          style: AppDesignTokens.bodyCrispStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _timeGreeting(),
                style: AppDesignTokens.bodyCrispStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ag-themed card with photo background, floating shadow, badges, and stats.
class _AgTrialCard extends StatefulWidget {
  const _AgTrialCard({
    required this.title,
    required this.subtitle,
    required this.description,
    this.descriptionFootnote,
    required this.icon,
    required this.imageAsset,
    required this.accentColor,
    required this.topBadgeLeft,
    required this.topBadgeRight,
    required this.footerStats,
    required this.footerDotColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String description;
  final String? descriptionFootnote;
  final IconData icon;
  final String imageAsset;
  final Color accentColor;
  final String topBadgeLeft;
  final String topBadgeRight;
  final List<String> footerStats;
  final Color footerDotColor;
  final VoidCallback onTap;

  @override
  State<_AgTrialCard> createState() => _AgTrialCardState();
}

class _AgTrialCardState extends State<_AgTrialCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) => _scaleController.reverse(),
      onTapCancel: () => _scaleController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppDesignTokens.tileShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                child: Stack(
                  children: [
                    // Photo background: minimal desaturation, soft yet visible
                    Positioned.fill(
                      child: ColorFiltered(
                        colorFilter: ColorFilter.saturation(0.72),
                        child: Image.asset(
                          widget.imageAsset,
                          fit: BoxFit.cover,
                          semanticLabel: 'Trial category background',
                          errorBuilder: (_, __, ___) => Container(
                            color: widget.accentColor.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                    // Light blur: soft, not too much
                    Positioned.fill(
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                    ),
                    // Soothing gradient overlay; text area stays clear for readability
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _HubPalette.background.withValues(alpha: 0.05),
                              _HubPalette.background.withValues(alpha: 0.25),
                              _HubPalette.background.withValues(alpha: 0.65),
                              _HubPalette.background.withValues(alpha: 0.92),
                            ],
                            stops: const [0.0, 0.3, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Top badges
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.accentColor.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.topBadgeLeft,
                          style: AppDesignTokens.bodyCrispStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.topBadgeRight,
                          style: AppDesignTokens.bodyCrispStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ),
                    // Content area
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDesignTokens.spacing20,
                        AppDesignTokens.spacing20,
                        AppDesignTokens.spacing20,
                        AppDesignTokens.spacing20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 36),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: widget.accentColor,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.accentColor
                                          .withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  widget.icon,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: AppDesignTokens.spacing16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: AppDesignTokens.headerTitleStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700,
                                        color: _HubPalette.textPrimary,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      widget.subtitle,
                                      style: AppDesignTokens.bodyCrispStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: widget.accentColor,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      widget.description,
                                      style: AppDesignTokens.bodyCrispStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _HubPalette.textPrimary,
                                        letterSpacing: 0.12,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (widget.descriptionFootnote != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.descriptionFootnote!,
                                        style: AppDesignTokens.bodyCrispStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _HubPalette.textPrimary,
                                          letterSpacing: 0.06,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppDesignTokens.spacing12),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _HubPalette.accentGreen,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              for (var i = 0;
                                  i < widget.footerStats.length;
                                  i++) ...[
                                if (i > 0)
                                  const SizedBox(
                                      width: AppDesignTokens.spacing20),
                                _FooterStat(
                                  label: widget.footerStats[i],
                                  dotColor: i < 2
                                      ? widget.footerDotColor
                                      : _HubPalette.mutedGrey,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterStat extends StatelessWidget {
  const _FooterStat({
    required this.label,
    required this.dotColor,
  });

  final String label;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppDesignTokens.bodyCrispStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _HubPalette.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Shows a "Continue Session" card when an open session exists.
/// Hidden when no open session. One tap resumes rating at saved position.
class _ContinueSessionCard extends StatelessWidget {
  const _ContinueSessionCard({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final lastCtx = ref.watch(lastSessionContextProvider).valueOrNull;
    if (lastCtx == null) return const SizedBox.shrink();
    final trial = lastCtx.trial;
    final session = lastCtx.session;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing16),
      child: Material(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _navigateToRating(context, trial, session),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppDesignTokens.borderCrisp),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppDesignTokens.openSessionBg.withValues(alpha: 0.08),
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
                    color: AppDesignTokens.openSessionBgLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.play_circle_filled,
                    color: AppDesignTokens.openSessionBg,
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
                        'Continue Session',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppDesignTokens.openSessionBg,
                          letterSpacing: 0.35,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${session.name} · ${trial.name}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppDesignTokens.primaryText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppDesignTokens.secondaryText.withValues(alpha: 0.75),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToRating(
    BuildContext context,
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
          content: Text(result.errorMessage ?? 'Unable to resume session.'),
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
}
