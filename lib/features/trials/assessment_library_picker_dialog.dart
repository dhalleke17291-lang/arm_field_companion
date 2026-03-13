import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/widgets/loading_error_widgets.dart';

const Map<String, String> _categoryLabels = {
  'crop_injury': 'Crop Injury',
  'disease': 'Disease',
  'weed': 'Weed',
  'growth': 'Growth',
  'yield': 'Yield',
  'phenology': 'Phenology',
  'quality': 'Quality',
  'custom': 'Custom',
};

const Color _titleColor = Color(0xFF1F2937);
const Color _subtitleColor = Color(0xFF6B7280);
const Color _borderColor = Color(0xFFE5E7EB);
const Color _iconBgColor = Color(0xFFF3F4F6);
const Color _primaryGreen = Color(0xFF2D5A40);
const Color _unselectedCheckColor = Color(0xFFD1D5DB);
const Color _dialogBgColor = Color(0xFFF8F6F2);

String _categoryLabel(String category) => _categoryLabels[category] ?? category;

class AssessmentLibraryPickerDialog extends ConsumerStatefulWidget {
  final int trialId;

  const AssessmentLibraryPickerDialog({super.key, required this.trialId});

  static Future<void> show(BuildContext context, int trialId) {
    return showDialog<void>(
      context: context,
      builder: (context) => AssessmentLibraryPickerDialog(trialId: trialId),
    );
  }

  @override
  ConsumerState<AssessmentLibraryPickerDialog> createState() =>
      _AssessmentLibraryPickerDialogState();
}

class _AssessmentLibraryPickerDialogState
    extends ConsumerState<AssessmentLibraryPickerDialog> {
  final Set<int> _selectedIds = {};
  bool _hasTriedSeeding = false;

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _saveSelected() async {
    if (_selectedIds.isEmpty) return;
    final repo = ref.read(trialAssessmentRepositoryProvider);
    for (final id in _selectedIds) {
      await repo.addToTrial(
        trialId: widget.trialId,
        assessmentDefinitionId: id,
        selectedManually: true,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final definitionsAsync = ref.watch(assessmentDefinitionsProvider);
    final trialListAsync =
        ref.watch(trialAssessmentsForTrialProvider(widget.trialId));

    return AlertDialog(
      backgroundColor: _dialogBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: EdgeInsets.zero,
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Add Assessments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _titleColor,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Select one or more assessments to add',
            style: TextStyle(fontSize: 13, color: _subtitleColor),
          ),
        ],
      ),
      content: SizedBox(
        width: double.infinity,
        child: definitionsAsync.when(
          loading: () => const AppLoadingView(),
          error: (e, st) => AppErrorView(
            error: e,
            stackTrace: st,
            onRetry: () => ref.invalidate(assessmentDefinitionsProvider),
          ),
          data: (definitions) {
            if (definitions.isEmpty) {
              if (!_hasTriedSeeding) {
                _hasTriedSeeding = true;
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  await ref
                      .read(databaseProvider)
                      .ensureAssessmentDefinitionsSeeded();
                  if (mounted) ref.invalidate(assessmentDefinitionsProvider);
                });
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading default templates…',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _subtitleColor, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'No assessment templates in the library.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _subtitleColor, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () {
                          ref.invalidate(assessmentDefinitionsProvider);
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final alreadyIds = trialListAsync.valueOrNull
                    ?.map((ta) => ta.assessmentDefinitionId)
                    .toSet() ??
                {};
            final byCategory = <String, List<AssessmentDefinition>>{};
            for (final d in definitions) {
              byCategory.putIfAbsent(d.category, () => []).add(d);
            }
            final categories = byCategory.keys.toList()..sort();

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    ...categories.map((cat) {
                      final list = byCategory[cat]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, top: 12),
                            child: Text(
                              _categoryLabel(cat),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _subtitleColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          ...list.map((def) {
                            final alreadyAdded = alreadyIds.contains(def.id);
                            final isChecked =
                                alreadyAdded || _selectedIds.contains(def.id);
                            final isSelected = _selectedIds.contains(def.id);
                            final dataTypeLabel =
                                '${def.dataType}${def.unit != null ? " (${def.unit})" : ""}';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      isSelected ? _primaryGreen : _borderColor,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: CheckboxListTile(
                                value: isChecked,
                                onChanged: alreadyAdded
                                    ? null
                                    : (val) => _toggleSelection(def.id),
                                activeColor: _primaryGreen,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(
                                  def.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: _titleColor,
                                  ),
                                ),
                                subtitle: Text(
                                  dataTypeLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _subtitleColor,
                                  ),
                                ),
                                secondary: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _iconBgColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.analytics_outlined,
                                    size: 18,
                                    color: alreadyAdded
                                        ? _unselectedCheckColor
                                        : _primaryGreen,
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: _primaryGreen),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _selectedIds.isEmpty ? null : _saveSelected,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _borderColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: Text(
                    _selectedIds.isEmpty
                        ? 'Add Selected'
                        : 'Add Selected (${_selectedIds.length})',
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
