import 'package:flutter/material.dart';

/// Standard app dialog wrapper to keep popups visually consistent.
///
/// Use this instead of bare [AlertDialog] for form and selection dialogs so
/// width, padding, title style, and actions all follow one pattern.
class AppDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
  final bool scrollable;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget body = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: content,
    );
    if (scrollable) {
      body = SingleChildScrollView(child: body);
    }

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      content: body,
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: actions,
    );
  }
}
