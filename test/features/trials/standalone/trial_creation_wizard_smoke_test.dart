import 'package:arm_field_companion/features/trials/standalone/create_standalone_trial_wizard_usecase.dart';
import 'package:arm_field_companion/features/trials/standalone/plot_generation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wizard input model includes plots per rep, guards, and physical fields', () {
    const input = CreateStandaloneTrialWizardInput(
      trialName: 'Model test',
      experimentalDesign: PlotGenerationEngine.designRcbd,
      treatments: [
        StandaloneWizardTreatmentInput(code: 'A'),
        StandaloneWizardTreatmentInput(code: 'B'),
      ],
      repCount: 3,
      plotsPerRep: 6,
      guardRowsPerRep: 2,
      plotLengthM: 10.0,
      plotWidthM: 3.0,
      alleyLengthM: 1.5,
      latitude: 44.0,
      longitude: -79.0,
      assessments: [],
    );
    expect(input.plotsPerRep, 6);
    expect(input.guardRowsPerRep, 2);
    expect(input.plotLengthM, 10.0);
    expect(input.plotWidthM, 3.0);
    expect(input.alleyLengthM, 1.5);
    expect(input.latitude, 44.0);
    expect(input.longitude, -79.0);
  });
}
