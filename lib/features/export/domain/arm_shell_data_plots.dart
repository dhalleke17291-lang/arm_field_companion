import '../../../core/database/app_database.dart';

/// Trial plots that participate in ARM Rating Shell matching and ARM shell
/// diagnostics: excludes [Plot.isGuardRow] (border / non-data plots).
List<Plot> armShellDataPlots(List<Plot> plots) {
  return plots.where((p) => !p.isGuardRow).toList();
}
