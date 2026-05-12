part of '../trial_detail_screen.dart';

class TrialExportMenu extends StatelessWidget {
  final bool isExporting;
  final VoidCallback onExportTapped;

  const TrialExportMenu({
    super.key,
    required this.isExporting,
    required this.onExportTapped,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isExporting ? null : onExportTapped,
      borderRadius: BorderRadius.circular(8),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.ios_share_outlined,
              size: 20,
              color: AppDesignTokens.primary,
            ),
            SizedBox(width: 6),
            Text(
              'Export',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
