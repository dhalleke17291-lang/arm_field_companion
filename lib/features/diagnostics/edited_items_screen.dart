import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../ratings/domain/get_edited_ratings_usecase.dart';
import '../../shared/widgets/app_card.dart';

class EditedItemsScreen extends ConsumerStatefulWidget {
  const EditedItemsScreen({super.key});

  @override
  ConsumerState<EditedItemsScreen> createState() => _EditedItemsScreenState();
}

class _EditedItemsScreenState extends ConsumerState<EditedItemsScreen> {
  Future<List<_EditedItemWithDiff>>? _future;

  Future<List<_EditedItemWithDiff>> _ensureFuture() {
    return _future ??= _loadEditedItemsWithDiffs();
  }

  Future<List<_EditedItemWithDiff>> _loadEditedItemsWithDiffs() async {
    final items = await GetEditedRatingsUseCase(
      db: ref.read(databaseProvider),
      trialRepo: ref.read(trialRepositoryProvider),
      sessionRepo: ref.read(sessionRepositoryProvider),
      plotRepo: ref.read(plotRepositoryProvider),
    ).call();
    final repo = ref.read(ratingRepositoryProvider);
    final out = <_EditedItemWithDiff>[];
    for (final item in items) {
      String? diffLine;
      if (item.hasCorrection) {
        final c = await repo.getLatestCorrectionForRating(item.rating.id);
        if (c != null) {
          diffLine = _correctionDiffLine(c);
        }
      } else {
        diffLine = _amendmentDiffLine(item.rating);
        if (diffLine == null && item.rating.previousId != null) {
          final prev = await repo.getRatingById(item.rating.previousId!);
          if (prev != null) {
            diffLine = _chainDiffLine(prev, item.rating);
          }
        }
      }
      out.add(_EditedItemWithDiff(item, diffLine));
    }
    return out;
  }

  /// Single-line summary from stored correction fields only (no audit/chain).
  static String? _correctionDiffLine(RatingCorrection c) {
    final os = c.oldResultStatus;
    final ns = c.newResultStatus;

    if (os != ns) {
      if (ns == 'RECORDED' && c.newNumericValue != null) {
        return 'Status: $os → RECORDED (${c.newNumericValue})';
      }
      final nt = c.newTextValue?.trim();
      if (ns == 'RECORDED' && nt != null && nt.isNotEmpty) {
        return 'Status: $os → RECORDED ($nt)';
      }
      return 'Status: $os → $ns';
    }

    final on = c.oldNumericValue;
    final nn = c.newNumericValue;
    if (on != null || nn != null) {
      final o = on?.toString() ?? '—';
      final n = nn?.toString() ?? '—';
      if (o != n) return 'Was $o → Now $n';
    }

    final ot = c.oldTextValue?.trim() ?? '';
    final nt = c.newTextValue?.trim() ?? '';
    if (ot.isNotEmpty || nt.isNotEmpty) {
      if (ot != nt) {
        final o = ot.isEmpty ? '—' : ot;
        final n = nt.isEmpty ? '—' : nt;
        return 'Was $o → Now $n';
      }
    }

    return null;
  }

  /// originalValue → current row only; no corrections, chain, or status inference.
  static String? _amendmentDiffLine(RatingRecord r) {
    if (!r.amended) return null;
    final old = r.originalValue?.trim() ?? '';
    if (old.isEmpty) return null;
    final now = r.numericValue != null
        ? r.numericValue!.toString()
        : ((r.textValue != null && r.textValue!.trim().isNotEmpty)
            ? r.textValue!.trim()
            : '—');
    if (old == now) return null;
    return 'Was $old → Now $now';
  }

  /// One hop: immediate previous row vs current only.
  static String? _chainDiffLine(RatingRecord prev, RatingRecord curr) {
    if (prev.resultStatus != curr.resultStatus) {
      return 'Status: ${prev.resultStatus} → ${curr.resultStatus}';
    }
    final on = prev.numericValue;
    final nn = curr.numericValue;
    if (on != null || nn != null) {
      final o = on?.toString() ?? '—';
      final n = nn?.toString() ?? '—';
      if (o != n) return 'Was $o → Now $n';
    }
    final ot = prev.textValue?.trim() ?? '';
    final nt = curr.textValue?.trim() ?? '';
    if (ot.isNotEmpty || nt.isNotEmpty) {
      if (ot != nt) {
        return 'Was ${ot.isEmpty ? '—' : ot} → Now ${nt.isEmpty ? '—' : nt}';
      }
    }
    return null;
  }

  static String _recordKindLabel(bool hasCorrection) =>
      hasCorrection ? 'Corrected record' : 'Edited record';

  static String _lastEditedLine(DateTime at, String? byDisplayName) {
    final fmt = DateFormat('MMM d, yyyy, h:mm a').format(at.toLocal());
    final name = byDisplayName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'Last edited $fmt by $name';
    }
    return 'Last edited $fmt';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: const GradientScreenHeader(
        title: 'Edited Items',
        subtitle: 'Includes all sessions in this trial',
      ),
      body: FutureBuilder<List<_EditedItemWithDiff>>(
        future: _ensureFuture(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDesignTokens.spacing24),
                child: Text(
                  'Could not load edited items.',
                  style: TextStyle(color: AppDesignTokens.secondaryText),
                ),
              ),
            );
          }
          final rows = snapshot.data ?? const <_EditedItemWithDiff>[];
          if (rows.isEmpty) {
            return const Center(
              child: Text(
                'No edited items',
                style: TextStyle(
                  fontSize: 16,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppDesignTokens.spacing16),
            itemCount: rows.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppDesignTokens.spacing12),
            itemBuilder: (context, i) {
              final row = rows[i];
              final item = row.item;
              final r = item.rating;
              final primary = item.assessmentLabel != null &&
                      item.assessmentLabel!.isNotEmpty
                  ? 'Plot ${item.plotLabel} · ${item.assessmentLabel}'
                  : 'Plot ${item.plotLabel}';
              final secondary =
                  '${item.trialName} · ${item.sessionName}';
              return AppCard(
                padding: const EdgeInsets.all(AppDesignTokens.spacing16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primary,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppDesignTokens.primaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      secondary,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _recordKindLabel(item.hasCorrection),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppDesignTokens.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lastEditedLine(
                        item.displayDate,
                        item.lastEditedByDisplayName,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                    if (row.diffLine != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        row.diffLine!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: AppDesignTokens.primaryText,
                        ),
                      ),
                    ],
                    if (r.amendmentReason != null &&
                        r.amendmentReason!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        r.amendmentReason!.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppDesignTokens.primaryText,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EditedItemWithDiff {
  const _EditedItemWithDiff(this.item, this.diffLine);

  final EditedRatingListItem item;
  /// Correction, else amendment, else one-hop chain diff.
  final String? diffLine;
}
