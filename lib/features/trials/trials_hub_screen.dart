import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/app_design_tokens.dart';
import '../shell/shell_providers.dart';
import 'trial_list_screen.dart';
import 'trials_hub_providers.dart';
import 'trials_portfolio_screen.dart';

/// Soothing light-mode palette inspired by ag research references.
class _HubPalette {
  _HubPalette._();
  static const Color background = AppDesignTokens.backgroundSurface;
  static const Color textPrimary = AppDesignTokens.primaryText;
  static const Color textSecondary = AppDesignTokens.secondaryText;
  static const Color accentGreen = AppDesignTokens.primary;
  static const Color accentAmber = Color(0xFFB8860B); // no token equivalent
  static const Color mutedGrey = AppDesignTokens.emptyBadgeFg;
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
      portfolioInitialWorkspace: isCustom
          ? PortfolioWorkspaceSegment.custom
          : PortfolioWorkspaceSegment.protocol,
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
                    _PortfolioHubCard(
                      onOpen: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const TrialsPortfolioScreen(
                              initialWorkspace: PortfolioWorkspaceSegment.all,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppDesignTokens.spacing24),
                    _AgTrialCard(
                      title: 'Custom Trials',
                      subtitle: 'Full trial design with templates',
                      description:
                          'RCBD/CRD randomization, statistical analysis, and evidence tracking',
                      icon: Icons.science_outlined,
                      accentColor: _HubPalette.accentGreen,
                      topBadgeLeft: 'CUSTOM',
                      topBadgeRight: stats.customCropCount == 1
                          ? '1 Crop'
                          : '${stats.customCropCount} Crops',
                      footerStats: [
                        _trialTotalLabel(stats.customTrialCount),
                        '${stats.customActiveCount} Active',
                        '${stats.customCompleteCount} Complete',
                      ],
                      footerDotColor: _HubPalette.accentGreen,
                      onTap: () => setState(() => _view = _HubView.customList),
                    ),
                    const SizedBox(height: AppDesignTokens.spacing24),
                    _AgTrialCard(
                      title: 'Protocol Trials',
                      subtitle: 'Import Rating Shells',
                      description:
                          'Collect data with full evidence tracking, export results via Rating Shell',
                      icon: Icons.assignment_outlined,
                      accentColor: _HubPalette.accentAmber,
                      topBadgeLeft: 'PROTOCOL',
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

/// Entry to [TrialsPortfolioScreen] from the hub.
class _PortfolioHubCard extends StatelessWidget {
  const _PortfolioHubCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.spacing16,
            vertical: AppDesignTokens.spacing12,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _HubPalette.accentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.dashboard_customize_outlined,
                  color: _HubPalette.accentGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Portfolio',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppDesignTokens.primaryText,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Cross-trial priority, open sessions, and recent activity',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.25,
                        color: _HubPalette.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
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
    required this.icon,
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
  final IconData icon;
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
              color: AppDesignTokens.cardSurface,
              child: InkWell(
                onTap: widget.onTap,
                child: Stack(
                  children: [
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
                                      color:
                                          Colors.black.withValues(alpha: 0.15),
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
