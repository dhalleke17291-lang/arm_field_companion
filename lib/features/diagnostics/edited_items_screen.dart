import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return _future ??= _loadEditedItemsWithCorrectionDiffs();
  }

  Future<List<_EditedItemWithDiff>> _loadEditedItemsWithCorrectionDiffs() async {
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

  static String _formatDate(DateTime at) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = at.month >= 1 && at.month <= 12 ? months[at.month - 1] : '';
    return '${at.day} $month ${at.year}';
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
              final meta =
                  '${item.statusLabel} · ${_formatDate(item.displayDate)}';
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
                      meta,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppDesignTokens.primary,
                      ),
                    ),
                    if (row.correctionDiffLine != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        row.correctionDiffLine!,
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
  const _EditedItemWithDiff(this.item, this.correctionDiffLine);

  final EditedRatingListItem item;
  final String? correctionDiffLine;
}
