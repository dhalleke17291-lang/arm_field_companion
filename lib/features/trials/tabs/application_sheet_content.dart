import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';

/// Five-section add/edit application bottom sheet content.
class ApplicationSheetContent extends ConsumerStatefulWidget {
  const ApplicationSheetContent({
    super.key,
    required this.trial,
    required this.existing,
    required this.scrollController,
    required this.rateUnits,
    required this.applicationMethods,
    required this.nozzleTypes,
    required this.pressureUnits,
    required this.speedUnits,
    required this.waterVolumeUnits,
    required this.adjuvantRateUnits,
    required this.treatedAreaUnits,
    required this.soilMoistureOptions,
    required this.onSaved,
    this.onDelete,
  });

  final Trial trial;
  final TrialApplicationEvent? existing;
  final ScrollController scrollController;
  final List<String> rateUnits;
  final List<String> applicationMethods;
  final List<String> nozzleTypes;
  final List<String> pressureUnits;
  final List<String> speedUnits;
  final List<String> waterVolumeUnits;
  final List<String> adjuvantRateUnits;
  final List<String> treatedAreaUnits;
  final List<String> soilMoistureOptions;
  final VoidCallback onSaved;
  final VoidCallback? onDelete;

  @override
  ConsumerState<ApplicationSheetContent> createState() =>
      _ApplicationSheetContentState();
}

class _ApplicationSheetContentState extends ConsumerState<ApplicationSheetContent> {
  late DateTime _date;
  late String? _timeStr;
  late int? _treatmentId;
  late final TextEditingController _productController;
  late final TextEditingController _rateController;
  late String? _rateUnit;
  late String? _applicationMethod;

  late final TextEditingController _nozzleSpacingController;
  late final TextEditingController _operatingPressureController;
  late String? _pressureUnit;
  late final TextEditingController _groundSpeedController;
  late String? _speedUnit;
  late final TextEditingController _equipmentController;
  late final TextEditingController _operatorController;
  late String? _nozzleType;

  late final TextEditingController _waterVolumeController;
  late String? _waterVolumeUnit;
  late final TextEditingController _adjuvantNameController;
  late final TextEditingController _adjuvantRateController;
  late String? _adjuvantRateUnit;
  late final TextEditingController _spraySolutionPhController;
  late final TextEditingController _treatedAreaController;
  late String? _treatedAreaUnit;

  late final TextEditingController _windSpeedController;
  late final TextEditingController _windDirectionController;
  late final TextEditingController _temperatureController;
  late final TextEditingController _humidityController;
  late final TextEditingController _cloudCoverController;
  late String? _soilMoisture;

  late final TextEditingController _growthStageController;
  late final TextEditingController _notesController;
  late Set<String> _selectedPlotLabels;

  bool _saving = false;
  bool _initialExpandedEquip = false;
  bool _initialExpandedTank = false;
  bool _initialExpandedWeather = false;
  bool _initialExpandedCoverage = false;

  static String? _trim(String? s) =>
      s == null || s.trim().isEmpty ? null : s.trim();
  static double? _parseDouble(String s) {
    final t = s.trim();
    return t.isEmpty ? null : double.tryParse(t);
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.applicationDate.toLocal() ?? DateTime.now();
    _timeStr = e?.applicationTime;
    _treatmentId = e?.treatmentId;
    _productController = TextEditingController(text: e?.productName ?? '');
    _rateController = TextEditingController(
        text: e?.rate != null ? e!.rate.toString() : '');
    _rateUnit = e?.rateUnit ?? widget.rateUnits.first;
    _applicationMethod = e?.applicationMethod;

    _nozzleType = e?.nozzleType;
    _nozzleSpacingController = TextEditingController(
        text: e?.nozzleSpacingCm != null ? e!.nozzleSpacingCm.toString() : '');
    _operatingPressureController = TextEditingController(
        text: e?.operatingPressure != null ? e!.operatingPressure.toString() : '');
    _pressureUnit = e?.pressureUnit;
    _groundSpeedController = TextEditingController(
        text: e?.groundSpeed != null ? e!.groundSpeed.toString() : '');
    _speedUnit = e?.speedUnit;
    _equipmentController = TextEditingController(text: e?.equipmentUsed ?? '');
    _operatorController = TextEditingController(text: e?.operatorName ?? '');
    _initialExpandedEquip = _nozzleType != null ||
        e?.nozzleSpacingCm != null ||
        e?.operatingPressure != null ||
        e?.groundSpeed != null ||
        _trim(e?.equipmentUsed) != null ||
        _trim(e?.operatorName) != null;

    _waterVolumeController = TextEditingController(
        text: e?.waterVolume != null ? e!.waterVolume.toString() : '');
    _waterVolumeUnit = e?.waterVolumeUnit;
    _adjuvantNameController = TextEditingController(text: e?.adjuvantName ?? '');
    _adjuvantRateController = TextEditingController(
        text: e?.adjuvantRate != null ? e!.adjuvantRate.toString() : '');
    _adjuvantRateUnit = e?.adjuvantRateUnit;
    _spraySolutionPhController = TextEditingController(
        text: e?.spraySolutionPh != null ? e!.spraySolutionPh.toString() : '');
    _treatedAreaController = TextEditingController(
        text: e?.treatedArea != null ? e!.treatedArea.toString() : '');
    _treatedAreaUnit = e?.treatedAreaUnit;
    _initialExpandedTank = e?.waterVolume != null ||
        _trim(e?.adjuvantName) != null ||
        e?.adjuvantRate != null ||
        e?.spraySolutionPh != null ||
        e?.treatedArea != null;

    _windSpeedController = TextEditingController(
        text: e?.windSpeed != null ? e!.windSpeed.toString() : '');
    _windDirectionController =
        TextEditingController(text: e?.windDirection ?? '');
    _temperatureController = TextEditingController(
        text: e?.temperature != null ? e!.temperature.toString() : '');
    _humidityController = TextEditingController(
        text: e?.humidity != null ? e!.humidity.toString() : '');
    _cloudCoverController = TextEditingController(
        text: e?.cloudCoverPct != null ? e!.cloudCoverPct.toString() : '');
    _soilMoisture = e?.soilMoisture;
    _initialExpandedWeather = e?.windSpeed != null ||
        _trim(e?.windDirection) != null ||
        e?.temperature != null ||
        e?.humidity != null ||
        e?.cloudCoverPct != null ||
        e?.soilMoisture != null;

    _growthStageController =
        TextEditingController(text: e?.growthStageCode ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _selectedPlotLabels = e?.plotsTreated != null && e!.plotsTreated!.trim().isNotEmpty
        ? e.plotsTreated!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet()
        : {};
    _initialExpandedCoverage = _trim(e?.growthStageCode) != null ||
        _selectedPlotLabels.isNotEmpty ||
        _trim(e?.notes) != null;
  }

  @override
  void dispose() {
    _productController.dispose();
    _rateController.dispose();
    _nozzleSpacingController.dispose();
    _operatingPressureController.dispose();
    _groundSpeedController.dispose();
    _equipmentController.dispose();
    _operatorController.dispose();
    _waterVolumeController.dispose();
    _adjuvantNameController.dispose();
    _adjuvantRateController.dispose();
    _spraySolutionPhController.dispose();
    _treatedAreaController.dispose();
    _windSpeedController.dispose();
    _windDirectionController.dispose();
    _temperatureController.dispose();
    _humidityController.dispose();
    _cloudCoverController.dispose();
    _growthStageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (p != null && mounted) setState(() => _date = p);
  }

  Future<void> _pickTime() async {
    TimeOfDay initial = TimeOfDay.now();
    if (_timeStr != null && _timeStr!.trim().isNotEmpty) {
      final parts = _timeStr!.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) initial = TimeOfDay(hour: h, minute: m);
      }
    }
    final t = await showTimePicker(context: context, initialTime: initial);
    if (t != null && mounted) {
      setState(() => _timeStr =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
    }
  }

  int _equipFilled() {
    int n = 0;
    if (_nozzleType != null) n++;
    if (_nozzleSpacingController.text.trim().isNotEmpty) n++;
    if (_operatingPressureController.text.trim().isNotEmpty) n++;
    if (_groundSpeedController.text.trim().isNotEmpty) n++;
    if (_equipmentController.text.trim().isNotEmpty) n++;
    if (_operatorController.text.trim().isNotEmpty) n++;
    return n;
  }

  int _tankFilled() {
    int n = 0;
    if (_waterVolumeController.text.trim().isNotEmpty) n++;
    if (_adjuvantNameController.text.trim().isNotEmpty) n++;
    if (_adjuvantRateController.text.trim().isNotEmpty) n++;
    if (_spraySolutionPhController.text.trim().isNotEmpty) n++;
    if (_treatedAreaController.text.trim().isNotEmpty) n++;
    return n;
  }

  int _weatherFilled() {
    int n = 0;
    if (_windSpeedController.text.trim().isNotEmpty) n++;
    if (_windDirectionController.text.trim().isNotEmpty) n++;
    if (_temperatureController.text.trim().isNotEmpty) n++;
    if (_humidityController.text.trim().isNotEmpty) n++;
    if (_cloudCoverController.text.trim().isNotEmpty) n++;
    if (_soilMoisture != null) n++;
    return n;
  }

  int _coverageFilled() {
    int n = 0;
    if (_growthStageController.text.trim().isNotEmpty) n++;
    if (_selectedPlotLabels.isNotEmpty) n++;
    if (_notesController.text.trim().isNotEmpty) n++;
    return n;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(applicationRepositoryProvider);
      final companion = _buildCompanion();
      if (widget.existing == null) {
        await repo.createApplication(companion);
      } else {
        await repo.updateApplication(widget.existing!.id, companion);
      }
      if (mounted) widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  TrialApplicationEventsCompanion _buildCompanion() {
    final plotsTreatedStr = _selectedPlotLabels.isEmpty
        ? null
        : _selectedPlotLabels.join(', ');
    if (widget.existing == null) {
      return TrialApplicationEventsCompanion.insert(
        trialId: widget.trial.id,
        applicationDate: _date,
        applicationTime: drift.Value(_timeStr),
        treatmentId: drift.Value(_treatmentId),
        productName: drift.Value(_trim(_productController.text)),
        rate: drift.Value(_parseDouble(_rateController.text)),
        rateUnit: drift.Value(_rateUnit),
        applicationMethod: drift.Value(_applicationMethod),
        nozzleType: drift.Value(_nozzleType),
        nozzleSpacingCm: drift.Value(_parseDouble(_nozzleSpacingController.text)),
        operatingPressure: drift.Value(_parseDouble(_operatingPressureController.text)),
        pressureUnit: drift.Value(_pressureUnit),
        groundSpeed: drift.Value(_parseDouble(_groundSpeedController.text)),
        speedUnit: drift.Value(_speedUnit),
        equipmentUsed: drift.Value(_trim(_equipmentController.text)),
        operatorName: drift.Value(_trim(_operatorController.text)),
        waterVolume: drift.Value(_parseDouble(_waterVolumeController.text)),
        waterVolumeUnit: drift.Value(_waterVolumeUnit),
        adjuvantName: drift.Value(_trim(_adjuvantNameController.text)),
        adjuvantRate: drift.Value(_parseDouble(_adjuvantRateController.text)),
        adjuvantRateUnit: drift.Value(_adjuvantRateUnit),
        spraySolutionPh: drift.Value(_parseDouble(_spraySolutionPhController.text)),
        treatedArea: drift.Value(_parseDouble(_treatedAreaController.text)),
        treatedAreaUnit: drift.Value(_treatedAreaUnit),
        windSpeed: drift.Value(_parseDouble(_windSpeedController.text)),
        windDirection: drift.Value(_trim(_windDirectionController.text)),
        temperature: drift.Value(_parseDouble(_temperatureController.text)),
        humidity: drift.Value(_parseDouble(_humidityController.text)),
        cloudCoverPct: drift.Value(_parseDouble(_cloudCoverController.text)),
        soilMoisture: drift.Value(_soilMoisture),
        growthStageCode: drift.Value(_trim(_growthStageController.text)),
        plotsTreated: drift.Value(plotsTreatedStr),
        notes: drift.Value(_trim(_notesController.text)),
      );
    }
    return TrialApplicationEventsCompanion(
      id: drift.Value(widget.existing!.id),
      trialId: drift.Value(widget.trial.id),
      applicationDate: drift.Value(_date),
      applicationTime: drift.Value(_timeStr),
      treatmentId: drift.Value(_treatmentId),
      productName: drift.Value(_trim(_productController.text)),
      rate: drift.Value(_parseDouble(_rateController.text)),
      rateUnit: drift.Value(_rateUnit),
      applicationMethod: drift.Value(_applicationMethod),
      nozzleType: drift.Value(_nozzleType),
      nozzleSpacingCm: drift.Value(_parseDouble(_nozzleSpacingController.text)),
      operatingPressure: drift.Value(_parseDouble(_operatingPressureController.text)),
      pressureUnit: drift.Value(_pressureUnit),
      groundSpeed: drift.Value(_parseDouble(_groundSpeedController.text)),
      speedUnit: drift.Value(_speedUnit),
      equipmentUsed: drift.Value(_trim(_equipmentController.text)),
      operatorName: drift.Value(_trim(_operatorController.text)),
      waterVolume: drift.Value(_parseDouble(_waterVolumeController.text)),
      waterVolumeUnit: drift.Value(_waterVolumeUnit),
      adjuvantName: drift.Value(_trim(_adjuvantNameController.text)),
      adjuvantRate: drift.Value(_parseDouble(_adjuvantRateController.text)),
      adjuvantRateUnit: drift.Value(_adjuvantRateUnit),
      spraySolutionPh: drift.Value(_parseDouble(_spraySolutionPhController.text)),
      treatedArea: drift.Value(_parseDouble(_treatedAreaController.text)),
      treatedAreaUnit: drift.Value(_treatedAreaUnit),
      windSpeed: drift.Value(_parseDouble(_windSpeedController.text)),
      windDirection: drift.Value(_trim(_windDirectionController.text)),
      temperature: drift.Value(_parseDouble(_temperatureController.text)),
      humidity: drift.Value(_parseDouble(_humidityController.text)),
      cloudCoverPct: drift.Value(_parseDouble(_cloudCoverController.text)),
      soilMoisture: drift.Value(_soilMoisture),
      growthStageCode: drift.Value(_trim(_growthStageController.text)),
      plotsTreated: drift.Value(plotsTreatedStr),
      notes: drift.Value(_trim(_notesController.text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final treatments =
        ref.watch(treatmentsForTrialProvider(widget.trial.id)).value ?? [];
    final plots =
        ref.watch(plotsForTrialProvider(widget.trial.id)).value ?? [];
    final dateLabel = DateFormat('MMM d, yyyy').format(_date);

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(AppDesignTokens.spacing16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? 'Add Application' : 'Edit Application',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          // Section 1 — Core (always visible)
          Text('Core',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600)),
          const Divider(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text('Date: $dateLabel'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.access_time, size: 18),
            label: Text('Time: ${_timeStr ?? '—'}'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            key: ValueKey<int?>(_treatmentId),
            initialValue: _treatmentId,
            decoration: const InputDecoration(
              labelText: 'Treatment',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('None')),
              ...treatments.map((t) =>
                  DropdownMenuItem<int?>(value: t.id, child: Text(t.code))),
            ],
            onChanged: (v) => setState(() => _treatmentId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _productController,
            decoration: const InputDecoration(
              labelText: 'Product name',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _rateController,
                  decoration: const InputDecoration(
                    labelText: 'Rate',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String?>(_rateUnit),
                  initialValue: _rateUnit,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.rateUnits
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) => setState(() => _rateUnit = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: ValueKey<String?>(_applicationMethod),
            initialValue: _applicationMethod,
            decoration: const InputDecoration(
              labelText: 'Application method',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('—')),
              ...widget.applicationMethods.map((s) =>
                  DropdownMenuItem<String?>(value: s, child: Text(s))),
            ],
            onChanged: (v) => setState(() => _applicationMethod = v),
          ),
          const SizedBox(height: 16),
          // Section 2 — Equipment
          ExpansionTile(
            initiallyExpanded: _initialExpandedEquip,
            title: Row(
              children: [
                const Text('Equipment details'),
                if (_equipFilled() > 0) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('${_equipFilled()} filled'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ],
            ),
            children: [
              DropdownButtonFormField<String?>(
                key: ValueKey<String?>(_nozzleType),
                initialValue: _nozzleType,
                decoration: const InputDecoration(
                  labelText: 'Nozzle type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('—')),
                  ...widget.nozzleTypes.map((s) =>
                      DropdownMenuItem<String?>(value: s, child: Text(s))),
                ],
                onChanged: (v) => setState(() => _nozzleType = v),
              ),
              _field('Nozzle spacing cm', _nozzleSpacingController),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _operatingPressureController,
                      decoration: const InputDecoration(
                        labelText: 'Operating pressure',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey<String?>(_pressureUnit),
                      initialValue: _pressureUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('—')),
                        ...widget.pressureUnits.map((s) =>
                            DropdownMenuItem<String?>(value: s, child: Text(s))),
                      ],
                      onChanged: (v) => setState(() => _pressureUnit = v),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _groundSpeedController,
                      decoration: const InputDecoration(
                        labelText: 'Ground speed',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey<String?>(_speedUnit),
                      initialValue: _speedUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('—')),
                        ...widget.speedUnits.map((s) =>
                            DropdownMenuItem<String?>(value: s, child: Text(s))),
                      ],
                      onChanged: (v) => setState(() => _speedUnit = v),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _equipmentController,
                decoration: const InputDecoration(
                  labelText: 'Equipment used',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _operatorController,
                decoration: const InputDecoration(
                  labelText: 'Operator name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          // Section 3 — Tank mix
          ExpansionTile(
            initiallyExpanded: _initialExpandedTank,
            title: Row(
              children: [
                const Text('Tank mix'),
                if (_tankFilled() > 0) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('${_tankFilled()} filled'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ],
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _waterVolumeController,
                      decoration: const InputDecoration(
                        labelText: 'Water volume',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey<String?>(_waterVolumeUnit),
                      initialValue: _waterVolumeUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('—')),
                        ...widget.waterVolumeUnits.map((s) =>
                            DropdownMenuItem<String?>(value: s, child: Text(s))),
                      ],
                      onChanged: (v) => setState(() => _waterVolumeUnit = v),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _adjuvantNameController,
                decoration: const InputDecoration(
                  labelText: 'Adjuvant name',
                  hintText: 'e.g. Agral 90, Merge',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _adjuvantRateController,
                      decoration: const InputDecoration(
                        labelText: 'Adjuvant rate',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey<String?>(_adjuvantRateUnit),
                      initialValue: _adjuvantRateUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('—')),
                        ...widget.adjuvantRateUnits.map((s) =>
                            DropdownMenuItem<String?>(value: s, child: Text(s))),
                      ],
                      onChanged: (v) => setState(() => _adjuvantRateUnit = v),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _spraySolutionPhController,
                decoration: const InputDecoration(
                  labelText: 'Spray solution pH',
                  hintText: 'pH of mixed solution',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _treatedAreaController,
                      decoration: const InputDecoration(
                        labelText: 'Treated area',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey<String?>(_treatedAreaUnit),
                      initialValue: _treatedAreaUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('—')),
                        ...widget.treatedAreaUnits.map((s) =>
                            DropdownMenuItem<String?>(value: s, child: Text(s))),
                      ],
                      onChanged: (v) => setState(() => _treatedAreaUnit = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Section 4 — Weather
          ExpansionTile(
            initiallyExpanded: _initialExpandedWeather,
            title: Row(
              children: [
                const Text('Weather & conditions'),
                if (_weatherFilled() > 0) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('${_weatherFilled()} filled'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ],
            ),
            children: [
              TextField(
                controller: _windSpeedController,
                decoration: const InputDecoration(
                  labelText: 'Wind speed',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _windDirectionController,
                decoration: const InputDecoration(
                  labelText: 'Wind direction',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _temperatureController,
                decoration: const InputDecoration(
                  labelText: 'Temperature (°C)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _humidityController,
                decoration: const InputDecoration(
                  labelText: 'Humidity (%)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _cloudCoverController,
                decoration: const InputDecoration(
                  labelText: 'Cloud cover (%)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              DropdownButtonFormField<String?>(
                key: ValueKey<String?>(_soilMoisture),
                initialValue: _soilMoisture,
                decoration: const InputDecoration(
                  labelText: 'Soil moisture',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('—')),
                  ...widget.soilMoistureOptions.map((s) =>
                      DropdownMenuItem<String?>(value: s, child: Text(s))),
                ],
                onChanged: (v) => setState(() => _soilMoisture = v),
              ),
            ],
          ),
          // Section 5 — Coverage & timing
          ExpansionTile(
            initiallyExpanded: _initialExpandedCoverage,
            title: Row(
              children: [
                const Text('Coverage & timing'),
                if (_coverageFilled() > 0) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('${_coverageFilled()} filled'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ],
            ),
            children: [
              TextField(
                controller: _growthStageController,
                decoration: const InputDecoration(
                  labelText: 'Growth stage / BBCH',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: plots.map((plot) {
                  final label = plot.plotId;
                  final selected = _selectedPlotLabels.contains(label);
                  return FilterChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _selectedPlotLabels.add(label);
                        } else {
                          _selectedPlotLabels.remove(label);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (widget.onDelete != null) ...[
                TextButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
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
                                      backgroundColor: Colors.red),
                                  onPressed: () => Navigator.pop(d, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && mounted) widget.onDelete!();
                        },
                  child: const Text('Delete'),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child:
                    Text(_saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
