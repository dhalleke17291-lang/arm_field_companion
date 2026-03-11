import 'package:flutter/material.dart';
import '../design/app_design_tokens.dart';

/// Prototype-style gradient header for screens. Use for consistent top bars.
class GradientScreenHeader extends StatelessWidget implements PreferredSizeWidget {
  const GradientScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.titleFontSize = 22,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final double titleFontSize;

  static const Color g800 = Color(0xFF2D5A40);
  static const Color g700 = Color(0xFF3D7A57);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 24);

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
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: Row(
            children: [
              leading ??
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
        ),
        ),
      ),
    );
  }
}
