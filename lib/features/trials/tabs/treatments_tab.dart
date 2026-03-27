import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/design/form_styles.dart';
import '../../../core/providers.dart';
import '../../../core/trial_state.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/loading_error_widgets.dart';
import '../../../core/widgets/app_standard_widgets.dart';
import '../../../shared/widgets/app_empty_state.dart';

/// Builds a single-line formula string for a treatment from its components (paper-protocol style).
/// Includes formulation type when present (e.g. "Headline SC 1.0 L/ha").
String buildTreatmentFormula(List<TreatmentComponent> components) {
  if (components.isEmpty) return 'No components defined';
  String one(TreatmentComponent c) {
    final parts = <String>[
      c.productName.trim(),
      if (c.formulationType != null && c.formulationType!.trim().isNotEmpty)
        c.formulationType!.trim(),
      if (c.rate != null && c.rate!.trim().isNotEmpty) c.rate!.trim(),
      if (c.rateUnit != null && c.rateUnit!.trim().isNotEmpty)
        c.rateUnit!.trim(),
    ];
    return parts.where((s) => s.isNotEmpty).join(' ');
  }

  if (components.length == 1) {
    return one(components.first);
  }
  if (components.length == 2) {
    return '${one(components[0])} + ${one(components[1])}';
  }
  return '${one(components.first)} + ${components.length - 1} more';
}

const List<String> _treatmentTypes = [
  'Chemical',
  'Biological',
  'Cultural',
  'Untreated control',
  'Fertiliser',
  'Other',
];

const List<String> _timingCodes = [
  'PRE',
  'POST',
  'EPOST',
  'AT',
  'FPOST',
  'LPOST',
  'MPOST',
  'PREPLANT',
  'Other',
];

const List<String> _formulationTypes = [
  'EC',
  'WP',
  'WDG',
  'SC',
  'SL',
  'GR',
  'WG',
  'ME',
  'EW',
  'CS',
  'Other',
];

/// Treatments tab for trial detail: list treatments, components, add/edit/delete.
class TreatmentsTab extends ConsumerWidget {
  const TreatmentsTab({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treatmentsAsync = ref.watch(treatmentsForTrialProvider(trial.id));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Treatments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Open in full screen',
                icon: const Icon(Icons.fullscreen),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Treatments')),
                        body: TreatmentsTab(trial: trial),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: treatmentsAsync.when(
            loading: () => const AppLoadingView(),
            error: (e, st) => AppErrorView(
                error: e,
                stackTrace: st,
                onRetry: () =>
                    ref.invalidate(treatmentsForTrialProvider(trial.id))),
            data: (treatments) => treatments.isEmpty
                ? _buildEmpty(context, ref)
                : _buildList(context, ref, treatments),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    final locked = isProtocolLocked(trial.status);
    final button = FilledButton(
      onPressed: locked ? null : () => _showAddTreatmentDialog(context, ref),
      child: const Text('Add Treatment'),
    );
    return AppEmptyState(
      icon: Icons.science_outlined,
      title: 'No Treatments Yet',
      subtitle: locked
          ? getModeLockMessage(trial.status, trial.workspaceType)
          : 'Add the treatment groups for this trial.',
      action: locked && getModeLockMessage(trial.status, trial.workspaceType).isNotEmpty
          ? Tooltip(
              message: getModeLockMessage(trial.status, trial.workspaceType), child: button)
          : button,
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, List<Treatment> treatments) {
    final locked = isProtocolLocked(trial.status);
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
          itemCount: treatments.length + (locked ? 1 : 0),
          itemBuilder: (context, index) {
            if (locked && index == 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ProtocolLockChip(isLocked: true, status: trial.status),
                    const SizedBox(height: 4),
                    Text(
                      getModeLockMessage(trial.status, trial.workspaceType),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              );
            }
            final i = locked ? index - 1 : index;
            final t = treatments[i];
            return _TreatmentExpansionTile(
              trial: trial,
              treatment: t,
              locked: locked,
              onEdit: () => _showEditTreatmentDialog(context, ref, trial, t),
              onDelete: () =>
                  _showDeleteTreatmentDialog(context, ref, trial, t),
              onAddComponent: () => _showAddComponentSheet(context, ref, t),
              onOpenSheet: () => _showTreatmentComponents(context, ref, t),
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: locked
              ? GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(getModeLockMessage(trial.status, trial.workspaceType))),
                  ),
                  child: Tooltip(
                    message: getModeLockMessage(trial.status, trial.workspaceType),
                    child: const FloatingActionButton.extended(
                      heroTag: 'add_treatment',
                      onPressed: null,
                      icon: Icon(Icons.add),
                      label: Text('Add Treatment'),
                    ),
                  ),
                )
              : Tooltip(
                  message: 'Add treatment',
                  child: FloatingActionButton.extended(
                    heroTag: 'add_treatment',
                    onPressed: () => _showAddTreatmentDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Treatment'),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _showAddComponentSheet(
      BuildContext context, WidgetRef ref, Treatment treatment) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AddComponentBottomSheet(
        trial: trial,
        treatment: treatment,
        ref: ref,
        onSaved: () {
          ref.invalidate(treatmentComponentsForTreatmentProvider(treatment.id));
          ref.invalidate(treatmentComponentsCountForTrialProvider(trial.id));
        },
      ),
    );
  }

  Future<void> _showTreatmentComponents(
      BuildContext context, WidgetRef ref, Treatment treatment) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _TreatmentComponentsSheet(
        trial: trial,
        treatment: treatment,
      ),
    );
  }

  Future<void> _showEditTreatmentDialog(BuildContext context, WidgetRef ref,
      Trial trial, Treatment treatment) async {
    final codeController = TextEditingController(text: treatment.code);
    final nameController = TextEditingController(text: treatment.name);
    final descController =
        TextEditingController(text: treatment.description ?? '');
    final eppoController =
        TextEditingController(text: treatment.eppoCode ?? '');
    String? treatmentType = treatment.treatmentType;
    String? timingCode = treatment.timingCode;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AppDialog(
          title: 'Edit Treatment',
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: FormStyles.inputDecoration(
                    labelText: 'Code (e.g. T1, T2)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameController,
                decoration: FormStyles.inputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: FormStyles.inputDecoration(
                    labelText: 'Description (optional)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                key: ValueKey('edit_type_$treatmentType'),
                initialValue: treatmentType,
                decoration: FormStyles.inputDecoration(
                    labelText: 'Treatment type'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('—')),
                  ..._treatmentTypes.map((s) =>
                      DropdownMenuItem<String?>(value: s, child: Text(s))),
                ],
                onChanged: (v) => setState(() => treatmentType = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                key: ValueKey('edit_timing_$timingCode'),
                initialValue: timingCode,
                decoration: FormStyles.inputDecoration(
                    labelText: 'Timing code'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('—')),
                  ..._timingCodes.map((s) =>
                      DropdownMenuItem<String?>(value: s, child: Text(s))),
                ],
                onChanged: (v) => setState(() => timingCode = v),
              ),
              const SizedBox(height: 14),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                trailing: const Icon(Icons.keyboard_arrow_down_rounded),
                title: const Text('Regulatory details',
                    style: FormStyles.expansionTitleStyle),
                initiallyExpanded: false,
                children: [
                  TextField(
                    controller: eppoController,
                    decoration: FormStyles.inputDecoration(
                        labelText: 'EPPO code'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, FormStyles.buttonHeight),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(FormStyles.buttonRadius)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: FormStyles.primaryButton,
                minimumSize: const Size(0, FormStyles.buttonHeight),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(FormStyles.buttonRadius)),
              ),
              onPressed: () async {
                final useCase = ref.read(updateTreatmentUseCaseProvider);
                final result = await useCase.execute(
                  trial: trial,
                  treatmentId: treatment.id,
                  code: codeController.text,
                  name: nameController.text,
                  description: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                  treatmentType: treatmentType,
                  timingCode: timingCode,
                  eppoCode: eppoController.text.trim().isEmpty
                      ? null
                      : eppoController.text.trim(),
                );
                if (!ctx.mounted) return;
                if (result.success) {
                  ref.invalidate(treatmentsForTrialProvider(trial.id));
                  Navigator.pop(ctx);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                        content: Text(result.errorMessage ?? 'Update failed'),
                        backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteTreatmentDialog(BuildContext context, WidgetRef ref,
      Trial trial, Treatment treatment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Treatment'),
        content: Text(
          'Delete "${treatment.code} — ${treatment.name}"? Plots assigned to this treatment will be unassigned. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final useCase = ref.read(deleteTreatmentUseCaseProvider);
    final result =
        await useCase.execute(trial: trial, treatmentId: treatment.id);
    if (!context.mounted) return;
    if (result.success) {
      ref.invalidate(treatmentsForTrialProvider(trial.id));
      ref.invalidate(assignmentsForTrialProvider(trial.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treatment deleted')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result.errorMessage ?? 'Delete failed'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showAddTreatmentDialog(
      BuildContext context, WidgetRef ref) async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final eppoController = TextEditingController();
    String? treatmentType;
    String? timingCode;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AppDialog(
          title: 'Add Treatment',
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Code (e.g. T1, T2)',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                key: ValueKey('add_type_$treatmentType'),
                initialValue: treatmentType,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Treatment type',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('—')),
                  ..._treatmentTypes.map((s) =>
                      DropdownMenuItem<String?>(value: s, child: Text(s))),
                ],
                onChanged: (v) => setState(() => treatmentType = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: ValueKey('add_timing_$timingCode'),
                initialValue: timingCode,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Timing code',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('—')),
                  ..._timingCodes.map((s) =>
                      DropdownMenuItem<String?>(value: s, child: Text(s))),
                ],
                onChanged: (v) => setState(() => timingCode = v),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text('Regulatory details'),
                initiallyExpanded: false,
                children: [
                  TextField(
                    controller: eppoController,
decoration: FormStyles.inputDecoration(
                labelText: 'EPPO code',
                ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (codeController.text.trim().isEmpty ||
                    nameController.text.trim().isEmpty) {
                  return;
                }
                final repo = ref.read(treatmentRepositoryProvider);
                await repo.insertTreatment(
                  trialId: trial.id,
                  code: codeController.text.trim(),
                  name: nameController.text.trim(),
                  description: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                  treatmentType: treatmentType,
                  timingCode: timingCode,
                  eppoCode: eppoController.text.trim().isEmpty
                      ? null
                      : eppoController.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreatmentExpansionTile extends ConsumerStatefulWidget {
  final Trial trial;
  final Treatment treatment;
  final bool locked;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddComponent;
  final VoidCallback onOpenSheet;

  const _TreatmentExpansionTile({
    required this.trial,
    required this.treatment,
    required this.locked,
    required this.onEdit,
    required this.onDelete,
    required this.onAddComponent,
    required this.onOpenSheet,
  });

  @override
  ConsumerState<_TreatmentExpansionTile> createState() =>
      _TreatmentExpansionTileState();
}

class _TreatmentExpansionTileState
    extends ConsumerState<_TreatmentExpansionTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final treatment = widget.treatment;
    final componentsAsync =
        ref.watch(treatmentComponentsForTreatmentProvider(treatment.id));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: componentsAsync.when(
        loading: () =>
            _buildTile(context, ref, componentCount: 0, components: null),
        error: (_, __) =>
            _buildTile(context, ref, componentCount: 0, components: null),
        data: (components) => _buildTile(context, ref,
            componentCount: components.length, components: components),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    WidgetRef ref, {
    required int componentCount,
    List<TreatmentComponent>? components,
  }) {
    final theme = Theme.of(context);
    final formula = buildTreatmentFormula(components ?? []);
    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing16, vertical: 8),
      childrenPadding: const EdgeInsets.fromLTRB(32, 0, 16, 8),
      onExpansionChanged: (v) => setState(() => _expanded = v),
      leading: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.spacing8,
            vertical: AppDesignTokens.spacing4),
        decoration: BoxDecoration(
          color: AppDesignTokens.primary,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
        ),
        child: Text(widget.treatment.code,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: Colors.white,
                letterSpacing: 0.2)),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.treatment.name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppDesignTokens.primaryText,
            ),
          ),
          if ((widget.treatment.treatmentType != null &&
                  widget.treatment.treatmentType!.isNotEmpty) ||
              (widget.treatment.timingCode != null &&
                  widget.treatment.timingCode!.isNotEmpty)) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (widget.treatment.treatmentType != null &&
                    widget.treatment.treatmentType!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.6)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.treatment.treatmentType!,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (widget.treatment.timingCode != null &&
                    widget.treatment.timingCode!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.6)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.treatment.timingCode!,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (!_expanded) ...[
            const SizedBox(height: 2),
            Text(
              formula,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.locked) ...[
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              tooltip: 'Add Component',
              onPressed: widget.onAddComponent,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  size: 20, color: AppDesignTokens.iconSubtle),
              tooltip: 'Edit, view components, or delete treatment',
              onSelected: (value) {
                if (value == 'edit') widget.onEdit();
                if (value == 'delete') widget.onDelete();
                if (value == 'sheet') widget.onOpenSheet();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                    value: 'sheet', child: Text('View Components')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ] else
            const Icon(Icons.expand_more,
                size: 20, color: AppDesignTokens.iconSubtle),
        ],
      ),
      children: [
        if (!widget.locked)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onAddComponent,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Component'),
              ),
            ),
          ),
        if (components == null || components.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'No components yet. Tap Add Component to add products and rates.',
              style:
                  TextStyle(fontSize: 13, color: AppDesignTokens.secondaryText),
            ),
          )
        else
          ...components.map((c) => _ComponentListTile(
                trial: widget.trial,
                treatment: widget.treatment,
                component: c,
                onDelete: () async {
                  final repo = ref.read(treatmentRepositoryProvider);
                  await repo.deleteComponent(c.id);
                  ref.invalidate(treatmentComponentsForTreatmentProvider(
                      widget.treatment.id));
                  ref.invalidate(treatmentComponentsCountForTrialProvider(
                      widget.trial.id));
                },
              )),
      ],
    );
  }
}

class _ComponentListTile extends StatelessWidget {
  final Trial trial;
  final Treatment treatment;
  final TreatmentComponent component;
  final VoidCallback onDelete;

  const _ComponentListTile({
    required this.trial,
    required this.treatment,
    required this.component,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ratePart = (component.rate != null &&
            component.rate!.isNotEmpty &&
            component.rateUnit != null)
        ? '${component.rate} ${component.rateUnit}'
        : null;
    final formulationPart = component.applicationTiming;
    return Dismissible(
      key: Key('component_${component.id}'),
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
            title: const Text('Remove Component?'),
            content: Text(
              'Remove "${component.productName}" from ${treatment.code}?',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Remove')),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: ListTile(
        title: Text(
          component.productName,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppDesignTokens.primaryText),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ratePart != null)
              Text(ratePart,
                  style: const TextStyle(
                      fontSize: 12, color: AppDesignTokens.secondaryText)),
            if (formulationPart != null && formulationPart.isNotEmpty)
              Text(formulationPart,
                  style: const TextStyle(
                      fontSize: 12, color: AppDesignTokens.secondaryText)),
          ],
        ),
      ),
    );
  }
}

const List<String> _componentRateUnits = [
  'g/ha',
  'kg/ha',
  'L/ha',
  'mL/ha',
  'oz/ac',
  'lbs/ac'
];

class _AddComponentBottomSheet extends StatefulWidget {
  final Trial trial;
  final Treatment treatment;
  final WidgetRef ref;
  final VoidCallback onSaved;

  const _AddComponentBottomSheet({
    required this.trial,
    required this.treatment,
    required this.ref,
    required this.onSaved,
  });

  @override
  State<_AddComponentBottomSheet> createState() =>
      _AddComponentBottomSheetState();
}

class _AddComponentBottomSheetState extends State<_AddComponentBottomSheet> {
  final _productController = TextEditingController();
  final _rateController = TextEditingController();
  final _formulationController = TextEditingController();
  final _notesController = TextEditingController();
  final _activeIngredientPctController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _eppoController = TextEditingController();
  String _rateUnit = _componentRateUnits.first;
  String? _formulationType;

  @override
  void dispose() {
    _productController.dispose();
    _rateController.dispose();
    _formulationController.dispose();
    _notesController.dispose();
    _activeIngredientPctController.dispose();
    _manufacturerController.dispose();
    _registrationNumberController.dispose();
    _eppoController.dispose();
    super.dispose();
  }

  double? _parseActiveIngredientPct() {
    final s = _activeIngredientPctController.text.trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Component — ${widget.treatment.code}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _productController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Component Name *',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _rateController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: FormStyles.inputDecoration(
                          labelText: 'Rate'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('sheet_rate_unit_$_rateUnit'),
                      initialValue: _rateUnit,
                      decoration: FormStyles.inputDecoration(
                          labelText: 'Unit'),
                      items: _componentRateUnits
                          .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _rateUnit = v ?? _componentRateUnits.first),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: ValueKey('sheet_form_$_formulationType'),
                initialValue: _formulationType,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Formulation type',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('—')),
                  ..._formulationTypes.map((s) =>
                      DropdownMenuItem<String?>(value: s, child: Text(s))),
                ],
                onChanged: (v) => setState(() => _formulationType = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _activeIngredientPctController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: FormStyles.inputDecoration(
                  labelText: 'Active ingredient %',
                  suffixText: '%',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _formulationController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Application timing (optional)',
                ),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text('Regulatory details'),
                initiallyExpanded: false,
                children: [
                  TextField(
                    controller: _manufacturerController,
decoration: FormStyles.inputDecoration(
                labelText: 'Manufacturer',
                ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _registrationNumberController,
decoration: FormStyles.inputDecoration(
                labelText: 'Registration number',
                ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _eppoController,
decoration: FormStyles.inputDecoration(
                labelText: 'EPPO code',
                      hintText: 'e.g. 1BAS5B4048',
                ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Notes',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      final name = _productController.text.trim();
                      if (name.isEmpty) return;
                      final repo = widget.ref.read(treatmentRepositoryProvider);
                      await repo.insertComponent(
                        treatmentId: widget.treatment.id,
                        trialId: widget.trial.id,
                        productName: name,
                        rate: _rateController.text.trim().isEmpty
                            ? null
                            : _rateController.text.trim(),
                        rateUnit: _rateUnit,
                        applicationTiming:
                            _formulationController.text.trim().isEmpty
                                ? null
                                : _formulationController.text.trim(),
                        notes: _notesController.text.trim().isEmpty
                            ? null
                            : _notesController.text.trim(),
                        activeIngredientPct: _parseActiveIngredientPct(),
                        formulationType: _formulationType,
                        manufacturer: _manufacturerController.text.trim().isEmpty
                            ? null
                            : _manufacturerController.text.trim(),
                        registrationNumber:
                            _registrationNumberController.text.trim().isEmpty
                                ? null
                                : _registrationNumberController.text.trim(),
                        eppoCode: _eppoController.text.trim().isEmpty
                            ? null
                            : _eppoController.text.trim(),
                      );
                      if (!context.mounted) return;
                      widget.onSaved();
                      Navigator.pop(context);
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
  }
}

class _AddComponentDialog extends StatefulWidget {
  const _AddComponentDialog({
    required this.trial,
    required this.treatment,
    required this.ref,
    required this.onSaved,
  });

  final Trial trial;
  final Treatment treatment;
  final WidgetRef ref;
  final Future<void> Function() onSaved;

  @override
  State<_AddComponentDialog> createState() => _AddComponentDialogState();
}

class _AddComponentDialogState extends State<_AddComponentDialog> {
  late final TextEditingController productController;
  late final TextEditingController rateController;
  late final TextEditingController rateUnitController;
  late final TextEditingController timingController;
  late final TextEditingController notesController;
  late final TextEditingController activeIngredientPctController;
  late final TextEditingController manufacturerController;
  late final TextEditingController registrationNumberController;
  late final TextEditingController eppoController;
  String? formulationType;

  @override
  void initState() {
    super.initState();
    productController = TextEditingController();
    rateController = TextEditingController();
    rateUnitController = TextEditingController();
    timingController = TextEditingController();
    notesController = TextEditingController();
    activeIngredientPctController = TextEditingController();
    manufacturerController = TextEditingController();
    registrationNumberController = TextEditingController();
    eppoController = TextEditingController();
  }

  @override
  void dispose() {
    productController.dispose();
    rateController.dispose();
    rateUnitController.dispose();
    timingController.dispose();
    notesController.dispose();
    activeIngredientPctController.dispose();
    manufacturerController.dispose();
    registrationNumberController.dispose();
    eppoController.dispose();
    super.dispose();
  }

  double? _parseActiveIngredientPct() {
    final s = activeIngredientPctController.text.trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Add Product to ${widget.treatment.code}',
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: productController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
decoration: FormStyles.inputDecoration(
                labelText: 'Product Name *',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: rateController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: FormStyles.inputDecoration(
                    labelText: 'Rate',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: rateUnitController,
                  decoration: FormStyles.inputDecoration(
                    labelText: 'Unit (e.g. L/ha)',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: ValueKey('dialog_form_$formulationType'),
            initialValue: formulationType,
decoration: FormStyles.inputDecoration(
                labelText: 'Formulation type',
            ),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('—')),
              ..._formulationTypes.map((s) =>
                  DropdownMenuItem<String?>(value: s, child: Text(s))),
            ],
            onChanged: (v) => setState(() => formulationType = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: activeIngredientPctController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
decoration: FormStyles.inputDecoration(
                labelText: 'Active ingredient %',
              suffixText: '%',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: timingController,
decoration: FormStyles.inputDecoration(
                labelText: 'Application Timing (optional)',
            ),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            title: const Text('Regulatory details'),
            initiallyExpanded: false,
            children: [
              TextField(
                controller: manufacturerController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Manufacturer',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: registrationNumberController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Registration number',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: eppoController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'EPPO code',
                  hintText: 'e.g. 1BAS5B4048',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            maxLines: 2,
decoration: FormStyles.inputDecoration(
                labelText: 'Notes (optional)',
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
            if (productController.text.trim().isEmpty) return;
            final repo = widget.ref.read(treatmentRepositoryProvider);
            await repo.insertComponent(
              treatmentId: widget.treatment.id,
              trialId: widget.trial.id,
              productName: productController.text.trim(),
              rate: rateController.text.trim().isEmpty
                  ? null
                  : rateController.text.trim(),
              rateUnit: rateUnitController.text.trim().isEmpty
                  ? null
                  : rateUnitController.text.trim(),
              applicationTiming: timingController.text.trim().isEmpty
                  ? null
                  : timingController.text.trim(),
              notes: notesController.text.trim().isEmpty
                  ? null
                  : notesController.text.trim(),
              activeIngredientPct: _parseActiveIngredientPct(),
              formulationType: formulationType,
              manufacturer: manufacturerController.text.trim().isEmpty
                  ? null
                  : manufacturerController.text.trim(),
              registrationNumber:
                  registrationNumberController.text.trim().isEmpty
                      ? null
                      : registrationNumberController.text.trim(),
              eppoCode: eppoController.text.trim().isEmpty
                  ? null
                  : eppoController.text.trim(),
            );
            if (!context.mounted) return;
            Navigator.pop(context);
            await widget.onSaved();
          },
          child: const Text('Add Product'),
        ),
      ],
    );
  }
}

class _TreatmentComponentsSheet extends ConsumerStatefulWidget {
  final Trial trial;
  final Treatment treatment;

  const _TreatmentComponentsSheet({
    required this.trial,
    required this.treatment,
  });

  @override
  ConsumerState<_TreatmentComponentsSheet> createState() =>
      _TreatmentComponentsSheetState();
}

class _TreatmentComponentsSheetState
    extends ConsumerState<_TreatmentComponentsSheet> {
  List<TreatmentComponent> _components = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadComponents();
  }

  Future<void> _loadComponents() async {
    final repo = ref.read(treatmentRepositoryProvider);
    final result = await repo.getComponentsForTreatment(widget.treatment.id);
    if (mounted) {
      setState(() {
        _components = result;
        _loading = false;
      });
    }
    ref.invalidate(treatmentsForTrialProvider(widget.trial.id));
  }

  @override
  Widget build(BuildContext context) {
    final locked = isProtocolLocked(widget.trial.status);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppDesignTokens.dragHandle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                  AppDesignTokens.spacing16,
                  AppDesignTokens.spacing8,
                  AppDesignTokens.spacing16,
                  AppDesignTokens.spacing12),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppDesignTokens.borderCrisp)),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.primary,
                      borderRadius:
                          BorderRadius.circular(AppDesignTokens.radiusXSmall),
                    ),
                    child: Text(widget.treatment.code,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ),
                  const SizedBox(width: AppDesignTokens.spacing8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.treatment.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppDesignTokens.primaryText)),
                        if (_components.isNotEmpty)
                          Text(
                            '${_components.length} ${_components.length == 1 ? "product" : "products"}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppDesignTokens.secondaryText),
                          ),
                      ],
                    ),
                  ),
                  if (!locked)
                    ElevatedButton.icon(
                      onPressed: () => _showAddComponentDialog(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Product'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignTokens.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppDesignTokens.spacing16,
                            vertical: AppDesignTokens.spacing8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppDesignTokens.radiusSmall)),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _components.isEmpty
                      ? _buildEmpty(context, locked)
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: _components.length,
                          itemBuilder: (context, i) =>
                              _buildComponentTile(context, i),
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context, bool locked) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppDesignTokens.successBg,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(Icons.science_outlined,
                size: 32, color: AppDesignTokens.primary),
          ),
          const SizedBox(height: AppDesignTokens.spacing16),
          const Text('No products yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppDesignTokens.primaryText)),
          const SizedBox(height: 6),
          const Text('Add products, rates and timing',
              style: TextStyle(
                  fontSize: 13, color: AppDesignTokens.secondaryText)),
          if (!locked) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showAddComponentDialog(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Product'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesignTokens.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDesignTokens.radiusSmall)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComponentTile(BuildContext context, int i) {
    final c = _components[i];
    final locked = isProtocolLocked(widget.trial.status);
    final ratePart = (c.rate != null && c.rateUnit != null)
        ? '${c.rate} ${c.rateUnit}'
        : null;
    final timingPart = c.applicationTiming;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignTokens.spacing16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppDesignTokens.emptyBadgeBg,
                borderRadius:
                    BorderRadius.circular(AppDesignTokens.radiusXSmall),
              ),
              child: Center(
                child: Text('${i + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppDesignTokens.primary)),
              ),
            ),
            const SizedBox(width: AppDesignTokens.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.productName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppDesignTokens.primaryText)),
                  if (ratePart != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.water_drop_outlined,
                            size: 13, color: AppDesignTokens.secondaryText),
                        const SizedBox(width: 4),
                        Text(ratePart,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppDesignTokens.secondaryText)),
                      ],
                    ),
                  ],
                  if (timingPart != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.schedule,
                            size: 13, color: AppDesignTokens.secondaryText),
                        const SizedBox(width: 4),
                        Text(timingPart,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppDesignTokens.secondaryText)),
                      ],
                    ),
                  ],
                  if (c.notes != null && c.notes!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(c.notes!,
                        style: const TextStyle(
                            fontSize: 11, color: AppDesignTokens.emptyBadgeFg)),
                  ],
                ],
              ),
            ),
            if (!locked)
              GestureDetector(
                onTap: () => _confirmDelete(context, c),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline,
                      size: 16, color: Color(0xFFDC2626)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, TreatmentComponent component) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDesignTokens.backgroundSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge)),
        title: const Text('Remove Product',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppDesignTokens.primaryText)),
        content: Text(
          'Remove "${component.productName}" from ${widget.treatment.code}?',
          style: const TextStyle(
              fontSize: 14, color: AppDesignTokens.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppDesignTokens.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final repo = ref.read(treatmentRepositoryProvider);
    await repo.deleteComponent(component.id);
    await _loadComponents();
  }

  Future<void> _showAddComponentDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => _AddComponentDialog(
        trial: widget.trial,
        treatment: widget.treatment,
        ref: ref,
        onSaved: _loadComponents,
      ),
    );
  }
}
