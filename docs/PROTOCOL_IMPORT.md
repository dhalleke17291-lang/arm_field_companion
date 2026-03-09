# Protocol import

Protocol import brings trial structure from CSV files into the app.

## What gets imported

- **Trial** — name, crop, location, season (from section TRIAL)
- **Treatments** — code, name, description (from section TREATMENT)
- **Plots** — plot_id, rep, row, column, plot_sort_index, treatment_code (from section PLOT)
- **Assignments** — plot rows reference treatment_code to assign treatments to plots

CSV must have a `section` column with values TRIAL, TREATMENT, or PLOT. See [protocol_import_models.dart](../lib/features/protocol_import/protocol_import_models.dart) for constants and review/execute result types.

## Flow

1. User selects a CSV file (e.g. from Import Protocol or similar entry point).
2. App parses and validates sections, producing a [ProtocolImportReviewResult].
3. User reviews and confirms; app executes import ([ProtocolImportExecuteResult]) and writes to trials, treatments, and plots tables.

## Operational data (future)

If protocol import is extended to include seeding or application plans, those can be stored in `audit_events` with `eventType` and JSON `metadata`. Helpers in [audit_metadata.dart](../lib/core/audit_metadata.dart) support source labels (Prefilled from Protocol / Manual / Recorded) and marking as recorded.

## References

- Import models: `lib/features/protocol_import/protocol_import_models.dart`
- Use case: `lib/features/protocol_import/protocol_import_usecase.dart`
- UI: `lib/features/protocol_import/protocol_import_screen.dart`
