import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/diagnostics/diagnostic_finding.dart';
import '../../core/providers.dart';

import 'usecases/arm_export_preflight_usecase.dart';

/// Full-screen ARM Rating Shell pre-export trust summary and export action.
class ArmExportPreflightScreen extends ConsumerStatefulWidget {
  const ArmExportPreflightScreen({super.key, required this.trial});

  final Trial trial;

  @override
  ConsumerState<ArmExportPreflightScreen> createState() =>
      _ArmExportPreflightScreenState();
}

class _ArmExportPreflightScreenState
    extends ConsumerState<ArmExportPreflightScreen> {
  bool _exportBusy = false;
  String? _exportError;

  Future<void> _runExport() async {
    setState(() {
      _exportBusy = true;
      _exportError = null;
    });
    try {
      final useCase = ref.read(exportArmRatingShellUseCaseProvider);
      final result = await useCase.execute(
        trial: widget.trial,
        suppressShare: true,
      );
      if (!mounted) return;
      if (!result.success) {
        setState(() {
          _exportBusy = false;
          _exportError = result.errorMessage ?? 'Export failed';
        });
        return;
      }
      final path = result.filePath;
      if (path == null) {
        setState(() {
          _exportBusy = false;
          _exportError = 'Export failed: missing file path';
        });
        return;
      }
      setState(() => _exportBusy = false);
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [
          XFile(path),
        ],
        text: '${widget.trial.name} – ARM Rating Shell',
        sharePositionOrigin: box == null
            ? const Rect.fromLTWH(0, 0, 100, 100)
            : box.localToGlobal(Offset.zero) & box.size,
      );
      if (!mounted) return;
      final warn = result.warningMessage?.trim();
      Navigator.pop(context, warn ?? '');
    } catch (e) {
      if (mounted) {
        setState(() {
          _exportBusy = false;
          _exportError = 'Export failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncPreflight =
        ref.watch(armExportPreflightFutureProvider(widget.trial.id));

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.primary,
        foregroundColor: AppDesignTokens.onPrimary,
        title: Text(
          'ARM Rating Shell Export',
          style: AppDesignTokens.headerTitleStyle(
            fontSize: 18,
            color: AppDesignTokens.onPrimary,
          ),
        ),
      ),
      body: Stack(
        children: [
          asyncPreflight.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDesignTokens.spacing24),
                child: Text(
                  'Could not load preflight: $e',
                  style: AppDesignTokens.bodyStyle(
                    color: AppDesignTokens.warningFg,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (preflight) => _PreflightBody(
              trial: widget.trial,
              preflight: preflight,
              exportError: _exportError,
              onExport: _runExport,
              onExportAnyway: _runExport,
            ),
          ),
          if (_exportBusy)
            ColoredBox(
              color: AppDesignTokens.primaryText.withValues(alpha: 0.35),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _PreflightBody extends StatelessWidget {
  const _PreflightBody({
    required this.trial,
    required this.preflight,
    required this.exportError,
    required this.onExport,
    required this.onExportAnyway,
  });

  final Trial trial;
  final ArmExportPreflight preflight;
  final String? exportError;
  final VoidCallback onExport;
  final VoidCallback onExportAnyway;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final s = preflight.summary;
    final plotProgress =
        s.totalPlots <= 0 ? 0.0 : s.ratedPlots / s.totalPlots;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDesignTokens.spacing16,
              AppDesignTokens.spacing16,
              AppDesignTokens.spacing16,
              AppDesignTokens.spacing8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  trial.name,
                  style: AppDesignTokens.headingStyle(
                    fontSize: 17,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
                const SizedBox(height: AppDesignTokens.spacing4),
                Text(
                  'Session: ${s.sessionName}'
                  '${s.sessionDate != null && s.sessionDate!.isNotEmpty ? ' · ${s.sessionDate}' : ''}',
                  style: AppDesignTokens.bodyCrispStyle(
                    fontSize: 14,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
                const SizedBox(height: AppDesignTokens.spacing20),
                _CardChrome(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data summary',
                        style: AppDesignTokens.headingStyle(
                          color: AppDesignTokens.primaryText,
                        ),
                      ),
                      const SizedBox(height: AppDesignTokens.spacing12),
                      Text(
                        'Plots: ${s.ratedPlots} of ${s.totalPlots} rated'
                        '${s.unratedPlots > 0 ? ' (${s.unratedPlots} unrated)' : ''}',
                        style: AppDesignTokens.bodyStyle(
                          color: AppDesignTokens.primaryText,
                        ),
                      ),
                      const SizedBox(height: AppDesignTokens.spacing8),
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppDesignTokens.radiusSmall),
                        child: LinearProgressIndicator(
                          value: plotProgress.clamp(0.0, 1.0),
                          minHeight: AppDesignTokens.spacing8,
                          backgroundColor: AppDesignTokens.divider,
                          color: AppDesignTokens.primary,
                        ),
                      ),
                      const SizedBox(height: AppDesignTokens.spacing16),
                      Text(
                        'Assessments: ${s.totalAssessments}',
                        style: AppDesignTokens.bodyStyle(
                          color: AppDesignTokens.primaryText,
                        ),
                      ),
                      const SizedBox(height: AppDesignTokens.spacing8),
                      Text(
                        'Total ratings (shell session): ${s.totalRatings}',
                        style: AppDesignTokens.bodyStyle(
                          color: AppDesignTokens.primaryText,
                        ),
                      ),
                      const SizedBox(height: AppDesignTokens.spacing12),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  'Corrected: ${s.correctedRatings}',
                                  style: AppDesignTokens.bodyStyle(
                                    color: AppDesignTokens.primaryText,
                                  ),
                                ),
                                const SizedBox(
                                    width: AppDesignTokens.spacing4),
                                const Tooltip(
                                  message:
                                      'Corrected values will be exported (effective values after correction).',
                                  child: Icon(
                                    Icons.info_outline,
                                    size: AppDesignTokens.spacing20,
                                    color: AppDesignTokens.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDesignTokens.spacing8),
                      Row(
                        children: [
                          Text(
                            'Voided: ${s.voidedRatings}',
                            style: AppDesignTokens.bodyStyle(
                              color: AppDesignTokens.primaryText,
                            ),
                          ),
                          const SizedBox(width: AppDesignTokens.spacing4),
                          const Tooltip(
                            message:
                                'Voided ratings export as empty cells in the shell.',
                            child: Icon(
                              Icons.info_outline,
                              size: AppDesignTokens.spacing20,
                              color: AppDesignTokens.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDesignTokens.spacing16),
                Text(
                  'Quality status',
                  style: AppDesignTokens.headingStyle(
                    fontSize: 16,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
                const SizedBox(height: AppDesignTokens.spacing8),
                if (exportError != null) ...[
                  _CardChrome(
                    background: AppDesignTokens.warningBg,
                    borderColor: AppDesignTokens.warningBorder,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppDesignTokens.missedColor,
                        ),
                        const SizedBox(width: AppDesignTokens.spacing12),
                        Expanded(
                          child: Text(
                            exportError!,
                            style: AppDesignTokens.bodyStyle(
                              color: AppDesignTokens.warningFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDesignTokens.spacing12),
                ],
                if (preflight.blockers.isNotEmpty)
                  _FindingSection(
                    title:
                        'Blockers (${preflight.blockerCount})',
                    titleColor: AppDesignTokens.missedColor,
                    background: AppDesignTokens.missedColor.withValues(
                        alpha: 0.08),
                    borderColor: AppDesignTokens.missedColor.withValues(
                        alpha: 0.35),
                    findings: preflight.blockers,
                    showBadge: true,
                  ),
                if (preflight.warnings.isNotEmpty) ...[
                  const SizedBox(height: AppDesignTokens.spacing12),
                  _FindingSection(
                    title: 'Warnings (${preflight.warningCount})',
                    titleColor: AppDesignTokens.warningFg,
                    background: AppDesignTokens.warningBg,
                    borderColor: AppDesignTokens.warningBorder,
                    findings: preflight.warnings,
                    showBadge: false,
                  ),
                ],
                if (preflight.infos.isNotEmpty) ...[
                  const SizedBox(height: AppDesignTokens.spacing12),
                  _FindingSection(
                    title: 'Info (${preflight.infos.length})',
                    titleColor: AppDesignTokens.secondaryText,
                    background: AppDesignTokens.softBlueAccent,
                    borderColor: AppDesignTokens.divider,
                    findings: preflight.infos,
                    showBadge: false,
                  ),
                ],
                if (preflight.blockers.isEmpty &&
                    preflight.warnings.isEmpty &&
                    preflight.infos.isEmpty)
                  _CardChrome(
                    background: AppDesignTokens.successBg,
                    borderColor: AppDesignTokens.successFg.withValues(alpha: 0.35),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: AppDesignTokens.successFg,
                          size: AppDesignTokens.spacing24,
                        ),
                        const SizedBox(width: AppDesignTokens.spacing12),
                        Expanded(
                          child: Text(
                            'Ready to export',
                            style: AppDesignTokens.headingStyle(
                              color: AppDesignTokens.successFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppDesignTokens.spacing16,
            AppDesignTokens.spacing8,
            AppDesignTokens.spacing16,
            AppDesignTokens.spacing16 + bottom,
          ),
          child: _ActionBar(
            canExport: preflight.canExport,
            hasWarnings: preflight.warningCount > 0,
            onBack: () => Navigator.pop(context),
            onExport: onExport,
            onExportAnyway: onExportAnyway,
          ),
        ),
      ],
    );
  }
}

class _CardChrome extends StatelessWidget {
  const _CardChrome({
    required this.child,
    this.background = AppDesignTokens.cardSurface,
    this.borderColor = AppDesignTokens.borderCrisp,
  });

  final Widget child;
  final Color background;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: borderColor, width: AppDesignTokens.borderWidthCrisp),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignTokens.spacing16),
        child: child,
      ),
    );
  }
}

class _FindingSection extends StatelessWidget {
  const _FindingSection({
    required this.title,
    required this.titleColor,
    required this.background,
    required this.borderColor,
    required this.findings,
    required this.showBadge,
  });

  final String title;
  final Color titleColor;
  final Color background;
  final Color borderColor;
  final List<DiagnosticFinding> findings;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return _CardChrome(
      background: background,
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppDesignTokens.headingStyle(
              color: titleColor,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing12),
          ...findings.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      f.severity == DiagnosticSeverity.blocker
                          ? Icons.block
                          : f.severity == DiagnosticSeverity.warning
                              ? Icons.warning_amber_outlined
                              : Icons.info_outline,
                      size: AppDesignTokens.spacing20,
                      color: titleColor,
                    ),
                    const SizedBox(width: AppDesignTokens.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showBadge)
                            Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppDesignTokens.spacing4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDesignTokens.spacing8,
                                  vertical: AppDesignTokens.spacing4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppDesignTokens.missedColor
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                      AppDesignTokens.radiusChip),
                                ),
                                child: Text(
                                  'Blocker',
                                  style: AppDesignTokens.headingStyle(
                                    fontSize: 11,
                                    color: AppDesignTokens.missedColor,
                                  ),
                                ),
                              ),
                            ),
                          Text(
                            f.message,
                            style: AppDesignTokens.bodyStyle(
                              color: AppDesignTokens.primaryText,
                            ),
                          ),
                          if (f.detail != null &&
                              f.detail!.trim().isNotEmpty) ...[
                            const SizedBox(height: AppDesignTokens.spacing4),
                            Text(
                              f.detail!,
                              style: AppDesignTokens.bodyStyle(
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
              )),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.canExport,
    required this.hasWarnings,
    required this.onBack,
    required this.onExport,
    required this.onExportAnyway,
  });

  final bool canExport;
  final bool hasWarnings;
  final VoidCallback onBack;
  final VoidCallback onExport;
  final VoidCallback onExportAnyway;

  @override
  Widget build(BuildContext context) {
    if (!canExport) {
      return FilledButton.tonal(
        onPressed: onBack,
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
        ),
        child: const Text('Back'),
      );
    }
    if (hasWarnings) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: onExportAnyway,
            style: FilledButton.styleFrom(
              backgroundColor: AppDesignTokens.primary,
              foregroundColor: AppDesignTokens.onPrimary,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Export Anyway'),
          ),
          const SizedBox(height: AppDesignTokens.spacing8),
          OutlinedButton(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Back'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: onExport,
          style: FilledButton.styleFrom(
            backgroundColor: AppDesignTokens.primary,
            foregroundColor: AppDesignTokens.onPrimary,
            minimumSize: const Size(double.infinity, 48),
          ),
          child: const Text('Export'),
        ),
        const SizedBox(height: AppDesignTokens.spacing8),
        OutlinedButton(
          onPressed: onBack,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          child: const Text('Back'),
        ),
      ],
    );
  }
}
