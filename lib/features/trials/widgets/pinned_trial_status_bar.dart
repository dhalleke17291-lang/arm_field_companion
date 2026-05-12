part of '../trial_detail_screen.dart';

class PinnedTrialStatusBar extends ConsumerStatefulWidget {
  const PinnedTrialStatusBar({
    super.key,
    required this.trial,
    required this.onTransitionStatus,
    required this.onOpenSessions,
  });

  final Trial trial;
  final Future<void> Function(
      BuildContext context, WidgetRef ref, String newStatus) onTransitionStatus;
  final VoidCallback onOpenSessions;

  @override
  ConsumerState<PinnedTrialStatusBar> createState() =>
      PinnedTrialStatusBarState();
}

class ActiveCloseToggle extends StatefulWidget {
  const ActiveCloseToggle({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<ActiveCloseToggle> createState() => ActiveCloseToggleState();
}

class SessionsStatusBarButton extends StatelessWidget {
  const SessionsStatusBarButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppDesignTokens.primary,
      elevation: 3,
      shadowColor: AppDesignTokens.primary.withValues(alpha: 0.28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: AppDesignTokens.onPrimary.withValues(alpha: 0.24),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(10, 6, 8, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_note_rounded,
                size: 15,
                color: AppDesignTokens.onPrimary,
              ),
              SizedBox(width: 6),
              Text(
                'Sessions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppDesignTokens.onPrimary,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppDesignTokens.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
