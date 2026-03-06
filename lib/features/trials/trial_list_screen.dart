import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/database/app_database.dart';
import '../../core/crop_icons.dart';
import 'usecases/create_trial_usecase.dart';
import 'trial_detail_screen.dart';

class TrialListScreen extends ConsumerWidget {
  const TrialListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trialsAsync = ref.watch(trialsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ag-Quest Field Companion'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: trialsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (trials) => trials.isEmpty
            ? _buildEmptyState(context)
            : _buildTrialList(context, ref, trials),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTrialDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Trial'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.energy_savings_leaf,
              size: 80, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          const Text('No trials yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Tap + New Trial to get started',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTrialList(
      BuildContext context, WidgetRef ref, List<Trial> trials) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: trials.length,
      itemBuilder: (context, index) {
        final trial = trials[index];
        return _TrialCard(trial: trial);
      },
    );
  }

  Future<void> _showCreateTrialDialog(
      BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final cropController = TextEditingController();
    final locationController = TextEditingController();
    final seasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Trial'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Trial Name *',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cropController,
                decoration: const InputDecoration(
                  labelText: 'Crop',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: seasonController,
                decoration: const InputDecoration(
                  labelText: 'Season',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final useCase = ref.read(createTrialUseCaseProvider);
              final result = await useCase.execute(CreateTrialInput(
                name: nameController.text,
                crop: cropController.text.isEmpty ? null : cropController.text,
                location: locationController.text.isEmpty
                    ? null
                    : locationController.text,
                season: seasonController.text.isEmpty
                    ? null
                    : seasonController.text,
              ));

              if (context.mounted) {
                Navigator.pop(context);
                if (result.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Trial "${result.trial?.name}" created'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.errorMessage ?? 'Error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _TrialCard extends StatelessWidget {
  final Trial trial;

  const _TrialCard({required this.trial});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Builder(builder: (context) {
          final style = cropStyleFor(trial.crop);
          return CircleAvatar(
            backgroundColor: style.lightColor,
            child: Icon(style.icon, color: style.color),
          );
        }),
        title: Text(
          trial.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          [
            if (trial.crop != null) trial.crop!,
            if (trial.location != null) trial.location!,
            if (trial.season != null) trial.season!,
          ].join(' • '),
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => TrialDetailScreen(trial: trial)));
        },
      ),
    );
  }
}
