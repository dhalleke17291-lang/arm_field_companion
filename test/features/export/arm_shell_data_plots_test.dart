import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/export/domain/arm_shell_data_plots.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('armShellDataPlots excludes guard rows', () {
    const data = Plot(
      id: 1,
      trialId: 1,
      plotId: '101',
      isGuardRow: false,
      isDeleted: false,
      excludeFromAnalysis: false,
    );
    const guard = Plot(
      id: 2,
      trialId: 1,
      plotId: 'G1-L',
      isGuardRow: true,
      isDeleted: false,
      excludeFromAnalysis: false,
    );
    expect(armShellDataPlots([data, guard]), [data]);
    expect(armShellDataPlots([guard]), isEmpty);
  });
}
