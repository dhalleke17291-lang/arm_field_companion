import 'package:flutter/material.dart';

import '../../core/design/app_design_tokens.dart';
import 'assessment_library.dart';

/// Full-screen curated assessment library: search, category filters, multi-select.
class AssessmentLibraryPicker extends StatefulWidget {
  const AssessmentLibraryPicker({
    super.key,
    this.libraryEntryIdsAlreadyChosen = const {},
  });

  /// Library entry ids already present in the trial or wizard draft (not re-selectable).
  final Set<String> libraryEntryIdsAlreadyChosen;

  /// Returns selected entries, or `null` if the user closed without confirming.
  static Future<List<LibraryAssessment>?> open(
    BuildContext context, {
    Set<String> libraryEntryIdsAlreadyChosen = const {},
  }) {
    return Navigator.of(context).push<List<LibraryAssessment>?>(
      MaterialPageRoute<List<LibraryAssessment>?>(
        builder: (_) => AssessmentLibraryPicker(
          libraryEntryIdsAlreadyChosen: libraryEntryIdsAlreadyChosen,
        ),
      ),
    );
  }

  @override
  State<AssessmentLibraryPicker> createState() =>
      _AssessmentLibraryPickerState();
}

class _AssessmentLibraryPickerState extends State<AssessmentLibraryPicker> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  /// `null` = All categories.
  String? _filterCategory;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _categoryChipTint(int categoryIndex) {
    final base =
        AppDesignTokens.treatmentPalette[categoryIndex %
            AppDesignTokens.treatmentPalette.length];
    return base.withValues(alpha: 0.14);
  }

  String _scaleLine(LibraryAssessment e) {
    String fmt(double x) =>
        x == x.roundToDouble() ? x.toInt().toString() : x.toString();
    return '${fmt(e.scaleMin)}–${fmt(e.scaleMax)} ${e.unit}';
  }

  List<LibraryAssessment> get _filtered {
    List<LibraryAssessment> base;
    if (_searchQuery.isEmpty) {
      base = List<LibraryAssessment>.from(AssessmentLibrary.entries);
    } else {
      base = AssessmentLibrary.search(_searchQuery);
    }
    if (_filterCategory != null) {
      base = base.where((e) => e.category == _filterCategory).toList();
    }
    return base;
  }

  void _toggle(LibraryAssessment e) {
    if (widget.libraryEntryIdsAlreadyChosen.contains(e.id)) return;
    setState(() {
      if (_selectedIds.contains(e.id)) {
        _selectedIds.remove(e.id);
      } else {
        _selectedIds.add(e.id);
      }
    });
  }

  void _done() {
    final out = <LibraryAssessment>[];
    for (final e in AssessmentLibrary.entries) {
      if (_selectedIds.contains(e.id)) out.add(e);
    }
    Navigator.of(context).pop(out);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.cardSurface,
        foregroundColor: AppDesignTokens.primaryText,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(
          color: AppDesignTokens.primaryText,
          size: 24,
        ),
        title: Text(
          'Assessment Library',
          style: AppDesignTokens.headerTitleStyle(
            fontSize: 18,
            color: AppDesignTokens.primaryText,
            letterSpacing: -0.3,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          iconSize: 24,
          onPressed: () => Navigator.of(context).pop(null),
          tooltip: 'Close',
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const ValueKey('assessment-library-search'),
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search name, category, or description',
                hintStyle: AppDesignTokens.bodyStyle(
                  color: AppDesignTokens.secondaryText,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppDesignTokens.secondaryText,
                ),
                filled: true,
                fillColor: AppDesignTokens.cardSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
                  borderSide: const BorderSide(color: AppDesignTokens.borderCrisp),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
                  borderSide: const BorderSide(color: AppDesignTokens.borderCrisp),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
                  borderSide: const BorderSide(color: AppDesignTokens.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    key: const ValueKey('assessment-library-cat-all'),
                    label: const Text('All'),
                    selected: _filterCategory == null,
                    onSelected: (_) => setState(() => _filterCategory = null),
                    selectedColor: AppDesignTokens.primaryTint,
                    checkmarkColor: AppDesignTokens.primary,
                    labelStyle: AppDesignTokens.bodyStyle(fontSize: 13),
                  ),
                ),
                ...List.generate(AssessmentLibrary.categoryDisplayOrder.length, (i) {
                  final cat = AssessmentLibrary.categoryDisplayOrder[i];
                  final sel = _filterCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      key: ValueKey('assessment-library-cat-$cat'),
                      label: Text(cat),
                      selected: sel,
                      onSelected: (_) =>
                          setState(() => _filterCategory = sel ? null : cat),
                      backgroundColor: _categoryChipTint(i),
                      selectedColor: AppDesignTokens.primaryTintStrong,
                      checkmarkColor: AppDesignTokens.primary,
                      labelStyle: AppDesignTokens.bodyStyle(fontSize: 13),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final e = filtered[index];
                final already =
                    widget.libraryEntryIdsAlreadyChosen.contains(e.id);
                final picked = _selectedIds.contains(e.id);
                final showCheck = already || picked;
                final catIdx =
                    AssessmentLibrary.categoryDisplayOrder.indexOf(e.category);
                final tint = catIdx >= 0
                    ? _categoryChipTint(catIdx)
                    : AppDesignTokens.emptyBadgeBg;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  key: ValueKey('assessment-library-row-${e.id}'),
                  child: Material(
                    color: AppDesignTokens.cardSurface,
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: already ? null : () => _toggle(e),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppDesignTokens.radiusCard),
                          border: Border.all(
                            color: picked
                                ? AppDesignTokens.primary
                                : AppDesignTokens.borderCrisp,
                            width: picked
                                ? AppDesignTokens.borderWidthCrisp * 2
                                : AppDesignTokens.borderWidthCrisp,
                          ),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.name,
                                    style: AppDesignTokens.headingStyle(
                                      fontSize: 16,
                                      color: AppDesignTokens.primaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tint,
                                      borderRadius: BorderRadius.circular(
                                        AppDesignTokens.radiusChip,
                                      ),
                                    ),
                                    child: Text(
                                      e.category,
                                      style: AppDesignTokens.bodyStyle(
                                        fontSize: 12,
                                        color: AppDesignTokens.primaryText,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Scale: ${_scaleLine(e)}',
                                    style: AppDesignTokens.bodyStyle(
                                      fontSize: 13,
                                      color: AppDesignTokens.secondaryText,
                                    ),
                                  ),
                                  Text(
                                    'Data type: ${e.dataType}',
                                    style: AppDesignTokens.bodyStyle(
                                      fontSize: 12,
                                      color: AppDesignTokens.secondaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    e.description,
                                    style: AppDesignTokens.bodyStyle(
                                      fontSize: 13,
                                      color: AppDesignTokens.secondaryText,
                                    ),
                                  ),
                                  if (already) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Already added',
                                      style: AppDesignTokens.bodyStyle(
                                        fontSize: 12,
                                        color: AppDesignTokens.emptyBadgeFg,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              showCheck
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: showCheck
                                  ? AppDesignTokens.primary
                                  : AppDesignTokens.iconSubtle,
                              size: 26,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Material(
        elevation: 8,
        color: AppDesignTokens.cardSurface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedIds.isEmpty
                        ? 'No assessments selected'
                        : '${_selectedIds.length} assessments selected',
                    style: AppDesignTokens.bodyStyle(
                      color: AppDesignTokens.primaryText,
                    ),
                  ),
                ),
                FilledButton(
                  key: const ValueKey('assessment-library-done'),
                  onPressed: _selectedIds.isEmpty ? null : _done,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppDesignTokens.primary,
                    foregroundColor: AppDesignTokens.onPrimary,
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
