import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/loading_error_widgets.dart';
import '../../../shared/widgets/app_empty_state.dart';
import 'application_sheet_content.dart';

/// Applications tab for trial detail: list and add/edit application events.
class ApplicationsTab extends ConsumerWidget {
  const ApplicationsTab({super.key, required this.trial});

  final Trial trial;

  static const List<String> _rateUnits = [
    'L/ha',
    'kg/ha',
    'g/ha',
    'mL/ha',
    'oz/ac',
  ];

  static const List<String> _applicationMethods = [
    'Ground sprayer',
    'Aerial',
    'Chemigation',
    'Hand application',
    'Granular spreader',
    'Other',
  ];

  static const List<String> _nozzleTypes = [
    'Flat fan',
    'Hollow cone',
    'Flood',
    'Air induction',
    'Rotary atomiser',
    'Other',
  ];
  static const List<String> _pressureUnits = ['PSI', 'kPa', 'bar'];
  static const List<String> _speedUnits = ['km/h', 'mph'];
  static const List<String> _waterVolumeUnits = ['L/ha', 'gal/ac'];
  static const List<String> _adjuvantRateUnits = ['L/ha', 'mL/100L', '% v/v'];
  static const List<String> _treatedAreaUnits = ['ha', 'ac', 'm²'];
  static const List<String> _soilMoistureOptions = [
    'Dry',
    'Moist',
    'Wet',
    'Waterlogged',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync =
        ref.watch(trialApplicationsForTrialProvider(trial.id));
    return applicationsAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, st) => AppErrorView(
        error: e,
        stackTrace: st,
        onRetry: () =>
            ref.invalidate(trialApplicationsForTrialProvider(trial.id)),
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
      subtitle:
          'Record spray, granular and other application events for this trial.',
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
    final timeStr = e.applicationTime?.trim().isNotEmpty == true
        ? e.applicationTime!
        : null;
    final dateTimeLabel =
        timeStr != null ? '$dateStr $timeStr' : dateStr;
    final productLabel =
        e.productName?.trim().isNotEmpty == true ? e.productName! : null;
    final rateUnitLabel = (e.rate != null && e.rateUnit != null)
        ? '${e.rate} ${e.rateUnit}'
        : null;
    final methodLabel = e.applicationMethod?.trim().isNotEmpty == true
        ? e.applicationMethod!
        : null;
    final treatments =
        ref.watch(treatmentsForTrialProvider(trial.id)).value ?? [];
    final treatment = e.treatmentId != null
        ? treatments.where((t) => t.id == e.treatmentId).firstOrNull
        : null;

    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(
          dateTimeLabel,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              productLabel ?? 'No product specified',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: productLabel != null
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (rateUnitLabel != null)
              Text(
                rateUnitLabel,
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (methodLabel != null)
                  Chip(
                    label: Text(
                      methodLabel,
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (treatment != null)
                  Chip(
                    label: Text(treatment.code),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => _showApplicationSheet(context, ref, e),
      ),
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, List<TrialApplicationEvent> list) {
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
                        style:
                            FilledButton.styleFrom(backgroundColor: Colors.red),
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
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => ApplicationSheetContent(
            trial: trial,
            existing: existing,
            scrollController: scrollController,
            rateUnits: _rateUnits,
            applicationMethods: _applicationMethods,
            nozzleTypes: _nozzleTypes,
            pressureUnits: _pressureUnits,
            speedUnits: _speedUnits,
            waterVolumeUnits: _waterVolumeUnits,
            adjuvantRateUnits: _adjuvantRateUnits,
            treatedAreaUnits: _treatedAreaUnits,
            soilMoistureOptions: _soilMoistureOptions,
            onSaved: () {
              ref.invalidate(trialApplicationsForTrialProvider(trial.id));
              if (context.mounted) Navigator.pop(ctx);
            },
            onDelete: existing != null
                ? () async {
                    final repo = ref.read(applicationRepositoryProvider);
                    await repo.deleteApplication(existing.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                : null,
          ),
        ),
      ),
    );
  }
}
