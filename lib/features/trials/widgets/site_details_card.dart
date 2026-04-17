import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';
import '../trial_setup_screen.dart';

/// Collapsible Site Details card for the trial overview tab.
/// Groups trial location, soil, crop, and management fields with
/// completion fraction. Missing fields are tappable → opens editor.
class SiteDetailsCard extends ConsumerStatefulWidget {
  const SiteDetailsCard({super.key, required this.trial});

  final Trial trial;

  @override
  ConsumerState<SiteDetailsCard> createState() => _SiteDetailsCardState();
}

class _SiteDetailsCardState extends ConsumerState<SiteDetailsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trialProvider(widget.trial.id)).valueOrNull ??
        widget.trial;

    final fields = _buildFieldList(t);
    final filled = fields.where((f) => f.hasValue).length;
    final total = fields.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing8,
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing8,
      ),
      child: Material(
        color: AppDesignTokens.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          side: const BorderSide(color: AppDesignTokens.borderCrisp),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDesignTokens.spacing16,
                  vertical: AppDesignTokens.spacing12,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 20, color: AppDesignTokens.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Site Details',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppDesignTokens.primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$filled of $total fields',
                            style: TextStyle(
                              fontSize: 12,
                              color: filled == total
                                  ? AppDesignTokens.successFg
                                  : AppDesignTokens.secondaryText,
                              fontWeight: filled == total
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 24,
                      color: AppDesignTokens.iconSubtle,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDesignTokens.spacing16,
                  0,
                  AppDesignTokens.spacing16,
                  AppDesignTokens.spacing12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: AppDesignTokens.spacing8),
                    for (final group in _groupFields(fields)) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                            top: AppDesignTokens.spacing8, bottom: 4),
                        child: Text(
                          group.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppDesignTokens.secondaryText
                                .withValues(alpha: 0.7),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      for (final f in group.fields)
                        _FieldRow(
                          label: f.label,
                          value: f.displayValue,
                          isMissing: !f.hasValue,
                          onTap: () => _openSetup(context),
                        ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openSetup(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TrialSetupScreen(trial: widget.trial),
      ),
    ).then((_) {
      ref.invalidate(trialProvider(widget.trial.id));
    });
  }

  List<_FieldInfo> _buildFieldList(Trial t) {
    return [
      // Location
      _FieldInfo('GPS', _gpsDisplay(t.latitude, t.longitude),
          t.latitude != null && t.longitude != null, 'Location'),
      _FieldInfo('Field', t.fieldName, t.fieldName != null, 'Location'),
      _FieldInfo('County', t.county, t.county != null, 'Location'),
      _FieldInfo('State/Province', t.stateProvince,
          t.stateProvince != null, 'Location'),
      _FieldInfo('Country', t.country, t.country != null, 'Location'),
      // Soil
      _FieldInfo(
          'Soil texture', t.soilTexture, t.soilTexture != null, 'Soil'),
      _FieldInfo('Soil pH',
          t.soilPh?.toStringAsFixed(1), t.soilPh != null, 'Soil'),
      _FieldInfo(
          'Organic matter',
          t.organicMatterPct != null
              ? '${t.organicMatterPct!.toStringAsFixed(1)}%'
              : null,
          t.organicMatterPct != null,
          'Soil'),
      _FieldInfo(
          'Soil series', t.soilSeries, t.soilSeries != null, 'Soil'),
      // Crop
      _FieldInfo('Crop', t.crop, t.crop != null, 'Crop'),
      _FieldInfo(
          'Cultivar', t.cultivar, t.cultivar != null, 'Crop'),
      _FieldInfo('Previous crop', t.previousCrop,
          t.previousCrop != null, 'Crop'),
      _FieldInfo(
          'Row spacing',
          t.rowSpacingCm != null ? '${t.rowSpacingCm!.round()} cm' : null,
          t.rowSpacingCm != null,
          'Crop'),
      // Management
      _FieldInfo('Tillage', t.tillage, t.tillage != null, 'Management'),
      _FieldInfo(
          'Irrigated',
          t.irrigated != null ? (t.irrigated! ? 'Yes' : 'No') : null,
          t.irrigated != null,
          'Management'),
      _FieldInfo(
          'GEP',
          t.gepComplianceFlag != null
              ? (t.gepComplianceFlag! ? 'Yes' : 'No')
              : null,
          t.gepComplianceFlag != null,
          'Management'),
    ];
  }

  String? _gpsDisplay(double? lat, double? lon) {
    if (lat == null || lon == null) return null;
    return '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
  }

  List<_FieldGroup> _groupFields(List<_FieldInfo> fields) {
    final groups = <String, List<_FieldInfo>>{};
    for (final f in fields) {
      groups.putIfAbsent(f.group, () => []).add(f);
    }
    return groups.entries
        .map((e) => _FieldGroup(label: e.key, fields: e.value))
        .toList();
  }
}

class _FieldInfo {
  const _FieldInfo(this.label, this.displayValue, this.hasValue, this.group);
  final String label;
  final String? displayValue;
  final bool hasValue;
  final String group;
}

class _FieldGroup {
  const _FieldGroup({required this.label, required this.fields});
  final String label;
  final List<_FieldInfo> fields;
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.value,
    required this.isMissing,
    required this.onTap,
  });

  final String label;
  final String? value;
  final bool isMissing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isMissing ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: AppDesignTokens.secondaryText
                      .withValues(alpha: 0.85),
                ),
              ),
            ),
            Expanded(
              child: Text(
                value ?? '—',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isMissing
                      ? AppDesignTokens.secondaryText
                          .withValues(alpha: 0.5)
                      : AppDesignTokens.primaryText,
                ),
              ),
            ),
            if (isMissing)
              const Icon(
                Icons.add_circle_outline,
                size: 16,
                color: AppDesignTokens.iconSubtle,
              ),
          ],
        ),
      ),
    );
  }
}
