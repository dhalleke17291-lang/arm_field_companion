part of '../trial_detail_screen.dart';

class TrialNotesHeaderButton extends ConsumerWidget {
  final Trial trial;

  const TrialNotesHeaderButton({
    super.key,
    required this.trial,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesForTrialProvider(trial.id));
    final hasNotes = notesAsync.maybeWhen(
      data: (list) => list.isNotEmpty,
      orElse: () => false,
    );
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: 'Field notes',
          iconSize: 24,
          padding: const EdgeInsets.all(8),
          style: IconButton.styleFrom(foregroundColor: Colors.white),
          icon: const Icon(Icons.sticky_note_2_outlined),
          onPressed: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => FieldNotesListScreen(trial: trial),
              ),
            );
          },
        ),
        if (hasNotes)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}
