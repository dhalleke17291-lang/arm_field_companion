import 'package:flutter/material.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/form_styles.dart';
import '../../core/widgets/app_draggable_modal_sheet.dart';
import '../../core/widgets/standard_form_bottom_sheet.dart';
import '../../domain/trial_cognition/interpretation_factors_codec.dart';

/// Returns true when the first-session interpretation factors prompt should
/// be shown: no existing (non-deleted) sessions yet and the column is still
/// unanswered (null).
bool shouldShowInterpretationFactorsPrompt({
  required int existingSessionCount,
  required String? knownInterpretationFactors,
}) {
  return existingSessionCount == 0 && knownInterpretationFactors == null;
}

/// Shows the interpretation factors bottom sheet.
///
/// Returns a JSON string to write to [known_interpretation_factors] when the
/// researcher answers (either "None of the above" → '[]', or "Done" → JSON
/// array of selected keys). Returns null when the sheet is dismissed without
/// answering ("Not now" / drag-to-close).
Future<String?> showInterpretationFactorsSheet(
  BuildContext context,
) {
  return showAppDraggableModalSheet<String>(
    context: context,
    initialChildSize: 0.80,
    minChildSize: 0.50,
    maxChildSize: 0.95,
    sheetBuilder: (sheetContext, scrollController) =>
        InterpretationFactorsSheet(scrollController: scrollController),
  );
}

/// The bottom sheet content for the first-session interpretation factors
/// checklist. Exposed publicly for widget testing.
class InterpretationFactorsSheet extends StatefulWidget {
  const InterpretationFactorsSheet({
    super.key,
    required this.scrollController,
  });

  final ScrollController scrollController;

  @override
  State<InterpretationFactorsSheet> createState() =>
      _InterpretationFactorsSheetState();
}

class _InterpretationFactorsSheetState
    extends State<InterpretationFactorsSheet> {
  final Set<String> _selected = {};
  final _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  String _buildJson() {
    final keys = List<String>.from(_selected)..remove('other');
    final otherText = _selected.contains('other') ? _otherController.text : null;
    return InterpretationFactorsCodec.serialize(keys, otherText: otherText);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StandardFormBottomSheetLayout(
      title: 'Site and seasonal conditions',
      body: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: FormStyles.formSheetHorizontalPadding,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing12),
            child: Text(
              'Select any known factors. These help explain the trial context later. '
              'You can choose none.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppDesignTokens.secondaryText,
                height: 1.4,
              ),
            ),
          ),
          ...kInterpretationFactorKeys
              .where((k) => k != 'other')
              .map((key) => _FactorTile(
                    factorKey: key,
                    label: kInterpretationFactorLabels[key]!,
                    selected: _selected.contains(key),
                    onToggle: (v) => setState(() {
                      if (v) {
                        _selected.add(key);
                      } else {
                        _selected.remove(key);
                      }
                    }),
                  )),
          _FactorTile(
            factorKey: 'other',
            label: kInterpretationFactorLabels['other']!,
            selected: _selected.contains('other'),
            onToggle: (v) => setState(() {
              if (v) {
                _selected.add('other');
              } else {
                _selected.remove('other');
                _otherController.clear();
              }
            }),
          ),
          if (_selected.contains('other'))
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                4,
                0,
                AppDesignTokens.spacing8,
              ),
              child: TextField(
                controller: _otherController,
                maxLength: 200,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Describe the condition…',
                  border: OutlineInputBorder(),
                  isDense: true,
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          const SizedBox(height: AppDesignTokens.spacing8),
        ],
      ),
      customFooter: Padding(
        padding: const EdgeInsets.fromLTRB(
          FormStyles.formSheetHorizontalPadding,
          AppDesignTokens.spacing12,
          FormStyles.formSheetHorizontalPadding,
          AppDesignTokens.spacing16,
        ),
        child: Row(
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                InterpretationFactorsCodec.serialize([]),
              ),
              child: const Text('None of the above'),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, FormStyles.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(FormStyles.buttonRadius),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(_buildJson()),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactorTile extends StatelessWidget {
  const _FactorTile({
    required this.factorKey,
    required this.label,
    required this.selected,
    required this.onToggle,
  });

  final String factorKey;
  final String label;
  final bool selected;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      key: Key('factor_$factorKey'),
      value: selected,
      onChanged: (v) => onToggle(v ?? false),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14),
      ),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
    );
  }
}
