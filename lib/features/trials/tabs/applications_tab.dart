import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/loading_error_widgets.dart';
import '../../../shared/widgets/app_empty_state.dart';

/// Applications tab for trial detail: list and add/edit application events.
class ApplicationsTab extends ConsumerWidget {
  const ApplicationsTab({super.key, required this.trial});

  final Trial trial;

  static const List<String> _rateUnits = ['L/ha', 'kg/ha', 'g/ha', 'mL/ha', 'oz/ac'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(trialApplicationsForTrialProvider(trial.id));
    return applicationsAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, st) => AppErrorView(
        error: e,
        stackTrace: st,
        onRetry: () => ref.invalidate(trialApplicationsForTrialProvider(trial.id)),
      ),
      data: (list) => list.isEmpty
          ? _buildEmpty(context, ref)
          : _buildList(context, ref, list),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return AppEmptyState(
      icon: Icons.science,
      title: 'No Applications Yet',
      subtitle: 'Record spray, granular and other application events for this trial.',
      action: FilledButton.icon(
        onPressed: () => _showApplicationSheet(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add Application'),
      ),
    );
  }

  Widget _buildApplicationTile(
    BuildContext context,
    WidgetRef ref,
    TrialApplicationEvent e,
  ) {
    final dateStr = DateFormat('MMM d, yyyy').format(e.applicationDate);
    final productLabel = e.productName?.trim().isNotEmpty == true
        ? e.productName!
        : null;
    final treatments = ref.watch(treatmentsForTrialProvider(trial.id)).value ?? [];
    final treatment = e.treatmentId != null
        ? treatments.where((t) => t.id == e.treatmentId).firstOrNull
        : null;

    return Card(
      child: ListTile(
        title: Text(
          dateStr,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              productLabel ?? 'No product specified',
              style: TextStyle(
                color: productLabel != null
                    ? null
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            if (e.rate != null && e.rateUnit != null)
              Text(
                '${e.rate} ${e.rateUnit}',
                style: const TextStyle(fontSize: 13),
              ),
            if (treatment != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Chip(
                  label: Text(treatment.code),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => _showApplicationSheet(context, ref, e),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<TrialApplicationEvent> list) {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final e = list[index];
            return Dismissible(
              key: Key(e.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                color: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Application?'),
                    content: const Text(
                      'This application will be permanently deleted.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (_) {
                ref.read(applicationRepositoryProvider).deleteApplication(e.id);
              },
              child: _buildApplicationTile(context, ref, e),
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'add_application',
            onPressed: () => _showApplicationSheet(context, ref, null),
            icon: const Icon(Icons.add),
            label: const Text('Add Application'),
          ),
        ),
      ],
    );
  }

  Future<void> _showApplicationSheet(
    BuildContext context,
    WidgetRef ref,
    TrialApplicationEvent? existing,
  ) async {
    final repo = ref.read(applicationRepositoryProvider);
    final treatments = ref.watch(treatmentsForTrialProvider(trial.id)).value ?? [];

    final dateController = ValueNotifier<DateTime>(
      existing?.applicationDate ?? DateTime.now(),
    );
    final treatmentIdController = ValueNotifier<int?>(existing?.treatmentId);
    final productController = TextEditingController(text: existing?.productName ?? '');
    final rateController = TextEditingController(
      text: existing?.rate != null ? existing!.rate.toString() : '',
    );
    final rateUnitController = ValueNotifier<String?>(
      existing?.rateUnit ?? (existing == null ? _rateUnits.first : null),
    );
    final waterVolumeController = TextEditingController(
      text: existing?.waterVolume != null ? existing!.waterVolume.toString() : '',
    );
    final growthStageController = TextEditingController(text: existing?.growthStageCode ?? '');
    final operatorController = TextEditingController(text: existing?.operatorName ?? '');
    final equipmentController = TextEditingController(text: existing?.equipmentUsed ?? '');
    final windSpeedController = TextEditingController(
      text: existing?.windSpeed != null ? existing!.windSpeed.toString() : '',
    );
    final windDirectionController = TextEditingController(text: existing?.windDirection ?? '');
    final temperatureController = TextEditingController(
      text: existing?.temperature != null ? existing!.temperature.toString() : '',
    );
    final humidityController = TextEditingController(
      text: existing?.humidity != null ? existing!.humidity.toString() : '',
    );
    final notesController = TextEditingController(text: existing?.notes ?? '');

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final selectedDate = dateController.value;
          final selectedTreatmentId = treatmentIdController.value;
          final selectedRateUnit = rateUnitController.value ?? _rateUnits.first;
          final dateLabel = DateFormat('MMM d, yyyy').format(selectedDate);
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null ? 'Add Application' : 'Edit Application',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          dateController.value = picked;
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text('Date: $dateLabel'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      initialValue: selectedTreatmentId,
                      decoration: const InputDecoration(
                        labelText: 'Treatment',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...treatments.map(
                          (t) => DropdownMenuItem<int?>(
                            value: t.id,
                            child: Text(t.code),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        treatmentIdController.value = v;
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: productController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: rateController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Rate',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedRateUnit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(),
                            ),
                            items: _rateUnits
                                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                .toList(),
                            onChanged: (v) {
                              rateUnitController.value = v;
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: waterVolumeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Water Volume (L/ha)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: growthStageController,
                      decoration: const InputDecoration(
                        labelText: 'Growth Stage / BBCH',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: operatorController,
                      decoration: const InputDecoration(
                        labelText: 'Operator',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: equipmentController,
                      decoration: const InputDecoration(
                        labelText: 'Equipment',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Weather',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: windSpeedController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Wind Speed',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: windDirectionController,
                            decoration: const InputDecoration(
                              labelText: 'Wind Direction',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: temperatureController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Temperature (°C)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: humidityController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Humidity (%)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (existing != null) ...[
                          TextButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: ctx,
                                builder: (d) => AlertDialog(
                                  title: const Text('Delete Application?'),
                                  content: const Text(
                                    'This application will be permanently deleted.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(d, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      onPressed: () => Navigator.pop(d, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && ctx.mounted) {
                                await repo.deleteApplication(existing.id);
                                if (ctx.mounted) Navigator.pop(ctx);
                              }
                            },
                            child: const Text('Delete'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            final date = dateController.value;
                            final rate = double.tryParse(rateController.text.trim());
                            final waterVolume = double.tryParse(
                              waterVolumeController.text.trim(),
                            );
                            final windSpeed = double.tryParse(
                              windSpeedController.text.trim(),
                            );
                            final temperature = double.tryParse(
                              temperatureController.text.trim(),
                            );
                            final humidity = double.tryParse(
                              humidityController.text.trim(),
                            );
                            if (existing == null) {
                              await repo.createApplication(
                                TrialApplicationEventsCompanion.insert(
                                  trialId: trial.id,
                                  applicationDate: date,
                                  treatmentId: drift.Value(treatmentIdController.value),
                                  productName: drift.Value(
                                    productController.text.trim().isEmpty
                                        ? null
                                        : productController.text.trim(),
                                  ),
                                  rate: drift.Value(rate),
                                  rateUnit: drift.Value(
                                    rateUnitController.value?.trim().isEmpty == true
                                        ? null
                                        : rateUnitController.value,
                                  ),
                                  waterVolume: drift.Value(waterVolume),
                                  growthStageCode: drift.Value(
                                    growthStageController.text.trim().isEmpty
                                        ? null
                                        : growthStageController.text.trim(),
                                  ),
                                  operatorName: drift.Value(
                                    operatorController.text.trim().isEmpty
                                        ? null
                                        : operatorController.text.trim(),
                                  ),
                                  equipmentUsed: drift.Value(
                                    equipmentController.text.trim().isEmpty
                                        ? null
                                        : equipmentController.text.trim(),
                                  ),
                                  windSpeed: drift.Value(windSpeed),
                                  windDirection: drift.Value(
                                    windDirectionController.text.trim().isEmpty
                                        ? null
                                        : windDirectionController.text.trim(),
                                  ),
                                  temperature: drift.Value(temperature),
                                  humidity: drift.Value(humidity),
                                  notes: drift.Value(
                                    notesController.text.trim().isEmpty
                                        ? null
                                        : notesController.text.trim(),
                                  ),
                                ),
                              );
                            } else {
                              await repo.updateApplication(
                                existing.id,
                                TrialApplicationEventsCompanion(
                                  treatmentId: drift.Value(treatmentIdController.value),
                                  productName: drift.Value(
                                    productController.text.trim().isEmpty
                                        ? null
                                        : productController.text.trim(),
                                  ),
                                  rate: drift.Value(rate),
                                  rateUnit: drift.Value(
                                    rateUnitController.value?.trim().isEmpty == true
                                        ? null
                                        : rateUnitController.value,
                                  ),
                                  waterVolume: drift.Value(waterVolume),
                                  growthStageCode: drift.Value(
                                    growthStageController.text.trim().isEmpty
                                        ? null
                                        : growthStageController.text.trim(),
                                  ),
                                  operatorName: drift.Value(
                                    operatorController.text.trim().isEmpty
                                        ? null
                                        : operatorController.text.trim(),
                                  ),
                                  equipmentUsed: drift.Value(
                                    equipmentController.text.trim().isEmpty
                                        ? null
                                        : equipmentController.text.trim(),
                                  ),
                                  windSpeed: drift.Value(windSpeed),
                                  windDirection: drift.Value(
                                    windDirectionController.text.trim().isEmpty
                                        ? null
                                        : windDirectionController.text.trim(),
                                  ),
                                  temperature: drift.Value(temperature),
                                  humidity: drift.Value(humidity),
                                  notes: drift.Value(
                                    notesController.text.trim().isEmpty
                                        ? null
                                        : notesController.text.trim(),
                                  ),
                                  applicationDate: drift.Value(date),
                                ),
                              );
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
