import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/loading_error_widgets.dart';

class AssessmentLibraryPickerDialog extends ConsumerStatefulWidget {
  final int trialId;

  const AssessmentLibraryPickerDialog({super.key, required this.trialId});

  static Future<void> show(BuildContext context, int trialId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + subtitle
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Add Assessments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppDesignTokens.primaryText,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Tap to select · tap again to deselect',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
          ),
          // Content: loading / error / empty / chips
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.5,
            ),
            child: definitionsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: AppLoadingView(),
                ),
              ),
              error: (e, st) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppErrorView(
                  error: e,
                  stackTrace: st,
                  onRetry: () =>
                      ref.invalidate(assessmentDefinitionsProvider),
                ),
              ),
              data: (definitions) {
                if (definitions.isEmpty) {
                  if (!_hasTriedSeeding) {
                    _hasTriedSeeding = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      await ref
                          .read(databaseProvider)
                          .ensureAssessmentDefinitionsSeeded();
                      if (mounted) {
                        ref.invalidate(assessmentDefinitionsProvider);
                      }
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Loading default templates…',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppDesignTokens.secondaryText,
                                fontSize: 14,
                              ),
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
                            style: TextStyle(
                              color: AppDesignTokens.secondaryText,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () =>
                                ref.invalidate(assessmentDefinitionsProvider),
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
                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                  children: definitions.map((def) {
                    final alreadyAdded = alreadyIds.contains(def.id);
                    final isSelected = _selectedIds.contains(def.id);
                    return InkWell(
                      onTap: alreadyAdded
                          ? null
                          : () => _toggleSelection(def.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: alreadyAdded
                              ? AppDesignTokens.emptyBadgeBg
                              : (isSelected
                                  ? const Color(0xFFE8F5EE)
                                  : Colors.white),
                          border: const Border(
                            bottom: BorderSide(
                              color: Color(0xFFF0EDE8),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    def.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: alreadyAdded
                                          ? AppDesignTokens.secondaryText
                                          : (isSelected
                                              ? const Color(0xFF2D5A40)
                                              : const Color(0xFF1A1A1A)),
                                    ),
                                  ),
                                  if (def.unit != null &&
                                      def.unit!.isNotEmpty)
                                    Text(
                                      def.unit!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (alreadyAdded)
                              Text(
                                'Added',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400,
                                ),
                              )
                            else if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF2D5A40),
                                size: 20,
                              )
                            else
                              Icon(
                                Icons.circle_outlined,
                                color: Colors.grey.shade300,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          // Divider + action row
          const Divider(height: 1, thickness: 0.5),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE0DDD6)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedIds.isEmpty
                          ? Colors.grey.shade200
                          : const Color(0xFF2D5A40),
                      foregroundColor: _selectedIds.isEmpty
                          ? Colors.grey.shade400
                          : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed:
                        _selectedIds.isEmpty ? null : _saveSelected,
                    child: Text(
                      _selectedIds.isEmpty
                          ? 'Select assessments'
                          : 'Add ${_selectedIds.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: _selectedIds.isEmpty
                            ? Colors.grey.shade400
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
