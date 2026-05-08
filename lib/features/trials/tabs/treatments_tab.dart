import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/design/form_styles.dart';
import '../../../core/providers.dart';
import '../../../core/trial_state.dart';
import '../../../core/units/unit_switch_mixin.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/loading_error_widgets.dart';
import '../../../core/widgets/app_standard_widgets.dart';
import '../../../core/trial_review_invalidation.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../core/protocol_edit_blocked_exception.dart';
import 'add_treatment_sheet.dart';

/// Builds a single-line formula string for a treatment from its components (paper-protocol style).
/// Pass [aam] for ARM-linked trials so lines match the ARM Protocol / Field Plan subtitle:
/// product · rate unit · form conc · form type (core formulation type omitted when [aam] is present).
String buildTreatmentFormula(List<TreatmentComponent> components,
    {ArmTreatmentMetadataData? aam}) {
  if (components.isEmpty) return 'No products added yet';
  if (components.length == 1) {
    return _componentOneLine(components.first, aam: aam);
  }
  if (components.length == 2) {
    return '${_componentOneLine(components[0], aam: aam)} + ${_componentOneLine(components[1], aam: aam)}';
  }
  return '${_componentOneLine(components.first, aam: aam)} + ${components.length - 1} more';
}

Future<void> _deleteTreatmentComponent(
  WidgetRef ref,
  int componentId,
) async {
  final userId = await ref.read(currentUserIdProvider.future);
  final user = await ref.read(currentUserProvider.future);
  await ref.read(treatmentRepositoryProvider).softDeleteComponent(
        componentId,
        deletedBy: user?.displayName,
        deletedByUserId: userId,
      );
}

Future<bool> _treatmentHasApplications(WidgetRef ref, int treatmentId) async {
  final db = ref.read(databaseProvider);
  final rows = await (db.select(db.trialApplicationEvents)
        ..where((a) => a.treatmentId.equals(treatmentId))
        ..limit(1))
      .get();
  return rows.isNotEmpty;
}

/// One line per component for the compact treatments list.
/// With [aam], matches ARM Protocol subtitle order: rate, then Form Conc / Type
/// (core [TreatmentComponent.formulationType] omitted to avoid clashing with ARM form type).
String _componentOneLine(TreatmentComponent c, {ArmTreatmentMetadataData? aam}) {
  final parts = <String>[];
  final pn = c.productName.trim();
  if (pn.isNotEmpty) parts.add(pn);
  final rate = c.rate;
  final unit = c.rateUnit?.trim();
  if (rate != null) {
    final rateStr = rate == rate.roundToDouble()
        ? rate.toInt().toString()
        : rate.toString();
    parts.add(unit != null && unit.isNotEmpty ? '$rateStr $unit' : rateStr);
  } else if (unit != null && unit.isNotEmpty) {
    parts.add(unit);
  }
  if (aam != null) {
    final formConc = aam.formConc;
    final formConcUnit = aam.formConcUnit;
    if (formConc != null) {
      final concStr = formConc == formConc.roundToDouble()
          ? formConc.toInt().toString()
          : formConc.toString();
      parts.add(formConcUnit != null && formConcUnit.isNotEmpty
          ? '$concStr $formConcUnit'
          : concStr);
    }
    final formType = aam.formType;
    if (formType != null && formType.isNotEmpty) parts.add(formType);
  } else {
    final cat = c.pesticideCategory?.trim();
    if (cat != null && cat.isNotEmpty) {
      parts.add(_pesticideCategories[cat] ?? cat);
    }
    final ft = c.formulationType?.trim();
    if (ft != null && ft.isNotEmpty) parts.add(ft);
  }
  return parts.isEmpty ? '—' : parts.join(' · ');
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

const Map<String, String> _pesticideCategories = {
  'herbicide': 'Herbicide',
  'fungicide': 'Fungicide',
  'insecticide': 'Insecticide',
  'biological': 'Biological',
  'fertilizer': 'Fertilizer',
  'variety': 'Variety',
  'adjuvant': 'Adjuvant',
  'other': 'Other',
};

void _pushTreatmentsFullScreen(BuildContext context, Trial trial) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Treatments')),
        body: SafeArea(top: false, child: TreatmentsTab(trial: trial)),
      ),
    ),
  );
}

/// Local section header: count + label + fullscreen (matches Assessments tab).
Widget _treatmentsSectionHeader(
  BuildContext context,
  Trial trial, {
  required int count,
}) {
  final title = count == 1 ? '1 treatment' : '$count treatments';
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppDesignTokens.spacing16,
      vertical: 10,
    ),
    decoration: const BoxDecoration(
      color: AppDesignTokens.sectionHeaderBg,
      border: Border(bottom: BorderSide(color: AppDesignTokens.borderCrisp)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.science_outlined,
          size: 16,
          color: AppDesignTokens.primary,
        ),
        const SizedBox(width: AppDesignTokens.spacing8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.2,
              color: AppDesignTokens.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          tooltip: 'Full screen',
          icon: const Icon(Icons.fullscreen),
          onPressed: () => _pushTreatmentsFullScreen(context, trial),
        ),
      ],
    ),
  );
}

/// Treatments tab for trial detail: list treatments, components, add/edit/delete.
class TreatmentsTab extends ConsumerWidget {
  const TreatmentsTab({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treatmentsAsync = ref.watch(treatmentsForTrialProvider(trial.id));
    final hasSessionData =
        ref.watch(trialHasSessionDataProvider(trial.id)).valueOrNull ?? false;
    final trialIsArmLinked = ref
            .watch(armTrialMetadataStreamProvider(trial.id))
            .valueOrNull
            ?.isArmLinked ??
        false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: treatmentsAsync.when(
            loading: () => const AppLoadingView(),
            error: (e, st) => AppErrorView(
                error: e,
                stackTrace: st,
                onRetry: () =>
                    ref.invalidate(treatmentsForTrialProvider(trial.id))),
            data: (treatments) {
              if (treatments.isEmpty) {
                return _buildEmpty(
                  context,
                  ref,
                  hasSessionData,
                  trialIsArmLinked,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _treatmentsSectionHeader(
                    context,
                    trial,
                    count: treatments.length,
                  ),
                  Expanded(
                    child: _buildList(
                      context,
                      ref,
                      treatments,
                      hasSessionData,
                      trialIsArmLinked,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(
    BuildContext context,
    WidgetRef ref,
    bool hasSessionData,
    bool trialIsArmLinked,
  ) {
    final locked = !canEditTrialStructure(
      trial,
      hasSessionData: hasSessionData,
      trialIsArmLinked: trialIsArmLinked,
    );
    return Stack(
      children: [
        AppEmptyState(
          icon: Icons.science_outlined,
          title: 'No Treatments Yet',
          subtitle: locked
              ? structureEditBlockedMessage(
                  trial,
                  hasSessionData: hasSessionData,
                  trialIsArmLinked: trialIsArmLinked,
                )
              : 'Add the treatment groups for this trial.',
          action: null,
        ),
        if (!locked)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: 'add_treatment_empty',
              onPressed: () => _showAddTreatmentDialog(context, ref),
              backgroundColor: AppDesignTokens.primary,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<Treatment> treatments,
    bool hasSessionData,
    bool trialIsArmLinked,
  ) {
    final locked = !canEditTrialStructure(
      trial,
      hasSessionData: hasSessionData,
      trialIsArmLinked: trialIsArmLinked,
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 72),
            itemCount: treatments.length + (locked ? 1 : 0),
            itemBuilder: (context, index) {
              if (locked && index == 0) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ProtocolLockChip(
                        isLocked: true,
                        trial: trial,
                        hasSessionData: hasSessionData,
                        trialIsArmLinked: trialIsArmLinked,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        structureEditBlockedMessage(
                          trial,
                          hasSessionData: hasSessionData,
                          trialIsArmLinked: trialIsArmLinked,
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                );
              }
              final i = locked ? index - 1 : index;
              final t = treatments[i];
              return _TreatmentCompactCard(
                trial: trial,
                treatment: t,
                locked: locked,
                trialIsArmLinked: trialIsArmLinked,
                onEdit: () => _showEditTreatmentDialog(context, ref, trial, t),
                onDelete: () =>
                    _showDeleteTreatmentDialog(context, ref, trial, t),
                onOpenComponentSheet: (existing, restricted) =>
                    _showAddComponentSheet(context, ref, t, existing: existing, restrictedMode: restricted),
                onOpenSheet: () => _showTreatmentComponents(context, ref, t),
              );
            },
          ),
        ),
      ],
    );
    return Stack(
      children: [
        content,
        if (!locked)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: 'add_treatment',
              onPressed: () => _showAddTreatmentDialog(context, ref),
              backgroundColor: AppDesignTokens.primary,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Future<void> _showAddComponentSheet(
    BuildContext context,
    WidgetRef ref,
    Treatment treatment, {
    TreatmentComponent? existing,
    bool restrictedMode = false,
  }) async {
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
        existingComponent: existing,
        restrictedMode: restrictedMode,
        onSaved: () {
          ref.invalidate(treatmentComponentsForTreatmentProvider(treatment.id));
          ref.invalidate(treatmentComponentsByTreatmentForTrialProvider(trial.id));
          ref.invalidate(treatmentComponentsCountForTrialProvider(trial.id));
          invalidateTrialReviewProviders(ref, trial.id);
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
    String? treatmentType = _treatmentTypes.contains(treatment.treatmentType)
        ? treatment.treatmentType
        : null;
    String? timingCode = _timingCodes.contains(treatment.timingCode)
        ? treatment.timingCode
        : null;

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
                decoration:
                    FormStyles.inputDecoration(labelText: 'Code (e.g. T1, T2)'),
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
                decoration:
                    FormStyles.inputDecoration(labelText: 'Treatment type'),
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
                key: ValueKey('edit_timing_${timingCode ?? 'null'}'),
                initialValue: timingCode,
                decoration:
                    FormStyles.inputDecoration(labelText: 'Timing code'),
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
                    decoration:
                        FormStyles.inputDecoration(labelText: 'Product code'),
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
                final userId = await ref.read(currentUserIdProvider.future);
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
                  performedByUserId: userId,
                );
                if (!ctx.mounted) return;
                if (result.success) {
                  ref.invalidate(treatmentsForTrialProvider(trial.id));
                  ref.invalidate(
                    treatmentComponentsByTreatmentForTrialProvider(trial.id),
                  );
                  ref.invalidate(
                    treatmentComponentsCountForTrialProvider(trial.id),
                  );
                  invalidateTrialReviewProviders(ref, trial.id);
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
        title: const Text('Remove Treatment'),
        content: Text(
          'Remove "${treatment.code} — ${treatment.name}" from this trial?\n\n'
          'This treatment will be removed and can be restored from Recovery if needed. '
          'Plot assignments are unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final userId = await ref.read(currentUserIdProvider.future);
    final user = await ref.read(currentUserProvider.future);
    final useCase = ref.read(deleteTreatmentUseCaseProvider);
    final result = await useCase.execute(
      trial: trial,
      treatmentId: treatment.id,
      deletedBy: user?.displayName,
      deletedByUserId: userId,
    );
    if (!context.mounted) return;
    if (result.success) {
      ref.invalidate(treatmentsForTrialProvider(trial.id));
      ref.invalidate(assignmentsForTrialProvider(trial.id));
      ref.invalidate(treatmentComponentsByTreatmentForTrialProvider(trial.id));
      ref.invalidate(treatmentComponentsCountForTrialProvider(trial.id));
      invalidateTrialReviewProviders(ref, trial.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treatment removed')),
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
    await showAddTreatmentSheet(context, ref, trial: trial);
  }
}

class _TreatmentCompactCard extends ConsumerStatefulWidget {
  final Trial trial;
  final Treatment treatment;
  final bool locked;
  final bool trialIsArmLinked;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function(TreatmentComponent? existing, bool restrictedMode)
      onOpenComponentSheet;
  final VoidCallback onOpenSheet;

  const _TreatmentCompactCard({
    required this.trial,
    required this.treatment,
    required this.locked,
    required this.trialIsArmLinked,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenComponentSheet,
    required this.onOpenSheet,
  });

  @override
  ConsumerState<_TreatmentCompactCard> createState() =>
      _TreatmentCompactCardState();
}

class _TreatmentCompactCardState extends ConsumerState<_TreatmentCompactCard> {
  Widget _treatmentOverflowMenu(BuildContext context) {
    if (!widget.locked) {
      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert,
            size: 20, color: AppDesignTokens.iconSubtle),
        tooltip: 'Edit, view components, or delete treatment',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        onSelected: (value) {
          if (value == 'edit') widget.onEdit();
          if (value == 'delete') widget.onDelete();
          if (value == 'sheet') widget.onOpenSheet();
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'sheet', child: Text('View Components')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      );
    }
    if (widget.trialIsArmLinked) {
      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert,
            size: 20, color: AppDesignTokens.iconSubtle),
        tooltip: 'View components',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        onSelected: (value) {
          if (value == 'sheet') widget.onOpenSheet();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'sheet',
            child: Text('View Components'),
          ),
        ],
      );
    }
    return const SizedBox(width: 40, height: 40);
  }

  @override
  Widget build(BuildContext context) {
    final treatment = widget.treatment;
    final trialId = widget.trial.id;
    final componentsAsync =
        ref.watch(treatmentComponentsForTreatmentProvider(treatment.id));
    final applicationSummaries = ref
            .watch(applicationProductSummariesForTreatmentProvider(
                (trialId, treatment.id)))
            .valueOrNull ??
        const <String>[];
    final aamMap = ref
            .watch(armTreatmentMetadataMapForTrialProvider(trialId))
            .valueOrNull ??
        const <int, ArmTreatmentMetadataData>{};
    final aam = aamMap[treatment.id];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: AppDesignTokens.cardShadow,
      ),
      child: componentsAsync.when(
        loading: () => _buildBody(
          context,
          ref,
          components: null,
          applicationSummaries: applicationSummaries,
          aam: aam,
        ),
        error: (_, __) => _buildBody(
          context,
          ref,
          components: null,
          applicationSummaries: applicationSummaries,
          aam: aam,
        ),
        data: (components) => _buildBody(
          context,
          ref,
          components: components,
          applicationSummaries: applicationSummaries,
          aam: aam,
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref, {
    required List<TreatmentComponent>? components,
    required List<String> applicationSummaries,
    ArmTreatmentMetadataData? aam,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final codeChip = Container(
      constraints: const BoxConstraints(minWidth: 36, minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppDesignTokens.primary,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
      ),
      alignment: Alignment.center,
      child: Text(
        widget.treatment.code,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
    );

    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
          height: 1.25,
        ) ??
        TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.25);

    final List<Widget> subtitleRows;
    if (components == null) {
      subtitleRows = [];
    } else if (components.isEmpty) {
      if (applicationSummaries.isNotEmpty) {
        subtitleRows = [
          for (final line in applicationSummaries)
            Padding(
              padding: const EdgeInsets.only(left: 46, top: 2),
              child: Text(line, style: subtitleStyle),
            ),
        ];
      } else {
        subtitleRows = [
          Padding(
            padding: const EdgeInsets.only(left: 46, top: 2),
            child: Text(
              widget.treatment.treatmentType == 'CHK'
                  ? 'Untreated check'
                  : 'No products added yet',
              style: subtitleStyle,
            ),
          ),
        ];
      }
    } else {
      subtitleRows = [
        for (final c in components)
          Padding(
            padding: const EdgeInsets.only(left: 46, top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    _componentOneLine(c, aam: aam),
                    style: subtitleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!widget.locked || !widget.trialIsArmLinked)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      size: 18,
                      color: AppDesignTokens.iconSubtle,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await widget.onOpenComponentSheet(c, false);
                      } else if (value == 'metadata') {
                        await widget.onOpenComponentSheet(c, true);
                      } else if (value == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete this component?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true && context.mounted) {
                          await _deleteTreatmentComponent(ref, c.id);
                          ref.invalidate(
                            treatmentComponentsForTreatmentProvider(
                                widget.treatment.id),
                          );
                          ref.invalidate(
                            treatmentComponentsCountForTrialProvider(
                                widget.trial.id),
                          );
                          ref.invalidate(
                            treatmentComponentsByTreatmentForTrialProvider(
                                widget.trial.id),
                          );
                          invalidateTrialReviewProviders(ref, widget.trial.id);
                        }
                      }
                    },
                    itemBuilder: (context) => widget.locked
                        ? const [
                            PopupMenuItem(
                                value: 'metadata',
                                child: Text('Edit metadata')),
                          ]
                        : const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                  ),
              ],
            ),
          ),
      ];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              codeChip,
              const SizedBox(width: 10),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onOpenSheet,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        widget.treatment.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppDesignTokens.primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
              if (!widget.locked)
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: 'Add Component',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  onPressed: () => widget.onOpenComponentSheet(null, false),
                ),
              _treatmentOverflowMenu(context),
            ],
          ),
          ...subtitleRows,
        ],
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
  final TreatmentComponent? existingComponent;
  final bool restrictedMode;

  const _AddComponentBottomSheet({
    required this.trial,
    required this.treatment,
    required this.ref,
    required this.onSaved,
    this.existingComponent,
    this.restrictedMode = false,
  });

  @override
  State<_AddComponentBottomSheet> createState() =>
      _AddComponentBottomSheetState();
}

class _AddComponentBottomSheetState extends State<_AddComponentBottomSheet>
    with UnitSwitchMixin<_AddComponentBottomSheet> {
  bool _isSaving = false;
  final _productController = TextEditingController();
  final _rateController = TextEditingController();
  final _formulationController = TextEditingController();
  final _notesController = TextEditingController();
  final _activeIngredientPctController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _eppoController = TextEditingController();
  final _aiNameController = TextEditingController();
  final _aiConcentrationController = TextEditingController();
  final _labelRateController = TextEditingController();
  String _rateUnit = _componentRateUnits.first;
  String? _formulationType;
  String? _pesticideCategory;
  String _aiConcentrationUnit = 'g/L';
  String _labelRateUnit = 'g ai/ha';
  bool _isTestProduct = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existingComponent;
    if (e != null) {
      _productController.text = e.productName;
      _rateController.text = e.rate != null ? '${e.rate}' : '';
      final u = e.rateUnit?.trim();
      if (u != null && u.isNotEmpty && _componentRateUnits.contains(u)) {
        _rateUnit = u;
      }
      _formulationController.text = e.applicationTiming ?? '';
      _notesController.text = e.notes ?? '';
      final pct = e.activeIngredientPct;
      if (pct != null) {
        _activeIngredientPctController.text =
            pct == pct.roundToDouble() ? '${pct.round()}' : '$pct';
      }
      _manufacturerController.text = e.manufacturer ?? '';
      _registrationNumberController.text = e.registrationNumber ?? '';
      _eppoController.text = e.eppoCode ?? '';
      _formulationType = e.formulationType;
      _pesticideCategory = e.pesticideCategory;
      _aiNameController.text = e.activeIngredientName ?? '';
      if (e.aiConcentration != null) {
        _aiConcentrationController.text =
            e.aiConcentration == e.aiConcentration!.roundToDouble()
                ? '${e.aiConcentration!.round()}'
                : '${e.aiConcentration}';
      }
      if (e.aiConcentrationUnit != null && e.aiConcentrationUnit!.isNotEmpty) {
        _aiConcentrationUnit = e.aiConcentrationUnit!;
      }
      if (e.labelRate != null) {
        _labelRateController.text = e.labelRate == e.labelRate!.roundToDouble()
            ? '${e.labelRate!.round()}'
            : '${e.labelRate}';
      }
      if (e.labelRateUnit != null && e.labelRateUnit!.isNotEmpty) {
        _labelRateUnit = e.labelRateUnit!;
      }
      _isTestProduct = e.isTestProduct;
    }
  }

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
    _aiNameController.dispose();
    _aiConcentrationController.dispose();
    _labelRateController.dispose();
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
                widget.existingComponent == null
                    ? 'Add Component — ${widget.treatment.code}'
                    : 'Edit Component — ${widget.treatment.code}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _productController,
                readOnly: widget.restrictedMode,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Component Name *',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 6),
              Text(
                'Product identifier (optional) — enter a standard code for '
                'research and regulatory records.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _eppoController,
                textCapitalization: TextCapitalization.characters,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Product code',
                  hintText: 'e.g. 1BAS5B4048',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _rateController,
                      readOnly: widget.restrictedMode,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: FormStyles.inputDecoration(labelText: 'Rate'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('sheet_rate_unit_$_rateUnit'),
                      isExpanded: true,
                      initialValue: _rateUnit,
                      decoration: FormStyles.inputDecoration(labelText: 'Unit'),
                      items: _componentRateUnits
                          .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: widget.restrictedMode
                          ? null
                          : (v) => switchUnit(
                                controller: _rateController,
                                currentUnit: _rateUnit,
                                newUnit: v ?? _componentRateUnits.first,
                                applyUnit: (u) =>
                                    _rateUnit = u ?? _componentRateUnits.first,
                              ),
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
              DropdownButtonFormField<String?>(
                key: ValueKey('sheet_pestcat_$_pesticideCategory'),
                initialValue: _pesticideCategory,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Pesticide category',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('—')),
                  ..._pesticideCategories.entries.map((e) =>
                      DropdownMenuItem<String?>(
                          value: e.key, child: Text(e.value))),
                ],
                onChanged: (v) => setState(() => _pesticideCategory = v),
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
              ExpansionTile(
                title: const Text('Active ingredient'),
                initiallyExpanded: _aiNameController.text.isNotEmpty,
                children: [
                  TextField(
                    controller: _aiNameController,
                    decoration: FormStyles.inputDecoration(
                      labelText: 'Active ingredient name',
                      hintText: 'e.g. glyphosate',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _aiConcentrationController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: FormStyles.inputDecoration(
                            labelText: 'AI concentration',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('sheet_ai_unit_$_aiConcentrationUnit'),
                          isExpanded: true,
                          initialValue: _aiConcentrationUnit,
                          decoration:
                              FormStyles.inputDecoration(labelText: 'Unit'),
                          items: const [
                            DropdownMenuItem(value: 'g/L', child: Text('g/L')),
                            DropdownMenuItem(
                                value: 'g/kg', child: Text('g/kg')),
                            DropdownMenuItem(value: '%', child: Text('%')),
                          ],
                          onChanged: (v) => switchUnit(
                            controller: _aiConcentrationController,
                            currentUnit: _aiConcentrationUnit,
                            newUnit: v ?? 'g/L',
                            applyUnit: (u) =>
                                _aiConcentrationUnit = u ?? 'g/L',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _labelRateController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: FormStyles.inputDecoration(
                            labelText: 'Label rate',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('sheet_label_unit_$_labelRateUnit'),
                          isExpanded: true,
                          initialValue: _labelRateUnit,
                          decoration:
                              FormStyles.inputDecoration(labelText: 'Unit'),
                          items: const [
                            DropdownMenuItem(
                                value: 'g ai/ha', child: Text('g ai/ha')),
                            DropdownMenuItem(
                                value: 'L/ha', child: Text('L/ha')),
                            DropdownMenuItem(
                                value: 'mL/ha', child: Text('mL/ha')),
                            DropdownMenuItem(
                                value: 'kg/ha', child: Text('kg/ha')),
                          ],
                          onChanged: (v) => switchUnit(
                            controller: _labelRateController,
                            currentUnit: _labelRateUnit,
                            newUnit: v ?? 'g ai/ha',
                            applyUnit: (u) =>
                                _labelRateUnit = u ?? 'g ai/ha',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Test product',
                        style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Mark as test product for comparison',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppDesignTokens.secondaryText)),
                    value: _isTestProduct,
                    onChanged: (v) => setState(() => _isTestProduct = v),
                  ),
                ],
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
                subtitle: const Text(
                  'Manufacturer, registration',
                  style: TextStyle(fontSize: 12),
                ),
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
                    onPressed: _isSaving
                        ? null
                        : () async {
                            final name = _productController.text.trim();
                            if (name.isEmpty) return;
                            setState(() => _isSaving = true);
                            try {
                              final userId = await widget.ref
                                  .read(currentUserIdProvider.future);
                              final repo =
                                  widget.ref.read(treatmentRepositoryProvider);
                              final existing = widget.existingComponent;
                              if (widget.restrictedMode && existing != null) {
                                await repo.updateComponentAnnotationsOnly(
                                  componentId: existing.id,
                                  pesticideCategory: _pesticideCategory,
                                  formulationType: _formulationType,
                                  activeIngredientName:
                                      _aiNameController.text.trim().isEmpty
                                          ? null
                                          : _aiNameController.text.trim(),
                                  aiConcentration: double.tryParse(
                                      _aiConcentrationController.text.trim()),
                                  aiConcentrationUnit:
                                      _aiConcentrationController.text
                                              .trim()
                                              .isNotEmpty
                                          ? _aiConcentrationUnit
                                          : null,
                                  manufacturer: _manufacturerController.text
                                          .trim()
                                          .isEmpty
                                      ? null
                                      : _manufacturerController.text.trim(),
                                  registrationNumber:
                                      _registrationNumberController.text
                                              .trim()
                                              .isEmpty
                                          ? null
                                          : _registrationNumberController.text
                                              .trim(),
                                  eppoCode: _eppoController.text.trim().isEmpty
                                      ? null
                                      : _eppoController.text.trim(),
                                  applicationTiming: _formulationController.text
                                          .trim()
                                          .isEmpty
                                      ? null
                                      : _formulationController.text.trim(),
                                  labelRate: double.tryParse(
                                      _labelRateController.text.trim()),
                                  labelRateUnit:
                                      _labelRateController.text.trim().isNotEmpty
                                          ? _labelRateUnit
                                          : null,
                                  isTestProduct: _isTestProduct,
                                  performedByUserId: userId,
                                );
                              } else {
                                if (existing != null) {
                                  await _deleteTreatmentComponent(
                                      widget.ref, existing.id);
                                }
                                await repo.insertFirstComponent(
                                  treatmentId: widget.treatment.id,
                                  trialId: widget.trial.id,
                                  productName: name,
                                  rate: double.tryParse(_rateController.text
                                      .trim()
                                      .replaceAll(',', '.')),
                                  rateUnit: _rateUnit,
                                  applicationTiming: _formulationController.text
                                          .trim()
                                          .isEmpty
                                      ? null
                                      : _formulationController.text.trim(),
                                  notes: _notesController.text.trim().isEmpty
                                      ? null
                                      : _notesController.text.trim(),
                                  sortOrder: existing?.sortOrder ?? 0,
                                  activeIngredientPct:
                                      _parseActiveIngredientPct(),
                                  formulationType: _formulationType,
                                  manufacturer: _manufacturerController.text
                                          .trim()
                                          .isEmpty
                                      ? null
                                      : _manufacturerController.text.trim(),
                                  registrationNumber:
                                      _registrationNumberController.text
                                              .trim()
                                              .isEmpty
                                          ? null
                                          : _registrationNumberController.text
                                              .trim(),
                                  eppoCode: _eppoController.text.trim().isEmpty
                                      ? null
                                      : _eppoController.text.trim(),
                                  activeIngredientName:
                                      _aiNameController.text.trim().isEmpty
                                          ? null
                                          : _aiNameController.text.trim(),
                                  aiConcentration: double.tryParse(
                                      _aiConcentrationController.text.trim()),
                                  aiConcentrationUnit:
                                      _aiConcentrationController.text
                                              .trim()
                                              .isNotEmpty
                                          ? _aiConcentrationUnit
                                          : null,
                                  labelRate: double.tryParse(
                                      _labelRateController.text.trim()),
                                  labelRateUnit: _labelRateController.text
                                          .trim()
                                          .isNotEmpty
                                      ? _labelRateUnit
                                      : null,
                                  isTestProduct: _isTestProduct,
                                  pesticideCategory: _pesticideCategory,
                                  performedByUserId: userId,
                                );
                              }
                              if (!context.mounted) return;
                              widget.onSaved();
                              Navigator.pop(context);
                            } on ProtocolEditBlockedException catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.message)),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isSaving = false);
                              }
                            }
                          },
                    child: Text(_isSaving ? 'Saving…' : 'Save'),
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
  bool _isSaving = false;
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
  String? pesticideCategory;

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
          const SizedBox(height: 6),
          Text(
            'Product code (optional) — standard code for research records.',
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: eppoController,
            textCapitalization: TextCapitalization.characters,
            decoration: FormStyles.inputDecoration(
              labelText: 'Product code',
              hintText: 'e.g. 1BAS5B4048',
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
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
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
              const DropdownMenuItem<String?>(value: null, child: Text('—')),
              ..._formulationTypes.map(
                  (s) => DropdownMenuItem<String?>(value: s, child: Text(s))),
            ],
            onChanged: (v) => setState(() => formulationType = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: ValueKey('dialog_pestcat_$pesticideCategory'),
            initialValue: pesticideCategory,
            decoration: FormStyles.inputDecoration(
              labelText: 'Pesticide category',
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('—')),
              ..._pesticideCategories.entries.map((e) =>
                  DropdownMenuItem<String?>(
                      value: e.key, child: Text(e.value))),
            ],
            onChanged: (v) => setState(() => pesticideCategory = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: activeIngredientPctController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            subtitle: const Text(
              'Manufacturer, registration',
              style: TextStyle(fontSize: 12),
            ),
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
          onPressed: _isSaving
              ? null
              : () async {
                  if (productController.text.trim().isEmpty) return;
                  setState(() => _isSaving = true);
                  try {
                    final userId =
                        await widget.ref.read(currentUserIdProvider.future);
                    final repo = widget.ref.read(treatmentRepositoryProvider);
                    await repo.insertFirstComponent(
                      treatmentId: widget.treatment.id,
                      trialId: widget.trial.id,
                      productName: productController.text.trim(),
                      rate: double.tryParse(
                          rateController.text.trim().replaceAll(',', '.')),
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
                      pesticideCategory: pesticideCategory,
                      performedByUserId: userId,
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    await widget.onSaved();
                  } on ProtocolEditBlockedException catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message)),
                    );
                  } finally {
                    if (mounted) {
                      setState(() => _isSaving = false);
                    }
                  }
                },
          child: Text(_isSaving ? 'Adding…' : 'Add Product'),
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
    ref.invalidate(treatmentComponentsByTreatmentForTrialProvider(widget.trial.id));
    invalidateTrialReviewProviders(ref, widget.trial.id);
  }

  @override
  Widget build(BuildContext context) {
    final hasSessionData =
        ref.watch(trialHasSessionDataProvider(widget.trial.id)).valueOrNull ??
            false;
    final trialIsArmLinked = ref
            .watch(armTrialMetadataStreamProvider(widget.trial.id))
            .valueOrNull
            ?.isArmLinked ??
        false;
    final locked = !canEditTrialStructure(
      widget.trial,
      hasSessionData: hasSessionData,
      trialIsArmLinked: trialIsArmLinked,
    );

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
    final hasSessionData =
        ref.watch(trialHasSessionDataProvider(widget.trial.id)).valueOrNull ??
            false;
    final trialIsArmLinked = ref
            .watch(armTrialMetadataStreamProvider(widget.trial.id))
            .valueOrNull
            ?.isArmLinked ??
        false;
    final locked = !canEditTrialStructure(
      widget.trial,
      hasSessionData: hasSessionData,
      trialIsArmLinked: trialIsArmLinked,
    );
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
    final hasApps = await _treatmentHasApplications(ref, widget.treatment.id);
    if (!context.mounted) return;
    if (hasApps) {
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
            'Remove "${component.productName}" from ${widget.treatment.code}?\n\n'
            'This treatment has application records. '
            'Removing this product will lose planned rate comparison data.',
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
    }
    await _deleteTreatmentComponent(ref, component.id);
    ref.invalidate(
      treatmentComponentsForTreatmentProvider(widget.treatment.id),
    );
    ref.invalidate(
      treatmentComponentsCountForTrialProvider(widget.trial.id),
    );
    ref.invalidate(
      treatmentComponentsByTreatmentForTrialProvider(widget.trial.id),
    );
    invalidateTrialReviewProviders(ref, widget.trial.id);
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
