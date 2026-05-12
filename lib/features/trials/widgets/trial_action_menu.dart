part of '../trial_detail_screen.dart';

class TrialActionMenu extends ConsumerWidget {
  final Trial trial;
  final VoidCallback onDelete;

  const TrialActionMenu({
    super.key,
    required this.trial,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      iconSize: 24,
      tooltip: 'More',
      padding: const EdgeInsets.all(8),
      onSelected: (value) {
        if (value == 'activity') {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AuditLogScreen(trialId: trial.id),
            ),
          );
        } else if (value == 'trial_data') {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => TrialDataScreen(trial: trial),
            ),
          );
        } else if (value == 'trial_intent') {
          showTrialIntentSheet(context, ref, trial: trial);
        } else if (value == 'delete_trial') {
          onDelete();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'activity',
          child: Text('Activity'),
        ),
        const PopupMenuItem<String>(
          value: 'trial_intent',
          child: Text('Trial intent'),
        ),
        const PopupMenuItem<String>(
          value: 'trial_data',
          child: Text('Trial data'),
        ),
        const PopupMenuItem<String>(
          value: 'delete_trial',
          child: Text('Delete trial'),
        ),
      ],
    );
  }
}
