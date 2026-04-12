Stress-test CSV scenarios for ARM import/export.

Tests live under test/stress/ and build CSV strings in Dart (no runtime dependency on these files).
The large 200-plot matrix is generated in test/stress/csv_import_stress_test.dart.

Optional mirrors (for human review / diff tools):
  - minimal_trial.csv — two plots, one assessment
  - count_assessment.csv — CNTLIV integer column

UTF-8 BOM: ArmImportUseCase strips a leading UTF-8 BOM before parsing (Excel-on-Windows exports).
