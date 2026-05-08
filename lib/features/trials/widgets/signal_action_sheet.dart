import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/design/form_styles.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_draggable_modal_sheet.dart';
import '../../../core/widgets/standard_form_bottom_sheet.dart';
import '../../../domain/signals/signal_models.dart';
import '../../../domain/signals/signal_providers.dart';
import '../../../domain/signals/signal_review_projection.dart';
import '../../../domain/signals/signal_review_projection_mapper.dart';

Future<void> showSignalActionSheet(
  BuildContext context, {
  required Signal signal,
  required int trialId,
}) {
  return showAppDraggableModalSheet(
    context: context,
    initialChildSize: 0.72,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    sheetBuilder: (sheetCtx, scrollCtrl) => _SignalActionSheet(
      signal: signal,
      trialId: trialId,
      scrollController: scrollCtrl,
    ),
  );
}

const _kDecisionOptions = [
  SignalDecisionEventType.confirm,
  SignalDecisionEventType.investigate,
  SignalDecisionEventType.defer,
  SignalDecisionEventType.suppress,
];

bool _supportsReRate(Signal signal) =>
    signal.signalType == 'rater_drift' ||
    signal.signalType == 'between_rater_divergence';

bool _requiresReason(SignalDecisionEventType? type) =>
    type == SignalDecisionEventType.investigate ||
    type == SignalDecisionEventType.suppress;

class _SignalActionSheet extends ConsumerStatefulWidget {
  const _SignalActionSheet({
    required this.signal,
    required this.trialId,
    required this.scrollController,
  });

  final Signal signal;
  final int trialId;
  final ScrollController scrollController;

  @override
  ConsumerState<_SignalActionSheet> createState() => _SignalActionSheetState();
}

class _SignalActionSheetState extends ConsumerState<_SignalActionSheet> {
  SignalDecisionEventType? _selected;
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

  bool get _saveEnabled {
    if (_selected == null) return false;
    if (_requiresReason(_selected)) {
      return _reasonCtrl.text.trim().length >= 10;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_saveEnabled || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(signalRepositoryProvider).recordResearcherDecision(
            signalId: widget.signal.id,
            eventType: _selected!,
            reason: _reasonCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Decision recorded.'),
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
    final projection = projectSignalForReview(widget.signal);

    // For deferred signals, distinguish system-deferred (session close) from
    // researcher-deferred using the canned note phrases written at session close.
    String? statusLabelOverride;
    if (widget.signal.status == SignalStatus.deferred.dbValue) {
      const cannedPhrases = [
        'Proceeded at session close',
        'Not shown at session close',
      ];
      final historyAsync =
          ref.watch(signalDecisionHistoryProvider(widget.signal.id));
      historyAsync.whenOrNull(
        data: (events) {
          for (final e in events.reversed) {
            if (e.eventType == 'defer') {
              final note = e.note ?? '';
              if (cannedPhrases.any((p) => note.contains(p))) {
                statusLabelOverride = 'Auto-deferred at session close';
              }
              return;
            }
          }
        },
      );
    }
    return StandardFormBottomSheetLayout(
      title: 'Signal Decision',
      saveLabel: _saving ? 'Saving…' : 'Record Decision',
      saveEnabled: _saveEnabled && !_saving,
      onCancel: () => Navigator.of(context).pop(),
      onSave: _save,
      body: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.symmetric(horizontal: pad),
        children: [
          const SizedBox(height: AppDesignTokens.spacing8),
          _SeverityBadge(projection: projection),
          const SizedBox(height: AppDesignTokens.spacing8),
          Text(
            projection.displayTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppDesignTokens.primaryText,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing8),
          Text(
            projection.shortSummary,
            style: const TextStyle(
              fontSize: 14,
              color: AppDesignTokens.primaryText,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing12),
          _ProjectionInfoBlock(
            projection: projection,
            statusLabelOverride: statusLabelOverride,
          ),
          const SizedBox(height: AppDesignTokens.spacing20),
          const Text('DECISION', style: FormStyles.sectionLabelStyle),
          const SizedBox(height: AppDesignTokens.spacing8),
          ..._kDecisionOptions.map(
            (opt) => _DecisionOption(
              option: opt,
              selected: _selected == opt,
              onTap: () => setState(() => _selected = opt),
            ),
          ),
          if (_supportsReRate(widget.signal))
            _DecisionOption(
              option: SignalDecisionEventType.reRate,
              selected: false,
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Open the session to correct the plot rating.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          const SizedBox(height: AppDesignTokens.spacing20),
          const Text('REASONING', style: FormStyles.sectionLabelStyle),
          const SizedBox(height: AppDesignTokens.spacing8),
          TextField(
            controller: _reasonCtrl,
            maxLines: 4,
            maxLength: 2000,
            decoration: FormStyles.inputDecoration(
              hintText: _selected == SignalDecisionEventType.defer
                  ? 'Adding reasoning now is better than reconstructing it later.'
                  : 'Required for this decision type.',
            ).copyWith(
              helperText: _requiresReason(_selected)
                  ? '${_reasonCtrl.text.trim().length}/10 characters minimum'
                  : null,
              counterText: '',
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing16),
        ],
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.projection});
  final SignalReviewProjection projection;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (projection.severity) {
      'critical' => projection.blocksExport
          ? (AppDesignTokens.warningBg, AppDesignTokens.warningFg)
          : (const Color(0xFFFEF3C7), AppDesignTokens.flagColor),
      'review' => (const Color(0xFFFEF3C7), AppDesignTokens.flagColor),
      _ => (AppDesignTokens.sectionHeaderBg, AppDesignTokens.secondaryText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusChip),
      ),
      child: Text(
        projection.severityLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _ProjectionInfoBlock extends StatelessWidget {
  const _ProjectionInfoBlock({
    required this.projection,
    this.statusLabelOverride,
  });

  final SignalReviewProjection projection;
  final String? statusLabelOverride;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoLine(label: 'Status', value: statusLabelOverride ?? projection.statusLabel),
        _InfoLine(label: 'Why it matters', value: projection.whyItMatters),
        _InfoLine(
          label: 'Recommended action',
          value: projection.recommendedAction,
        ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            title: const Text(
              'Original signal detail',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  projection.detailText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppDesignTokens.secondaryText,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: FormStyles.sectionLabelStyle),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppDesignTokens.primaryText,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionOption extends StatelessWidget {
  const _DecisionOption({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final SignalDecisionEventType option;
  final bool selected;
  final VoidCallback onTap;

  static String _label(SignalDecisionEventType opt) => switch (opt) {
        SignalDecisionEventType.confirm => 'Confirm — deviation is acceptable',
        SignalDecisionEventType.investigate => 'Investigate — needs follow-up',
        SignalDecisionEventType.defer => 'Defer — review later',
        SignalDecisionEventType.suppress => 'Suppress — not relevant',
        SignalDecisionEventType.reRate => 'Re-rate — correct the plot rating',
        _ => opt.dbValue,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing12,
          vertical: AppDesignTokens.spacing12,
        ),
        decoration: selected
            ? FormStyles.selectedCardDecoration
            : FormStyles.unselectedCardDecoration,
        child: Text(
          _label(option),
          style: TextStyle(
            fontSize: 14,
            color: selected
                ? AppDesignTokens.primary
                : AppDesignTokens.primaryText,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
