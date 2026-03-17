import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/form_styles.dart';
import '../../../core/plot_display.dart';
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
  late String _temperatureUnit;
  late final TextEditingController _humidityController;
  late final TextEditingController _cloudCoverController;
  late String? _soilMoisture;
  late final TextEditingController _soilTempController;
  late final TextEditingController _soilDepthController;
  late String _soilTempUnit;
  late String _soilDepthUnit;

  late final TextEditingController _growthStageController;
  late final TextEditingController _notesController;
  late Set<String> _selectedPlotLabels;

  bool _saving = false;
  bool _initialExpandedEquip = false;
  bool _initialExpandedTank = false;
  bool _initialExpandedWeather = false;
  bool _initialExpandedCoverage = true;

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
    _temperatureUnit = '°C';
    _humidityController = TextEditingController(
        text: e?.humidity != null ? e!.humidity.toString() : '');
    _cloudCoverController = TextEditingController(
        text: e?.cloudCoverPct != null ? e!.cloudCoverPct.toString() : '');
    _soilMoisture = e?.soilMoisture;
    _soilTempController = TextEditingController(
        text: e?.soilTemperature != null ? e!.soilTemperature.toString() : '');
    _soilDepthController = TextEditingController(
        text: e?.soilDepth != null ? e!.soilDepth.toString() : '');
    _soilTempUnit = e?.soilTempUnit ?? '°C';
    final depthUnit = e?.soilDepthUnit ?? 'cm';
    _soilDepthUnit = depthUnit == 'inches' ? 'in' : depthUnit;
    _initialExpandedWeather = e?.windSpeed != null ||
        _trim(e?.windDirection) != null ||
        e?.temperature != null ||
        e?.humidity != null ||
        e?.cloudCoverPct != null ||
        e?.soilMoisture != null ||
        e?.soilTemperature != null ||
        e?.soilDepth != null;

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
    _soilTempController.dispose();
    _soilDepthController.dispose();
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
    if (_soilTempController.text.trim().isNotEmpty) n++;
    if (_soilDepthController.text.trim().isNotEmpty) n++;
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
        soilTemperature: drift.Value(_parseDouble(_soilTempController.text)),
        soilTempUnit: drift.Value(_soilTempUnit),
        soilDepth: drift.Value(_parseDouble(_soilDepthController.text)),
        soilDepthUnit: drift.Value(_soilDepthUnit),
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
      soilTemperature: drift.Value(_parseDouble(_soilTempController.text)),
      soilTempUnit: drift.Value(_soilTempUnit),
      soilDepth: drift.Value(_parseDouble(_soilDepthController.text)),
      soilDepthUnit: drift.Value(_soilDepthUnit),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? 'Add Application' : 'Edit Application',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          // Section 1 — Core (always visible)
          const Padding(
            padding: FormStyles.sectionLabelPadding,
            child: Text('CORE', style: FormStyles.sectionLabelStyle),
          ),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text('Date: $dateLabel'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.access_time, size: 18),
            label: Text('Time: ${_timeStr ?? '—'}'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int?>(
            key: ValueKey<int?>(_treatmentId),
            initialValue: _treatmentId,
            decoration: FormStyles.inputDecoration(labelText: 'Treatment'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('None')),
              ...treatments.map((t) =>
                  DropdownMenuItem<int?>(value: t.id, child: Text(t.code))),
            ],
            onChanged: (v) => setState(() => _treatmentId = v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _productController,
            decoration: FormStyles.inputDecoration(
                labelText: 'Product name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _rateController,
            decoration: FormStyles.inputDecoration(
              labelText: 'Rate',
              suffixIcon: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _rateUnit ?? widget.rateUnits.first,
                  isDense: true,
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  padding: const EdgeInsets.only(right: 8),
                  items: widget.rateUnits
                      .map((u) => DropdownMenuItem<String>(
                          value: u,
                          child: Text(u,
                              style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() => _rateUnit = v),
                ),
              ),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            key: ValueKey<String?>(_applicationMethod),
            initialValue: _applicationMethod,
            decoration: FormStyles.inputDecoration(
                labelText: 'Application method'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('—')),
              ...widget.applicationMethods.map((s) =>
                  DropdownMenuItem<String?>(value: s, child: Text(s))),
            ],
            onChanged: (v) => setState(() => _applicationMethod = v),
          ),
          const SizedBox(height: 14),
          // Section 2 — Equipment
          ExpansionTile(
            initiallyExpanded: _initialExpandedEquip,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            trailing: const Icon(Icons.keyboard_arrow_down_rounded),
            title: Row(
              children: [
                const Text('Equipment details',
                    style: FormStyles.expansionTitleStyle),
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
                decoration: FormStyles.inputDecoration(
                    labelText: 'Nozzle type'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('—')),
                  ...widget.nozzleTypes.map((s) =>
                      DropdownMenuItem<String?>(value: s, child: Text(s))),
                ],
                onChanged: (v) => setState(() => _nozzleType = v),
              ),
              _field('Nozzle spacing cm', _nozzleSpacingController),
              TextField(
                controller: _operatingPressureController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Operating pressure',
                  suffixIcon: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _pressureUnit,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      padding: const EdgeInsets.only(right: 8),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('—')),
                        ...widget.pressureUnits.map((s) =>
                            DropdownMenuItem<String?>(
                                value: s,
                                child: Text(s,
                                    style: const TextStyle(fontSize: 13)))),
                      ],
                      onChanged: (v) => setState(() => _pressureUnit = v),
                    ),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _groundSpeedController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Ground speed',
                  suffixIcon: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _speedUnit,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      padding: const EdgeInsets.only(right: 8),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('—')),
                        ...widget.speedUnits.map((s) =>
                            DropdownMenuItem<String?>(
                                value: s,
                                child: Text(s,
                                    style: const TextStyle(fontSize: 13)))),
                      ],
                      onChanged: (v) => setState(() => _speedUnit = v),
                    ),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _equipmentController,
                decoration: FormStyles.inputDecoration(
                    labelText: 'Equipment used'),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _operatorController,
                decoration: FormStyles.inputDecoration(
                    labelText: 'Operator name'),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          // Section 3 — Tank mix
          ExpansionTile(
            initiallyExpanded: _initialExpandedTank,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            trailing: const Icon(Icons.keyboard_arrow_down_rounded),
            title: Row(
              children: [
                const Text('Tank mix', style: FormStyles.expansionTitleStyle),
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
              TextField(
                controller: _waterVolumeController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Water volume',
                  suffixIcon: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _waterVolumeUnit,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      padding: const EdgeInsets.only(right: 8),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('—')),
                        ...widget.waterVolumeUnits.map((s) =>
                            DropdownMenuItem<String?>(
                                value: s,
                                child: Text(s,
                                    style: const TextStyle(fontSize: 13)))),
                      ],
                      onChanged: (v) => setState(() => _waterVolumeUnit = v),
                    ),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _adjuvantNameController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Adjuvant name',
                  hintText: 'e.g. Agral 90, Merge',
                ),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _adjuvantRateController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Adjuvant rate',
                  suffixIcon: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _adjuvantRateUnit,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      padding: const EdgeInsets.only(right: 8),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('—')),
                        ...widget.adjuvantRateUnits.map((s) =>
                            DropdownMenuItem<String?>(
                                value: s,
                                child: Text(s,
                                    style: const TextStyle(fontSize: 13)))),
                      ],
                      onChanged: (v) => setState(() => _adjuvantRateUnit = v),
                    ),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _spraySolutionPhController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Spray solution pH',
                  hintText: 'pH of mixed solution',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _treatedAreaController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Treated area',
                  suffixIcon: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _treatedAreaUnit,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      padding: const EdgeInsets.only(right: 8),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('—')),
                        ...widget.treatedAreaUnits.map((s) =>
                            DropdownMenuItem<String?>(
                                value: s,
                                child: Text(s,
                                    style: const TextStyle(fontSize: 13)))),
                      ],
                      onChanged: (v) => setState(() => _treatedAreaUnit = v),
                    ),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          // Section 4 — Weather
          ExpansionTile(
            initiallyExpanded: _initialExpandedWeather,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            trailing: const Icon(Icons.keyboard_arrow_down_rounded),
            title: Row(
              children: [
                const Text('Weather & conditions',
                    style: FormStyles.expansionTitleStyle),
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
                decoration: FormStyles.inputDecoration(
                    labelText: 'Wind speed'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _windDirectionController,
                decoration: FormStyles.inputDecoration(
                    labelText: 'Wind direction'),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _temperatureController,
                decoration: FormStyles.inputDecoration(
                    hintText: 'Temperature',
                    suffixIcon: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _temperatureUnit,
                        items: ['°C', '°F']
                            .map((u) => DropdownMenuItem<String>(
                                value: u,
                                child: Text(u,
                                    style:
                                        const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _temperatureUnit = v!),
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        padding: const EdgeInsets.only(right: 8),
                      ),
                    )),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _humidityController,
                style: const TextStyle(color: Color(0xFF1A1A1A)),
                decoration: FormStyles.inputDecoration(
                  hintText: 'Humidity',
                ).copyWith(
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Align(
                      widthFactor: 1.0,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '%',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _cloudCoverController,
                style: const TextStyle(color: Color(0xFF1A1A1A)),
                decoration: FormStyles.inputDecoration(
                  hintText: 'Cloud cover',
                ).copyWith(
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Align(
                      widthFactor: 1.0,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '%',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              DropdownButtonFormField<String?>(
                key: ValueKey<String?>(_soilMoisture),
                initialValue: _soilMoisture,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF1A1A1A),
                ),
                decoration: FormStyles.inputDecoration(
                  hintText: 'Soil moisture',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Soil moisture')),
                  ...widget.soilMoistureOptions.map((s) =>
                      DropdownMenuItem<String?>(value: s, child: Text(s))),
                ],
                onChanged: (v) => setState(() => _soilMoisture = v),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _soilTempController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        hintText: 'Soil temp.',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE0DDD6)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE0DDD6)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFF2D5A40), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _soilTempUnit,
                            items: ['°C', '°F']
                                .map((u) => DropdownMenuItem<String>(
                                    value: u,
                                    child: Text(u,
                                        style:
                                            const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _soilTempUnit = v!),
                            icon: const Icon(Icons.arrow_drop_down, size: 18),
                            padding: const EdgeInsets.only(right: 8),
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 16),
                    child: Text(
                      'at',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _soilDepthController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        hintText: 'Depth',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE0DDD6)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE0DDD6)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFF2D5A40), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _soilDepthUnit,
                            items: ['cm', 'in']
                                .map((u) => DropdownMenuItem<String>(
                                    value: u,
                                    child: Text(u,
                                        style:
                                            const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _soilDepthUnit = v!),
                            icon: const Icon(Icons.arrow_drop_down, size: 18),
                            padding: const EdgeInsets.only(right: 8),
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Section 5 — Coverage & timing
          ExpansionTile(
            initiallyExpanded: _initialExpandedCoverage,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            trailing: const Icon(Icons.keyboard_arrow_down_rounded),
            title: Row(
              children: [
                const Text('Coverage & timing',
                    style: FormStyles.expansionTitleStyle),
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
              TextFormField(
                controller: _growthStageController,
                decoration: FormStyles.inputDecoration(
                    hintText: 'Growth stage / BBCH'),
                keyboardType: TextInputType.text,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PLOTS TREATED',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade400,
                      letterSpacing: 0.6,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      final allLabels =
                          plots.map((p) => getDisplayPlotLabel(p, plots));
                      if (_selectedPlotLabels.length == plots.length) {
                        _selectedPlotLabels.clear();
                      } else {
                        _selectedPlotLabels.addAll(allLabels);
                      }
                    }),
                    child: Text(
                      _selectedPlotLabels.length == plots.length
                          ? 'Deselect all'
                          : 'Select all',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF2D5A40),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Builder(
                builder: (context) {
                  final byRep = <int?, List<Plot>>{};
                  for (final p in plots) {
                    byRep.putIfAbsent(p.rep, () => []).add(p);
                  }
                  final repKeys = byRep.keys.toList()
                    ..sort((a, b) {
                      if (a == null) return 1;
                      if (b == null) return -1;
                      return a.compareTo(b);
                    });
                  return SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: repKeys.map<Widget>((rep) {
                        final repPlots = byRep[rep]!
                          ..sort((a, b) {
                            final sa = a.plotSortIndex ?? a.id;
                            final sb = b.plotSortIndex ?? b.id;
                            if (sa != sb) return sa.compareTo(sb);
                            return a.id.compareTo(b.id);
                          });
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 10, bottom: 6),
                              child: Text(
                                'Rep ${rep ?? '?'}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade400,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: repPlots.map((plot) {
                                final displayLabel =
                                    getDisplayPlotLabel(plot, plots);
                                final isSelected =
                                    _selectedPlotLabels.contains(displayLabel) ||
                                        _selectedPlotLabels.contains(plot.plotId);
                                return IntrinsicWidth(
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      if (isSelected) {
                                        _selectedPlotLabels.remove(displayLabel);
                                        _selectedPlotLabels.remove(plot.plotId);
                                      } else {
                                        _selectedPlotLabels.remove(plot.plotId);
                                        _selectedPlotLabels.add(displayLabel);
                                      }
                                    }),
                                    child: Container(
                                      height: 32,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFE8F5EE)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF2D5A40)
                                              : const Color(0xFFE0DDD6),
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          displayLabel,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? const Color(0xFF2D5A40)
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: FormStyles.inputDecoration(labelText: 'Notes'),
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
                            builder: (d) {
                              final theme = Theme.of(d);
                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                title: const Text('Delete Application?'),
                                content: Text(
                                  'This application will be permanently deleted.',
                                  style: TextStyle(
                                      fontSize: 15,
                                      color: theme.colorScheme.onSurfaceVariant),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(d, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: theme.colorScheme.error),
                                    onPressed: () => Navigator.pop(d, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (confirm == true && mounted) widget.onDelete!();
                        },
                  child: const Text('Delete'),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, FormStyles.buttonHeight),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(FormStyles.buttonRadius)),
                ),
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: FormStyles.primaryButton,
                  minimumSize: const Size(0, FormStyles.buttonHeight),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(FormStyles.buttonRadius)),
                ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: FormStyles.inputDecoration(labelText: label),
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
