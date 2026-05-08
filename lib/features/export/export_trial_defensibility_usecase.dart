import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/pdf_branding.dart';
import '../../core/providers.dart';
import '../../domain/signals/signal_providers.dart';
import '../derived/domain/trial_statistics.dart';
import 'trial_defensibility_pdf_builder.dart';

class ExportTrialDefensibilityUseCase {
  ExportTrialDefensibilityUseCase(this._ref);

  final Ref _ref;

  Future<void> execute({required Trial trial}) async {
    final purpose = await _ref.read(trialPurposeProvider(trial.id).future);
    final evidenceArc =
        await _ref.read(trialEvidenceArcProvider(trial.id).future);
    final ctq =
        await _ref.read(trialCriticalToQualityProvider(trial.id).future);
    final coherence = await _ref.read(trialCoherenceProvider(trial.id).future);
    final interpretationRisk =
        await _ref.read(trialInterpretationRiskProvider(trial.id).future);
    final decisionSummary =
        await _ref.read(trialDecisionSummaryProvider(trial.id).future);
    final openSignals =
        await _ref.read(openSignalsForTrialProvider(trial.id).future);
    final environmentalSummary =
        await _ref.read(trialEnvironmentalSummaryProvider(trial.id).future);
    final amendmentCount =
        await _ref.read(amendedRatingCountForTrialProvider(trial.id).future);
    final assessmentStats = await _computeAssessmentStats(trial);
    final logo = await PdfBranding.loadLogo();

    final builder = TrialDefensibilityPdfBuilder(
      trial: trial,
      purpose: purpose,
      evidenceArc: evidenceArc,
      ctq: ctq,
      coherence: coherence,
      interpretationRisk: interpretationRisk,
      decisionSummary: decisionSummary,
      openSignals: openSignals,
      environmentalSummary: environmentalSummary,
      assessmentStats: assessmentStats,
      amendmentCount: amendmentCount,
      generatedAt: DateTime.now(),
      logo: logo,
    );
    final bytes = await builder.build();

    final dir = await getTemporaryDirectory();
    final safeName = trial.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/Defensibility_${safeName}_$timestamp.pdf');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: '${trial.name} — Trial Defensibility Summary',
    );
  }

  Future<List<AssessmentStatistics>> _computeAssessmentStats(
      Trial trial) async {
    final statsByAssessment =
        await _ref.read(trialAssessmentStatisticsProvider(trial.id).future);
    final stats = <AssessmentStatistics>[];
    for (final entries in statsByAssessment.values) {
      stats.addAll(entries);
    }
    stats.sort((a, b) {
      final byName =
          a.progress.assessmentName.compareTo(b.progress.assessmentName);
      if (byName != 0) return byName;
      final ad = a.sessionDate ?? '';
      final bd = b.sessionDate ?? '';
      return ad.compareTo(bd);
    });
    return stats;
  }
}
