import 'package:flutter/material.dart';
import '../design/app_design_tokens.dart';

/// Prototype-style gradient header for screens. Use for consistent top bars.
class GradientScreenHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const GradientScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleLine2,
    this.leading,
    this.actions,
    this.titleFontSize = 22,
  });

  final String title;
  final String? subtitle;
  /// Optional second line under [subtitle] (e.g. BBCH · DAT · DAS).
  final String? subtitleLine2;
  final Widget? leading;
  final List<Widget>? actions;
  final double titleFontSize;

  static const Color g800 = Color(0xFF2D5A40);
  static const Color g700 = Color(0xFF3D7A57);

  /// Tall enough for title + optional subtitle + optional second line (up to 2 lines),
  /// plus [Padding] (8+16) — must leave cross-axis room for the leading [IconButton] (~48).
  double get _preferredHeight {
    const topPad = 8.0;
    const bottomPad = 16.0;
    const verticalPadding = topPad + bottomPad;
    // Text stack height (title + optional lines).
    var textBlock = titleFontSize * 1.35;
    if (subtitle != null && subtitle!.trim().isNotEmpty) {
      textBlock += 4 + 17;
    }
    if (subtitleLine2 != null && subtitleLine2!.trim().isNotEmpty) {
      // Two lines at 12px (tall descenders / dense BBCH · weather · timing) + gap.
      textBlock += 2 + 44;
    }
    // Row cross-axis = max(leading/actions height, text column).
    const minCrossAxisForToolbar = 48.0;
    final body = textBlock > minCrossAxisForToolbar ? textBlock : minCrossAxisForToolbar;
    return (verticalPadding + body).clamp(kToolbarHeight + 24, 150);
  }

  @override
  Size get preferredSize => Size.fromHeight(_preferredHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
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
        child: Theme(
          data: ThemeData.dark().copyWith(
            iconTheme: const IconThemeData(color: Colors.white),
            textTheme: ThemeData.dark().textTheme,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading ??
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      iconSize: 24,
                      padding: const EdgeInsets.all(8),
                      style: IconButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back',
                    ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppDesignTokens.headerTitleStyle(
                          fontSize: titleFontSize,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: AppDesignTokens.bodyCrispStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.88),
                            fontWeight: FontWeight.w500,
                          ).copyWith(letterSpacing: 0.2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (subtitleLine2 != null &&
                          subtitleLine2!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitleLine2!,
                          style: AppDesignTokens.bodyCrispStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.82),
                            fontWeight: FontWeight.w500,
                          ).copyWith(letterSpacing: 0.15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (actions != null && actions!.isNotEmpty)
                  Flexible(
                    fit: FlexFit.loose,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: actions!,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
