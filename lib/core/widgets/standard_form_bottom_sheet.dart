import 'package:flutter/material.dart';

import '../design/app_design_tokens.dart';
import '../design/form_styles.dart';

/// Standard bottom sheet body for form flows:
///
/// ```
/// [ drag handle ]
/// TITLE (titleLarge)
/// SECTION LABEL (optional, small caps / muted)
/// [ fields... ]
/// [ expandable sections ]
/// ------------------------
/// [ Cancel ]     [ Save ]
/// ```
///
/// Use inside [showModalBottomSheet] / [DraggableScrollableSheet] with a
/// scrollable [body] (typically [ListView] with a [ScrollController]).
///
/// Set [customFooter] to replace the default Cancel + Save row (e.g. Delete +
/// Cancel + Save). Horizontal padding uses [FormStyles.formSheetHorizontalPadding].
class StandardFormBottomSheetLayout extends StatelessWidget {
  const StandardFormBottomSheetLayout({
    super.key,
    required this.title,
    this.sectionLabel,
    required this.body,
    this.onCancel,
    this.onSave,
    this.customFooter,
    this.saveLabel = 'Save',
    this.cancelLabel = 'Cancel',
    this.saveEnabled = true,
  }) : assert(
          customFooter != null || (onCancel != null && onSave != null),
          'Provide customFooter or both onCancel and onSave',
        );

  final String title;

  /// Optional small-caps style label below the title (e.g. section name).
  final String? sectionLabel;

  /// Scrollable content (e.g. [ListView] or [SingleChildScrollView]).
  final Widget body;

  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  /// Replaces the default Cancel + primary row when non-null.
  final Widget? customFooter;

  final String saveLabel;
  final String cancelLabel;

  final bool saveEnabled;

  static double get _pad => FormStyles.formSheetHorizontalPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: AppDesignTokens.spacing8),
            decoration: BoxDecoration(
              color: AppDesignTokens.dragHandle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            _pad,
            AppDesignTokens.spacing16,
            _pad,
            AppDesignTokens.spacing8,
          ),
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ) ??
                const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (sectionLabel != null && sectionLabel!.trim().isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              _pad,
              0,
              _pad,
              AppDesignTokens.spacing8,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                sectionLabel!.toUpperCase(),
                style: FormStyles.sectionLabelStyle,
              ),
            ),
          ),
        Expanded(child: body),
        const Divider(height: 1),
        if (customFooter != null)
          customFooter!
        else
          Padding(
            padding: EdgeInsets.fromLTRB(
              _pad,
              AppDesignTokens.spacing12,
              _pad,
              AppDesignTokens.spacing16,
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: onCancel,
                  child: Text(cancelLabel),
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
                  onPressed: saveEnabled ? onSave : null,
                  child: Text(saveLabel),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
