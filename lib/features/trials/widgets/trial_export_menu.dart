part of '../trial_detail_screen.dart';

class TrialExportMenu extends StatelessWidget {
  final bool isExporting;
  final VoidCallback onExportTapped;
  final Color? badgeColor;

  const TrialExportMenu({
    super.key,
    required this.isExporting,
    required this.onExportTapped,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isExporting ? null : onExportTapped,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.ios_share_outlined,
              size: 20,
              color: AppDesignTokens.primary,
            ),
            const SizedBox(width: 6),
            const Text(
              'Export',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.primary,
              ),
            ),
            if (badgeColor != null) ...[
              const SizedBox(width: 5),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badgeColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
