import 'package:flutter/material.dart';

import '../../core/design/app_design_tokens.dart';

/// Reusable card container with consistent styling only.
/// Use for white surfaces with border and subtle shadow.
/// Does not enforce layout logic.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(
          color: AppDesignTokens.borderCrisp,
          width: AppDesignTokens.borderWidthCrisp,
        ),
        boxShadow: AppDesignTokens.cardShadow,
      ),
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );
  }
}
