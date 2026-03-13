import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/loading_error_widgets.dart';
import '../../../shared/widgets/app_empty_state.dart';

const List<String> _kSeedingRateUnits = ['seeds/m²', 'kg/ha', 'lbs/ac'];

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
          return AppEmptyState(
            icon: Icons.agriculture,
            title: 'No Seeding Event Yet',
            subtitle: 'Record the seeding operation for this trial',
            action: FilledButton.icon(
              onPressed: () => _openSeedingEventSheet(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Add Seeding Event'),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppDesignTokens.spacing16),
          child: _SeedingEventSummaryCard(
            event: event,
            onEdit: () => _openSeedingEventSheet(context, ref, event),
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
      backgroundColor: AppDesignTokens.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDesignTokens.radiusLarge)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
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
    );
  }
}

class _SeedingEventSummaryCard extends StatelessWidget {
  final SeedingEvent event;
  final VoidCallback onEdit;

  const _SeedingEventSummaryCard(
      {required this.event, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final dateText =
        event.seedingDate.toLocal().toString().split(' ')[0];

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDesignTokens.spacing16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDesignTokens.spacing8),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.sectionHeaderBg,
                    borderRadius:
                        BorderRadius.circular(AppDesignTokens.radiusXSmall),
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
                if (event.operatorName != null &&
                    event.operatorName!.trim().isNotEmpty)
                  _summaryRow('Operator', event.operatorName!),
                if (event.seedLotNumber != null &&
                    event.seedLotNumber!.trim().isNotEmpty)
                  _summaryRow('Seed lot', event.seedLotNumber!),
                if (event.seedingRate != null)
                  _summaryRow(
                    'Rate',
                    '${event.seedingRate} ${event.seedingRateUnit ?? ''}'
                        .trim()),
                if (event.seedingDepth != null)
                  _summaryRow('Seeding depth', '${event.seedingDepth} cm'),
                if (event.rowSpacing != null)
                  _summaryRow('Row spacing', '${event.rowSpacing} cm'),
                if (event.equipmentUsed != null &&
                    event.equipmentUsed!.trim().isNotEmpty)
                  _summaryRow('Equipment', event.equipmentUsed!),
                if (event.notes != null && event.notes!.trim().isNotEmpty)
                  _summaryRow('Notes', event.notes!),
              ],
            ),
          ),
        ],
      ),
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

class _SeedingEventFormSheetState extends ConsumerState<_SeedingEventFormSheet> {
  late final TextEditingController _operatorController;
  late final TextEditingController _seedLotController;
  late final TextEditingController _rateController;
  late final TextEditingController _depthController;
  late final TextEditingController _rowSpacingController;
  late final TextEditingController _equipmentController;
  late final TextEditingController _notesController;
  DateTime _seedingDate = DateTime.now();
  String? _rateUnit;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _seedingDate = e?.seedingDate.toLocal() ?? DateTime.now();
    _rateUnit = e?.seedingRateUnit;
    _operatorController =
        TextEditingController(text: e?.operatorName ?? '');
    _seedLotController =
        TextEditingController(text: e?.seedLotNumber ?? '');
    _rateController = TextEditingController(
        text: e?.seedingRate != null ? e!.seedingRate.toString() : '');
    _depthController = TextEditingController(
        text: e?.seedingDepth != null ? e!.seedingDepth.toString() : '');
    _rowSpacingController = TextEditingController(
        text: e?.rowSpacing != null ? e!.rowSpacing.toString() : '');
    _equipmentController =
        TextEditingController(text: e?.equipmentUsed ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
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

  Future<void> _save() async {
    final rate = _rateController.text.trim().isEmpty
        ? null
        : double.tryParse(_rateController.text.trim());
    final depth = _depthController.text.trim().isEmpty
        ? null
        : double.tryParse(_depthController.text.trim());
    final rowSpacing = _rowSpacingController.text.trim().isEmpty
        ? null
        : double.tryParse(_rowSpacingController.text.trim());

    final companion = widget.existing == null
        ? SeedingEventsCompanion.insert(
            trialId: widget.trial.id,
            seedingDate: _seedingDate,
            operatorName: drift.Value(_operatorController.text.trim().isEmpty
                ? null
                : _operatorController.text.trim()),
            seedLotNumber: drift.Value(_seedLotController.text.trim().isEmpty
                ? null
                : _seedLotController.text.trim()),
            seedingRate: drift.Value(rate),
            seedingRateUnit: drift.Value(_rateUnit),
            seedingDepth: drift.Value(depth),
            rowSpacing: drift.Value(rowSpacing),
            equipmentUsed: drift.Value(_equipmentController.text.trim().isEmpty
                ? null
                : _equipmentController.text.trim()),
            notes: drift.Value(_notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim()),
          )
        : SeedingEventsCompanion(
            id: drift.Value(widget.existing!.id),
            trialId: drift.Value(widget.trial.id),
            seedingDate: drift.Value(_seedingDate),
            operatorName: drift.Value(_operatorController.text.trim().isEmpty
                ? null
                : _operatorController.text.trim()),
            seedLotNumber: drift.Value(_seedLotController.text.trim().isEmpty
                ? null
                : _seedLotController.text.trim()),
            seedingRate: drift.Value(rate),
            seedingRateUnit: drift.Value(_rateUnit),
            seedingDepth: drift.Value(depth),
            rowSpacing: drift.Value(rowSpacing),
            equipmentUsed: drift.Value(_equipmentController.text.trim().isEmpty
                ? null
                : _equipmentController.text.trim()),
            notes: drift.Value(_notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim()),
          );

    setState(() => _saving = true);
    try {
      await ref.read(seedingRepositoryProvider).upsertSeedingEvent(companion);
      if (mounted) widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(
                top: AppDesignTokens.spacing12,
                bottom: AppDesignTokens.spacing16),
            decoration: BoxDecoration(
              color: AppDesignTokens.dragHandle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing16),
            child: Text(
              widget.existing == null
                  ? 'Add Seeding Event'
                  : 'Edit Seeding Event',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppDesignTokens.primaryText),
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing16),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing16),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date',
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
                const SizedBox(height: AppDesignTokens.spacing8),
                TextField(
                  controller: _operatorController,
                  decoration: const InputDecoration(
                    labelText: 'Operator name (optional)',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppDesignTokens.spacing12),
                TextField(
                  controller: _seedLotController,
                  decoration: const InputDecoration(
                    labelText: 'Seed lot number (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppDesignTokens.spacing12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _rateController,
                        decoration: const InputDecoration(
                          labelText: 'Seeding rate (optional)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: AppDesignTokens.spacing8),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        // ignore: deprecated_member_use
                        value: _rateUnit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('—')),
                          ..._kSeedingRateUnits.map(
                            (u) => DropdownMenuItem<String?>(
                                value: u, child: Text(u)),
                          ),
                        ],
                        onChanged: (v) => setState(() => _rateUnit = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDesignTokens.spacing12),
                TextField(
                  controller: _depthController,
                  decoration: const InputDecoration(
                    labelText: 'Seeding depth cm (optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: AppDesignTokens.spacing12),
                TextField(
                  controller: _rowSpacingController,
                  decoration: const InputDecoration(
                    labelText: 'Row spacing cm (optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: AppDesignTokens.spacing12),
                TextField(
                  controller: _equipmentController,
                  decoration: const InputDecoration(
                    labelText: 'Equipment used (optional)',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppDesignTokens.spacing12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: AppDesignTokens.spacing24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Save'),
                  ),
                ),
                const SizedBox(height: AppDesignTokens.spacing16),
              ],
            ),
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
          _readOnlyRow(context, 'Comments',
              widget.record.comments ?? 'None'),
          if (existingValues.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...existingValues.map<Widget>((v) {
              final label = v.fieldLabel as String? ?? v.fieldKey as String;
              final value = v.valueText ?? v.valueNumber?.toString() ??
                  v.valueDate ?? (v.valueBool == true ? 'Yes' : v.valueBool == false ? 'No' : '—');
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
