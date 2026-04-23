import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/excel_column_letters.dart';
import '../../core/providers.dart';
import '../../core/widgets/loading_error_widgets.dart';

/// ARM Protocol tab — read-only; visible only on ARM-imported trials.
///
/// Surfaces ARM import context that has no other dedicated UI:
///  - Import summary (source file, ARM version, import date)
///  - Shell link (linked shell file, link date)
///  - ARM assessments (columns, SE codes, rating dates)
///  - Applications sheet (imported application blocks, read-only)
///  - Comments sheet text (`ECM` row), when present
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
        if (meta.shellCommentsSheet != null &&
            meta.shellCommentsSheet!.trim().isNotEmpty)
          _ShellCommentsCard(text: meta.shellCommentsSheet!.trim()),
        ArmTreatmentsSection(trialId: trialId),
        ArmApplicationsSection(trialId: trialId),
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

// ─── Comments sheet (ECM) ────────────────────────────────────────────────────

class _ShellCommentsCard extends StatelessWidget {
  const _ShellCommentsCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.notes_rounded,
      title: 'Comments (rating sheet)',
      iconColor: const Color(0xFF6D28D9),
      children: [
        SelectableText(
          text,
          style: const TextStyle(
            fontSize: 14,
            height: 1.35,
            color: AppDesignTokens.primaryText,
          ),
        ),
      ],
    );
  }
}

// ─── ARM Treatments Section ──────────────────────────────────────────────────
//
// Phase 2c: renders the data parsed from the ARM Rating Shell's
// "Treatments" sheet (sheet 7). Read-only — the authoritative record
// lives in `arm_treatment_metadata` (ARM-specific coding) + core
// `treatments` / `treatment_components` (universal product + rate).
//
// Only ARM-linked trials reach this widget (the tab itself is gated on
// `isArmLinked`). Standalone trials never render this section — they
// have zero rows in `arm_treatment_metadata`.
/// Read-only Treatments sub-section of the ARM Protocol tab. Public so
/// it can be widget-tested in isolation with static provider overrides —
/// mounting the full [ArmProtocolTab] under `testWidgets` is impractical
/// because its Drift `watch()` streams schedule teardown timers that the
/// FakeAsync test zone cannot drain.
class ArmTreatmentsSection extends ConsumerWidget {
  const ArmTreatmentsSection({super.key, required this.trialId});

  final int trialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treatmentsAsync = ref.watch(treatmentsForTrialProvider(trialId));
    final aamMapAsync =
        ref.watch(armTreatmentMetadataMapForTrialProvider(trialId));
    final componentsMapAsync =
        ref.watch(treatmentComponentsByTreatmentForTrialProvider(trialId));

    return treatmentsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppDesignTokens.spacing16),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppDesignTokens.spacing16),
        child: Text(
          'Could not load treatments: $e',
          style: const TextStyle(color: AppDesignTokens.warningFg),
        ),
      ),
      data: (treatments) {
        final aamMap =
            aamMapAsync.valueOrNull ?? const <int, ArmTreatmentMetadataData>{};
        final componentsMap = componentsMapAsync.valueOrNull ??
            const <int, List<TreatmentComponent>>{};

        // A treatment is "ARM-tagged" when it has an AAM row (Phase 2b
        // writes one per parsed Treatments-sheet row, including CHK).
        // Treatments with no AAM row are hidden from this section —
        // they'd appear as orphan rows with blank coding, which is
        // confusing for the user. Users still see them on the standard
        // Treatments tab.
        final tagged = treatments.where((t) => aamMap.containsKey(t.id)).toList();
        if (tagged.isEmpty) {
          return const _SectionCard(
            icon: Icons.science_outlined,
            title: 'Treatments',
            iconColor: Color(0xFFC2410C),
            children: [
              _EmptyRowHint(text: 'No ARM Treatments sheet data for this trial.'),
            ],
          );
        }

        // Order by Treatments-sheet row position so on-screen order
        // matches the sheet (Phase 2b writes `armRowSortOrder`).
        int sortKey(Treatment t) =>
            aamMap[t.id]?.armRowSortOrder ?? 1 << 30;
        tagged.sort((a, b) => sortKey(a).compareTo(sortKey(b)));

        return _SectionCard(
          icon: Icons.science_outlined,
          title: 'Treatments',
          iconColor: const Color(0xFFC2410C),
          children: [
            for (final t in tagged)
              _ArmTreatmentRow(
                treatment: t,
                aam: aamMap[t.id]!,
                components: componentsMap[t.id] ?? const <TreatmentComponent>[],
              ),
          ],
        );
      },
    );
  }
}

class _ArmTreatmentRow extends StatelessWidget {
  const _ArmTreatmentRow({
    required this.treatment,
    required this.aam,
    required this.components,
  });

  final Treatment treatment;
  final ArmTreatmentMetadataData aam;
  final List<TreatmentComponent> components;

  @override
  Widget build(BuildContext context) {
    final typeCode = aam.armTypeCode;
    final subtitle = _buildFormulationSubtitle();

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
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDD5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              treatment.code,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFC2410C),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        treatment.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppDesignTokens.primaryText,
                        ),
                      ),
                    ),
                    if (typeCode != null && typeCode.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _MicroChip(
                        label: typeCode,
                        color: const Color(0xFFC2410C),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Joins the first component's rate + rate unit (universal, core)
  /// with ARM-only formulation coding (Form Conc / Unit / Type) from
  /// AAM, skipping any piece that's null/blank. Returns null when
  /// there's nothing to show — typical for CHK rows.
  String? _buildFormulationSubtitle() {
    final parts = <String>[];

    if (components.isNotEmpty) {
      final c = components.first;
      final rate = c.rate;
      final rateUnit = c.rateUnit;
      if (rate != null) {
        final rateStr = rate == rate.roundToDouble()
            ? rate.toInt().toString()
            : rate.toString();
        parts.add(rateUnit != null && rateUnit.isNotEmpty
            ? '$rateStr $rateUnit'
            : rateStr);
      }
    }

    final formConc = aam.formConc;
    final formConcUnit = aam.formConcUnit;
    if (formConc != null) {
      final concStr = formConc == formConc.roundToDouble()
          ? formConc.toInt().toString()
          : formConc.toString();
      parts.add(formConcUnit != null && formConcUnit.isNotEmpty
          ? '$concStr $formConcUnit'
          : concStr);
    }

    final formType = aam.formType;
    if (formType != null && formType.isNotEmpty) {
      parts.add(formType);
    }

    return parts.isEmpty ? null : parts.join(' • ');
  }
}

// ─── ARM Applications Section ────────────────────────────────────────────────
//
// Phase 3d: read-only view of `arm_applications` + core
// `trial_application_events` (Applications sheet import). Events without an
// ARM extension row are omitted here — they still appear on the main
// Applications tab.

/// Read-only Applications sub-section of the ARM Protocol tab. Public for
/// widget tests (same pattern as [ArmTreatmentsSection]).
class ArmApplicationsSection extends ConsumerWidget {
  const ArmApplicationsSection({super.key, required this.trialId});

  final int trialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(armSheetApplicationsForTrialProvider(trialId));

    return rowsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppDesignTokens.spacing16),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppDesignTokens.spacing16),
        child: Text(
          'Could not load applications: $e',
          style: const TextStyle(color: AppDesignTokens.warningFg),
        ),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const _SectionCard(
            icon: Icons.agriculture_outlined,
            title: 'Applications',
            iconColor: Color(0xFF0D9488),
            children: [
              _EmptyRowHint(
                text: 'No ARM Applications sheet data for this trial.',
              ),
            ],
          );
        }

        return _SectionCard(
          icon: Icons.agriculture_outlined,
          title: 'Applications',
          iconColor: const Color(0xFF0D9488),
          children: [
            for (final row in rows)
              _ArmApplicationRow(
                event: row.event,
                arm: row.arm,
              ),
          ],
        );
      },
    );
  }
}

class _ArmApplicationRow extends StatelessWidget {
  const _ArmApplicationRow({
    required this.event,
    required this.arm,
  });

  final TrialApplicationEvent event;
  final ArmApplication arm;

  @override
  Widget build(BuildContext context) {
    final local = event.applicationDate.toLocal();
    final dateStr = DateFormat('d MMM yyyy').format(local);
    final time = event.applicationTime?.trim();
    final title = (time != null && time.isNotEmpty) ? '$dateStr · $time' : dateStr;

    final colIdx = arm.armSheetColumnIndex;
    final colLabel =
        colIdx != null ? columnIndexToLettersZeroBased(colIdx) : '—';

    final subtitle = _subtitleFromEvent(event);
    final timing = arm.row07?.trim();

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
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              colLabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F766E),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    if (timing != null && timing.isNotEmpty)
                      _MicroChip(
                        label: timing,
                        color: const Color(0xFFB45309),
                      ),
                    if (event.applicationMethod != null &&
                        event.applicationMethod!.trim().isNotEmpty)
                      _MicroChip(
                        label: event.applicationMethod!.trim(),
                        color: const Color(0xFF0369A1),
                      ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _subtitleFromEvent(TrialApplicationEvent e) {
    final parts = <String>[];
    final op = e.operatorName?.trim();
    if (op != null && op.isNotEmpty) parts.add('Operator: $op');
    final eq = e.equipmentUsed?.trim();
    if (eq != null && eq.isNotEmpty) parts.add('Equipment: $eq');
    if (parts.isEmpty) return null;
    return parts.join(' • ');
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
    final appTimingCode = aam?.shellAppTimingCode;

    final m = aam;
    final detailParts = <String>[
      if (m != null) ...[
        if (m.seDescription != null &&
            m.seDescription!.trim().isNotEmpty &&
            m.seDescription!.trim() != name.trim())
          m.seDescription!,
        if (m.partRated != null && m.partRated!.isNotEmpty)
          'Part: ${m.partRated}',
        if (m.ratingUnit != null && m.ratingUnit!.isNotEmpty)
          'Unit: ${m.ratingUnit}',
        if (m.collectBasis != null && m.collectBasis!.isNotEmpty)
          'Collect: ${m.collectBasis}',
        if (m.shellSizeUnit != null && m.shellSizeUnit!.isNotEmpty)
          'Size unit: ${m.shellSizeUnit}',
        if (m.shellSampleSize != null && m.shellSampleSize!.isNotEmpty)
          'Sample size: ${m.shellSampleSize}',
        if (m.numSubsamples != null)
          '# subsamples: ${m.numSubsamples}',
        if (m.shellCollectionBasisUnit != null &&
            m.shellCollectionBasisUnit!.trim().isNotEmpty)
          'Coll. basis unit: ${m.shellCollectionBasisUnit}',
        if (m.shellCropOrPest != null && m.shellCropOrPest!.trim().isNotEmpty)
          'Crop/Pest: ${m.shellCropOrPest}',
        if (m.shellRatingTime != null && m.shellRatingTime!.trim().isNotEmpty)
          'Rating time: ${m.shellRatingTime}',
        if (m.shellPestType != null && m.shellPestType!.trim().isNotEmpty)
          'Pest type: ${m.shellPestType}',
        if (m.shellPestName != null && m.shellPestName!.trim().isNotEmpty)
          'Pest: ${m.shellPestName}',
        if (m.shellCropCode != null && m.shellCropCode!.trim().isNotEmpty ||
            m.shellCropName != null && m.shellCropName!.trim().isNotEmpty ||
            m.shellCropVariety != null &&
                m.shellCropVariety!.trim().isNotEmpty)
          [
            if (m.shellCropCode != null && m.shellCropCode!.trim().isNotEmpty)
              m.shellCropCode!,
            if (m.shellCropName != null && m.shellCropName!.trim().isNotEmpty)
              m.shellCropName!,
            if (m.shellCropVariety != null &&
                m.shellCropVariety!.trim().isNotEmpty)
              m.shellCropVariety!,
          ].join(' · '),
        if (m.shellReportingBasis != null &&
                m.shellReportingBasis!.trim().isNotEmpty ||
            m.shellReportingBasisUnit != null &&
                m.shellReportingBasisUnit!.trim().isNotEmpty)
          'Report: ${[
            if (m.shellReportingBasis != null &&
                m.shellReportingBasis!.trim().isNotEmpty)
              m.shellReportingBasis!,
            if (m.shellReportingBasisUnit != null &&
                m.shellReportingBasisUnit!.trim().isNotEmpty)
              m.shellReportingBasisUnit!,
          ].join(' ')}',
        if (m.shellStageScale != null && m.shellStageScale!.trim().isNotEmpty)
          'Stage scale: ${m.shellStageScale}',
        if (m.shellCropStageMaj != null && m.shellCropStageMaj!.isNotEmpty ||
            m.shellCropStageMin != null &&
                m.shellCropStageMin!.trim().isNotEmpty ||
            m.shellCropStageMax != null &&
                m.shellCropStageMax!.trim().isNotEmpty)
          'Crop stage: ${[
            if (m.shellCropStageMaj != null &&
                m.shellCropStageMaj!.trim().isNotEmpty)
              m.shellCropStageMaj!,
            if (m.shellCropStageMin != null &&
                m.shellCropStageMin!.trim().isNotEmpty)
              m.shellCropStageMin!,
            if (m.shellCropStageMax != null &&
                m.shellCropStageMax!.trim().isNotEmpty)
              m.shellCropStageMax!,
          ].join('–')}',
        if (m.shellCropDensity != null &&
                m.shellCropDensity!.trim().isNotEmpty ||
            m.shellCropDensityUnit != null &&
                m.shellCropDensityUnit!.trim().isNotEmpty)
          'Crop density: ${[
            if (m.shellCropDensity != null &&
                m.shellCropDensity!.trim().isNotEmpty)
              m.shellCropDensity!,
            if (m.shellCropDensityUnit != null &&
                m.shellCropDensityUnit!.trim().isNotEmpty)
              m.shellCropDensityUnit!,
          ].join(' ')}',
        if (m.shellPestStageMaj != null &&
                m.shellPestStageMaj!.trim().isNotEmpty ||
            m.shellPestStageMin != null &&
                m.shellPestStageMin!.trim().isNotEmpty ||
            m.shellPestStageMax != null &&
                m.shellPestStageMax!.trim().isNotEmpty)
          'Pest stage: ${[
            if (m.shellPestStageMaj != null &&
                m.shellPestStageMaj!.trim().isNotEmpty)
              m.shellPestStageMaj!,
            if (m.shellPestStageMin != null &&
                m.shellPestStageMin!.trim().isNotEmpty)
              m.shellPestStageMin!,
            if (m.shellPestStageMax != null &&
                m.shellPestStageMax!.trim().isNotEmpty)
              m.shellPestStageMax!,
          ].join('–')}',
        if (m.shellPestDensity != null &&
                m.shellPestDensity!.trim().isNotEmpty ||
            m.shellPestDensityUnit != null &&
                m.shellPestDensityUnit!.trim().isNotEmpty)
          'Pest density: ${[
            if (m.shellPestDensity != null &&
                m.shellPestDensity!.trim().isNotEmpty)
              m.shellPestDensity!,
            if (m.shellPestDensityUnit != null &&
                m.shellPestDensityUnit!.trim().isNotEmpty)
              m.shellPestDensityUnit!,
          ].join(' ')}',
        if (m.shellTrtEvalInterval != null &&
            m.shellTrtEvalInterval!.trim().isNotEmpty)
          'Trt interval: ${m.shellTrtEvalInterval}',
        if (m.shellPlantEvalInterval != null &&
            m.shellPlantEvalInterval!.trim().isNotEmpty)
          'Plant interval: ${m.shellPlantEvalInterval}',
        if (m.shellAssessedBy != null && m.shellAssessedBy!.isNotEmpty)
          'Assessed by: ${m.shellAssessedBy}',
        if (m.shellEquipment != null && m.shellEquipment!.isNotEmpty)
          'Equipment: ${m.shellEquipment}',
        if (m.shellUntreatedRatingType != null &&
            m.shellUntreatedRatingType!.trim().isNotEmpty)
          'Untrt. type: ${m.shellUntreatedRatingType}',
        if (m.shellArmActions != null && m.shellArmActions!.trim().isNotEmpty)
          'ARM actions: ${m.shellArmActions}',
      ],
    ];

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
                    if (appTimingCode != null &&
                        appTimingCode.trim().isNotEmpty)
                      _MicroChip(
                        label: appTimingCode,
                        color: const Color(0xFFB45309),
                      ),
                  ],
                ),
                if (detailParts.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    detailParts.join(' • '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ],
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
