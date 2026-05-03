import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../../domain/trial_cognition/trial_ctq_dto.dart';
import '../../domain/trial_cognition/trial_evidence_arc_dto.dart';
import '../../domain/trial_cognition/trial_purpose_dto.dart';
import '../../domain/trial_story/trial_story_event.dart';
import '../../domain/trial_story/trial_story_provider.dart';
import 'tabs/trial_intent_sheet.dart';

class TrialStoryScreen extends ConsumerWidget {
  const TrialStoryScreen({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trialStoryProvider(trial.id));

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: GradientScreenHeader(
        title: 'Trial Story',
        subtitle: trial.name,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text(
            'Unable to load trial story',
            style: TextStyle(color: AppDesignTokens.secondaryText),
          ),
        ),
        data: (events) => _TrialStoryBody(trial: trial, events: events),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _TrialStoryBody extends StatelessWidget {
  const _TrialStoryBody({required this.trial, required this.events});

  final Trial trial;
  final List<TrialStoryEvent> events;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDesignTokens.spacing16),
      children: [
        // ── Cognition summary ───────────────────────────────────────────────
        _PurposeCard(trial: trial),
        const SizedBox(height: AppDesignTokens.spacing12),
        _EvidenceArcCard(trialId: trial.id),
        const SizedBox(height: AppDesignTokens.spacing12),
        _CtqCard(trialId: trial.id),
        const SizedBox(height: AppDesignTokens.spacing24),

        // ── Timeline section ────────────────────────────────────────────────
        const Text(
          'TIMELINE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: AppDesignTokens.secondaryText,
          ),
        ),
        const SizedBox(height: AppDesignTokens.spacing8),

        if (events.isEmpty) ...[
          const SizedBox(height: AppDesignTokens.spacing8),
          const Text(
            'No trial story yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.primaryText,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing8),
          const Text(
            'Seeding, applications, and sessions will appear here '
            'as the trial is executed.',
            style: TextStyle(
              fontSize: 13,
              color: AppDesignTokens.secondaryText,
              height: 1.5,
            ),
          ),
        ] else ...[
          const Text(
            'Events are shown with current unresolved signal context '
            'where available.',
            style: TextStyle(
              fontSize: 12,
              color: AppDesignTokens.secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing12),
          ...events.map(
            (e) => Padding(
              padding:
                  const EdgeInsets.only(bottom: AppDesignTokens.spacing12),
              child: _TrialStoryEventTile(event: e),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cognition cards
// ---------------------------------------------------------------------------

class _CognitionCard extends StatelessWidget {
  const _CognitionCard({required this.sectionLabel, required this.child});

  final String sectionLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDesignTokens.spacing16),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: AppDesignTokens.cardShadowRating,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sectionLabel,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing8),
          child,
        ],
      ),
    );
  }
}

// ── Purpose ──────────────────────────────────────────────────────────────────

class _PurposeCard extends ConsumerWidget {
  const _PurposeCard({required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trialPurposeProvider(trial.id));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (dto) => _CognitionCard(
        sectionLabel: 'CLAIM / PURPOSE',
        child: _PurposeBody(
          dto: dto,
          onCta: () => showTrialIntentSheet(context, ref, trial: trial),
        ),
      ),
    );
  }
}

class _PurposeBody extends StatelessWidget {
  const _PurposeBody({required this.dto, required this.onCta});

  final TrialPurposeDto dto;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    if (dto.isUnknown) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Not captured yet.',
            style: TextStyle(
              fontSize: 13,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing8),
          _Cta(label: 'Capture intent →', onTap: onCta),
        ],
      );
    }

    final claim = dto.claimBeingTested;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (claim != null && claim.isNotEmpty)
          Text(
            claim,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.primaryText,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          )
        else
          Text(
            dto.isConfirmed ? 'Confirmed.' : 'In progress.',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.primaryText,
            ),
          ),
        if (dto.isPartial && dto.missingIntentFields.isNotEmpty) ...[
          const SizedBox(height: AppDesignTokens.spacing4),
          Text(
            '${dto.missingIntentFields.length} '
            'field${dto.missingIntentFields.length == 1 ? '' : 's'} incomplete.',
            style: const TextStyle(
              fontSize: 12,
              color: AppDesignTokens.secondaryText,
            ),
          ),
        ],
        const SizedBox(height: AppDesignTokens.spacing8),
        _Cta(label: 'Review intent →', onTap: onCta),
      ],
    );
  }
}

// ── Evidence Arc ──────────────────────────────────────────────────────────────

class _EvidenceArcCard extends ConsumerWidget {
  const _EvidenceArcCard({required this.trialId});

  final int trialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trialEvidenceArcProvider(trialId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (dto) => _CognitionCard(
        sectionLabel: 'EVIDENCE ARC',
        child: _EvidenceArcBody(dto: dto),
      ),
    );
  }
}

class _EvidenceArcBody extends StatelessWidget {
  const _EvidenceArcBody({required this.dto});

  final TrialEvidenceArcDto dto;

  static String _stateLabel(String state) => switch (state) {
        'no_evidence' => 'No evidence recorded yet.',
        'started' => 'Evidence recording started.',
        'partial' => 'Partial — some sessions completed.',
        'sufficient_for_review' => 'Sufficient for review.',
        'export_ready_candidate' => 'Export ready.',
        _ => state,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _stateLabel(dto.evidenceState),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppDesignTokens.primaryText,
          ),
        ),
        if (dto.actualEvidenceSummary.isNotEmpty) ...[
          const SizedBox(height: AppDesignTokens.spacing4),
          Text(
            dto.actualEvidenceSummary,
            style: const TextStyle(
              fontSize: 12,
              color: AppDesignTokens.secondaryText,
              height: 1.4,
            ),
          ),
        ],
        if (dto.riskFlags.isNotEmpty) ...[
          const SizedBox(height: AppDesignTokens.spacing4),
          Text(
            dto.riskFlags.first,
            style: const TextStyle(
              fontSize: 12,
              color: AppDesignTokens.warningFg,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

// ── CTQ ───────────────────────────────────────────────────────────────────────

class _CtqCard extends ConsumerWidget {
  const _CtqCard({required this.trialId});

  final int trialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trialCriticalToQualityProvider(trialId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (dto) => _CognitionCard(
        sectionLabel: 'CRITICAL TO QUALITY',
        child: _CtqBody(dto: dto),
      ),
    );
  }
}

class _CtqBody extends StatelessWidget {
  const _CtqBody({required this.dto});

  final TrialCtqDto dto;

  static String _overallLabel(String status) => switch (status) {
        'unknown' => 'Not yet evaluated.',
        'incomplete' => 'Incomplete — evidence gaps remain.',
        'review_needed' => 'Needs review before export.',
        'ready_for_review' => 'Ready for review.',
        _ => status,
      };

  static Color _overallColor(String status) => switch (status) {
        'ready_for_review' => AppDesignTokens.successFg,
        'review_needed' => AppDesignTokens.warningFg,
        _ => AppDesignTokens.primaryText,
      };

  @override
  Widget build(BuildContext context) {
    final attentionItems = _topAttentionItems(dto);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _overallLabel(dto.overallStatus),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _overallColor(dto.overallStatus),
          ),
        ),
        if (dto.blockerCount > 0 ||
            dto.warningCount > 0 ||
            dto.reviewCount > 0) ...[
          const SizedBox(height: AppDesignTokens.spacing4),
          Text(
            _countSummary(dto),
            style: const TextStyle(
              fontSize: 12,
              color: AppDesignTokens.secondaryText,
            ),
          ),
        ],
        if (attentionItems.isNotEmpty) ...[
          const SizedBox(height: AppDesignTokens.spacing8),
          ...attentionItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '· ${item.label}',
                style: TextStyle(
                  fontSize: 12,
                  color: item.isBlocked
                      ? AppDesignTokens.warningFg
                      : AppDesignTokens.secondaryText,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  static String _countSummary(TrialCtqDto dto) {
    final parts = <String>[];
    if (dto.blockerCount > 0) parts.add('${dto.blockerCount} blocked');
    if (dto.reviewCount > 0) parts.add('${dto.reviewCount} need review');
    if (dto.warningCount > 0) parts.add('${dto.warningCount} incomplete');
    return parts.join(' · ');
  }

  static List<TrialCtqItemDto> _topAttentionItems(TrialCtqDto dto) {
    final blocked =
        dto.ctqItems.where((i) => i.status == 'blocked').toList();
    final review =
        dto.ctqItems.where((i) => i.status == 'review_needed').toList();
    final missing =
        dto.ctqItems.where((i) => i.status == 'missing').toList();
    return [...blocked, ...review, ...missing].take(5).toList();
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _Cta extends StatelessWidget {
  const _Cta({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppDesignTokens.primaryText,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

class _TrialStoryEventTile extends StatelessWidget {
  const _TrialStoryEventTile({required this.event});

  final TrialStoryEvent event;

  static final _dateFmt = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDesignTokens.spacing16),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: AppDesignTokens.cardShadowRating,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TypeDot(type: event.type),
          const SizedBox(width: AppDesignTokens.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dateFmt.format(event.occurredAt.toLocal()),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppDesignTokens.secondaryText,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppDesignTokens.primaryText,
                    letterSpacing: 0.1,
                  ),
                ),
                if (event.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    event.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ],
                if (event.type == TrialStoryEventType.session) ...[
                  const SizedBox(height: AppDesignTokens.spacing8),
                  _SessionDetails(event: event),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session detail rows
// ---------------------------------------------------------------------------

class _SessionDetails extends StatelessWidget {
  const _SessionDetails({required this.event});

  final TrialStoryEvent event;

  @override
  Widget build(BuildContext context) {
    final signals = event.activeSignalSummary;
    final divs = event.divergenceSummary;
    final ev = event.evidenceSummary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (signals != null && signals.count > 0) ...[
          _DetailRow(
            label:
                '${signals.count} active signal${signals.count == 1 ? '' : 's'}',
          ),
          if (signals.hasCritical)
            const _DetailRow(
              label: 'Critical signal present',
              muted: true,
            ),
        ],
        if (divs != null && divs.count > 0)
          _DetailRow(
            label:
                '${divs.count} protocol difference${divs.count == 1 ? '' : 's'}',
          ),
        if (ev != null) _EvidenceRow(summary: ev),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: muted
              ? AppDesignTokens.secondaryText
              : AppDesignTokens.primaryText,
          height: 1.4,
        ),
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.summary});

  final EvidenceSummary summary;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (summary.photoCount > 0) 'Photos',
      if (summary.hasGps) 'GPS',
      if (summary.hasWeather) 'Weather',
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        'Evidence: ${parts.isEmpty ? 'None recorded' : parts.join(' · ')}',
        style: const TextStyle(
          fontSize: 12,
          color: AppDesignTokens.secondaryText,
          height: 1.4,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leading dot
// ---------------------------------------------------------------------------

class _TypeDot extends StatelessWidget {
  const _TypeDot({required this.type});

  final TrialStoryEventType type;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppDesignTokens.secondaryText,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
