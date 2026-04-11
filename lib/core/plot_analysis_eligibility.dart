import 'database/app_database.dart';

/// True when [p] counts toward analysis, statistics, completion, and export statistics.
///
/// Guard rows never count; researcher-excluded data plots remain in the field workflow
/// but are omitted from these aggregates.
bool isAnalyzablePlot(Plot p) =>
    !p.isGuardRow && p.excludeFromAnalysis != true;
