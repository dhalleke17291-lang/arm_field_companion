import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/design/form_styles.dart';
import '../../../core/widgets/standard_form_bottom_sheet.dart';
import '../../../core/plot_display.dart';
import '../../../core/application_state.dart';
import '../../../core/application_event_numeric_rules.dart';
import '../../../core/field_operation_date_rules.dart';
import '../../../core/providers.dart';
import '../../../core/units/unit_switch_mixin.dart';
import '../../../data/repositories/application_product_repository.dart';

/// Parses a BBCH integer from a text-field string. Returns null for empty or unparseable input.
int? parseBbch(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  return int.tryParse(t);
}

/// Validates a BBCH text-field value. Returns an error message or null if valid.
String? validateBbch(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final v = parseBbch(text);
  if (v == null || v < 0 || v > 99) return 'Enter a value between 0 and 99';
  return null;
}

String? _trimSheetText(String? s) =>
    s == null || s.trim().isEmpty ? null : s.trim();

/// Whether "Coverage & timing" starts expanded — mirrors [_ApplicationSheetContentState] initState.
bool computeApplicationCoverageTimingInitiallyExpanded(
  TrialApplicationEvent? event,
) {
  if (event == null) return false;
  final plotsSplit = event.plotsTreated != null &&
          event.plotsTreated!.trim().isNotEmpty
      ? event.plotsTreated!
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
      : <String>{};
  return _trimSheetText(event.growthStageCode) != null ||
      plotsSplit.isNotEmpty ||
      _trimSheetText(event.notes) != null ||
      event.growthStageBbchAtApplication != null;
}

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

class _ApplicationSheetContentState
    extends ConsumerState<ApplicationSheetContent>
    with UnitSwitchMixin<ApplicationSheetContent> {
  late DateTime _date;
  late String? _timeStr;
  late int? _treatmentId;
  late List<TextEditingController> _productControllers;
  late List<TextEditingController> _rateControllers;
  late List<String> _rateUnits;
  late List<TextEditingController> _lotCodeControllers;
  bool _junctionLoadScheduled = false;
  bool _weatherRetryAttempted = false;
  /// Parallel to product rows when a treatment is selected: the treatment
  /// component for protocol-bound rows, or null for extra rows (legacy / not on protocol).
  List<TreatmentComponent?> _protocolRowSources = [];
  /// Seeded a single free-form row when the trial has no treatments (only option).
  bool _seededManualRowForEmptyTrial = false;
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
  late final TextEditingController _growthStageBbchController;
  late final FocusNode _growthStageFocusNode;
  late final FocusNode _bbchFocusNode;
  late final TextEditingController _notesController;
  late Set<String> _selectedPlotLabels;

  bool _saving = false;
  bool _sameAsLastApplied = false;
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

  /// Match [ApplicationRepository] ALCOA+ lock semantics (pending is editable).
  bool get _isConfirmed {
    final e = widget.existing;
    if (e == null) return false;
    return e.appliedAt != null ||
        e.status == kAppStatusApplied ||
        e.status ==
            'complete'; // legacy / non-canonical rows; aligns with repo layer
  }

  String _confirmedDateLabel() {
    final e = widget.existing!;
    final d = e.appliedAt?.toLocal() ?? e.applicationDate.toLocal();
    return 'Applied ${DateFormat('MMM d').format(d)} — annotations editable, structure locked';
  }


  @override
  void initState() {
    super.initState();
    _growthStageFocusNode = FocusNode();
    _bbchFocusNode = FocusNode();
    _attachBbchFocusDebugListeners();
    if (kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        debugPrint(
          '[ApplicationSheet BOOT] '
          '_isConfirmed=$_isConfirmed '
          'existing.status=${widget.existing?.status} '
          'appliedAt=${widget.existing?.appliedAt} '
          'growth/ro=$_isConfirmed bbch/ro=$_isConfirmed '
          'bbch.canReq=${_bbchFocusNode.canRequestFocus}',
        );
      });
    }

    final e = widget.existing;
    _date = e?.applicationDate.toLocal() ?? DateTime.now();
    _timeStr = e?.applicationTime;
    _treatmentId = e?.treatmentId;
    if (e == null) {
      // New application: no free-form products until we know the trial has zero
      // treatments (then [didChangeDependencies] adds one row) or user picks a
      // treatment (protocol rows). Avoids duplicating product entry vs Treatments tab.
      _productControllers = [];
      _rateControllers = [];
      _rateUnits = [];
      _lotCodeControllers = [];
    } else {
      _productControllers = [
        TextEditingController(text: e.productName ?? ''),
      ];
      _rateControllers = [
        TextEditingController(text: e.rate != null ? e.rate.toString() : ''),
      ];
      _rateUnits = [e.rateUnit ?? widget.rateUnits.first];
      _lotCodeControllers = [TextEditingController()];
    }
    _applicationMethod = e?.applicationMethod;

    _nozzleType = e?.nozzleType;
    _nozzleSpacingController = TextEditingController(
        text: e?.nozzleSpacingCm != null ? e!.nozzleSpacingCm.toString() : '');
    _operatingPressureController = TextEditingController(
        text: e?.operatingPressure != null
            ? e!.operatingPressure.toString()
            : '');
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
    _adjuvantNameController =
        TextEditingController(text: e?.adjuvantName ?? '');
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
    _growthStageBbchController = TextEditingController(
        text: e?.growthStageBbchAtApplication?.toString() ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _selectedPlotLabels =
        e?.plotsTreated != null && e!.plotsTreated!.trim().isNotEmpty
            ? e.plotsTreated!
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toSet()
            : {};
    _initialExpandedCoverage = computeApplicationCoverageTimingInitiallyExpanded(e);

    if (_isConfirmed &&
        e != null &&
        e.capturedLatitude != null &&
        e.temperature == null &&
        !_weatherRetryAttempted) {
      _weatherRetryAttempted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref
              .read(applicationWeatherBackfillServiceProvider)
              .queueApplicationWeatherBackfill(
                applicationId: e.id,
                trialId: widget.trial.id,
                latitude: e.capturedLatitude!,
                longitude: e.capturedLongitude!,
                appliedAt: e.appliedAt ?? e.applicationDate,
              ),
        );
      });
    }
  }

  void _attachBbchFocusDebugListeners() {
    if (!kDebugMode) return;

    void log(String slot, FocusNode n) {
      n.addListener(() {
        debugPrint(
          '[ApplicationSheet focus #$slot] hasFocus=${n.hasFocus} '
          'primary=${FocusManager.instance.primaryFocus?.debugLabel}',
        );
      });
    }

    log('growth', _growthStageFocusNode);
    log('bbch', _bbchFocusNode);
  }

  void _requestKeyboardFor(FocusNode node) {
    node.requestFocus();
    unawaited(SystemChannels.textInput.invokeMethod('TextInput.show'));
  }

  void _disposeProductRows() {
    for (final c in _productControllers) {
      c.dispose();
    }
    for (final c in _rateControllers) {
      c.dispose();
    }
    for (final c in _lotCodeControllers) {
      c.dispose();
    }
    _productControllers = [];
    _rateControllers = [];
    _rateUnits = [];
    _lotCodeControllers = [];
    _protocolRowSources = [];
  }

  Future<void> _loadJunctionProducts() async {
    final id = widget.existing?.id;
    if (id == null) return;
    final list = await ref
        .read(applicationProductRepositoryProvider)
        .getProductsForEvent(id);
    if (!mounted) return;
    if (list.isNotEmpty) {
      setState(() {
        _disposeProductRows();
        _productControllers =
            list.map((p) => TextEditingController(text: p.productName)).toList();
        _rateControllers = list
            .map((p) => TextEditingController(
                text: p.rate != null ? p.rate.toString() : ''))
            .toList();
        _rateUnits = list
            .map((p) => (p.rateUnit != null && p.rateUnit!.trim().isNotEmpty)
                ? p.rateUnit!.trim()
                : widget.rateUnits.first)
            .toList();
        _lotCodeControllers = list
            .map((p) => TextEditingController(text: p.lotCode ?? ''))
            .toList();
      });
    }
    await _applyTreatmentProtocolBinding();
  }

  /// Binds product rows to [TreatmentComponent]s when a treatment is selected.
  /// Preserves as-applied rates by matching on product name where possible.
  Future<void> _applyTreatmentProtocolBinding() async {
    if (_treatmentId == null) {
      if (!mounted) return;
      setState(() => _protocolRowSources = []);
      return;
    }

    final comps = await ref
        .read(treatmentRepositoryProvider)
        .getComponentsForTreatment(_treatmentId!);

    if (!mounted) return;

    final savedByName = <String, ({String rateText, String unit})>{};
    for (var i = 0; i < _productControllers.length; i++) {
      final n = _productControllers[i].text.trim();
      if (n.isEmpty) continue;
      savedByName[n] = (
        rateText: _rateControllers[i].text,
        unit: i < _rateUnits.length ? _rateUnits[i] : widget.rateUnits.first,
      );
    }

    setState(() {
      _disposeProductRows();

      final compNames = comps.map((c) => c.productName.trim()).toSet();

      for (final c in comps) {
        _protocolRowSources.add(c);
        _productControllers.add(TextEditingController(text: c.productName));
        final preserved = savedByName[c.productName.trim()];
        final planned = c.rate;
        final rateText = preserved?.rateText.trim().isNotEmpty == true
            ? preserved!.rateText
            : (planned != null ? planned.toString() : '');
        _rateControllers.add(TextEditingController(text: rateText));
        _rateUnits.add(
          preserved?.unit ??
              (c.rateUnit != null && c.rateUnit!.trim().isNotEmpty
                  ? c.rateUnit!.trim()
                  : widget.rateUnits.first),
        );
        _lotCodeControllers.add(TextEditingController());
      }

      for (final e in savedByName.entries) {
        if (compNames.contains(e.key)) continue;
        _protocolRowSources.add(null);
        _productControllers.add(TextEditingController(text: e.key));
        _rateControllers.add(TextEditingController(text: e.value.rateText));
        _rateUnits.add(e.value.unit);
        _lotCodeControllers.add(TextEditingController());
      }
    });
  }

  bool _isProtocolLockedRow(int i) =>
      _treatmentId != null &&
      i < _protocolRowSources.length &&
      _protocolRowSources[i] != null;

  bool _canRemoveProductRow(int i) {
    if (_productControllers.length <= 1) return false;
    if (_treatmentId == null) return true;
    return i < _protocolRowSources.length && _protocolRowSources[i] == null;
  }

  String? _protocolPlannedRateLine(TreatmentComponent c) {
    final pr = c.rate;
    final pu = c.rateUnit?.trim();
    if (pr == null && (pu == null || pu.isEmpty)) return null;
    if (pr != null && pu != null && pu.isNotEmpty) {
      return 'Protocol rate: $pr $pu';
    }
    if (pr != null) return 'Protocol rate: $pr';
    return 'Protocol rate: $pu';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.existing == null && !_seededManualRowForEmptyTrial) {
      final list =
          ref.read(treatmentsForTrialProvider(widget.trial.id)).valueOrNull;
      if (list != null) {
        _seededManualRowForEmptyTrial = true;
        if (list.isEmpty && _productControllers.isEmpty && mounted) {
          setState(() {
            _productControllers = [TextEditingController()];
            _rateControllers = [TextEditingController()];
            _rateUnits = [widget.rateUnits.first];
            _lotCodeControllers = [TextEditingController()];
          });
        }
      }
    }
    if (widget.existing != null && !_junctionLoadScheduled) {
      _junctionLoadScheduled = true;
      unawaited(_loadJunctionProducts());
    }
  }

  @override
  void dispose() {
    _disposeProductRows();
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
    _growthStageBbchController.dispose();
    _growthStageFocusNode.dispose();
    _bbchFocusNode.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final trial =
        ref.read(trialProvider(widget.trial.id)).valueOrNull ?? widget.trial;
    final seedingEvent =
        await ref.read(seedingEventForTrialProvider(trial.id).future);
    if (!mounted) return;
    final minD = minimumApplicationOrAppliedDate(
      trialCreatedAt: trial.createdAt,
      seedingDate: seedingEvent?.seedingDate,
    );
    final maxD = dateOnlyLocal(DateTime.now());
    var initial = dateOnlyLocal(_date);
    if (initial.isBefore(minD)) initial = minD;
    if (initial.isAfter(maxD)) initial = maxD;
    final p = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minD,
      lastDate: maxD,
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

  String? _firstProductName() => _productControllers.isNotEmpty
      ? _trim(_productControllers.first.text)
      : null;

  double? _firstRate() => _rateControllers.isNotEmpty
      ? _parseDouble(_rateControllers.first.text)
      : null;

  String? _firstRateUnit() =>
      _rateUnits.isNotEmpty ? _rateUnits.first : widget.rateUnits.first;

  /// Validates optional numeric application fields before save.
  String? _applicationNumericValidationError() {
    String? checkRaw(String label, TextEditingController ctrl) =>
        validateRawDoubleField(label, ctrl.text);

    for (var i = 0; i < _rateControllers.length; i++) {
      final label = i < _productControllers.length &&
              _productControllers[i].text.trim().isNotEmpty
          ? 'Rate (${_productControllers[i].text.trim()})'
          : 'Application rate';
      final r = checkRaw(label, _rateControllers[i]);
      if (r != null) return r;
      final v = _parseDouble(_rateControllers[i].text);
      final nn = validateOptionalNonNegative(label, v);
      if (nn != null) return nn;
    }

    final pairs = <(String, TextEditingController)>[
      ('Nozzle spacing', _nozzleSpacingController),
      ('Operating pressure', _operatingPressureController),
      ('Ground speed', _groundSpeedController),
      ('Water volume', _waterVolumeController),
      ('Adjuvant rate', _adjuvantRateController),
      ('Treated area', _treatedAreaController),
      ('Wind speed', _windSpeedController),
      ('Soil depth', _soilDepthController),
    ];
    for (final p in pairs) {
      final r = checkRaw(p.$1, p.$2);
      if (r != null) return r;
      final nn = validateOptionalNonNegative(p.$1, _parseDouble(p.$2.text));
      if (nn != null) return nn;
    }

    for (final p in [
      ('Air temperature', _temperatureController),
      ('Soil temperature', _soilTempController),
    ]) {
      final r = checkRaw(p.$1, p.$2);
      if (r != null) return r;
      final fin = validateOptionalFiniteNumber(p.$1, _parseDouble(p.$2.text));
      if (fin != null) return fin;
    }

    for (final p in [
      ('Humidity', _humidityController),
      ('Cloud cover', _cloudCoverController),
    ]) {
      final r = checkRaw(p.$1, p.$2);
      if (r != null) return r;
      final h = validateOptionalHumidityPercent(p.$1, _parseDouble(p.$2.text));
      if (h != null) return h;
    }

    final phR = checkRaw('Spray solution pH', _spraySolutionPhController);
    if (phR != null) return phR;
    final phV = validateOptionalPh(
        'Spray solution pH', _parseDouble(_spraySolutionPhController.text));
    if (phV != null) return phV;

    final bbchErr = validateBbch(_growthStageBbchController.text);
    if (bbchErr != null) return bbchErr;

    return null;
  }

  /// Copies equipment + weather fields from the most recent application
  /// on this trial. Only available when creating a new application.
  Future<void> _applyFromLast() async {
    final repo = ref.read(applicationRepositoryProvider);
    final apps = await repo.getApplicationsForTrial(widget.trial.id);
    if (apps.isEmpty || !mounted) return;
    // Most recent by applicationDate.
    final sorted = List<TrialApplicationEvent>.from(apps)
      ..sort((a, b) => b.applicationDate.compareTo(a.applicationDate));
    final last = sorted.first;
    setState(() {
      _sameAsLastApplied = true;
      // Equipment
      _applicationMethod = last.applicationMethod ?? _applicationMethod;
      _equipmentController.text = last.equipmentUsed ?? '';
      _nozzleType = last.nozzleType ?? _nozzleType;
      _nozzleSpacingController.text =
          last.nozzleSpacingCm?.toString() ?? '';
      _operatingPressureController.text =
          last.operatingPressure?.toString() ?? '';
      _pressureUnit = last.pressureUnit ?? _pressureUnit;
      _groundSpeedController.text = last.groundSpeed?.toString() ?? '';
      _speedUnit = last.speedUnit ?? _speedUnit;
      // Tank mix
      _waterVolumeController.text = last.waterVolume?.toString() ?? '';
      _waterVolumeUnit = last.waterVolumeUnit ?? _waterVolumeUnit;
      _adjuvantNameController.text = last.adjuvantName ?? '';
      _adjuvantRateController.text =
          last.adjuvantRate?.toString() ?? '';
      _adjuvantRateUnit = last.adjuvantRateUnit ?? _adjuvantRateUnit;
      _spraySolutionPhController.text =
          last.spraySolutionPh?.toString() ?? '';
      // Expand sections that now have data.
      _initialExpandedEquip = true;
      _initialExpandedTank = true;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Equipment and tank mix copied from last application'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final trial =
        ref.read(trialProvider(widget.trial.id)).valueOrNull ?? widget.trial;
    final seedingEvent =
        await ref.read(seedingEventForTrialProvider(trial.id).future);
    if (!mounted) return;
    final appErr = validateApplicationEventDate(
      applicationDate: _date,
      trialCreatedAt: trial.createdAt,
      seedingDate: seedingEvent?.seedingDate,
    );
    if (appErr != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appErr), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final trialTreatments =
        ref.read(treatmentsForTrialProvider(widget.trial.id)).valueOrNull ?? [];
    if (widget.existing == null &&
        trialTreatments.isNotEmpty &&
        _treatmentId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Select which treatment was applied. Tank-mix products are defined '
              'under the Treatments tab — not here — so there is a single protocol.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final numErr = _applicationNumericValidationError();
    if (numErr != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(numErr), backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(applicationRepositoryProvider);
      final productRepo = ref.read(applicationProductRepositoryProvider);
      final companion = _buildCompanion();
      final userId = await ref.read(currentUserIdProvider.future);
      final user = await ref.read(currentUserProvider.future);
      final String eventId;
      if (widget.existing == null) {
        eventId = await repo.createApplication(
          companion,
          performedBy: user?.displayName,
          performedByUserId: userId,
        );
      } else {
        await repo.updateApplication(
          widget.existing!.id,
          companion,
          performedBy: user?.displayName,
          performedByUserId: userId,
        );
        eventId = widget.existing!.id;
      }
      final rows = <ApplicationProductSaveRow>[];
      for (var i = 0; i < _productControllers.length; i++) {
        final name = _productControllers[i].text.trim();
        if (name.isEmpty) continue;
        final TreatmentComponent? c =
            _treatmentId != null && i < _protocolRowSources.length
                ? _protocolRowSources[i]
                : null;
        rows.add(ApplicationProductSaveRow(
          productName: name,
          rate: _parseDouble(_rateControllers[i].text),
          rateUnit: i < _rateUnits.length ? _rateUnits[i] : null,
          lotCode: i < _lotCodeControllers.length
              ? _trim(_lotCodeControllers[i].text)
              : null,
          plannedProduct: c?.productName,
          plannedRate: c?.rate,
          plannedRateUnit: c?.rateUnit,
        ));
      }
      await productRepo.saveProductsForEvent(eventId, rows);

      // Dual-write: persist plot selections to junction table alongside TEXT.
      final plotAssignmentRepo =
          ref.read(applicationPlotAssignmentRepositoryProvider);
      final plots =
          ref.read(plotsForTrialProvider(widget.trial.id)).value ?? [];
      final plotSelections = _selectedPlotLabels.map((label) {
        final plot = plots.where((p) =>
            getDisplayPlotLabel(p, plots) == label || p.plotId == label)
            .firstOrNull;
        return (label: label, plotId: plot?.id);
      }).toList();
      await plotAssignmentRepo.saveForEvent(eventId, plotSelections);

      if (mounted) widget.onSaved();
    } catch (e) {
      if (mounted) {
        final msg = e is OperationalDateRuleException ? e.message : '$e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Save failed: $msg'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  TrialApplicationEventsCompanion _buildCompanion() {
    final plotsTreatedStr =
        _selectedPlotLabels.isEmpty ? null : _selectedPlotLabels.join(', ');
    if (widget.existing == null) {
      return TrialApplicationEventsCompanion.insert(
        trialId: widget.trial.id,
        applicationDate: _date,
        applicationTime: drift.Value(_timeStr),
        treatmentId: drift.Value(_treatmentId),
        productName: drift.Value(_firstProductName()),
        rate: drift.Value(_firstRate()),
        rateUnit: drift.Value(_firstRateUnit()),
        applicationMethod: drift.Value(_applicationMethod),
        nozzleType: drift.Value(_nozzleType),
        nozzleSpacingCm:
            drift.Value(_parseDouble(_nozzleSpacingController.text)),
        operatingPressure:
            drift.Value(_parseDouble(_operatingPressureController.text)),
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
        spraySolutionPh:
            drift.Value(_parseDouble(_spraySolutionPhController.text)),
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
        growthStageBbchAtApplication:
            drift.Value(parseBbch(_growthStageBbchController.text)),
        plotsTreated: drift.Value(plotsTreatedStr),
        notes: drift.Value(_trim(_notesController.text)),
        startedAt: drift.Value(DateTime.now().toUtc()),
      );
    }
    return TrialApplicationEventsCompanion(
      id: drift.Value(widget.existing!.id),
      trialId: drift.Value(widget.trial.id),
      applicationDate: drift.Value(_date),
      applicationTime: drift.Value(_timeStr),
      treatmentId: drift.Value(_treatmentId),
      productName: drift.Value(_firstProductName()),
      rate: drift.Value(_firstRate()),
      rateUnit: drift.Value(_firstRateUnit()),
      applicationMethod: drift.Value(_applicationMethod),
      nozzleType: drift.Value(_nozzleType),
      nozzleSpacingCm: drift.Value(_parseDouble(_nozzleSpacingController.text)),
      operatingPressure:
          drift.Value(_parseDouble(_operatingPressureController.text)),
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
      spraySolutionPh:
          drift.Value(_parseDouble(_spraySolutionPhController.text)),
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
      growthStageBbchAtApplication:
          drift.Value(parseBbch(_growthStageBbchController.text)),
      plotsTreated: drift.Value(plotsTreatedStr),
      notes: drift.Value(_trim(_notesController.text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final treatments =
        ref.watch(treatmentsForTrialProvider(widget.trial.id)).value ?? [];
    final trialHasTreatments = treatments.isNotEmpty;
    final strictNewAppRequiresTreatment =
        widget.existing == null && trialHasTreatments;
    final legacyUnlinkedApplication = widget.existing != null &&
        widget.existing!.treatmentId == null &&
        trialHasTreatments;
    final showManualAddProduct = _treatmentId == null &&
        !strictNewAppRequiresTreatment;
    final plots = ref.watch(plotsForTrialProvider(widget.trial.id)).value ?? [];
    final seedingEvent =
        ref.watch(seedingEventForTrialProvider(widget.trial.id)).valueOrNull;
    final seedingDay = seedingEvent?.seedingDate;
    final dateLabel = DateFormat('MMM d, yyyy').format(_date);

    return StandardFormBottomSheetLayout(
      title: widget.existing == null ? 'Add Application' : 'Edit Application',
      customFooter: _buildApplicationSheetFooter(context),
      body: ListView(
        controller: widget.scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
        padding: const EdgeInsets.fromLTRB(
          FormStyles.formSheetHorizontalPadding,
          0,
          FormStyles.formSheetHorizontalPadding,
          FormStyles.formSheetSectionSpacing,
        ),
        children: [
          if (_isConfirmed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _confirmedDateLabel(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Some fields (weather, growth stage, equipment notes) can '
                    'be corrected after applying — corrections are written to '
                    'the audit trail.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: AppDesignTokens.secondaryText.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          // "Same as last" — copies equipment + tank mix from most recent app.
          if (widget.existing == null && !_sameAsLastApplied)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: _applyFromLast,
                icon: const Icon(Icons.content_copy, size: 16),
                label: const Text('Same as last application'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          // Section 1 — Core (always visible)
          const Padding(
            padding: FormStyles.sectionLabelPadding,
            child: Text('CORE', style: FormStyles.sectionLabelStyle),
          ),
          OutlinedButton.icon(
            onPressed: _isConfirmed ? null : _pickDate,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text('Date: $dateLabel'),
          ),
          if (seedingDay != null) ...[
            const SizedBox(height: 6),
            Text(
              'Earliest: ${DateFormat('MMM d, yyyy').format(dateOnlyLocal(seedingDay))} (seeding day)',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: FormStyles.formSheetFieldSpacing),
          OutlinedButton.icon(
            onPressed: _isConfirmed ? null : _pickTime,
            icon: const Icon(Icons.access_time, size: 18),
            label: Text('Time: ${_timeStr ?? '—'}'),
          ),
          const SizedBox(height: FormStyles.formSheetFieldSpacing),
          DropdownButtonFormField<int?>(
            key: ValueKey<int?>(_treatmentId),
            initialValue: _treatmentId,
            decoration: FormStyles.inputDecoration(labelText: 'Treatment'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('None')),
              ...treatments.map((t) =>
                  DropdownMenuItem<int?>(value: t.id, child: Text(t.code))),
            ],
            onChanged: _isConfirmed ? null : (v) async {
              final prev = _treatmentId;
              setState(() => _treatmentId = v);
              if (prev != null && v == null) {
                setState(() {
                  _protocolRowSources = [];
                  _disposeProductRows();
                  if (strictNewAppRequiresTreatment) {
                    // Stay empty until user picks a treatment again.
                  } else {
                    _productControllers = [TextEditingController()];
                    _rateControllers = [TextEditingController()];
                    _rateUnits = [widget.rateUnits.first];
                  }
                });
                return;
              }
              await _applyTreatmentProtocolBinding();
            },
          ),
          if (_treatmentId != null) ...[
            Builder(
              builder: (context) {
                Treatment? tr;
                for (final t in treatments) {
                  if (t.id == _treatmentId) {
                    tr = t;
                    break;
                  }
                }
                final code = tr?.eppoCode?.trim();
                if (code == null || code.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Treatment code: $code',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: FormStyles.formSheetFieldSpacing),
          if (strictNewAppRequiresTreatment && _treatmentId == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Choose a treatment first. Under Treatments → Add component, '
                          'enter product name, rate, and optional product code (text field '
                          'directly under the name — not a separate picker). This '
                          'screen records when you applied and as-applied rates only.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (legacyUnlinkedApplication)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppDesignTokens.warningBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'This application is not linked to a treatment. Select a '
                    'treatment to align with your protocol, or keep legacy rows as-is.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _treatmentId != null
                      ? 'PRODUCTS (from treatment protocol)'
                      : (strictNewAppRequiresTreatment
                          ? 'PRODUCTS (after treatment)'
                          : 'PRODUCTS'),
                  style: FormStyles.sectionLabelStyle,
                ),
              ),
              if (showManualAddProduct && !_isConfirmed)
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Product'),
                  style: TextButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => setState(() {
                    _productControllers.add(TextEditingController());
                    _rateControllers.add(TextEditingController());
                    _rateUnits.add(widget.rateUnits.first);
                    _lotCodeControllers.add(TextEditingController());
                  }),
                ),
            ],
          ),
          if (_treatmentId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Product names and protocol rates come from the Treatments tab. '
                'Adjust rates here only for as-applied values (planned vs actual is tracked). '
                'Per-product codes are shown below when set.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (_treatmentId != null && _productControllers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'No products in this treatment yet. Add components in the Treatments tab.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: FormStyles.formSheetFieldSpacing),
          ...List.generate(_productControllers.length, (i) {
            final TreatmentComponent? src =
                i < _protocolRowSources.length ? _protocolRowSources[i] : null;
            final protocolLine =
                src != null ? _protocolPlannedRateLine(src) : null;
            final componentEppo = src?.eppoCode?.trim();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (i > 0) ...[
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade200)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Product ${i + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade200)),
                      if (_canRemoveProductRow(i))
                        IconButton(
                          tooltip: 'Remove product',
                          icon: Icon(Icons.remove_circle_outline,
                              color: Colors.grey.shade400, size: 18),
                          onPressed: () {
                            if (!_canRemoveProductRow(i)) return;
                            setState(() {
                              _productControllers[i].dispose();
                              _rateControllers[i].dispose();
                              _productControllers.removeAt(i);
                              _rateControllers.removeAt(i);
                              _rateUnits.removeAt(i);
                              if (i < _lotCodeControllers.length) {
                                _lotCodeControllers[i].dispose();
                                _lotCodeControllers.removeAt(i);
                              }
                              if (i < _protocolRowSources.length) {
                                _protocolRowSources.removeAt(i);
                              }
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                        )
                      else
                        const SizedBox(width: 32, height: 32),
                    ],
                  ),
                  const SizedBox(height: FormStyles.formSheetFieldSpacing),
                ],
                TextField(
                  controller: _productControllers[i],
                  readOnly: _isConfirmed || _isProtocolLockedRow(i),
                  decoration: FormStyles.inputDecoration(
                    hintText: 'Product name',
                    labelText:
                        _isProtocolLockedRow(i) ? 'Product (protocol)' : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (componentEppo != null && componentEppo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Code: $componentEppo',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (protocolLine != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    protocolLine,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (_treatmentId != null && src == null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Not on treatment protocol — retained from a previous save; '
                    'you can edit the name or remove this row.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: FormStyles.formSheetFieldSpacing),
                TextField(
                  controller: _rateControllers[i],
                  readOnly: _isConfirmed,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: FormStyles.inputDecoration(
                    labelText:
                        _isProtocolLockedRow(i) ? 'As-applied rate' : null,
                    hintText: _isProtocolLockedRow(i) ? null : 'Rate',
                    suffixIcon: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: i < _rateUnits.length
                            ? _rateUnits[i]
                            : widget.rateUnits.first,
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        padding: const EdgeInsets.only(right: 8),
                        items: widget.rateUnits
                            .map((u) => DropdownMenuItem<String>(
                                  value: u,
                                  child: Text(u,
                                      style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: _isConfirmed
                            ? null
                            : (v) {
                                if (v == null) return;
                                while (_rateUnits.length <= i) {
                                  _rateUnits.add(widget.rateUnits.first);
                                }
                                switchUnit(
                                  controller: _rateControllers[i],
                                  currentUnit: _rateUnits[i],
                                  newUnit: v,
                                  applyUnit: (u) => _rateUnits[i] = u ?? v,
                                );
                              },
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: FormStyles.formSheetFieldSpacing),
                TextField(
                  controller: i < _lotCodeControllers.length
                      ? _lotCodeControllers[i]
                      : TextEditingController(),
                  readOnly: _isConfirmed,
                  decoration: FormStyles.inputDecoration(
                    labelText: 'Lot / batch code (optional)',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: FormStyles.formSheetFieldSpacing),
              ],
            );
          }),
          DropdownButtonFormField<String?>(
            key: ValueKey<String?>(_applicationMethod),
            initialValue: _applicationMethod,
            decoration:
                FormStyles.inputDecoration(labelText: 'Application method'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('—')),
              ...widget.applicationMethods.map(
                  (s) => DropdownMenuItem<String?>(value: s, child: Text(s))),
            ],
            onChanged: (v) => setState(() => _applicationMethod = v),
          ),
          const SizedBox(height: FormStyles.formSheetSectionSpacing),
          // Section 2 — Equipment
          ExpansionTile(
            initiallyExpanded: _initialExpandedEquip,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
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
                decoration:
                    FormStyles.inputDecoration(labelText: 'Nozzle type'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('—')),
                  ...widget.nozzleTypes.map((s) =>
                      DropdownMenuItem<String?>(value: s, child: Text(s))),
                ],
                onChanged: (v) => setState(() => _nozzleType = v),
              ),
              const SizedBox(height: 12),
              _field('Nozzle spacing cm', _nozzleSpacingController),
              const SizedBox(height: 12),
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
                      onChanged: (v) => switchUnit(
                        controller: _operatingPressureController,
                        currentUnit: _pressureUnit,
                        newUnit: v,
                        applyUnit: (u) => _pressureUnit = u,
                      ),
                    ),
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
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
                      onChanged: (v) => switchUnit(
                        controller: _groundSpeedController,
                        currentUnit: _speedUnit,
                        newUnit: v,
                        applyUnit: (u) => _speedUnit = u,
                      ),
                    ),
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _equipmentController,
                decoration:
                    FormStyles.inputDecoration(labelText: 'Equipment used'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _operatorController,
                decoration:
                    FormStyles.inputDecoration(labelText: 'Operator name'),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          // Section 3 — Tank mix
          ExpansionTile(
            initiallyExpanded: _initialExpandedTank,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
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
                      onChanged: (v) => switchUnit(
                        controller: _waterVolumeController,
                        currentUnit: _waterVolumeUnit,
                        newUnit: v,
                        applyUnit: (u) => _waterVolumeUnit = u,
                      ),
                    ),
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _adjuvantNameController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'Adjuvant name',
                  hintText: 'e.g. Agral 90, Merge',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
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
                      onChanged: (v) => switchUnit(
                        controller: _adjuvantRateController,
                        currentUnit: _adjuvantRateUnit,
                        newUnit: v,
                        applyUnit: (u) => _adjuvantRateUnit = u,
                      ),
                    ),
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
                      onChanged: (v) => switchUnit(
                        controller: _treatedAreaController,
                        currentUnit: _treatedAreaUnit,
                        newUnit: v,
                        applyUnit: (u) => _treatedAreaUnit = u,
                      ),
                    ),
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          // Section 4 — Weather
          ExpansionTile(
            initiallyExpanded: _initialExpandedWeather,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
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
                decoration: FormStyles.inputDecoration(labelText: 'Wind speed'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _windDirectionController,
                decoration:
                    FormStyles.inputDecoration(labelText: 'Wind direction'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _temperatureController,
                decoration: FormStyles.inputDecoration(
                    labelText: 'Temperature',
                    suffixIcon: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _temperatureUnit,
                        items: ['°C', '°F']
                            .map((u) => DropdownMenuItem<String>(
                                value: u,
                                child: Text(u,
                                    style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          switchUnit(
                            controller: _temperatureController,
                            currentUnit: _temperatureUnit,
                            newUnit: v,
                            applyUnit: (u) => _temperatureUnit = u ?? v,
                          );
                        },
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        padding: const EdgeInsets.only(right: 8),
                      ),
                    )),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _humidityController,
                style: const TextStyle(color: Color(0xFF1A1A1A)),
                decoration: FormStyles.inputDecoration(
                  labelText: 'Humidity',
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
              const SizedBox(height: 12),
              TextField(
                controller: _cloudCoverController,
                style: const TextStyle(color: Color(0xFF1A1A1A)),
                decoration: FormStyles.inputDecoration(
                  labelText: 'Cloud cover',
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
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: ValueKey<String?>(_soilMoisture),
                initialValue: _soilMoisture,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF1A1A1A),
                ),
                decoration: FormStyles.inputDecoration(
                  labelText: 'Soil moisture',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Soil moisture')),
                  ...widget.soilMoistureOptions.map((s) =>
                      DropdownMenuItem<String?>(value: s, child: Text(s))),
                ],
                onChanged: (v) => setState(() => _soilMoisture = v),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _soilTempController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
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
                                        style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              switchUnit(
                                controller: _soilTempController,
                                currentUnit: _soilTempUnit,
                                newUnit: v,
                                applyUnit: (u) => _soilTempUnit = u ?? v,
                              );
                            },
                            icon: const Icon(Icons.arrow_drop_down, size: 18),
                            padding: const EdgeInsets.only(right: 8),
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
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
                                        style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              switchUnit(
                                controller: _soilDepthController,
                                currentUnit: _soilDepthUnit,
                                newUnit: v,
                                applyUnit: (u) => _soilDepthUnit = u ?? v,
                              );
                            },
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
            childrenPadding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
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
                focusNode: _growthStageFocusNode,
                decoration:
                    FormStyles.inputDecoration(hintText: 'Growth stage / BBCH'),
                keyboardType: TextInputType.text,
                onTap: () {
                  if (kDebugMode) {
                    debugPrint(
                      '[ApplicationSheet onTap growth] '
                      'prePrimary=${FocusManager.instance.primaryFocus?.debugLabel}',
                    );
                  }
                  _requestKeyboardFor(_growthStageFocusNode);
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _growthStageBbchController,
                focusNode: _bbchFocusNode,
                decoration: FormStyles.inputDecoration(
                  labelText: 'BBCH at application',
                  hintText: 'e.g. 32',
                ),
                keyboardType: TextInputType.number,
                onTap: () {
                  if (kDebugMode) {
                    debugPrint(
                      '[ApplicationSheet onTap bbch] '
                      'prePrimary=${FocusManager.instance.primaryFocus?.debugLabel}',
                    );
                  }
                  _requestKeyboardFor(_bbchFocusNode);
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
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
                    onPressed: _isConfirmed
                        ? null
                        : () => setState(() {
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
              const SizedBox(height: 12),
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
                              padding: const EdgeInsets.only(
                                top: FormStyles.formSheetFieldSpacing,
                                bottom: AppDesignTokens.spacing8,
                              ),
                              child: Text(
                                'Rep ${rep ?? '?'}',
                                style: FormStyles.sectionLabelStyle,
                              ),
                            ),
                            Wrap(
                              spacing: AppDesignTokens.spacing8,
                              runSpacing: AppDesignTokens.spacing8,
                              children: repPlots.map((plot) {
                                final displayLabel =
                                    getDisplayPlotLabel(plot, plots);
                                final isSelected = _selectedPlotLabels
                                        .contains(displayLabel) ||
                                    _selectedPlotLabels.contains(plot.plotId);
                                return IntrinsicWidth(
                                  child: GestureDetector(
                                    onTap: _isConfirmed
                                        ? null
                                        : () => setState(() {
                                              if (isSelected) {
                                                _selectedPlotLabels
                                                    .remove(displayLabel);
                                                _selectedPlotLabels
                                                    .remove(plot.plotId);
                                              } else {
                                                _selectedPlotLabels
                                                    .remove(plot.plotId);
                                                _selectedPlotLabels
                                                    .add(displayLabel);
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
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: FormStyles.inputDecoration(labelText: 'Notes'),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationSheetFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FormStyles.formSheetHorizontalPadding,
        AppDesignTokens.spacing12,
        FormStyles.formSheetHorizontalPadding,
        AppDesignTokens.spacing16,
      ),
      child: Row(
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
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, FormStyles.buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FormStyles.buttonRadius),
              ),
            ),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {bool readOnly = false}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      decoration: FormStyles.inputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: readOnly ? null : (_) => setState(() {}),
    );
  }
}
