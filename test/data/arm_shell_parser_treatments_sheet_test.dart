// Phase 2a — ARM Treatments sheet parser ground truth.
//
// Verifies that [ArmShellParser] correctly reads the Treatments sheet
// (sheet 7) of the real `AgQuest_RatingShell.xlsx` fixture. Every
// expected value below is documented in
// `test/fixtures/arm_shells/README.md` ("Treatments sheet (sheet 7)
// map") — keep the two in sync.
//
// Slice 2a: parser only, no DB writes. Slice 2b wires these rows into
// [ImportArmRatingShellUseCase]; slice 2c renders them in the ARM
// Protocol tab.

import 'package:arm_field_companion/data/services/arm_shell_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixturePath = 'test/fixtures/arm_shells/AgQuest_RatingShell.xlsx';

void main() {
  group('ArmShellParser — Treatments sheet', () {
    test('parses all four treatment rows from AgQuest fixture', () async {
      final shell = await ArmShellParser(_fixturePath).parse();

      expect(shell.treatmentSheetRows, hasLength(4),
          reason:
              'AgQuest fixture has 4 treatments (RCBD, 4 treatments × 4 reps)');
    });

    test('CHK row (trt 1): name / formulation blank, type = CHK', () async {
      final shell = await ArmShellParser(_fixturePath).parse();
      final chk = shell.treatmentSheetRows.firstWhere((r) => r.trtNumber == 1);

      expect(chk.typeCode, 'CHK');
      expect(chk.rowIndex, 0);
      expect(chk.treatmentName, isNull,
          reason: 'CHK (untreated check) has blank name in AgQuest');
      expect(chk.formConc, isNull);
      expect(chk.formConcUnit, isNull);
      expect(chk.formType, isNull);
      expect(chk.rate, isNull);
      expect(chk.rateUnit, isNull);
    });

    test('FUNG row (trt 2): full product + formulation + rate', () async {
      final shell = await ArmShellParser(_fixturePath).parse();
      final fung = shell.treatmentSheetRows.firstWhere((r) => r.trtNumber == 2);

      expect(fung.typeCode, 'FUNG');
      expect(fung.rowIndex, 1);
      expect(fung.treatmentName, 'APRON');
      expect(fung.formConc, 25);
      expect(fung.formConcUnit, '%W/W',
          reason: 'Form Unit preserves ARM %W/W syntax verbatim');
      expect(fung.formType, 'W');
      expect(fung.rate, 5);
      expect(fung.rateUnit, '% w/v');
    });

    test('treatments are returned in sheet order (rowIndex strictly increases)',
        () async {
      final shell = await ArmShellParser(_fixturePath).parse();
      final rowIndices = shell.treatmentSheetRows.map((r) => r.rowIndex).toList();

      expect(rowIndices, equals(<int>[0, 1, 2, 3]),
          reason:
              'parser populates rowIndex from the sheet row position so '
              'Slice 2b can write it to ArmTreatmentMetadata.armRowSortOrder');
    });

    test('trt numbers are returned in sheet order (1, 2, 3, 4)', () async {
      final shell = await ArmShellParser(_fixturePath).parse();
      final trtNumbers =
          shell.treatmentSheetRows.map((r) => r.trtNumber).toList();

      expect(trtNumbers, equals(<int>[1, 2, 3, 4]));
    });

    test('Plot Data parse still works (regression guard on the original path)',
        () async {
      // The Treatments-sheet addition must not break the existing
      // Plot Data-only parse. If this fails, revisit _parseTreatmentsSheet's
      // error swallowing — it should never cascade into Plot Data parsing.
      final shell = await ArmShellParser(_fixturePath).parse();
      expect(shell.plotRows, isNotEmpty);
      expect(shell.assessmentColumns, hasLength(6),
          reason: 'AgQuest fixture has 6 assessment columns per README');
    });
  });
}
