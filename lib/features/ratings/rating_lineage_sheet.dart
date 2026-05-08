import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../domain/interpretation/causal_context_interpreter.dart';
import '../../domain/relationships/causal_context_provider.dart';
import 'usecases/rating_lineage_usecase.dart';

String _lineageStatusLabel(String value) {
  switch (value) {
    case 'VOID':
      return 'Void';
    case 'NOT_OBSERVED':
      return 'Not observed';
    case 'NOT_APPLICABLE':
      return 'N/A';
    case 'MISSING_CONDITION':
      return 'Missing';
    case 'TECHNICAL_ISSUE':
      return 'Tech issue';
    case 'RECORDED':
      return 'Recorded';
    default:
      return value
          .replaceAll('_', ' ')
          .toLowerCase()
          .split(' ')
          .map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}')
          .join(' ');
  }
}

String _formatEntryValue(RatingLineageEntry e) {
  if (e.resultStatus == 'RECORDED') {
    if (e.numericValue != null) return e.numericValue!.toString();
    if (e.textValue != null && e.textValue!.isNotEmpty) return e.textValue!;
  }
  return _lineageStatusLabel(e.resultStatus);
}

String _formatPreviousValue(RatingLineageEntry e) {
  if (e.previousResultStatus == null) return '';
  if (e.previousResultStatus == 'RECORDED') {
    if (e.previousNumericValue != null) {
      return e.previousNumericValue!.toString();
    }
    if (e.previousTextValue != null && e.previousTextValue!.isNotEmpty) {
      return e.previousTextValue!;
    }
  }
  return _lineageStatusLabel(e.previousResultStatus!);
}

String _formatCorrectionSide({
  required String resultStatus,
  double? numericValue,
  String? textValue,
}) {
  if (resultStatus == 'RECORDED') {
    if (numericValue != null) return numericValue.toString();
    if (textValue != null && textValue.isNotEmpty) return textValue;
  }
  return _lineageStatusLabel(resultStatus);
}

IconData _iconForType(RatingLineageEntryType t) {
  switch (t) {
    case RatingLineageEntryType.recorded:
      return Icons.check_circle_outline;
    case RatingLineageEntryType.superseded:
      return Icons.edit_outlined;
    case RatingLineageEntryType.voided:
      return Icons.block;
    case RatingLineageEntryType.undone:
      return Icons.undo;
  }
}

Color _iconColorForType(RatingLineageEntryType t) {
  switch (t) {
    case RatingLineageEntryType.recorded:
      return AppDesignTokens.successFg;
    case RatingLineageEntryType.superseded:
      return AppDesignTokens.warningFg;
    case RatingLineageEntryType.voided:
      return AppDesignTokens.missedColor;
    case RatingLineageEntryType.undone:
      return AppDesignTokens.iconSubtle;
  }
}

/// GLP transparency: read-only rating version and correction timeline.
void showRatingLineageBottomSheet({
  required BuildContext context,
  required WidgetRef ref,
  required int trialId,
  required int plotPk,
  required int assessmentId,
  required int sessionId,
  required String assessmentName,
  required String plotLabel,
  int? ratingId,
}) {
  final future = ref.read(ratingLineageUseCaseProvider).execute(
        trialId: trialId,
        plotPk: plotPk,
        assessmentId: assessmentId,
        sessionId: sessionId,
      );

  final causalContextFuture = ratingId != null
      ? ref.read(causalContextProvider(ratingId).future)
      : null;

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: false,
    isScrollControlled: true,
    backgroundColor: AppDesignTokens.cardSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDesignTokens.radiusLarge),
      ),
    ),
    builder: (ctx) => _RatingLineageSheetBody(
      future: future,
      assessmentName: assessmentName,
      plotLabel: plotLabel,
      causalContextFuture: causalContextFuture,
    ),
  );
}

class _RatingLineageSheetBody extends StatelessWidget {
  const _RatingLineageSheetBody({
    required this.future,
    required this.assessmentName,
    required this.plotLabel,
    this.causalContextFuture,
  });

  final Future<RatingLineage> future;
  final String assessmentName;
  final String plotLabel;
  final Future<CausalContext>? causalContextFuture;

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('dd MMM yyyy HH:mm');
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: AppDesignTokens.spacing16,
        right: AppDesignTokens.spacing16,
        top: AppDesignTokens.spacing12,
        bottom: AppDesignTokens.spacing16 + bottomInset,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: AppDesignTokens.spacing32,
                height: AppDesignTokens.spacing4,
                decoration: BoxDecoration(
                  color: AppDesignTokens.dragHandle,
                  borderRadius:
                      BorderRadius.circular(AppDesignTokens.radiusXSmall),
                ),
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing16),
            Text(
              'Rating History',
              style: AppDesignTokens.headerTitleStyle(
                fontSize: 18,
                color: AppDesignTokens.primaryText,
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing4),
            Text(
              '$assessmentName · Plot $plotLabel',
              style: AppDesignTokens.bodyCrispStyle(
                fontSize: 13,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing16),
            Expanded(
              child: FutureBuilder<RatingLineage>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Could not load history.',
                        style: AppDesignTokens.bodyStyle(
                          color: AppDesignTokens.warningFg,
                        ),
                      ),
                    );
                  }
                  final lineage = snapshot.data!;
                  if (lineage.entries.isEmpty) {
                    return Center(
                      child: Text(
                        'No history available',
                        style: AppDesignTokens.bodyStyle(
                          color: AppDesignTokens.secondaryText,
                        ),
                      ),
                    );
                  }

                  final newestFirst = lineage.entries.reversed.toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ListView.separated(
                          itemCount: newestFirst.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppDesignTokens.divider,
                          ),
                          itemBuilder: (context, index) {
                            final e = newestFirst[index];
                            final isCurrent = index == 0;
                            return _LineageEntryTile(
                              entry: e,
                              timeFmt: timeFmt,
                              highlight: isCurrent,
                            );
                          },
                        ),
                      ),
                      if (causalContextFuture != null)
                        _CausalContextSection(
                            future: causalContextFuture!),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineageEntryTile extends StatelessWidget {
  const _LineageEntryTile({
    required this.entry,
    required this.timeFmt,
    required this.highlight,
  });

  final RatingLineageEntry entry;
  final DateFormat timeFmt;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final centerText = _centerSummary(entry);
    final iconColor = _iconColorForType(entry.entryType);
    final secondary = AppDesignTokens.bodyStyle(
      fontSize: 13,
      color: AppDesignTokens.secondaryText,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppDesignTokens.spacing12,
        horizontal: AppDesignTokens.spacing4,
      ),
      decoration: highlight
          ? BoxDecoration(
              color: AppDesignTokens.primaryTint,
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _iconForType(entry.entryType),
            color: iconColor,
            size: AppDesignTokens.spacing24,
          ),
          const SizedBox(width: AppDesignTokens.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  centerText,
                  style: AppDesignTokens.headingStyle(
                    color: AppDesignTokens.primaryText,
                  ),
                ),
                if (entry.performedBy != null &&
                    entry.performedBy!.isNotEmpty) ...[
                  const SizedBox(height: AppDesignTokens.spacing4),
                  Text(entry.performedBy!, style: secondary),
                ],
                if (entry.performedBy == null &&
                    entry.performedByUserId != null) ...[
                  const SizedBox(height: AppDesignTokens.spacing4),
                  Text('User #${entry.performedByUserId}', style: secondary),
                ],
                if (entry.reason != null && entry.reason!.isNotEmpty) ...[
                  const SizedBox(height: AppDesignTokens.spacing4),
                  Text(entry.reason!, style: secondary),
                ],
                if (entry.entryType == RatingLineageEntryType.voided &&
                    entry.voidReason != null &&
                    entry.voidReason!.isNotEmpty) ...[
                  const SizedBox(height: AppDesignTokens.spacing4),
                  Text(entry.voidReason!, style: secondary),
                ],
                if (entry.corrections.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppDesignTokens.spacing8,
                      top: AppDesignTokens.spacing8,
                    ),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: AppDesignTokens.divider,
                            width: AppDesignTokens.borderWidthCrisp,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: AppDesignTokens.spacing12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0;
                                i < entry.corrections.length;
                                i++) ...[
                              if (i > 0)
                                const SizedBox(
                                    height: AppDesignTokens.spacing12),
                              _CorrectionBlock(
                                c: entry.corrections[i],
                                timeFmt: timeFmt,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppDesignTokens.spacing8),
          Text(
            timeFmt.format(entry.timestamp.toLocal()),
            style: AppDesignTokens.bodyStyle(
              fontSize: 12,
              color: AppDesignTokens.secondaryText,
            ),
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }

  String _centerSummary(RatingLineageEntry e) {
    switch (e.entryType) {
      case RatingLineageEntryType.recorded:
        return 'Recorded: ${_formatEntryValue(e)}';
      case RatingLineageEntryType.superseded:
        final prev = _formatPreviousValue(e);
        final cur = _formatEntryValue(e);
        if (prev.isNotEmpty) {
          return 'Re-rated: $prev → $cur';
        }
        return 'Re-rated: $cur';
      case RatingLineageEntryType.voided:
        return 'Voided';
      case RatingLineageEntryType.undone:
        return 'Undone';
    }
  }
}

class _CorrectionBlock extends StatelessWidget {
  const _CorrectionBlock({
    required this.c,
    required this.timeFmt,
  });

  final RatingCorrectionEntry c;
  final DateFormat timeFmt;

  @override
  Widget build(BuildContext context) {
    final secondary = AppDesignTokens.bodyStyle(
      fontSize: 13,
      color: AppDesignTokens.secondaryText,
    );
    final oldV = _formatCorrectionSide(
      resultStatus: c.oldResultStatus,
      numericValue: c.oldNumericValue,
      textValue: c.oldTextValue,
    );
    final newV = _formatCorrectionSide(
      resultStatus: c.newResultStatus,
      numericValue: c.newNumericValue,
      textValue: c.newTextValue,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.swap_horiz,
              size: AppDesignTokens.spacing20,
              color: AppDesignTokens.primary,
            ),
            const SizedBox(width: AppDesignTokens.spacing8),
            Expanded(
              child: Text(
                'Corrected: $oldV → $newV',
                style: AppDesignTokens.headingStyle(
                  fontSize: 14,
                  color: AppDesignTokens.primaryText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDesignTokens.spacing4),
        Text(c.reason, style: secondary),
        if (c.correctedByUserId != null) ...[
          const SizedBox(height: AppDesignTokens.spacing4),
          Text('User #${c.correctedByUserId}', style: secondary),
        ],
        const SizedBox(height: AppDesignTokens.spacing4),
        Text(
          timeFmt.format(c.correctedAt.toLocal()),
          style: AppDesignTokens.bodyStyle(
            fontSize: 12,
            color: AppDesignTokens.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _CausalContextSection extends StatelessWidget {
  const _CausalContextSection({required this.future});

  final Future<CausalContext> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CausalContext>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final appEvents = snapshot.data!.priorEvents
            .where((e) => e.type == CausalEventType.application)
            .toList()
          ..sort((a, b) {
            final dA = a.daysBefore;
            final dB = b.daysBefore;
            if (dA == null && dB == null) return 0;
            if (dA == null) return 1;
            if (dB == null) return -1;
            return dA.compareTo(dB);
          });

        if (appEvents.isEmpty) return const SizedBox.shrink();

        final visible = appEvents.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(
              height: 1,
              thickness: 1,
              color: AppDesignTokens.divider,
            ),
            const SizedBox(height: AppDesignTokens.spacing12),
            Text(
              'Context',
              style: AppDesignTokens.bodyStyle(
                fontSize: 11,
                color: AppDesignTokens.secondaryText,
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing8),
            for (final event in visible)
              Padding(
                padding:
                    const EdgeInsets.only(bottom: AppDesignTokens.spacing4),
                child: Text(
                  interpretCausalEvent(event).description,
                  style: AppDesignTokens.bodyStyle(
                    fontSize: 13,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ),
            const SizedBox(height: AppDesignTokens.spacing12),
          ],
        );
      },
    );
  }
}
