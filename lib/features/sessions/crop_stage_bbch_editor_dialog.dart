import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import 'session_timing_helper.dart';

/// Shared BBCH editor used from session detail, plot queue, and elsewhere.
///
/// Returns `true` when the user saved or cleared BBCH successfully.
Future<bool> showCropStageBbchEditorDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Session session,
  required int trialId,
}) async {
  final controller =
      TextEditingController(text: session.cropStageBbch?.toString() ?? '');
  final formKey = GlobalKey<FormState>();
  bool? saved;
  try {
    saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crop Growth Stage (BBCH)'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'BBCH (0–99)',
              hintText: 'e.g. 32',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              return validateCropStageBbchInput(v);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final v = controller.text.trim();
              if (v.isEmpty) {
                await ref
                    .read(sessionRepositoryProvider)
                    .updateSessionCropStageBbch(session.id, null);
                if (ctx.mounted) Navigator.pop(ctx, true);
                return;
              }
              if (formKey.currentState?.validate() != true) return;
              final parsed = parseCropStageBbchOrNull(v);
              await ref.read(sessionRepositoryProvider).updateSessionCropStageBbch(
                    session.id,
                    parsed,
                  );
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
  if (saved == true && context.mounted) {
    ref.invalidate(sessionByIdProvider(session.id));
    ref.invalidate(sessionTimingContextProvider(session.id));
    ref.invalidate(sessionsForTrialProvider(trialId));
  }
  return saved == true;
}
