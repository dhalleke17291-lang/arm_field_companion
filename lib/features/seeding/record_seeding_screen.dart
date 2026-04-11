import 'package:flutter/material.dart';
import '../../core/widgets/gradient_screen_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../core/database/app_database.dart';
import '../../core/providers.dart';

class RecordSeedingScreen extends ConsumerStatefulWidget {
  final Trial trial;

  const RecordSeedingScreen({super.key, required this.trial});

  @override
  ConsumerState<RecordSeedingScreen> createState() =>
      _RecordSeedingScreenState();
}

class _RecordSeedingScreenState extends ConsumerState<RecordSeedingScreen> {
  final _seedingDate = ValueNotifier<DateTime>(DateTime.now());
  final _operatorController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _commentsController = TextEditingController();
  final _varietyController = TextEditingController();
  final _seedLotController = TextEditingController();
  final _seedingRateController = TextEditingController();
  final _rateUnitController = TextEditingController();
  final _seedingDepthController = TextEditingController();
  final _depthUnitController = TextEditingController();
  final _rowSpacingController = TextEditingController();
  final _spacingUnitController = TextEditingController();
  final _rowsPerPlotController = TextEditingController();
  final _rowLengthController = TextEditingController();
  final _rowLengthUnitController = TextEditingController();
  final _soilTempController = TextEditingController();
  final _soilMoistureController = TextEditingController();
  final _conditionsNotesController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _operatorController.dispose();
    _equipmentController.dispose();
    _commentsController.dispose();
    _varietyController.dispose();
    _seedLotController.dispose();
    _seedingRateController.dispose();
    _rateUnitController.dispose();
    _seedingDepthController.dispose();
    _depthUnitController.dispose();
    _rowSpacingController.dispose();
    _spacingUnitController.dispose();
    _rowsPerPlotController.dispose();
    _rowLengthController.dispose();
    _rowLengthUnitController.dispose();
    _soilTempController.dispose();
    _soilMoistureController.dispose();
    _conditionsNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _seedingDate.value,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) _seedingDate.value = picked;
  }

  Future<void> _onSave() async {
    setState(() => _isSaving = true);
    try {
      final db = ref.read(databaseProvider);
    final operatorName = _operatorController.text.trim();
    final comments = _commentsController.text.trim();

    final recordId = await db.into(db.seedingRecords).insert(
          SeedingRecordsCompanion.insert(
            trialId: widget.trial.id,
            seedingDate: _seedingDate.value,
            operatorName:
                drift.Value(operatorName.isEmpty ? null : operatorName),
            comments: drift.Value(comments.isEmpty ? null : comments),
          ),
        );

    // Persist all form fields so they show in the seeding event detail
    final extraFields = <Map<String, dynamic>>[
      {
        'key': 'equipment',
        'label': 'Equipment / Planter',
        'type': 'text',
        'text': _equipmentController.text.trim()
      },
      {
        'key': 'variety',
        'label': 'Variety / Hybrid',
        'type': 'text',
        'text': _varietyController.text.trim()
      },
      {
        'key': 'seed_lot',
        'label': 'Seed Lot',
        'type': 'text',
        'text': _seedLotController.text.trim()
      },
      {
        'key': 'seeding_rate',
        'label': 'Seeding Rate',
        'type': 'number',
        'text': _seedingRateController.text.trim()
      },
      {
        'key': 'rate_unit',
        'label': 'Rate Unit',
        'type': 'text',
        'text': _rateUnitController.text.trim()
      },
      {
        'key': 'seeding_depth',
        'label': 'Seeding Depth',
        'type': 'number',
        'text': _seedingDepthController.text.trim()
      },
      {
        'key': 'depth_unit',
        'label': 'Depth Unit',
        'type': 'text',
        'text': _depthUnitController.text.trim()
      },
      {
        'key': 'row_spacing',
        'label': 'Row Spacing',
        'type': 'number',
        'text': _rowSpacingController.text.trim()
      },
      {
        'key': 'spacing_unit',
        'label': 'Spacing Unit',
        'type': 'text',
        'text': _spacingUnitController.text.trim()
      },
      {
        'key': 'rows_per_plot',
        'label': 'Rows Per Plot',
        'type': 'number',
        'text': _rowsPerPlotController.text.trim()
      },
      {
        'key': 'row_length',
        'label': 'Row Length',
        'type': 'number',
        'text': _rowLengthController.text.trim()
      },
      {
        'key': 'row_length_unit',
        'label': 'Row Length Unit',
        'type': 'text',
        'text': _rowLengthUnitController.text.trim()
      },
      {
        'key': 'soil_temp',
        'label': 'Soil Temperature',
        'type': 'text',
        'text': _soilTempController.text.trim()
      },
      {
        'key': 'soil_moisture',
        'label': 'Soil Moisture',
        'type': 'text',
        'text': _soilMoistureController.text.trim()
      },
      {
        'key': 'conditions_notes',
        'label': 'Conditions / Notes',
        'type': 'text',
        'text': _conditionsNotesController.text.trim()
      },
    ];

    int sortOrder = 0;
    for (final f in extraFields) {
      final key = f['key'] as String;
      final label = f['label'] as String;
      final type = f['type'] as String;
      final text = f['text'] as String?;
      if (text == null || text.isEmpty) continue;

      final existing = await (db.select(db.protocolSeedingFields)
            ..where((p) =>
                p.trialId.equals(widget.trial.id) & p.fieldKey.equals(key)))
          .getSingleOrNull();
      if (existing == null) {
        await db.into(db.protocolSeedingFields).insert(
              ProtocolSeedingFieldsCompanion.insert(
                trialId: widget.trial.id,
                fieldKey: key,
                fieldLabel: label,
                fieldType: type,
              ),
            );
      }

      final isNum = type == 'number' || type == 'numeric';
      final numVal = isNum ? double.tryParse(text) : null;
      await db.into(db.seedingFieldValues).insert(
            SeedingFieldValuesCompanion.insert(
              seedingRecordId: recordId,
              fieldKey: key,
              fieldLabel: label,
              valueText: isNum && numVal != null
                  ? const drift.Value.absent()
                  : drift.Value(text),
              valueNumber: isNum && numVal != null
                  ? drift.Value(numVal)
                  : const drift.Value.absent(),
              unit: const drift.Value.absent(),
              sortOrder: drift.Value(sortOrder++),
            ),
          );
    }

    // Bridge: upsert authoritative seeding_events so attention, timeline, DAS, export reflect completion
    final op = _operatorController.text.trim();
    final equipment = _equipmentController.text.trim();
    final variety = _varietyController.text.trim();
    final seedLot = _seedLotController.text.trim();
    final rateUnit = _rateUnitController.text.trim();
    final companion = SeedingEventsCompanion.insert(
      trialId: widget.trial.id,
      seedingDate: _seedingDate.value,
      operatorName: drift.Value(op.isEmpty ? null : op),
      seedLotNumber: drift.Value(seedLot.isEmpty ? null : seedLot),
      seedingRate: drift.Value(double.tryParse(_seedingRateController.text.trim())),
      seedingRateUnit: drift.Value(rateUnit.isEmpty ? null : rateUnit),
      seedingDepth: drift.Value(double.tryParse(_seedingDepthController.text.trim())),
      rowSpacing: drift.Value(double.tryParse(_rowSpacingController.text.trim())),
      equipmentUsed: drift.Value(equipment.isEmpty ? null : equipment),
      notes: drift.Value(comments.isEmpty ? null : comments),
      variety: drift.Value(variety.isEmpty ? null : variety),
      status: const drift.Value('completed'),
      completedAt: drift.Value(_seedingDate.value),
    );
    final userId = await ref.read(currentUserIdProvider.future);
    final user = await ref.read(currentUserProvider.future);
    await ref.read(seedingRepositoryProvider).upsertSeedingEvent(
          companion,
          performedBy: user?.displayName,
          performedByUserId: userId,
        );
    ref.invalidate(seedingEventForTrialProvider(widget.trial.id));
    ref.invalidate(todayActivityProvider);
    ref.invalidate(workLogDatesProvider);

      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Seeding record added'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save seeding record'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('RecordSeedingScreen save error: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Widget _field(String label, TextEditingController controller,
      {String? hint, TextInputType? keyboardType}) {
    final isNumeric = keyboardType == TextInputType.number ||
        keyboardType == const TextInputType.numberWithOptions(decimal: true);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 2),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: isNumeric
                ? (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (double.tryParse(v.trim()) == null) return 'Invalid number';
                    return null;
                  }
                : null,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: hint,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EB),
      appBar: const GradientScreenHeader(title: 'Record Seeding'),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: scheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        child: Row(
                          children: [
                            Icon(Icons.agriculture, size: 18, color: primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.trial.name,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: primary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.trial.crop != null &&
                                widget.trial.crop!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                widget.trial.crop!,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<DateTime>(
                    valueListenable: _seedingDate,
                    builder: (_, date, __) {
                      final dateStr =
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Seeding Date',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 2),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(4),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today,
                                        size: 18, color: primary),
                                    const SizedBox(width: 8),
                                    Text(dateStr,
                                        style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  _field('Operator Name', _operatorController,
                      hint: 'Name of person operating'),
                  _field('Equipment / Planter', _equipmentController,
                      hint: 'e.g. John Deere 1750'),
                  const SizedBox(height: 6),
                  ExpansionTile(
                    initiallyExpanded: true,
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                    childrenPadding: const EdgeInsets.only(
                        left: 0, right: 0, bottom: 8, top: 4),
                    title: Text(
                      'Core',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: primary),
                    ),
                    children: [
                      _field('Comments', _commentsController,
                          hint: 'Optional notes',
                          keyboardType: TextInputType.multiline),
                    ],
                  ),
                  ExpansionTile(
                    initiallyExpanded: false,
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                    childrenPadding: const EdgeInsets.only(
                        left: 0, right: 0, bottom: 8, top: 4),
                    title: Text(
                      'Planting Parameters',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: primary),
                    ),
                    children: [
                      _field('Variety / Hybrid', _varietyController,
                          hint: 'Optional'),
                      _field('Seed Lot', _seedLotController, hint: 'Optional'),
                      _field('Seeding Rate', _seedingRateController,
                          hint: 'e.g. 350', keyboardType: TextInputType.number),
                      _field('Rate Unit', _rateUnitController,
                          hint: 'e.g. seeds/m'),
                      _field('Seeding Depth', _seedingDepthController,
                          hint: 'e.g. 3', keyboardType: TextInputType.number),
                      _field('Depth Unit', _depthUnitController,
                          hint: 'e.g. cm'),
                      _field('Row Spacing', _rowSpacingController,
                          hint: 'e.g. 19', keyboardType: TextInputType.number),
                      _field('Spacing Unit', _spacingUnitController,
                          hint: 'e.g. cm'),
                    ],
                  ),
                  ExpansionTile(
                    initiallyExpanded: false,
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                    childrenPadding: const EdgeInsets.only(
                        left: 0, right: 0, bottom: 8, top: 4),
                    title: Text(
                      'Plot Setup',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: primary),
                    ),
                    children: [
                      _field('Rows Per Plot', _rowsPerPlotController,
                          hint: 'Optional', keyboardType: TextInputType.number),
                      _field('Row Length', _rowLengthController,
                          hint: 'Optional', keyboardType: TextInputType.number),
                      _field('Row Length Unit', _rowLengthUnitController,
                          hint: 'e.g. m'),
                    ],
                  ),
                  ExpansionTile(
                    initiallyExpanded: false,
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                    childrenPadding: const EdgeInsets.only(
                        left: 0, right: 0, bottom: 8, top: 4),
                    title: Text(
                      'Notes / Conditions',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: primary),
                    ),
                    children: [
                      _field('Soil Temperature', _soilTempController,
                          hint: 'e.g. 12°C',
                          keyboardType: TextInputType.number),
                      _field('Soil Moisture', _soilMoistureController,
                          hint: 'e.g. % or condition',
                          keyboardType: TextInputType.number),
                      _field('Conditions / Notes', _conditionsNotesController,
                          hint: 'Weather, soil condition, etc.',
                          keyboardType: TextInputType.multiline),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _onSave,
                      icon: const Icon(Icons.save, size: 20),
                      label: const Text('Save'),
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
