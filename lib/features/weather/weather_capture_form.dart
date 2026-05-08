import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/connectivity/gps_service.dart';
import '../../core/connectivity/weather_api_service.dart';
import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/units/unit_switch_mixin.dart';
import '../../data/repositories/weather_snapshot_repository.dart';
import 'weather_capture_validation.dart';
import 'weather_field_values.dart';

/// Opens a bottom sheet to capture or edit weather for [session].
Future<void> showWeatherCaptureBottomSheet(
  BuildContext context, {
  required Trial trial,
  required Session session,
  WeatherSnapshot? initialSnapshot,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: false,
    isScrollControlled: true,
    backgroundColor: AppDesignTokens.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(ctx).bottom,
      ),
      child: WeatherCaptureForm(
        trial: trial,
        session: session,
        initialSnapshot: initialSnapshot,
      ),
    ),
  );
}

class WeatherCaptureForm extends ConsumerStatefulWidget {
  const WeatherCaptureForm({
    super.key,
    required this.trial,
    required this.session,
    this.initialSnapshot,
  });

  final Trial trial;
  final Session session;
  final WeatherSnapshot? initialSnapshot;

  @override
  ConsumerState<WeatherCaptureForm> createState() => _WeatherCaptureFormState();
}

class _WeatherCaptureFormState extends ConsumerState<WeatherCaptureForm>
    with UnitSwitchMixin<WeatherCaptureForm> {
  late final TextEditingController _tempCtrl;
  late final TextEditingController _humidityCtrl;
  late final TextEditingController _windCtrl;
  late final TextEditingController _notesCtrl;

  late String _tempUnit;
  late String _windUnit;
  String? _windDir;
  String? _cloudCover;
  String? _precipitation;
  double? _precipitationMm;
  String? _soilCondition;

  bool _localeDefaultsApplied = false;
  bool _autoFetching = false;
  String? _weatherSource;

  static const String _kWeatherProviderKey = 'weather_provider';

  @override
  void initState() {
    super.initState();
    final w = widget.initialSnapshot;
    _tempCtrl = TextEditingController(
      text: w?.temperature != null ? w!.temperature.toString() : '',
    );
    _humidityCtrl = TextEditingController(
      text: w?.humidity != null ? w!.humidity.toString() : '',
    );
    _windCtrl = TextEditingController(
      text: w?.windSpeed != null ? w!.windSpeed.toString() : '',
    );
    _notesCtrl = TextEditingController(text: w?.notes ?? '');
    _tempUnit = w?.temperatureUnit ?? 'C';
    _windUnit = w?.windSpeedUnit ?? 'km/h';
    _windDir = w?.windDirection;
    _cloudCover = w?.cloudCover;
    _precipitation = w?.precipitation;
    _precipitationMm = w?.precipitationMm;
    _soilCondition = w?.soilCondition;
    _weatherSource = w?.source ?? 'manual';

    if (w == null) {
      _tryAutoFetch();
    }
  }

  Future<void> _tryAutoFetch() async {
    final pos = await GpsService.getCurrentPosition(
        timeout: const Duration(seconds: 5));
    if (pos == null || !mounted) return;

    setState(() => _autoFetching = true);

    final prefs = await SharedPreferences.getInstance();
    final providerName = prefs.getString(_kWeatherProviderKey);
    final providerType = providerName == 'environment_canada'
        ? WeatherProviderType.environmentCanada
        : WeatherProviderType.openMeteo;
    final provider = weatherProviderFor(providerType);

    final result = await provider.fetchCurrent(
      latitude: pos.latitude,
      longitude: pos.longitude,
    );

    if (!mounted) return;
    setState(() => _autoFetching = false);

    if (result == null) return;

    setState(() {
      _weatherSource = 'api';
      if (_tempCtrl.text.trim().isEmpty) {
        final temp = _tempUnit == 'F'
            ? result.temperatureC * 9 / 5 + 32
            : result.temperatureC;
        _tempCtrl.text = temp.round().toString();
      }
      if (_humidityCtrl.text.trim().isEmpty) {
        _humidityCtrl.text = result.humidityPct.round().toString();
      }
      if (_windCtrl.text.trim().isEmpty) {
        final wind = _windUnit == 'mph'
            ? result.windSpeedKmh * 0.621371
            : result.windSpeedKmh;
        _windCtrl.text = wind.round().toString();
      }
      _windDir ??= result.windDirection;
      if (result.cloudCoverPct != null && _cloudCover == null) {
        final pct = result.cloudCoverPct!;
        if (pct < 15) {
          _cloudCover = 'Clear';
        } else if (pct < 50) {
          _cloudCover = 'Partly cloudy';
        } else if (pct < 85) {
          _cloudCover = 'Mostly cloudy';
        } else {
          _cloudCover = 'Overcast';
        }
      }
      if (_precipitation == null) {
        _precipitation = result.precipitation;
        _precipitationMm = result.precipitationMm;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Weather pre-filled from ${provider.displayName}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _markManualEdit() {
    if (_weatherSource == 'api') {
      setState(() {
        _weatherSource = 'manual';
        _precipitationMm = null;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.initialSnapshot != null || _localeDefaultsApplied) return;
    _localeDefaultsApplied = true;
  }

  @override
  void dispose() {
    _tempCtrl.dispose();
    _humidityCtrl.dispose();
    _windCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool _hasAnyField() {
    return _tempCtrl.text.trim().isNotEmpty ||
        _humidityCtrl.text.trim().isNotEmpty ||
        _windCtrl.text.trim().isNotEmpty ||
        _windDir != null ||
        _cloudCover != null ||
        _precipitation != null ||
        _soilCondition != null ||
        _notesCtrl.text.trim().isNotEmpty;
  }

  double? _parseOptionalDouble(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _confirmEmptyAndSave() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Empty Weather Record?'),
        content: const Text(
          'No weather fields are filled. Save an empty record anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (go == true && mounted) await _persist();
  }

  Future<void> _persist() async {
    final temp = _parseOptionalDouble(_tempCtrl.text);
    final humidity = _parseOptionalDouble(_humidityCtrl.text);
    final wind = _parseOptionalDouble(_windCtrl.text);

    final tErr = validateWeatherTemperature(temp, _tempUnit);
    final hErr = validateWeatherHumidity(humidity);
    final wErr = validateWeatherWindSpeed(wind);
    final err = tErr ?? hErr ?? wErr;
    if (err != null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
      return;
    }

    final user = ref.read(currentUserProvider).valueOrNull;
    final createdBy = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName.trim()
        : 'Unknown';
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final repo = ref.read(weatherSnapshotRepositoryProvider);
    final notesTrim = _notesCtrl.text.trim();
    final notesVal = notesTrim.isEmpty ? null : notesTrim;

    final existing = widget.initialSnapshot;
    try {
      if (existing != null) {
        await repo.updateWeatherSnapshot(
          existing.id,
          WeatherSnapshotsCompanion(
            source: Value(_weatherSource ?? 'manual'),
            temperature: Value(temp),
            temperatureUnit: Value(_tempUnit),
            humidity: Value(humidity),
            windSpeed: Value(wind),
            windSpeedUnit: Value(_windUnit),
            windDirection: Value(_windDir),
            cloudCover: Value(_cloudCover),
            precipitation: Value(_precipitation),
            precipitationMm: _weatherSource == 'api'
                ? Value(_precipitationMm)
                // qualitative only — no numeric value available from this source
                : const Value(null),
            soilCondition: Value(_soilCondition),
            notes: Value(notesVal),
            recordedAt: Value(nowMs),
            modifiedAt: Value(nowMs),
          ),
        );
      } else {
        await repo.upsertWeatherSnapshot(
          WeatherSnapshotsCompanion.insert(
            uuid: const Uuid().v4(),
            trialId: widget.trial.id,
            parentId: widget.session.id,
            recordedAt: nowMs,
            createdAt: nowMs,
            modifiedAt: nowMs,
            createdBy: createdBy,
            parentType: const Value(kWeatherParentTypeRatingSession),
            source: Value(_weatherSource ?? 'manual'),
            temperature: Value(temp),
            temperatureUnit: Value(_tempUnit),
            humidity: Value(humidity),
            windSpeed: Value(wind),
            windSpeedUnit: Value(_windUnit),
            windDirection: Value(_windDir),
            cloudCover: Value(_cloudCover),
            precipitation: Value(_precipitation),
            precipitationMm: _weatherSource == 'api'
                ? Value(_precipitationMm)
                // qualitative only — no numeric value available from this source
                : const Value(null),
            soilCondition: Value(_soilCondition),
            notes: Value(notesVal),
          ),
        );
      }
      ref.invalidate(weatherSnapshotForSessionProvider(widget.session.id));
      if (mounted) {
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save weather: $e')),
        );
      }
    }
  }

  Future<void> _onSavePressed() async {
    if (!_hasAnyField()) {
      await _confirmEmptyAndSave();
      return;
    }
    await _persist();
  }

  Widget _unitChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppDesignTokens.primary,
      checkmarkColor: AppDesignTokens.onPrimary,
      labelStyle: TextStyle(
        color:
            selected ? AppDesignTokens.onPrimary : AppDesignTokens.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      side: const BorderSide(color: AppDesignTokens.divider),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _choiceChipRow<T extends String>({
    required List<T> values,
    required String Function(T) labelFn,
    required T? selected,
    required void Function(T? next) onChanged,
  }) {
    return Wrap(
      spacing: AppDesignTokens.spacing8,
      runSpacing: AppDesignTokens.spacing8,
      children: values.map((v) {
        final sel = selected == v;
        return FilterChip(
          label: Text(labelFn(v)),
          selected: sel,
          onSelected: (on) => onChanged(on ? v : null),
          selectedColor: AppDesignTokens.primary,
          checkmarkColor: AppDesignTokens.onPrimary,
          labelStyle: TextStyle(
            color:
                sel ? AppDesignTokens.onPrimary : AppDesignTokens.primaryText,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          side: const BorderSide(color: AppDesignTokens.divider),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: AppDesignTokens.cardSurface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Weather',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.primaryText,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.session.name,
                style: const TextStyle(
                  color: AppDesignTokens.secondaryText,
                  fontSize: 13,
                ),
              ),
              if (_autoFetching)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Fetching weather...',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppDesignTokens.secondaryText,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_weatherSource == 'api')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_done,
                          size: 13,
                          color:
                              AppDesignTokens.successFg.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      const Text(
                        'Auto-filled from weather API — edit to override',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppDesignTokens.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Temperature',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('weather_field_temperature'),
                      controller: _tempCtrl,
                      onChanged: (_) => _markManualEdit(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Optional',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _unitChip(
                        label: '°C',
                        selected: _tempUnit == 'C',
                        onTap: () => switchUnit(
                          controller: _tempCtrl,
                          currentUnit: _tempUnit,
                          newUnit: 'C',
                          applyUnit: (u) => _tempUnit = u ?? 'C',
                        ),
                      ),
                      const SizedBox(width: 6),
                      _unitChip(
                        label: '°F',
                        selected: _tempUnit == 'F',
                        onTap: () => switchUnit(
                          controller: _tempCtrl,
                          currentUnit: _tempUnit,
                          newUnit: 'F',
                          applyUnit: (u) => _tempUnit = u ?? 'F',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Humidity',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('weather_field_humidity'),
                controller: _humidityCtrl,
                onChanged: (_) => _markManualEdit(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: '% (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  suffixText: '%',
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Wind Speed',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('weather_field_wind'),
                      controller: _windCtrl,
                      onChanged: (_) => _markManualEdit(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Optional',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _unitChip(
                        label: 'km/h',
                        selected: _windUnit == 'km/h',
                        onTap: () => switchUnit(
                          controller: _windCtrl,
                          currentUnit: _windUnit,
                          newUnit: 'km/h',
                          applyUnit: (u) => _windUnit = u ?? 'km/h',
                        ),
                      ),
                      const SizedBox(width: 6),
                      _unitChip(
                        label: 'mph',
                        selected: _windUnit == 'mph',
                        onTap: () => switchUnit(
                          controller: _windCtrl,
                          currentUnit: _windUnit,
                          newUnit: 'mph',
                          applyUnit: (u) => _windUnit = u ?? 'mph',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Wind Direction',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              const SizedBox(height: 6),
              _choiceChipRow<String>(
                values: kWeatherWindDirections,
                labelFn: (s) => s,
                selected: _windDir,
                onChanged: (v) {
                  setState(() => _windDir = v);
                  _markManualEdit();
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'Cloud Cover',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              const SizedBox(height: 6),
              _choiceChipRow<String>(
                values: kWeatherCloudCovers,
                labelFn: weatherCloudCoverLabel,
                selected: _cloudCover,
                onChanged: (v) {
                  setState(() => _cloudCover = v);
                  _markManualEdit();
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'Precipitation',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              const SizedBox(height: 6),
              _choiceChipRow<String>(
                values: kWeatherPrecipitations,
                labelFn: weatherPrecipitationLabel,
                selected: _precipitation,
                onChanged: (v) {
                  setState(() => _precipitation = v);
                  _markManualEdit();
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'Soil Condition',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              const SizedBox(height: 6),
              _choiceChipRow<String>(
                values: kWeatherSoilConditions,
                labelFn: weatherSoilLabel,
                selected: _soilCondition,
                onChanged: (v) => setState(() => _soilCondition = v),
              ),
              const SizedBox(height: 14),
              const Text(
                'Notes',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('weather_field_notes'),
                controller: _notesCtrl,
                maxLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Optional',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('weather_button_save'),
                onPressed: _onSavePressed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppDesignTokens.primary,
                  foregroundColor: AppDesignTokens.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
