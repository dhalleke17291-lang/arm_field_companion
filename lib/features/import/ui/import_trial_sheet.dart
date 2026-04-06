import 'package:flutter/material.dart';

import '../../../core/design/app_design_tokens.dart';
import '../../arm_import/arm_import_screen.dart';
import '../../protocol_import/protocol_import_screen.dart';

/// Bottom sheet: choose ARM CSV, Protocol CSV, or (when available) shell link.
class ImportTrialSheet extends StatelessWidget {
  const ImportTrialSheet({
    super.key,
    required this.parentContext,
  });

  final BuildContext parentContext;

  /// Presents the sheet; routes use [parentContext] after the sheet is closed.
  static Future<void> show(BuildContext parentContext) {
    return showModalBottomSheet<void>(
      context: parentContext,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ImportTrialSheet(parentContext: parentContext),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDesignTokens.spacing16,
          AppDesignTokens.spacing12,
          AppDesignTokens.spacing16,
          AppDesignTokens.spacing24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppDesignTokens.spacing16),
                decoration: BoxDecoration(
                  color: AppDesignTokens.borderCrisp,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Import Trial',
              style: AppDesignTokens.bodyCrispStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppDesignTokens.primaryText,
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing16),
            _ImportOptionTile(
              icon: Icons.table_chart_outlined,
              title: 'Import from ARM (CSV)',
              subtitle: 'Use an ARM export CSV for ARM-linked trials',
              onTap: () {
                Navigator.pop(context);
                Navigator.push<void>(
                  parentContext,
                  MaterialPageRoute<void>(
                    builder: (_) => const ArmImportScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: AppDesignTokens.spacing8),
            _ImportOptionTile(
              icon: Icons.file_download_outlined,
              title: 'Import Protocol (CSV)',
              subtitle: 'Use the AgQuest protocol CSV format',
              onTap: () {
                Navigator.pop(context);
                Navigator.push<void>(
                  parentContext,
                  MaterialPageRoute<void>(
                    builder: (_) => const ProtocolImportScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: AppDesignTokens.spacing8),
            const _ImportOptionTile(
              icon: Icons.link_outlined,
              title: 'Link ARM Rating Shell',
              subtitle: 'Store an empty ARM shell for export back to ARM',
              enabled: false,
              trailingBadge: 'Coming soon',
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportOptionTile extends StatelessWidget {
  const _ImportOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
    this.trailingBadge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final String? trailingBadge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? AppDesignTokens.cardSurface
          : AppDesignTokens.cardSurface.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.spacing12,
            vertical: AppDesignTokens.spacing12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 24,
                color: enabled
                    ? AppDesignTokens.primary
                    : AppDesignTokens.secondaryText,
              ),
              const SizedBox(width: AppDesignTokens.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? AppDesignTokens.primaryText
                            : AppDesignTokens.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppDesignTokens.secondaryText.withValues(
                          alpha: enabled ? 0.9 : 0.65,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingBadge != null) ...[
                const SizedBox(width: 8),
                Text(
                  trailingBadge!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
