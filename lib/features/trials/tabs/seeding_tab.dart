import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/design/form_styles.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_standard_widgets.dart';
import '../../../core/widgets/loading_error_widgets.dart';
import '../../../core/widgets/standard_form_bottom_sheet.dart';
import '../../../shared/widgets/app_empty_state.dart';

const List<String> _kSeedingRateUnits = ['seeds/m²', 'kg/ha', 'lbs/ac'];

const List<String> _kPlantingMethods = [
  'Direct seeded',
  'Transplanted',
  'Broadcast',
  'Dibbled',
  'Other',
];

Widget _sectionHeader(String title) {
  return Padding(
    padding: FormStyles.sectionLabelPadding,
    child: Text(
      title.toUpperCase(),
      style: FormStyles.sectionLabelStyle,
    ),
  );
}

/// Seeding tab for a trial. Use as tab content or full-screen body:
/// [body: SeedingTab(trial: trial)].
class SeedingTab extends ConsumerWidget {
  final Trial trial;

  const SeedingTab({super.key, required this.trial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(seedingEventForTrialProvider(trial.id));

    return eventAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDesignTokens.spacing16),
          child: Text(
            'Failed to load seeding event: $e',
            style: const TextStyle(color: AppDesignTokens.secondaryText),
          ),
        ),
      ),
      data: (event) {
        if (event == null) {
          return Column(
            children: [
              const Expanded(
                child: AppEmptyState(
                  icon: Icons.agriculture,
                  title: 'No Seeding Event Yet',
                  subtitle: 'Record the seeding operation for this trial',
                  action: null,
                ),
              ),
              TabListBottomAddButton(
                label: 'Add Seeding Event',
                onPressed: () => _openSeedingEventSheet(context, ref, null),
              ),
            ],
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppDesignTokens.spacing16),
          child: _SeedingEventSummaryCard(
            event: event,
            onEdit: () => _openSeedingEventSheet(context, ref, event),
            onRecordEmergence: () =>
                _openEmergenceSheet(context, ref, event),
            onMarkComplete: event.status == 'pending'
                ? () async {
                    await ref
                        .read(seedingRepositoryProvider)
                        .markSeedingCompleted(
                          id: event.id,
                          completedAt: DateTime.now(),
                        );
                    ref.invalidate(seedingEventForTrialProvider(trial.id));
                  }
                : null,
          ),
        );
      },
    );
  }

  void _openSeedingEventSheet(
      BuildContext context, WidgetRef ref, SeedingEvent? existing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppDesignTokens.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      showDragHandle: false,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => _SeedingEventFormSheet(
            trial: trial,
            existing: existing,
            scrollController: scrollController,
            onSaved: () {
              ref.invalidate(seedingEventForTrialProvider(trial.id));
              if (context.mounted) Navigator.pop(sheetContext);
            },
          ),
        ),
      ),
    );
  }

  void _openEmergenceSheet(
      BuildContext context, WidgetRef ref, SeedingEvent event) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppDesignTokens.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      showDragHandle: false,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => _EmergenceOnlySheet(
            trial: trial,
            existing: event,
            scrollController: scrollController,
            onSaved: () {
              ref.invalidate(seedingEventForTrialProvider(trial.id));
              if (context.mounted) Navigator.pop(sheetContext);
            },
          ),
        ),
      ),
    );
  }
}

class _SeedingEventSummaryCard extends StatelessWidget {
  final SeedingEvent event;
  final VoidCallback onEdit;
  final VoidCallback? onRecordEmergence;
  final Future<void> Function()? onMarkComplete;

  const _SeedingEventSummaryCard({
    required this.event,
    required this.onEdit,
    this.onRecordEmergence,
    this.onMarkComplete,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = event.seedingDate.toLocal().toString().split(' ')[0];
    final hasEmergence =
        event.emergenceDate != null || event.emergencePct != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppDesignTokens.cardSurface,
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
            border: Border.all(color: AppDesignTokens.borderCrisp),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 4,
                  offset: Offset(0, 2)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (event.status == 'completed')
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppDesignTokens.spacing16,
                    AppDesignTokens.spacing12,
                    AppDesignTokens.spacing16,
                    0,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: AppDesignTokens.successFg,
                      ),
                      SizedBox(width: AppDesignTokens.spacing8),
                      Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppDesignTokens.successFg,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppDesignTokens.spacing16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDesignTokens.spacing8),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.sectionHeaderBg,
                        borderRadius: BorderRadius.circular(
                            AppDesignTokens.radiusXSmall),
                      ),
                      child: const Icon(Icons.agriculture,
                          size: 20, color: AppDesignTokens.primary),
                    ),
                    const SizedBox(width: AppDesignTokens.spacing12),
                    Expanded(
                      child: Text(
                        'Seeding $dateText',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppDesignTokens.primaryText),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: onEdit,
                      color: AppDesignTokens.primary,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppDesignTokens.spacing16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (event.status == 'pending')
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppDesignTokens.spacing8,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDesignTokens.spacing8,
                              vertical: AppDesignTokens.spacing4,
                            ),
                            decoration: BoxDecoration(
                              color: AppDesignTokens.warningBg,
                              borderRadius: BorderRadius.circular(
                                AppDesignTokens.radiusXSmall,
                              ),
                            ),
                            child: const Text(
                              'Pending completion',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppDesignTokens.warningFg,
                              ),
                            ),
                          ),
                        ),
                      ),
                    _sectionHeader('Seed details'),
                    if (dateText.isNotEmpty) _summaryRow('Date', dateText),
                    if (event.plantingMethod != null &&
                        event.plantingMethod!.trim().isNotEmpty)
                      _summaryRow('Planting method', event.plantingMethod!),
                    if (event.variety != null &&
                        event.variety!.trim().isNotEmpty)
                      _summaryRow('Variety', event.variety!),
                    if (event.seedLotNumber != null &&
                        event.seedLotNumber!.trim().isNotEmpty)
                      _summaryRow('Seed lot', event.seedLotNumber!),
                    if (event.seedTreatment != null &&
                        event.seedTreatment!.trim().isNotEmpty)
                      _summaryRow('Seed treatment', event.seedTreatment!),
                    if (event.germinationPct != null)
                      _summaryRow(
                          'Germination', '${event.germinationPct}%'),
                    _sectionHeader('Operation details'),
                    if (event.seedingRate != null)
                      _summaryRow(
                          'Rate',
                          '${event.seedingRate} ${event.seedingRateUnit ?? ''}'
                              .trim()),
                    if (event.seedingDepth != null)
                      _summaryRow(
                          'Seeding depth', '${event.seedingDepth} cm'),
                    if (event.rowSpacing != null)
                      _summaryRow('Row spacing', '${event.rowSpacing} cm'),
                    if (event.equipmentUsed != null &&
                        event.equipmentUsed!.trim().isNotEmpty)
                      _summaryRow('Equipment', event.equipmentUsed!),
                    if (event.operatorName != null &&
                        event.operatorName!.trim().isNotEmpty)
                      _summaryRow('Operator', event.operatorName!),
                    if (event.notes != null &&
                        event.notes!.trim().isNotEmpty)
                      _summaryRow('Notes', event.notes!),
                    if (onMarkComplete != null) ...[
                      const Padding(
                        padding:
                            EdgeInsets.only(bottom: AppDesignTokens.spacing4),
                        child: Text(
                          'Seeding saved. Confirm when field work is complete.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppDesignTokens.warningFg,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDesignTokens.spacing12),
                      FilledButton.icon(
                        onPressed: () {
                          final mark = onMarkComplete;
                          if (mark != null) mark();
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Confirm Seeding Complete'),
                      ),
                    ],
                    if (onRecordEmergence != null) ...[
                      const SizedBox(height: AppDesignTokens.spacing12),
                      OutlinedButton.icon(
                        onPressed: onRecordEmergence,
                        icon: const Icon(Icons.grass, size: 18),
                        label: const Text('Record emergence'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (hasEmergence) ...[
          const SizedBox(height: AppDesignTokens.spacing12),
          _EstablishmentCard(event: event),
        ],
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppDesignTokens.secondaryText,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, color: AppDesignTokens.primaryText),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstablishmentCard extends StatelessWidget {
  const _EstablishmentCard({required this.event});

  final SeedingEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000),
              blurRadius: 4,
              offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppDesignTokens.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Establishment',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (event.emergenceDate != null)
              _EstablishmentCard._row(
                  'Emergence date',
                  event.emergenceDate!
                      .toLocal()
                      .toString()
                      .split(' ')[0]),
            if (event.emergencePct != null)
              _EstablishmentCard._row(
                  'Emergence %', '${event.emergencePct}%'),
          ],
        ),
      ),
    );
  }

  static Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppDesignTokens.secondaryText,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, color: AppDesignTokens.primaryText),
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal bottom sheet for quick entry of emergence date and % only.
class _EmergenceOnlySheet extends ConsumerStatefulWidget {
  final Trial trial;
  final SeedingEvent existing;
  final ScrollController scrollController;
  final VoidCallback onSaved;

  const _EmergenceOnlySheet({
    required this.trial,
    required this.existing,
    required this.scrollController,
    required this.onSaved,
  });

  @override
  ConsumerState<_EmergenceOnlySheet> createState() => _EmergenceOnlySheetState();
}

class _EmergenceOnlySheetState extends ConsumerState<_EmergenceOnlySheet> {
  DateTime? _emergenceDate;
  final TextEditingController _emergencePctController =
      TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _emergenceDate = widget.existing.emergenceDate?.toLocal();
    _emergencePctController.text = widget.existing.emergencePct != null
        ? widget.existing.emergencePct.toString()
        : '';
  }

  @override
  void dispose() {
    _emergencePctController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _emergenceDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _emergenceDate = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final pctText = _emergencePctController.text.trim();
    final emergencePct = pctText.isEmpty
        ? null
        : double.tryParse(pctText);

    setState(() => _saving = true);
    try {
      final companion = widget.existing.toCompanion(false).copyWith(
            emergenceDate: _emergenceDate != null
                ? drift.Value(_emergenceDate!)
                : const drift.Value.absent(),
            emergencePct: emergencePct != null
                ? drift.Value(emergencePct)
                : const drift.Value.absent(),
          );
      await ref.read(seedingRepositoryProvider).upsertSeedingEvent(companion);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergence recorded')),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StandardFormBottomSheetLayout(
      title: 'Record emergence',
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      saveEnabled: !_saving,
      saveLabel: _saving ? 'Saving…' : 'Save',
      body: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(
          FormStyles.formSheetHorizontalPadding,
          0,
          FormStyles.formSheetHorizontalPadding,
          FormStyles.formSheetSectionSpacing,
        ),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Emergence date',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.primaryText,
              ),
            ),
            subtitle: Text(
              _emergenceDate == null
                  ? 'Tap to select'
                  : _emergenceDate!.toLocal().toString().split(' ')[0],
              style: const TextStyle(
                color: AppDesignTokens.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: const Icon(
              Icons.calendar_today_outlined,
              color: AppDesignTokens.primary,
              size: 20,
            ),
            onTap: _pickDate,
          ),
          const SizedBox(height: FormStyles.formSheetFieldSpacing),
          TextField(
            controller: _emergencePctController,
            decoration: FormStyles.inputDecoration(
              labelText: 'Emergence % (optional)',
              suffixText: '%',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
    );
  }
}

class _SeedingEventFormSheet extends ConsumerStatefulWidget {
  final Trial trial;
  final SeedingEvent? existing;
  final ScrollController scrollController;
  final VoidCallback onSaved;

  const _SeedingEventFormSheet({
    required this.trial,
    required this.existing,
    required this.scrollController,
    required this.onSaved,
  });

  @override
  ConsumerState<_SeedingEventFormSheet> createState() =>
      _SeedingEventFormSheetState();
}

class _SeedingEventFormSheetState
    extends ConsumerState<_SeedingEventFormSheet> {
  late final TextEditingController _operatorController;
  late final TextEditingController _seedLotController;
  late final TextEditingController _rateController;
  late final TextEditingController _depthController;
  late final TextEditingController _rowSpacingController;
  late final TextEditingController _equipmentController;
  late final TextEditingController _notesController;
  late final TextEditingController _varietyController;
  late final TextEditingController _seedTreatmentController;
  late final TextEditingController _germinationPctController;
  late final TextEditingController _emergencePctController;
  DateTime _seedingDate = DateTime.now();
  String? _rateUnit;
  String? _plantingMethod;
  DateTime? _emergenceDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _seedingDate = e?.seedingDate.toLocal() ?? DateTime.now();
    _rateUnit = e?.seedingRateUnit;
    _plantingMethod = e?.plantingMethod;
    _emergenceDate = e?.emergenceDate?.toLocal();
    _operatorController = TextEditingController(text: e?.operatorName ?? '');
    _seedLotController = TextEditingController(text: e?.seedLotNumber ?? '');
    _rateController = TextEditingController(
        text: e?.seedingRate != null ? e!.seedingRate.toString() : '');
    _depthController = TextEditingController(
        text: e?.seedingDepth != null ? e!.seedingDepth.toString() : '');
    _rowSpacingController = TextEditingController(
        text: e?.rowSpacing != null ? e!.rowSpacing.toString() : '');
    _equipmentController = TextEditingController(text: e?.equipmentUsed ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _varietyController = TextEditingController(text: e?.variety ?? '');
    _seedTreatmentController =
        TextEditingController(text: e?.seedTreatment ?? '');
    _germinationPctController = TextEditingController(
        text: e?.germinationPct != null ? e!.germinationPct.toString() : '');
    _emergencePctController = TextEditingController(
        text: e?.emergencePct != null ? e!.emergencePct.toString() : '');
  }

  @override
  void dispose() {
    _operatorController.dispose();
    _seedLotController.dispose();
    _rateController.dispose();
    _depthController.dispose();
    _rowSpacingController.dispose();
    _equipmentController.dispose();
    _notesController.dispose();
    _varietyController.dispose();
    _seedTreatmentController.dispose();
    _germinationPctController.dispose();
    _emergencePctController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _seedingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _seedingDate = picked);
  }

  Future<void> _pickEmergenceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _emergenceDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _emergenceDate = picked);
  }

  String? _trimOrNull(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  double? _parseDouble(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _save() async {
    final rate = _parseDouble(_rateController);
    final depth = _parseDouble(_depthController);
    final rowSpacing = _parseDouble(_rowSpacingController);
    final germinationPct = _parseDouble(_germinationPctController);
    final emergencePct = _parseDouble(_emergencePctController);

    final baseCompanion = widget.existing == null
        ? SeedingEventsCompanion.insert(
            trialId: widget.trial.id,
            seedingDate: _seedingDate,
            operatorName: drift.Value(_trimOrNull(_operatorController)),
            seedLotNumber: drift.Value(_trimOrNull(_seedLotController)),
            seedingRate: drift.Value(rate),
            seedingRateUnit: drift.Value(_rateUnit),
            seedingDepth: drift.Value(depth),
            rowSpacing: drift.Value(rowSpacing),
            equipmentUsed: drift.Value(_trimOrNull(_equipmentController)),
            notes: drift.Value(_trimOrNull(_notesController)),
            variety: drift.Value(_trimOrNull(_varietyController)),
            seedTreatment: drift.Value(_trimOrNull(_seedTreatmentController)),
            germinationPct: drift.Value(germinationPct),
            emergenceDate: drift.Value(_emergenceDate),
            emergencePct: drift.Value(emergencePct),
            plantingMethod: drift.Value(_plantingMethod),
          )
        : SeedingEventsCompanion(
            id: drift.Value(widget.existing!.id),
            trialId: drift.Value(widget.trial.id),
            seedingDate: drift.Value(_seedingDate),
            operatorName: drift.Value(_trimOrNull(_operatorController)),
            seedLotNumber: drift.Value(_trimOrNull(_seedLotController)),
            seedingRate: drift.Value(rate),
            seedingRateUnit: drift.Value(_rateUnit),
            seedingDepth: drift.Value(depth),
            rowSpacing: drift.Value(rowSpacing),
            equipmentUsed: drift.Value(_trimOrNull(_equipmentController)),
            notes: drift.Value(_trimOrNull(_notesController)),
            variety: drift.Value(_trimOrNull(_varietyController)),
            seedTreatment: drift.Value(_trimOrNull(_seedTreatmentController)),
            germinationPct: drift.Value(germinationPct),
            emergenceDate: drift.Value(_emergenceDate),
            emergencePct: drift.Value(emergencePct),
            plantingMethod: drift.Value(_plantingMethod),
          );

    setState(() => _saving = true);
    try {
      await ref.read(seedingRepositoryProvider).upsertSeedingEvent(baseCompanion);
      if (mounted) widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save seeding: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StandardFormBottomSheetLayout(
      title: widget.existing == null
          ? 'Add Seeding Event'
          : 'Edit Seeding Event',
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      saveEnabled: !_saving,
      saveLabel: _saving ? 'Saving…' : 'Save',
      body: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(
          FormStyles.formSheetHorizontalPadding,
          0,
          FormStyles.formSheetHorizontalPadding,
          FormStyles.formSheetSectionSpacing,
        ),
        children: [
                _sectionHeader('Seed details'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Seeding date',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppDesignTokens.primaryText)),
                  subtitle: Text(
                    _seedingDate.toLocal().toString().split(' ')[0],
                    style: const TextStyle(
                        color: AppDesignTokens.primary,
                        fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined,
                      color: AppDesignTokens.primary, size: 20),
                  onTap: _pickDate,
                ),
                const SizedBox(height: FormStyles.formSheetFieldSpacing),
                DropdownButtonFormField<String?>(
                  key: ValueKey<String?>(_plantingMethod),
                  initialValue: _plantingMethod,
                  decoration: FormStyles.inputDecoration(
                      labelText: 'Planting method'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('—')),
                    ..._kPlantingMethods.map(
                      (s) => DropdownMenuItem<String?>(value: s, child: Text(s)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _plantingMethod = v),
                ),
                const SizedBox(height: FormStyles.formSheetFieldSpacing),
                TextField(
                  controller: _varietyController,
                  decoration: FormStyles.inputDecoration(
                    labelText: 'Variety / cultivar (optional)',
                    hintText: 'e.g. AAC Brandon, Pioneer P9623',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: FormStyles.formSheetFieldSpacing),
                TextField(
                  controller: _seedLotController,
                  decoration: FormStyles.inputDecoration(
                      labelText: 'Seed lot number (optional)'),
                ),
                const SizedBox(height: FormStyles.formSheetSectionSpacing),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  trailing: const Icon(Icons.keyboard_arrow_down_rounded),
                  title: const Text('Seed treatment & germination',
                      style: FormStyles.expansionTitleStyle),
                  initiallyExpanded: false,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _seedTreatmentController,
                            decoration: FormStyles.inputDecoration(
                              labelText: 'Seed treatment (optional)',
                              hintText: 'e.g. Vibrance 500 FS',
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: FormStyles.formSheetFieldSpacing),
                          TextField(
                            controller: _germinationPctController,
                            decoration: FormStyles.inputDecoration(
                              labelText: 'Germination % (optional)',
                            ).copyWith(suffixText: '%'),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  trailing: const Icon(Icons.keyboard_arrow_down_rounded),
                  title: const Text('Operation details',
                      style: FormStyles.expansionTitleStyle),
                  initiallyExpanded: false,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _rateController,
                            decoration: FormStyles.inputDecoration(
                              labelText: 'Seeding rate (optional)',
                              suffixIcon: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: _rateUnit,
                                  isDense: true,
                                  icon: const Icon(
                                      Icons.arrow_drop_down, size: 20),
                                  padding: const EdgeInsets.only(right: 8),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                        value: null, child: Text('—')),
                                    ..._kSeedingRateUnits.map(
                                      (u) => DropdownMenuItem<String?>(
                                          value: u,
                                          child: Text(u,
                                              style: const TextStyle(
                                                  fontSize: 13))),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _rateUnit = v),
                                ),
                              ),
                            ),
                            keyboardType: const TextInputType
                                .numberWithOptions(decimal: true),
                          ),
                          const SizedBox(height: FormStyles.formSheetFieldSpacing),
                          TextField(
                            controller: _depthController,
                            decoration: FormStyles.inputDecoration(
                                labelText: 'Seeding depth cm (optional)'),
                            keyboardType: const TextInputType
                                .numberWithOptions(decimal: true),
                          ),
                          const SizedBox(height: FormStyles.formSheetFieldSpacing),
                          TextField(
                            controller: _rowSpacingController,
                            decoration: FormStyles.inputDecoration(
                                labelText: 'Row spacing cm (optional)'),
                            keyboardType: const TextInputType
                                .numberWithOptions(decimal: true),
                          ),
                          const SizedBox(height: FormStyles.formSheetFieldSpacing),
                          TextField(
                            controller: _equipmentController,
                            decoration: FormStyles.inputDecoration(
                                labelText: 'Equipment used (optional)'),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: FormStyles.formSheetFieldSpacing),
                          TextField(
                            controller: _operatorController,
                            decoration: FormStyles.inputDecoration(
                                labelText: 'Operator name (optional)'),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  trailing: const Icon(Icons.keyboard_arrow_down_rounded),
                  title: const Text('Establishment (fill after emergence)',
                      style: FormStyles.expansionTitleStyle),
                  initiallyExpanded: false,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Emergence date (optional)',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppDesignTokens.primaryText)),
                            subtitle: Text(
                              _emergenceDate == null
                                  ? 'Tap to select'
                                  : _emergenceDate!
                                      .toLocal()
                                      .toString()
                                      .split(' ')[0],
                              style: const TextStyle(
                                  color: AppDesignTokens.primary,
                                  fontWeight: FontWeight.w500),
                            ),
                            trailing: const Icon(Icons.calendar_today_outlined,
                                color: AppDesignTokens.primary, size: 20),
                            onTap: _pickEmergenceDate,
                          ),
                          const SizedBox(height: FormStyles.formSheetFieldSpacing),
                          TextField(
                            controller: _emergencePctController,
                            decoration: FormStyles.inputDecoration(
                                labelText: 'Emergence % (optional)')
                                .copyWith(suffixText: '%'),
                            keyboardType: const TextInputType
                                .numberWithOptions(decimal: true),
                          ),
                          const SizedBox(height: FormStyles.formSheetFieldSpacing),
                          TextField(
                            controller: _notesController,
                            decoration: FormStyles.inputDecoration(
                                labelText: 'Notes (optional)')
                                .copyWith(alignLabelWithHint: true),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
        ),
    );
  }
}

// ─────────────────────────────────────────────
// SEEDING DETAIL SCREEN
// ─────────────────────────────────────────────

class _SeedingDetailScreen extends ConsumerStatefulWidget {
  final SeedingRecord record;

  const _SeedingDetailScreen({required this.record});

  @override
  ConsumerState<_SeedingDetailScreen> createState() =>
      _SeedingDetailScreenState();
}

class _SeedingDetailScreenState extends ConsumerState<_SeedingDetailScreen> {
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, String?> _boolValues = {};
  final Map<String, String?> _dateValues = {};
  bool _initialized = false;
  bool _isSaving = false;
  bool _isReadOnly = true;

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveValues(List<dynamic> fields) async {
    final db = ref.read(databaseProvider);

    setState(() => _isSaving = true);

    await (db.delete(db.seedingFieldValues)
          ..where((t) => t.seedingRecordId.equals(widget.record.id)))
        .go();

    for (final f in fields) {
      final fieldKey = f.fieldKey as String;
      final fieldLabel = f.fieldLabel as String;
      final fieldType = (f.fieldType as String).toLowerCase();
      final unit = f.unit as String?;
      final sortOrder = f.sortOrder as int;

      String? valueText;
      double? valueNumber;
      String? valueDate;
      bool? valueBool;

      if (fieldType == 'number' || fieldType == 'numeric') {
        final raw = _textControllers[fieldKey]?.text.trim();
        if (raw != null && raw.isNotEmpty) {
          valueNumber = double.tryParse(raw);
        }
      } else if (fieldType == 'date') {
        valueDate = _dateValues[fieldKey];
      } else if (fieldType == 'bool' || fieldType == 'boolean') {
        final raw = _boolValues[fieldKey];
        if (raw == 'yes') valueBool = true;
        if (raw == 'no') valueBool = false;
      } else {
        final raw = _textControllers[fieldKey]?.text.trim();
        if (raw != null && raw.isNotEmpty) {
          valueText = raw;
        }
      }

      final hasAnyValue = valueText != null ||
          valueNumber != null ||
          valueDate != null ||
          valueBool != null;

      if (!hasAnyValue) continue;

      await db.into(db.seedingFieldValues).insert(
            SeedingFieldValuesCompanion.insert(
              seedingRecordId: widget.record.id,
              fieldKey: fieldKey,
              fieldLabel: fieldLabel,
              valueText: drift.Value(valueText),
              valueNumber: drift.Value(valueNumber),
              valueDate: drift.Value(valueDate),
              valueBool: drift.Value(valueBool),
              unit: drift.Value(unit),
              sortOrder: drift.Value(sortOrder),
            ),
          );
    }

    if (!mounted) return;

    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Protocol values saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final dateText =
        widget.record.seedingDate.toLocal().toString().split(' ')[0];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seeding Event'),
        actions: [
          IconButton(
            icon: Icon(_isReadOnly ? Icons.edit_outlined : Icons.done),
            tooltip: _isReadOnly ? 'Edit' : 'Done',
            onPressed: () => setState(() => _isReadOnly = !_isReadOnly),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          (db.select(db.protocolSeedingFields)
                ..where((f) => f.trialId.equals(widget.record.trialId))
                ..orderBy([(f) => drift.OrderingTerm.asc(f.sortOrder)]))
              .get(),
          (db.select(db.seedingFieldValues)
                ..where((v) => v.seedingRecordId.equals(widget.record.id))
                ..orderBy([(v) => drift.OrderingTerm.asc(v.sortOrder)]))
              .get(),
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final fields = snapshot.data![0] as List;
          final existingValues = snapshot.data![1] as List;

          if (!_initialized) {
            final existingByKey = <String, dynamic>{
              for (final v in existingValues) v.fieldKey as String: v,
            };

            for (final f in fields) {
              final fieldKey = f.fieldKey as String;
              final fieldType = (f.fieldType as String).toLowerCase();
              final existing = existingByKey[fieldKey];

              if (fieldType == 'number' || fieldType == 'numeric') {
                _textControllers[fieldKey] = TextEditingController(
                  text: existing?.valueNumber?.toString() ?? '',
                );
              } else if (fieldType == 'date') {
                _dateValues[fieldKey] = existing?.valueDate as String?;
              } else if (fieldType == 'bool' || fieldType == 'boolean') {
                if (existing?.valueBool == true) _boolValues[fieldKey] = 'yes';
                if (existing?.valueBool == false) _boolValues[fieldKey] = 'no';
              } else {
                _textControllers[fieldKey] = TextEditingController(
                  text: existing?.valueText as String? ?? '',
                );
              }
            }

            _initialized = true;
          }

          if (_isReadOnly) {
            return _buildSeedingReadOnlyView(context, dateText, existingValues);
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  dateText,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Text(
                  'Operator',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.record.operatorName ?? 'Not recorded',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                Text(
                  'Comments',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.record.comments ?? 'None',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Protocol Fields',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : () => _saveValues(fields),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: fields.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('No protocol fields defined yet.'),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () => _addProtocolField(
                                    context, ref, widget.record),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Field Manually'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: fields.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final f = fields[i];
                            final fieldKey = f.fieldKey as String;
                            final fieldType =
                                (f.fieldType as String).toLowerCase();
                            final label = f.fieldLabel as String;
                            final unit = f.unit as String?;
                            final required = f.isRequired as bool;

                            if (fieldType == 'number' ||
                                fieldType == 'numeric') {
                              return TextFormField(
                                controller: _textControllers[fieldKey],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  labelText:
                                      unit == null ? label : '$label ($unit)',
                                  border: const OutlineInputBorder(),
                                  helperText:
                                      required ? 'Required field' : null,
                                ),
                              );
                            }

                            if (fieldType == 'date') {
                              return TextFormField(
                                readOnly: true,
                                controller: TextEditingController(
                                  text: _dateValues[fieldKey] ?? '',
                                ),
                                decoration: InputDecoration(
                                  labelText: label,
                                  border: const OutlineInputBorder(),
                                  helperText:
                                      required ? 'Required field' : null,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.calendar_today),
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _dateValues[fieldKey] =
                                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                        });
                                      }
                                    },
                                  ),
                                ),
                              );
                            }

                            if (fieldType == 'bool' || fieldType == 'boolean') {
                              return DropdownButtonFormField<String>(
                                initialValue: _boolValues[fieldKey],
                                decoration: InputDecoration(
                                  labelText: label,
                                  border: const OutlineInputBorder(),
                                  helperText:
                                      required ? 'Required field' : null,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'yes', child: Text('Yes')),
                                  DropdownMenuItem(
                                      value: 'no', child: Text('No')),
                                ],
                                onChanged: (value) {
                                  setState(() => _boolValues[fieldKey] = value);
                                },
                              );
                            }

                            return TextFormField(
                              controller: _textControllers[fieldKey],
                              decoration: InputDecoration(
                                labelText:
                                    unit == null ? label : '$label ($unit)',
                                border: const OutlineInputBorder(),
                                helperText: required ? 'Required field' : null,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSeedingReadOnlyView(
      BuildContext context, String dateText, List<dynamic> existingValues) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _readOnlyRow(context, 'Date', dateText),
          const SizedBox(height: 16),
          _readOnlyRow(context, 'Operator',
              widget.record.operatorName ?? 'Not recorded'),
          const SizedBox(height: 16),
          _readOnlyRow(context, 'Comments', widget.record.comments ?? 'None'),
          if (existingValues.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Details',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...existingValues.map<Widget>((v) {
              final label = v.fieldLabel as String? ?? v.fieldKey as String;
              final value = v.valueText ??
                  v.valueNumber?.toString() ??
                  v.valueDate ??
                  (v.valueBool == true
                      ? 'Yes'
                      : v.valueBool == false
                          ? 'No'
                          : '—');
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _readOnlyRow(context, label, value.toString()),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _readOnlyRow(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16)),
      ],
    );
  }
}

Future<void> _addProtocolField(
    BuildContext context, WidgetRef ref, SeedingRecord record) async {
  final db = ref.read(databaseProvider);

  final labelController = TextEditingController();
  final unitController = TextEditingController();

  String fieldType = 'text';
  bool isRequired = false;

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Add Protocol Field'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Field Label',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(
                  labelText: 'Unit (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: fieldType,
                decoration: const InputDecoration(
                  labelText: 'Field Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'text', child: Text('Text')),
                  DropdownMenuItem(value: 'number', child: Text('Number')),
                  DropdownMenuItem(value: 'date', child: Text('Date')),
                  DropdownMenuItem(value: 'bool', child: Text('Yes/No')),
                ],
                onChanged: (v) {
                  fieldType = v!;
                },
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: isRequired,
                title: const Text('Required field'),
                onChanged: (v) {
                  isRequired = v ?? false;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );

  if (saved != true) return;

  final label = labelController.text.trim();
  final unit = unitController.text.trim();

  if (label.isEmpty) return;

  final key = label.toLowerCase().replaceAll(' ', '_');

  await db.into(db.protocolSeedingFields).insert(
        ProtocolSeedingFieldsCompanion.insert(
          trialId: record.trialId,
          fieldKey: key,
          fieldLabel: label,
          fieldType: fieldType,
          unit: drift.Value(unit.isEmpty ? null : unit),
          isRequired: drift.Value(isRequired),
        ),
      );

  if (context.mounted) {
    Navigator.pop(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _SeedingDetailScreen(record: record),
      ),
    );
  }
}
