import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../more/more_screen.dart';
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

  static const int _workLogTabIndex = 1;

  static const _tabs = [
    _NavItem(
        label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home),
    _NavItem(
        label: 'Work Log',
        icon: Icons.work_history_outlined,
        selectedIcon: Icons.work_history),
    _NavItem(
        label: 'More', icon: Icons.more_horiz, selectedIcon: Icons.more_horiz),
  ];

  @override
  Widget build(BuildContext context) {
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
                      ref.invalidate(workLogDatesProvider);
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
                              : AppDesignTokens.iconSubtle,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? AppDesignTokens.primary
                                : AppDesignTokens.secondaryText,
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
