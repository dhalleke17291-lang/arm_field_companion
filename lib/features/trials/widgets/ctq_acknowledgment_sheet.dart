import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_design_tokens.dart';
import '../../../core/design/form_styles.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_draggable_modal_sheet.dart';
import '../../../core/widgets/standard_form_bottom_sheet.dart';
import '../../../domain/trial_cognition/trial_ctq_dto.dart';

Future<void> showCtqAcknowledgmentSheet(
  BuildContext context, {
  required TrialCtqItemDto item,
  required int trialId,
}) {
  return showAppDraggableModalSheet(
    context: context,
    initialChildSize: 0.65,
    minChildSize: 0.45,
    maxChildSize: 0.95,
    sheetBuilder: (sheetCtx, scrollCtrl) => _CtqAcknowledgmentSheet(
      item: item,
      trialId: trialId,
      scrollController: scrollCtrl,
    ),
  );
}

class _CtqAcknowledgmentSheet extends ConsumerStatefulWidget {
  const _CtqAcknowledgmentSheet({
    required this.item,
    required this.trialId,
    required this.scrollController,
  });

  final TrialCtqItemDto item;
  final int trialId;
  final ScrollController scrollController;

  @override
  ConsumerState<_CtqAcknowledgmentSheet> createState() =>
      _CtqAcknowledgmentSheetState();
}

class _CtqAcknowledgmentSheetState
    extends ConsumerState<_CtqAcknowledgmentSheet> {
  final _reasonCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reasonCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  bool get _saveEnabled => _reasonCtrl.text.trim().length >= 10;

  Future<void> _save() async {
    if (!_saveEnabled || _saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(ctqFactorDefinitionRepositoryProvider)
          .acknowledgeCtqFactor(
            trialId: widget.trialId,
            factorKey: widget.item.factorKey,
            reason: _reasonCtrl.text.trim(),
            factorStatusAtAcknowledgment: widget.item.status,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acknowledged.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      ref.invalidate(trialDecisionSummaryProvider(widget.trialId));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const pad = FormStyles.formSheetHorizontalPadding;
    final item = widget.item;
    return StandardFormBottomSheetLayout(
      title: item.label,
      saveLabel: _saving ? 'Saving…' : 'Acknowledge',
      saveEnabled: _saveEnabled && !_saving,
      onCancel: () => Navigator.of(context).pop(),
      onSave: _save,
      body: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.symmetric(horizontal: pad),
        children: [
          const SizedBox(height: AppDesignTokens.spacing8),
          Row(
            children: [
              const Text(
                'Status: ',
                style: TextStyle(
                  fontSize: 13,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
              Text(
                _statusLabel(item.status),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _statusColor(item.status),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing8),
          Container(
            padding: const EdgeInsets.all(AppDesignTokens.spacing12),
            decoration: BoxDecoration(
              color: AppDesignTokens.sectionHeaderBg,
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
            ),
            child: Text(
              item.reason,
              style: const TextStyle(
                fontSize: 13,
                color: AppDesignTokens.primaryText,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing20),
          const Text('REASONING', style: FormStyles.sectionLabelStyle),
          const SizedBox(height: AppDesignTokens.spacing8),
          TextField(
            controller: _reasonCtrl,
            maxLines: 4,
            maxLength: 2000,
            decoration: FormStyles.inputDecoration(
              hintText:
                  'Describe the field conditions or protocol context that informed this decision.',
            ).copyWith(
              helperText:
                  '${_reasonCtrl.text.trim().length}/10 characters minimum',
              counterText: '',
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing16),
        ],
      ),
    );
  }

  static String _statusLabel(String status) => switch (status) {
        'blocked' => 'Blocked',
        'review_needed' => 'Needs review',
        'missing' => 'Missing evidence',
        'satisfied' => 'Satisfied',
        _ => status,
      };

  static Color _statusColor(String status) => switch (status) {
        'blocked' || 'missing' => AppDesignTokens.warningFg,
        'review_needed' => AppDesignTokens.flagColor,
        'satisfied' => AppDesignTokens.successFg,
        _ => AppDesignTokens.secondaryText,
      };
}
