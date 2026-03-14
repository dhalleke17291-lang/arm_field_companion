import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';

/// Full-screen form for trial setup (protocol, location, plot dimensions, soil, field history).
class TrialSetupScreen extends ConsumerStatefulWidget {
  const TrialSetupScreen({super.key, required this.trial});

  final Trial trial;

  @override
  ConsumerState<TrialSetupScreen> createState() => _TrialSetupScreenState();
}

class _TrialSetupScreenState extends ConsumerState<TrialSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _sponsor;
  late TextEditingController _protocolNumber;
  late TextEditingController _investigatorName;
  late TextEditingController _cooperatorName;
  late TextEditingController _siteId;
  late TextEditingController _fieldName;
  late TextEditingController _county;
  late TextEditingController _stateProvince;
  late TextEditingController _country;
  late TextEditingController _latitude;
  late TextEditingController _longitude;
  late TextEditingController _elevationM;
  late TextEditingController _plotLengthM;
  late TextEditingController _plotWidthM;
  late TextEditingController _alleyLengthM;
  late TextEditingController _previousCrop;
  late TextEditingController _soilSeries;
  late TextEditingController _organicMatterPct;
  late TextEditingController _soilPh;

  String? _studyType;
  String? _experimentalDesign;
  String? _tillage;
  String? _soilTexture;
  bool? _irrigated;
  DateTime? _harvestDate;
  bool _saving = false;

  static const List<String> _studyTypes = [
    'Efficacy',
    'Variety',
    'GLP',
    'Other',
  ];
  static const List<String> _experimentalDesigns = [
    'RCBD',
    'CRD',
    'Latin Square',
    'Augmented',
    'Other',
  ];
  static const List<String> _tillages = [
    'No-till',
    'Minimum till',
    'Conventional',
  ];
  static const List<String> _soilTextures = [
    'Sand',
    'Sandy loam',
    'Loam',
    'Silt loam',
    'Silty clay loam',
    'Clay loam',
    'Clay',
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.trial;
    _sponsor = TextEditingController(text: t.sponsor ?? '');
    _protocolNumber = TextEditingController(text: t.protocolNumber ?? '');
    _investigatorName = TextEditingController(text: t.investigatorName ?? '');
    _cooperatorName = TextEditingController(text: t.cooperatorName ?? '');
    _siteId = TextEditingController(text: t.siteId ?? '');
    _fieldName = TextEditingController(text: t.fieldName ?? '');
    _county = TextEditingController(text: t.county ?? '');
    _stateProvince = TextEditingController(text: t.stateProvince ?? '');
    _country = TextEditingController(text: t.country ?? '');
    _latitude = TextEditingController(
        text: t.latitude != null ? t.latitude.toString() : '');
    _longitude = TextEditingController(
        text: t.longitude != null ? t.longitude.toString() : '');
    _elevationM = TextEditingController(
        text: t.elevationM != null ? t.elevationM.toString() : '');
    _plotLengthM = TextEditingController(
        text: t.plotLengthM != null ? t.plotLengthM.toString() : '');
    _plotWidthM = TextEditingController(
        text: t.plotWidthM != null ? t.plotWidthM.toString() : '');
    _alleyLengthM = TextEditingController(
        text: t.alleyLengthM != null ? t.alleyLengthM.toString() : '');
    _previousCrop = TextEditingController(text: t.previousCrop ?? '');
    _soilSeries = TextEditingController(text: t.soilSeries ?? '');
    _organicMatterPct = TextEditingController(
        text: t.organicMatterPct != null ? t.organicMatterPct.toString() : '');
    _soilPh = TextEditingController(
        text: t.soilPh != null ? t.soilPh.toString() : '');
    _studyType = t.studyType;
    _experimentalDesign = t.experimentalDesign;
    _tillage = t.tillage;
    _soilTexture = t.soilTexture;
    _irrigated = t.irrigated;
    _harvestDate = t.harvestDate;
  }

  @override
  void dispose() {
    _sponsor.dispose();
    _protocolNumber.dispose();
    _investigatorName.dispose();
    _cooperatorName.dispose();
    _siteId.dispose();
    _fieldName.dispose();
    _county.dispose();
    _stateProvince.dispose();
    _country.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _elevationM.dispose();
    _plotLengthM.dispose();
    _plotWidthM.dispose();
    _alleyLengthM.dispose();
    _previousCrop.dispose();
    _soilSeries.dispose();
    _organicMatterPct.dispose();
    _soilPh.dispose();
    super.dispose();
  }

  double? _parseDouble(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    return double.tryParse(s.trim());
  }

  Future<void> _useCurrentGps() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Location services are disabled. Enable and try again.')),
      );
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied.')),
      );
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude.text = pos.latitude.toString();
        _longitude.text = pos.longitude.toString();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location updated from GPS.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
    }
  }

  Future<void> _pickHarvestDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _harvestDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _harvestDate = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final companion = TrialsCompanion(
        sponsor: Value(_sponsor.text.trim().isEmpty ? null : _sponsor.text.trim()),
        protocolNumber:
            Value(_protocolNumber.text.trim().isEmpty ? null : _protocolNumber.text.trim()),
        investigatorName: Value(
            _investigatorName.text.trim().isEmpty ? null : _investigatorName.text.trim()),
        cooperatorName: Value(
            _cooperatorName.text.trim().isEmpty ? null : _cooperatorName.text.trim()),
        siteId: Value(_siteId.text.trim().isEmpty ? null : _siteId.text.trim()),
        fieldName: Value(_fieldName.text.trim().isEmpty ? null : _fieldName.text.trim()),
        county: Value(_county.text.trim().isEmpty ? null : _county.text.trim()),
        stateProvince:
            Value(_stateProvince.text.trim().isEmpty ? null : _stateProvince.text.trim()),
        country: Value(_country.text.trim().isEmpty ? null : _country.text.trim()),
        latitude: Value(_parseDouble(_latitude.text)),
        longitude: Value(_parseDouble(_longitude.text)),
        elevationM: Value(_parseDouble(_elevationM.text)),
        experimentalDesign: Value(_experimentalDesign),
        plotLengthM: Value(_parseDouble(_plotLengthM.text)),
        plotWidthM: Value(_parseDouble(_plotWidthM.text)),
        alleyLengthM: Value(_parseDouble(_alleyLengthM.text)),
        previousCrop: Value(
            _previousCrop.text.trim().isEmpty ? null : _previousCrop.text.trim()),
        tillage: Value(_tillage),
        irrigated: Value(_irrigated),
        soilSeries: Value(
            _soilSeries.text.trim().isEmpty ? null : _soilSeries.text.trim()),
        soilTexture: Value(_soilTexture),
        organicMatterPct: Value(_parseDouble(_organicMatterPct.text)),
        soilPh: Value(_parseDouble(_soilPh.text)),
        harvestDate: Value(_harvestDate),
        studyType: Value(_studyType),
      );
      final repo = ref.read(trialRepositoryProvider);
      await repo.updateTrialSetup(widget.trial.id, companion);
      ref.invalidate(trialProvider(widget.trial.id));
      ref.invalidate(trialSetupProvider(widget.trial.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trial setup saved.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: const GradientScreenHeader(title: 'Trial Setup'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDesignTokens.spacing16),
          children: [
            _SectionCard(
              title: 'Protocol',
              children: [
                _textField('Sponsor', _sponsor),
                _textField('Protocol number', _protocolNumber),
                _textField('Investigator name', _investigatorName),
                _textField('Cooperator name', _cooperatorName),
                _dropdown('Study type', _studyType, _studyTypes, (v) {
                  setState(() => _studyType = v);
                }),
              ],
            ),
            _SectionCard(
              title: 'Location',
              children: [
                _textField('Site ID', _siteId),
                _textField('Field name', _fieldName),
                _textField('County', _county),
                _textField('State / Province', _stateProvince),
                _textField('Country', _country),
                _textField('Latitude', _latitude,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true)),
                _textField('Longitude', _longitude,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true)),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _useCurrentGps,
                  icon: const Icon(Icons.gps_fixed, size: 18),
                  label: const Text('Use current GPS'),
                ),
                _textField('Elevation m', _elevationM,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true)),
              ],
            ),
            _SectionCard(
              title: 'Plot dimensions',
              children: [
                _dropdown('Experimental design', _experimentalDesign,
                    _experimentalDesigns, (v) {
                  setState(() => _experimentalDesign = v);
                }),
                _textField('Plot length m', _plotLengthM,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true)),
                _textField('Plot width m', _plotWidthM,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true)),
                _textField('Alley length m', _alleyLengthM,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true)),
              ],
            ),
            _SectionCard(
              title: 'Field history',
              children: [
                _textField('Previous crop', _previousCrop),
                _dropdown('Tillage', _tillage, _tillages, (v) {
                  setState(() => _tillage = v);
                }),
                SwitchListTile(
                  title: const Text('Irrigated'),
                  value: _irrigated ?? false,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _irrigated = v),
                ),
              ],
            ),
            _SectionCard(
              title: 'Soil',
              children: [
                _textField('Soil series', _soilSeries),
                _dropdown('Soil texture', _soilTexture, _soilTextures, (v) {
                  setState(() => _soilTexture = v);
                }),
                _textField('Organic matter %', _organicMatterPct,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true)),
                _textField('Soil pH', _soilPh,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true)),
              ],
            ),
            _SectionCard(
              title: 'Harvest',
              children: [
                ListTile(
                  title: Text(_harvestDate == null
                      ? 'Harvest date'
                      : DateFormat('MMM d, yyyy').format(_harvestDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _saving ? null : _pickHarvestDate,
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField(String label, TextEditingController controller,
      {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _dropdown(String label, String? value, List<String> items,
      ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        key: ValueKey<String?>(value),
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String>(value: null, child: Text('—')),
          ...items.map((s) => DropdownMenuItem(value: s, child: Text(s))),
        ],
        onChanged: _saving ? null : onChanged,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDesignTokens.spacing16),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignTokens.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
