import 'package:flutter/material.dart';

import '../../core/design/app_design_tokens.dart';

/// Shared breakpoint-based layout sizing for phones vs tablets (layout-only).
///
/// Breakpoints (logical width, Flutter “dp”):
/// - **Compact** (phones): `< 600`
/// - **Medium** (tablet): `600 … 1023`
/// - **Expanded** (large tablet / desktop-ish): `>= 1024`
class ResponsiveLayout {
  const ResponsiveLayout(this.viewportWidth);

  /// Shortest-side-based layout is deliberately **not** used so landscape phones
  /// wider than 600dp still upgrade to tablet padding (matching Material guidance).
  factory ResponsiveLayout.of(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return ResponsiveLayout(w);
  }

  final double viewportWidth;

  static const double compactMaxWidth = 599;
  static const double mediumMaxWidth = 1023;

  bool get isCompact => viewportWidth <= compactMaxWidth;
  bool get isMedium => viewportWidth >= 600 && viewportWidth <= mediumMaxWidth;
  bool get isExpanded => viewportWidth >= 1024;

  /// Readable max width for centered body content on tablets. Phone: unbounded.
  double get maxContentWidth =>
      isCompact ? double.infinity : (isMedium ? 760 : 980);

  /// Extra gutter when pinching content inward on tablets. Phone: `0` (leave
  /// existing full-bleed phone layouts unchanged relative to siblings).
  double get horizontalPagePadding => isCompact
      ? 0
      : (isMedium ? AppDesignTokens.spacing16 : AppDesignTokens.spacing24);

  /// Simple grid heuristic for dashboards / cards.
  int get cardGridColumnCount {
    if (isCompact) return 1;
    if (isMedium) return 2;
    return 3;
  }

  /// Two-pane rating/workspace when there is enough width for context + entry.
  bool get shouldUseTwoPaneLayout => viewportWidth >= 840 && !isCompact;

  /// Readable cap for modal form sheets so they don’t become full-width slabs.
  double get modalSheetMaxWidth =>
      isCompact ? double.infinity : (isMedium ? 560 : 640);

  /// Clamp [maxContentWidth] to fit inside [constraintsMaxWidth] with gutters.
  double clampedReadableWidth(double constraintsMaxWidth) {
    if (isCompact || !constraintsMaxWidth.isFinite) {
      return constraintsMaxWidth;
    }
    final cap = maxContentWidth;
    final innerBudget = constraintsMaxWidth - horizontalPagePadding * 2;
    if (innerBudget <= 0) return constraintsMaxWidth;
    final target = cap.isInfinite ? innerBudget : cap.clamp(0.0, innerBudget);
    return target;
  }
}

/// Centers [child] and caps width on tablets; phones pass through unchanged.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rl = ResponsiveLayout(constraints.maxWidth);
        if (rl.isCompact) return child;
        final maxW = rl.clampedReadableWidth(constraints.maxWidth);
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: rl.horizontalPagePadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
