import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/widgets/loading_error_widgets.dart';

const Map<String, String> _categoryLabels = {
  'crop_injury': 'Crop Injury',
  'disease': 'Disease',
  'weed': 'Weed',
  'growth': 'Growth',
  'yield': 'Yield',
  'phenology': 'Phenology',
  'quality': 'Quality',
  'custom': 'Custom',
};

String _categoryLabel(String category) =>
    _categoryLabels[category] ?? category;

class AssessmentLibraryPickerDialog extends ConsumerWidget {
  final int trialId;

  const AssessmentLibraryPickerDialog({super.key, required this.trialId});

  static Future<void> show(BuildContext context, int trialId) {
    return showDialog<void>(
      context: context,
      builder: (context) => AssessmentLibraryPickerDialog(trialId: trialId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definitionsAsync = ref.watch(assessmentDefinitionsProvider);
    final trialListAsync = ref.watch(trialAssessmentsForTrialProvider(trialId));

    return AlertDialog(
      title: const Text('Add from library'),
      content: SizedBox(
        width: double.maxFinite,
        child: definitionsAsync.when(
          loading: () => const AppLoadingView(),
          error: (e, st) => AppErrorView(
            error: e,
            stackTrace: st,
            onRetry: () => ref.invalidate(assessmentDefinitionsProvider),
          ),
          data: (definitions) {
            if (definitions.isEmpty) {
              return const Center(
                child: Text('No assessment templates in the library.'),
              );
            }
            final alreadyIds = trialListAsync.valueOrNull
                    ?.map((ta) => ta.assessmentDefinitionId)
                    .toSet() ??
                {};
            final byCategory = <String, List<AssessmentDefinition>>{};
            for (final d in definitions) {
              byCategory.putIfAbsent(d.category, () => []).add(d);
            }
            final categories = byCategory.keys.toList()..sort();

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Select an assessment template to add to this trial.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ...categories.map((cat) {
                    final list = byCategory[cat]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            _categoryLabel(cat),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        ...list.map((def) {
                          final already = alreadyIds.contains(def.id);
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.analytics_outlined,
                              size: 22,
                              color: already
                                  ? Theme.of(context).colorScheme.outline
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            title: Text(
                              def.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: already
                                    ? Theme.of(context).colorScheme.outline
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                              '${def.dataType}${def.unit != null ? " (${def.unit})" : ""}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: already
                                ? const Icon(Icons.check, size: 20, color: Colors.green)
                                : null,
                            onTap: already
                                ? null
                                : () async {
                                    await ref
                                        .read(trialAssessmentRepositoryProvider)
                                        .addToTrial(
                                          trialId: trialId,
                                          assessmentDefinitionId: def.id,
                                          selectedManually: true,
                                        );
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                          );
                        }),
                        const SizedBox(height: 8),
                      ],
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
