import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/database/app_database.dart';
import '../../core/crop_icons.dart';
import '../../core/widgets/app_dialog.dart';
import '../about/about_screen.dart';
import '../protocol_import/protocol_import_screen.dart';
import 'usecases/create_trial_usecase.dart';
import 'trial_detail_screen.dart';


Future<void> _exportAllTrials(BuildContext context, WidgetRef ref) async {
  final trials = ref.read(trialsStreamProvider).value ?? [];
  if (trials.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No trials to export')),
      );
    }
    return;
  }
  final useCase = ref.read(exportTrialClosedSessionsUsecaseProvider);
  final user = await ref.read(currentUserProvider.future);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Exporting all trials...')),
  );
  final files = <XFile>[];
  int exportedCount = 0;
  for (final trial in trials) {
    if (!context.mounted) return;
    final result = await useCase.execute(
      trialId: trial.id,
      trialName: trial.name,
      exportedByDisplayName: user?.displayName,
    );
    if (result.success && result.filePath != null) {
      files.add(XFile(result.filePath!));
      exportedCount += result.sessionCount;
    }
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).clearSnackBars();
  if (files.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No closed sessions to export. Close sessions first.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }
  try {
    await Share.shareXFiles(
      files,
      text: 'ARM Field Companion – ${files.length} trial export(s), $exportedCount session(s)',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${files.length} trial(s), $exportedCount session(s)')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

class TrialListScreen extends ConsumerWidget {
  const TrialListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trialsAsync = ref.watch(trialsStreamProvider);

    const g800 = Color(0xFF2D5A40);
    const g700 = Color(0xFF3D7A57);
    const bgWarm = Color(0xFFF4F1EB);
    return Scaffold(
      backgroundColor: bgWarm,
      body: Column(
        children: [
          Container(
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'My Trials',
                          style: AppDesignTokens.headerTitleStyle(
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.file_download_outlined, color: Colors.white),
                              tooltip: 'Export all trial data (closed sessions)',
                              onPressed: () => _exportAllTrials(context, ref),
                            ),
                            IconButton(
                              icon: const Icon(Icons.file_upload_outlined, color: Colors.white),
                              tooltip: 'Import Protocol',
                              onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProtocolImportScreen())),
                            ),
                            IconButton(
                              icon: const Icon(Icons.info_outline, color: Colors.white),
                              tooltip: 'About',
                              onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AboutScreen())),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trialsAsync.when(
                      loading: () => const SizedBox(height: 12),
                      error: (_, __) => const SizedBox(height: 12),
                      data: (trials) {
                        final active = trials.where((t) => t.status.toLowerCase() == 'active').length;
                        return Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Row(
                            children: [
                              Expanded(child: _summaryPill(context, '${trials.length}', 'Trials')),
                              const SizedBox(width: 10),
                              Expanded(child: _summaryPill(context, '$active', 'Active')),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            height: 20,
            decoration: const BoxDecoration(
              color: bgWarm,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Expanded(
            child: trialsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (trials) => trials.isEmpty
                  ? _buildEmptyState(context)
                  : _buildTrialList(context, ref, trials),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTrialDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Trial'),
      ),
    );
  }

  Widget _summaryPill(BuildContext context, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value, style: AppDesignTokens.headerTitleStyle(fontSize: 20, color: Colors.white)),
          const SizedBox(height: 1),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDesignTokens.spacing16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.energy_savings_leaf,
                size: 48,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing16),
            const Text(
              'No Trials Yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first field trial to begin collecting research data.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialList(
      BuildContext context, WidgetRef ref, List<Trial> trials) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Recent Trials',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A6358),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...trials.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TrialCard(trial: t),
        )),
      ],
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
      builder: (context) => AppDialog(
        title: 'New Trial',
        scrollable: true,
        content: Column(
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
            const SizedBox(height: 16),
            TextField(
              controller: cropController,
              decoration: const InputDecoration(
                labelText: 'Crop',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: seasonController,
              decoration: const InputDecoration(
                labelText: 'Season',
                border: OutlineInputBorder(),
              ),
            ),
          ],
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
    final style = cropStyleFor(trial.crop);
    final metadata = [
      if (trial.crop != null) trial.crop!,
      if (trial.location != null) trial.location!,
      if (trial.season != null) trial.season!,
    ].join(' • ');
    final statusLower = trial.status.toLowerCase();
    final isActive = statusLower == 'active';
    final isDraft = statusLower == 'draft';
    final badgeBg = isActive ? const Color(0xFFE8F2EC) : isDraft ? const Color(0xFFFFF4DC) : const Color(0xFFEFF6FF);
    final badgeFg = isActive ? const Color(0xFF3D7A57) : isDraft ? const Color(0xFFC97A0A) : const Color(0xFF2563EB);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E2D8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D5A40).withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => TrialDetailScreen(trial: trial),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: style.lightColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(style.icon, color: style.color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  trial.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A2E20),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              if (trial.status.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    trial.status,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: badgeFg,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (metadata.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              metadata,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8FA898),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: Color(0xFF8FA898)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
