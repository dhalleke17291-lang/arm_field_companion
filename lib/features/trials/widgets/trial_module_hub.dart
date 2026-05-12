part of '../trial_detail_screen.dart';

class TrialModuleHub extends StatelessWidget {
  final ScrollController scrollController;
  final WorkspaceConfig workspaceConfig;
  final bool isArmLinked;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onUserScroll;

  const TrialModuleHub({
    super.key,
    required this.scrollController,
    required this.workspaceConfig,
    required this.isArmLinked,
    required this.selectedIndex,
    required this.onSelected,
    this.onUserScroll,
  });

  @override
  Widget build(BuildContext context) {
    // All possible hub items mapped to their fixed IndexedStack index.
    // Overview (8) is always shown; module tabs use TrialTab for visibility.
    // ARM Protocol (9) is shown only for ARM-linked trials.
    // Trial Overview (10) is always shown — Sprint A4.
    const allItems = <(int, IconData, String, TrialTab?)>[
      (_overviewTabIndex, Icons.dashboard_outlined, 'Overview', null),
      (_trialOverviewTabIndex, Icons.fact_check_outlined, 'Trial Review', null),
      (6, Icons.timeline, 'Timeline', TrialTab.timeline),
      (0, Icons.grid_on, 'Plots', TrialTab.plots),
      (1, Icons.agriculture, 'Seeding', TrialTab.seeding),
      (3, Icons.assessment, 'Assessments', TrialTab.assessments),
      (4, Icons.science_outlined, 'Treatments', TrialTab.treatments),
      (2, Icons.science, 'Applications', TrialTab.applications),
      (5, Icons.photo_library, 'Photos', TrialTab.photos),
    ];

    final items = [
      ...allItems.where((item) =>
          item.$4 == null || workspaceConfig.visibleTabs.contains(item.$4!)),
      if (isArmLinked)
        (
          _armProtocolTabIndex,
          Icons.biotech_outlined,
          'Field Plan',
          null as TrialTab?
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 380;
        final padLeft = narrow ? 8.0 : AppDesignTokens.spacing16;
        final padRight = narrow ? 12.0 : 48.0;
        final sepW = narrow ? 6.0 : AppDesignTokens.spacing12;

        final listView = ListView.separated(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.hardEdge,
          padding: EdgeInsets.only(left: padLeft, right: padRight),
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => SizedBox(width: sepW),
          itemBuilder: (context, index) {
            final item = items[index];
            return DockTile(
              icon: item.$2,
              label: item.$3,
              compact: narrow,
              selected: selectedIndex == item.$1,
              onTap: () => onSelected(item.$1),
            );
          },
        );

        final content = onUserScroll != null
            ? NotificationListener<ScrollStartNotification>(
                onNotification: (ScrollStartNotification notification) {
                  if (notification.dragDetails != null) {
                    onUserScroll!();
                  }
                  return false;
                },
                child: listView,
              )
            : listView;

        return ClipRect(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppDesignTokens.backgroundSurface,
              border: Border(
                bottom: BorderSide(
                  color: AppDesignTokens.borderCrisp.withValues(alpha: 0.45),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppDesignTokens.spacing8,
                bottom: AppDesignTokens.spacing8,
              ),
              child: content,
            ),
          ),
        );
      },
    );
  }
}

class DockTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const DockTile({
    super.key,
    required this.icon,
    required this.label,
    this.compact = false,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = compact ? 6.0 : AppDesignTokens.spacing12;
    final vPad = compact ? 6.0 : AppDesignTokens.spacing8;
    final iconSize =
        selected ? (compact ? 22.0 : 26.0) : (compact ? 19.0 : 22.0);
    final fontSize =
        selected ? (compact ? 11.5 : 13.0) : (compact ? 11.0 : 12.0);

    return AnimatedScale(
      alignment: Alignment.center,
      scale: selected ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected
                    ? AppDesignTokens.primary
                    : AppDesignTokens.primaryText,
                size: iconSize,
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? AppDesignTokens.primary
                      : AppDesignTokens.primaryText,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: fontSize,
                ),
              ),
              SizedBox(height: compact ? 2 : 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 2,
                width: selected ? (compact ? 16 : 20) : 0,
                decoration: BoxDecoration(
                  color: AppDesignTokens.primary,
                  borderRadius: BorderRadius.circular(1),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
