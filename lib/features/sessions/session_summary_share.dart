import '../../core/database/app_database.dart';
import '../../core/plot_analysis_eligibility.dart';
import '../../domain/models/trial_insight.dart';
import '../sessions/session_timing_helper.dart';

/// Composes a plain-text session summary for sharing via system share sheet.
///
/// Format:
///   Trial 4 — Session 6 complete
///   14 DAT (Application 2, Apr 15) · BBCH 32
///   24/24 plots rated · Rater: J. Smith
///
///   Treatment means (WEED1):
///     CHK: 52%  T2: 72%  T3: 58%  T4: 79%
///
///   Crop injury: none observed
///   Weather: 22°C, 65% RH, 8 km/h SW
String composeSessionSummary({
  required Trial trial,
  required Session session,
  required List<Plot> plots,
  required List<Assessment> assessments,
  required List<RatingRecord> ratings,
  required List<Treatment> treatments,
  required List<Assignment> assignments,
  SessionTimingContext? timing,
  WeatherSnapshot? weather,
  List<TrialInsight>? insights,
}) {
  final buf = StringBuffer();

  // Header
  buf.writeln('${trial.name} — ${session.name} complete');

  // Timing line
  final timingParts = <String>[];
  if (timing != null && !timing.isEmpty) {
    timingParts.add(timing.displayLine);
  }
  if (timingParts.isNotEmpty) buf.writeln(timingParts.join(' · '));

  // Completion
  final dataPlots = plots.where(isAnalyzablePlot).toList();
  final ratedPlotPks = <int>{};
  for (final r in ratings) {
    if (r.isCurrent && r.resultStatus == 'RECORDED') {
      ratedPlotPks.add(r.plotPk);
    }
  }
  final completionParts = <String>[
    '${ratedPlotPks.length}/${dataPlots.length} plots rated',
  ];
  if (session.raterName != null && session.raterName!.trim().isNotEmpty) {
    completionParts.add('Rater: ${session.raterName}');
  }
  buf.writeln(completionParts.join(' · '));

  // Treatment means per assessment
  if (assessments.isNotEmpty && treatments.isNotEmpty) {
    final plotToTreatment = <int, int>{};
    for (final a in assignments) {
      if (a.treatmentId != null) plotToTreatment[a.plotId] = a.treatmentId!;
    }
    for (final p in dataPlots) {
      if (!plotToTreatment.containsKey(p.id) && p.treatmentId != null) {
        plotToTreatment[p.id] = p.treatmentId!;
      }
    }

    for (final assessment in assessments) {
      final byTreatment = <int, List<double>>{};
      for (final r in ratings) {
        if (r.assessmentId != assessment.id) continue;
        if (!r.isCurrent || r.resultStatus != 'RECORDED') continue;
        if (r.numericValue == null) continue;
        final tid = plotToTreatment[r.plotPk];
        if (tid == null) continue;
        byTreatment.putIfAbsent(tid, () => []).add(r.numericValue!);
      }
      if (byTreatment.isEmpty) continue;

      final assessmentName = assessment.name.contains('—')
          ? assessment.name.split('—').first.trim()
          : assessment.name;
      buf.writeln();
      buf.writeln('Treatment means ($assessmentName):');
      final sortedTreatments = treatments.toList()
        ..sort((a, b) => a.code.compareTo(b.code));
      final parts = <String>[];
      for (final t in sortedTreatments) {
        final vals = byTreatment[t.id];
        if (vals == null || vals.isEmpty) continue;
        final mean = vals.reduce((a, b) => a + b) / vals.length;
        parts.add('${t.code}: ${mean.round()}%');
      }
      buf.writeln('  ${parts.join('  ')}');
    }
  }

  // Crop injury
  if (session.cropInjuryStatus != null) {
    buf.writeln();
    final status = switch (session.cropInjuryStatus) {
      'none_observed' => 'none observed',
      'symptoms_observed' => 'symptoms observed',
      'not_assessed' => 'not assessed',
      _ => session.cropInjuryStatus!,
    };
    buf.write('Crop injury: $status');
    if (session.cropInjuryNotes != null &&
        session.cropInjuryNotes!.trim().isNotEmpty) {
      buf.write(' — ${session.cropInjuryNotes}');
    }
    buf.writeln();
  }

  // Weather
  if (weather != null) {
    final parts = <String>[];
    if (weather.temperature != null) {
      final unit = weather.temperatureUnit == 'F' ? '°F' : '°C';
      parts.add('${weather.temperature!.round()}$unit');
    }
    if (weather.humidity != null) parts.add('${weather.humidity!.round()}% RH');
    if (weather.windSpeed != null) {
      final windStr = '${weather.windSpeed!.round()} ${weather.windSpeedUnit}';
      if (weather.windDirection != null) {
        parts.add('$windStr ${weather.windDirection}');
      } else {
        parts.add(windStr);
      }
    }
    if (weather.cloudCover != null) parts.add(weather.cloudCover!);
    if (parts.isNotEmpty) {
      buf.writeln('Weather: ${parts.join(', ')}');
    }
  }

  // Top insight (if available)
  if (insights != null && insights.isNotEmpty) {
    final top = insights.first;
    buf.writeln();
    buf.writeln('${top.title}: ${top.detail}');
  }

  return buf.toString().trimRight();
}
