import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/loading_error_widgets.dart';

/// ARM Protocol tab — read-only; visible only on ARM-imported trials.
///
/// Surfaces ARM import context that has no other dedicated UI:
///  - Import summary (source file, ARM version, import date)
///  - Shell link (linked shell file, link date)
///  - ARM assessments (columns, SE codes, rating dates)
///  - Pinned import session
///
/// Lives under `lib/features/arm_protocol/` (ARM subtree). Trial hub accesses
/// this widget via [armProtocolTabBuilderProvider] in providers.dart so that
/// trial_detail_screen.dart never imports from the ARM subtree directly.
class ArmProtocolTab extends ConsumerWidget {
  const ArmProtocolTab({super.key, required this.trialId});

  final int trialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync = ref.watch(armTrialMetadataStreamProvider(trialId));

    return metaAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, st) => AppErrorView(
        error: e,
        stackTrace: st,
        onRetry: () => ref.invalidate(armTrialMetadataStreamProvider(trialId)),
      ),
      data: (meta) {
        if (meta == null || !meta.isArmLinked) {
          return const _NotLinkedPlaceholder();
        }
        return _ArmProtocolContent(trialId: trialId, meta: meta);
      },
    );
  }
}

// ─── Not linked placeholder ──────────────────────────────────────────────────

class _NotLinkedPlaceholder extends StatelessWidget {
  const _NotLinkedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignTokens.spacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppDesignTokens.emptyBadgeBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.link_off,
                size: 28,
                color: AppDesignTokens.emptyBadgeFg,
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing16),
            Text(
              'Not ARM-linked',
              style: AppDesignTokens.headingStyle(
                fontSize: 16,
                color: AppDesignTokens.primaryText,
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacing8),
            const Text(
              'This trial was not imported from ARM. Protocol tab is only available for ARM-imported trials.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppDesignTokens.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Main content ────────────────────────────────────────────────────────────

class _ArmProtocolContent extends ConsumerWidget {
  const _ArmProtocolContent({required this.trialId, required this.meta});

  final int trialId;
  final ArmTrialMetadataData meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.only(
        top: AppDesignTokens.spacing8,
        bottom: 32,
      ),
      children: [
        _ImportSummaryCard(meta: meta),
        if (meta.armLinkedShellPath != null || meta.armLinkedShellAt != null)
          _ShellLinkCard(meta: meta),
        _ArmAssessmentsSection(trialId: trialId),
        if (meta.armImportSessionId != null)
          _ImportSessionCard(sessionId: meta.armImportSessionId!),
      ],
    );
  }
}

// ─── Import Summary Card ─────────────────────────────────────────────────────

class _ImportSummaryCard extends StatelessWidget {
  const _ImportSummaryCard({required this.meta});

  final ArmTrialMetadataData meta;

  @override
  Widget build(BuildContext context) {
    final importedAt = meta.armImportedAt;
    final importedAtStr = importedAt != null
        ? DateFormat('d MMM yyyy, HH:mm').format(importedAt.toLocal())
        : null;

    return _SectionCard(
      icon: Icons.download_rounded,
      title: 'ARM Import',
      iconColor: AppDesignTokens.primary,
      children: [
        if (meta.armSourceFile != null)
          _InfoRow(label: 'Source file', value: meta.armSourceFile!),
        if (meta.armVersion != null)
          _InfoRow(label: 'ARM version', value: meta.armVersion!),
        if (importedAtStr != null)
          _InfoRow(label: 'Imported', value: importedAtStr),
        if (meta.armSourceFile == null &&
            meta.armVersion == null &&
            importedAtStr == null)
          const _EmptyRowHint(
              text: 'No import detail captured for this trial.'),
      ],
    );
  }
}

// ─── Shell Link Card ─────────────────────────────────────────────────────────

class _ShellLinkCard extends StatelessWidget {
  const _ShellLinkCard({required this.meta});

  final ArmTrialMetadataData meta;

  @override
  Widget build(BuildContext context) {
    final linkedAt = meta.armLinkedShellAt;
    final linkedAtStr = linkedAt != null
        ? DateFormat('d MMM yyyy, HH:mm').format(linkedAt.toLocal())
        : null;

    final shellName = meta.armLinkedShellPath != null
        ? _basenameOf(meta.armLinkedShellPath!)
        : null;

    return _SectionCard(
      icon: Icons.link_rounded,
      title: 'Rating Shell',
      iconColor: const Color(0xFF0369A1),
      children: [
        if (shellName != null) _InfoRow(label: 'Linked file', value: shellName),
        if (meta.armLinkedShellPath != null)
          _InfoRow(
            label: 'Full path',
            value: meta.armLinkedShellPath!,
            muted: true,
          ),
        if (linkedAtStr != null)
          _InfoRow(label: 'Linked on', value: linkedAtStr),
      ],
    );
  }

  String _basenameOf(String path) {
    final sep = path.contains('/') ? '/' : r'\';
    return path.split(sep).last;
  }
}

// ─── ARM Assessments Section ─────────────────────────────────────────────────

class _ArmAssessmentsSection extends ConsumerWidget {
  const _ArmAssessmentsSection({required this.trialId});

  final int trialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessmentsAsync =
        ref.watch(trialAssessmentsWithDefinitionsForTrialProvider(trialId));
    final aamMapAsync =
        ref.watch(armAssessmentMetadataMapForTrialProvider(trialId));

    return assessmentsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppDesignTokens.spacing16),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppDesignTokens.spacing16),
        child: Text(
          'Could not load assessments: $e',
          style: const TextStyle(color: AppDesignTokens.warningFg),
        ),
      ),
      data: (pairs) {
        // AAM map is additive context; render assessments even while it is
        // still loading to avoid a flash of emptiness on ARM trials.
        final aamMap = aamMapAsync.valueOrNull ?? const <int, ArmAssessmentMetadataData>{};

        // v60 moved per-column ARM fields to arm_assessment_metadata. An
        // assessment is "ARM-tagged" when its AAM row has
        // `armImportColumnIndex` set.
        int? armColIndexFor((TrialAssessment, AssessmentDefinition) pair) {
          return aamMap[pair.$1.id]?.armImportColumnIndex;
        }

        final armPairs = pairs.where((p) => armColIndexFor(p) != null).toList()
          ..sort((a, b) => (armColIndexFor(a) ?? 0)
              .compareTo(armColIndexFor(b) ?? 0));

        if (armPairs.isEmpty) {
          return const _SectionCard(
            icon: Icons.assessment_outlined,
            title: 'ARM Assessments',
            iconColor: Color(0xFF7C3AED),
            children: [
              _EmptyRowHint(text: 'No ARM column data linked to assessments.'),
            ],
          );
        }

        return _SectionCard(
          icon: Icons.assessment_outlined,
          title: 'ARM Assessments',
          iconColor: const Color(0xFF7C3AED),
          children: [
            for (final (ta, def) in armPairs)
              _ArmAssessmentRow(ta: ta, def: def, aam: aamMap[ta.id]),
          ],
        );
      },
    );
  }
}

class _ArmAssessmentRow extends StatelessWidget {
  const _ArmAssessmentRow({
    required this.ta,
    required this.def,
    required this.aam,
  });

  final TrialAssessment ta;
  final AssessmentDefinition def;
  final ArmAssessmentMetadataData? aam;

  @override
  Widget build(BuildContext context) {
    // v60 moved per-column ARM fields to arm_assessment_metadata; v61
    // (Unit 5d) finished the cutover by dropping seName / seDescription /
    // armRatingType / pestCode from trial_assessments. All ARM display
    // fields are now read from AAM.
    final name =
        ta.displayNameOverride?.isNotEmpty == true ? ta.displayNameOverride! : def.name;
    final colIdx = aam?.armImportColumnIndex;
    final columnId = aam?.armShellColumnId;
    final ratingDate = aam?.armShellRatingDate;
    final seName = aam?.seName;
    final ratingType = aam?.ratingType;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing16,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppDesignTokens.divider,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (colIdx != null) ...[
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$colIdx',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    if (columnId != null)
                      _MicroChip(label: columnId, color: const Color(0xFF7C3AED)),
                    if (ratingDate != null)
                      _MicroChip(
                        label: ratingDate,
                        color: AppDesignTokens.secondaryText,
                        icon: Icons.calendar_today,
                      ),
                    if (seName != null && seName.isNotEmpty)
                      _MicroChip(label: seName, color: const Color(0xFF0369A1)),
                    if (ratingType != null && ratingType.isNotEmpty)
                      _MicroChip(label: ratingType, color: const Color(0xFF047857)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Import Session Card ──────────────────────────────────────────────────────

class _ImportSessionCard extends ConsumerWidget {
  const _ImportSessionCard({required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionByIdProvider(sessionId));

    return sessionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (session) {
        if (session == null) return const SizedBox.shrink();

        final dateStr = DateFormat('d MMM yyyy').format(
          session.startedAt.toLocal(),
        );

        return _SectionCard(
          icon: Icons.calendar_month_outlined,
          title: 'Import Session',
          iconColor: AppDesignTokens.primaryGreen,
          children: [
            _InfoRow(label: 'Session', value: session.name),
            _InfoRow(label: 'Started', value: dateStr),
          ],
        );
      },
    );
  }
}

// ─── Shared building blocks ───────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.children,
  });

  final IconData icon;
  final String title;
  final Color iconColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing8,
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing8,
      ),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(icon: icon, title: title, iconColor: iconColor),
          ...children,
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing12,
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing12,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: AppDesignTokens.spacing12),
          Text(
            title,
            style: AppDesignTokens.headingStyle(
              fontSize: 14,
              color: AppDesignTokens.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing16,
        vertical: 9,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppDesignTokens.divider, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppDesignTokens.secondaryText,
              ),
            ),
          ),
          const SizedBox(width: AppDesignTokens.spacing8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: muted
                    ? AppDesignTokens.secondaryText
                    : AppDesignTokens.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRowHint extends StatelessWidget {
  const _EmptyRowHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing16,
        vertical: 12,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppDesignTokens.divider, width: 0.5),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppDesignTokens.secondaryText,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _MicroChip extends StatelessWidget {
  const _MicroChip({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
