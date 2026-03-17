import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  Future<List<EditedRatingListItem>>? _future;

  Future<List<EditedRatingListItem>> _ensureFuture() {
    return _future ??= GetEditedRatingsUseCase(
      db: ref.read(databaseProvider),
      trialRepo: ref.read(trialRepositoryProvider),
      sessionRepo: ref.read(sessionRepositoryProvider),
      plotRepo: ref.read(plotRepositoryProvider),
    ).call();
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
      appBar: const GradientScreenHeader(title: 'Edited Items'),
      body: FutureBuilder<List<EditedRatingListItem>>(
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
          final items = snapshot.data ?? const <EditedRatingListItem>[];
          if (items.isEmpty) {
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
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppDesignTokens.spacing12),
            itemBuilder: (context, i) {
              final item = items[i];
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
