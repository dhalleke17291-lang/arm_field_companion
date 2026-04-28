# Derived-State Investigation — Three High-Risk Columns

**Date:** 2026-04-27  
**Scope:** Three columns flagged in SCHEMA_AUDIT.md as highest-risk derived-state candidates.  
**Method:** Full read/write trace of every production `.dart` file for each column; no modifications made.

---

## Column 1 — `exportConfidence` on `compatibility_profiles`

### a. Exact Drift column definition

**File:** [lib/core/database/app_database.dart](../../lib/core/database/app_database.dart#L839)

```dart
// line 839
TextColumn get exportConfidence => text()();
```

Required (NOT NULL), no default. Stores the serialized `.name` of the `ImportConfidence` enum: one of `'high'`, `'medium'`, `'low'`, or `'blocked'`.

---

### b. Every write location

**1.** [lib/features/arm_import/data/arm_import_persistence_repository.dart:106](../../lib/features/arm_import/data/arm_import_persistence_repository.dart#L106)  
Written once per ARM import inside `insertCompatibilityProfile()`:

```dart
exportConfidence: payload.exportConfidence.name,
```

`payload.exportConfidence` is an `ImportConfidence` enum value. `.name` serializes it to a string. This is the only write path — there are no UPDATE statements for this column.

---

### c. Every read location

**1.** [lib/features/arm_import/data/arm_import_persistence_repository.dart:46](../../lib/features/arm_import/data/arm_import_persistence_repository.dart#L46)  
Convenience reader used internally:

```dart
Future<String?> getLatestExportConfidenceForTrial(int trialId) async {
  final row = await getLatestCompatibilityProfileForTrial(trialId);
  return row?.exportConfidence;
}
```

**2.** [lib/features/export/usecases/arm_export_preflight_usecase.dart:170](../../lib/features/export/usecases/arm_export_preflight_usecase.dart#L170)  
Used to generate a blocker or warning finding in the preflight report:

```dart
final gate = gateFromConfidence(profile?.exportConfidence);
```

**3.** [lib/features/export/domain/export_arm_rating_shell_usecase.dart:134](../../lib/features/export/domain/export_arm_rating_shell_usecase.dart#L134)  
Hard gate at the start of ARM Rating Shell export:

```dart
final gate = gateFromConfidence(profile?.exportConfidence);
if (gate == ExportGate.block) { ... return ArmRatingShellResult.failure(msg); }
```

**4.** [lib/features/export/domain/export_arm_rating_shell_usecase.dart:551](../../lib/features/export/domain/export_arm_rating_shell_usecase.dart#L551)  
Passed to the Phase 3 positional-fallback block decision:

```dart
final deterministic = deterministicAssessmentAnchorsExpectedForShellExport(
  assessmentAnchoredFlags: [...],
  latestProfileExportConfidence: profile?.exportConfidence,
);
```

**5.** [lib/features/export/export_trial_usecase.dart:301](../../lib/features/export/export_trial_usecase.dart#L301)  
Hard gate for CSV/JSON export:

```dart
final gate = gateFromConfidence(profile?.exportConfidence);
if (gate == ExportGate.block) { ... throw ExportBlockedByConfidenceException(msg); }
```

**6.** [lib/features/export/export_trial_pdf_report_usecase.dart:57](../../lib/features/export/export_trial_pdf_report_usecase.dart#L57)  
Hard gate for PDF report export:

```dart
final gate = gateFromConfidence(profile?.exportConfidence);
if (gate == ExportGate.block) { throw ExportBlockedByConfidenceException(msg); }
```

---

### d. Computation logic before storage

Computed in `ArmCsvParser._scoreConfidence()`:

**File:** [lib/features/arm_import/data/arm_csv_parser.dart:382–407](../../lib/features/arm_import/data/arm_csv_parser.dart#L382)

```dart
ImportConfidence _scoreConfidence(flags, columns) {
  final hasIdentityFields = columns.any(plotNumber) &&
      columns.any(treatmentNumber) && columns.any(rep);

  if (!hasIdentityFields) return ImportConfidence.blocked;

  final hasExportBlocking = flags.any(f => f.affectsExport && f.severity == high);
  if (hasExportBlocking) return ImportConfidence.blocked;

  final hasHighFlags = flags.any(f => f.severity == high);
  if (hasHighFlags) return ImportConfidence.low;

  final hasMediumFlags = flags.any(f => f.severity == medium);
  if (hasMediumFlags) return ImportConfidence.medium;

  final hasAnyExportConcern = flags.any(f => f.affectsExport);
  if (hasAnyExportConcern) return ImportConfidence.medium;

  return ImportConfidence.high;
}
```

Inputs are the `UnknownPatternFlag` list and `ArmColumnClassification` list — both computed from the raw CSV during `ArmCsvParser.parse()` and discarded after import. The CSV itself is not stored.

---

### e. Gates any behavior?

**Yes — all four export paths are hard-gated by this value.**

`gateFromConfidence()` ([lib/features/export/export_confidence_policy.dart:10](../../lib/features/export/export_confidence_policy.dart#L10)):

| Stored value | `ExportGate` | Effect |
|---|---|---|
| `'blocked'` | `block` | Immediate abort on all export paths; no output produced |
| `'low'` | `warn` | Warning shown but export continues |
| `'medium'` / `'high'` / null | `allow` | Export proceeds silently |

Additionally, when `exportConfidence == 'high'` and every `TrialAssessment` has an `armImportColumnIndex`, Phase 3 positional fallback is promoted from a warning to a hard block.

---

### f. Alternative source of truth?

Partially available: `ImportSnapshot.unknownPatterns` (JSON) stores the `UnknownPatternFlag` list (type, severity, affectsExport). In principle, `_scoreConfidence()` could be re-run on those. However:

1. The `ArmColumnClassification` list (needed for the `hasIdentityFields` check) is **not stored** in structured form — only `identityColumns` (a list of header strings) is persisted, which is insufficient to reconstruct the full classification.
2. The raw CSV is discarded after import; no re-parse is possible.
3. Recomputing from JSON would require deserializing `unknownPatterns` and re-applying the scoring algorithm — fragile under any future logic change, and would produce different results for old snapshots.

There is no safe, complete alternative.

---

### g. Assessment: **DEFENSIBLE STORED FACT — should stay**

`exportConfidence` captures the quality assessment made at import time against a CSV that is subsequently discarded. It is written once (at import) and read many times (on every export attempt). It cannot be re-derived without loss of fidelity. This is an event-sourced property, not redundant derived state.

**Recommendation:** Keep. Add a code comment on the column explaining it is the confidence score evaluated at CSV parse time and not recomputable after import. No migration needed.

---

---

## Column 2 — `plotsTreated` on `trial_application_events`

### a. Exact Drift column definition

**File:** [lib/core/database/app_database.dart](../../lib/core/database/app_database.dart#L734)

```dart
// line 734
TextColumn get plotsTreated => text().nullable()();
```

Nullable TEXT. Stores a comma-separated string of plot label values, e.g. `"1, 2, 5"`.

The schema comment immediately below the table (lines 786–788) reads:

> Replaces the comma-separated `TrialApplicationEvents.plotsTreated` TEXT field for structured queries. The TEXT field is kept as a denormalized cache alongside this table during the transition period.

---

### b. Every write location

**1.** [lib/features/trials/tabs/application_sheet_content.dart:758–760](../../lib/features/trials/tabs/application_sheet_content.dart#L758)  
INSERT companion inside `_buildCompanion()`:

```dart
final plotsTreatedStr =
    _selectedPlotLabels.isEmpty ? null : _selectedPlotLabels.join(', ');
// ...
plotsTreated: drift.Value(plotsTreatedStr),  // line 800
```

**2.** [lib/features/trials/tabs/application_sheet_content.dart:844](../../lib/features/trials/tabs/application_sheet_content.dart#L844)  
Same in the UPDATE companion branch of `_buildCompanion()`:

```dart
plotsTreated: drift.Value(plotsTreatedStr),
```

**3.** [lib/data/repositories/application_repository.dart:482–484](../../lib/data/repositories/application_repository.dart#L482)  
`_withNewFields()` in `ApplicationRepository` passes the companion's value through unchanged (passthrough, not a computation):

```dart
plotsTreated: c.plotsTreated.present
    ? Value(c.plotsTreated.value)
    : const Value.absent(),
```

**4.** Migration v55 — [lib/core/database/app_database.dart:2060–2097](../../lib/core/database/app_database.dart#L2060)  
One-time data migration at schema upgrade: reads existing `plots_treated` TEXT rows and backfills them into `ApplicationPlotAssignments` junction rows. Not a live write path.

---

### c. Every read location

**1.** [lib/features/trials/tabs/application_sheet_content.dart:236–242](../../lib/features/trials/tabs/application_sheet_content.dart#L236)  
Populates `_selectedPlotLabels` (a `Set<String>`) when loading an existing event into the form:

```dart
_selectedPlotLabels =
    e?.plotsTreated != null && e!.plotsTreated!.trim().isNotEmpty
        ? e.plotsTreated!
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
        : {};
```

**2.** [lib/features/trials/tabs/application_sheet_content.dart:243](../../lib/features/trials/tabs/application_sheet_content.dart#L243)  
Controls whether the "coverage" section is shown expanded on form load:

```dart
_initialExpandedCoverage = _trim(e?.growthStageCode) != null ||
    _selectedPlotLabels.isNotEmpty || ...;
```

These are the only two read locations. The field is not consumed by any export, report, analytics, or attention-service path.

---

### d. Exact computation logic before storage

```dart
final plotsTreatedStr =
    _selectedPlotLabels.isEmpty ? null : _selectedPlotLabels.join(', ');
```

`_selectedPlotLabels` is a `Set<String>` of display labels the user has checked in the plot multi-selector. There is no independent computation — this is a direct serialization of the user-selected set to a denormalized string.

---

### e. Gates any behavior?

**No.** The value is read only for form initialization. It does not control any workflow, export, or validation path.

---

### f. Alternative source of truth?

**Yes — `ApplicationPlotAssignments` junction table** (`application_plot_assignments`).  
Introduced in schema migration v55 specifically to replace this column. Every save since v55 writes to **both** the TEXT column and the junction table:

```dart
// application_sheet_content.dart:730–741
// Dual-write: persist plot selections to junction table alongside TEXT.
final plotAssignmentRepo =
    ref.read(applicationPlotAssignmentRepositoryProvider);
// ...
await plotAssignmentRepo.saveForEvent(eventId, plotSelections);
```

`ApplicationPlotAssignmentRepository.getForEvent(applicationEventId)` returns `List<ApplicationPlotAssignment>` with structured `plotLabel` and `plotId` fields — a complete, queryable replacement for the TEXT field.

The junction table comment at [lib/data/repositories/application_plot_assignment_repository.dart:22](../../lib/data/repositories/application_plot_assignment_repository.dart#L22) confirms: "Called alongside the existing plotsTreated TEXT write."

---

### g. Assessment: **GENUINE DERIVED STATE / TRANSITIONAL CACHE — migration target**

`plotsTreated` is a denormalized TEXT cache explicitly documented as transitional. The junction table `ApplicationPlotAssignments` is its canonical structured replacement. The TEXT column's only production role is initializing UI state — a role that the junction table can serve equally well. The dual-write is already in place; only the read path in `_initializeFormState()` still uses the TEXT field.

---

---

## Column 3 — `hasSparseData` on `import_snapshots`

### a. Exact Drift column definition

**File:** [lib/core/database/app_database.dart](../../lib/core/database/app_database.dart#L818)

```dart
// line 818
BoolColumn get hasSparseData => boolean().withDefault(const Constant(false))();
```

BOOLEAN NOT NULL, default `false`. Part of the `ImportSnapshots` table alongside the sibling flags `hasSubsamples`, `hasMultiApplication`, and `hasRepeatedCodes`.

---

### b. Every write location

**1.** [lib/features/arm_import/data/arm_import_persistence_repository.dart:78](../../lib/features/arm_import/data/arm_import_persistence_repository.dart#L78)  
Written once per import in `insertImportSnapshot()`:

```dart
hasSparseData: Value(payload.hasSparseData),
```

`payload` is an `ImportSnapshotPayload`, itself populated from `ParsedArmCsv.hasSparseData` in `ArmImportSnapshotService.buildSnapshot()` ([lib/features/arm_import/data/arm_import_snapshot_service.dart:116](../../lib/features/arm_import/data/arm_import_snapshot_service.dart#L116)):

```dart
hasSparseData: parsed.hasSparseData,
```

There are no UPDATE paths for this column. It is written once, at import time.

---

### c. Every read location

**From the database: none.**

The only consumer of `hasSparseData` in production code is `ArmImportReportBuilder.build()`:

**File:** [lib/features/arm_import/data/arm_import_report_builder.dart:22](../../lib/features/arm_import/data/arm_import_report_builder.dart#L22)

```dart
if (parsed.hasSparseData) {
  warnings.add(
    'Some assessment values are blank and were imported as null.',
  );
}
```

This reads from `parsed` — a `ParsedArmCsv` in-memory object, **not** from any DB row. The report builder is called during the import flow, immediately after parsing and before persistence. It never queries the `ImportSnapshots` table.

No production code reads `ImportSnapshot.hasSparseData` (the stored DB value) anywhere in the codebase. All reads are through the in-memory `ParsedArmCsv.hasSparseData` field on the transient parsed object.

The `ImportSnapshot` DB row is read in two places in production:
- `ArmImportPersistenceRepository` (checksum dedup queries) — never accesses `hasSparseData`
- `ExportArmRatingShellUseCase` (line 226–229) — reads the row to access `assessmentTokens` and `columnOrderOnExport` only; `hasSparseData` is not touched

---

### d. Exact computation logic before storage

Computed in `ArmCsvParser._detectSparseData()`:

**File:** [lib/features/arm_import/data/arm_csv_parser.dart:315–331](../../lib/features/arm_import/data/arm_csv_parser.dart#L315)

```dart
bool _detectSparseData(rows, columns) {
  final assessmentCols = columns
      .where((c) => c.kind == ArmColumnKind.assessment)
      .toList();

  for (final row in rows) {
    for (final col in assessmentCols) {
      final v = row[armImportDataRowKeyForColumnIndex(col.index)];
      if (v == null) return true;   // any null cell → sparse
    }
  }
  return false;
}
```

Returns `true` if **any** assessment cell across **any** data row is null. Inputs are the full parsed data rows (individual cell values) and column classification list — neither is retained after import.

---

### e. Gates any behavior?

**No.** The stored DB value is never read by production code, so it gates nothing. The in-memory read in `ArmImportReportBuilder` generates an informational warning message during import UI; it does not block any action.

---

### f. Alternative source of truth?

**No.** Sparse detection requires examining individual cell values across all assessment columns. This cell-level data is not stored after import — only aggregate counts (`assessmentCount`, `plotCount`, `treatmentCount`) and column/token metadata are persisted. The raw CSV is discarded; `rawFileChecksum` identifies the file but does not allow recomputation.

Unlike `exportConfidence`, where the scoring inputs (`unknownPatterns`) are partially preserved in JSON, there is no stored artifact from which `hasSparseData` could be reconstructed.

---

### g. Assessment: **DEFENSIBLE STORED FACT — should stay, but currently write-only from the DB**

`hasSparseData` is a valid import-time provenance property, consistent in pattern with its three sibling boolean flags on `ImportSnapshots` (`hasSubsamples`, `hasMultiApplication`, `hasRepeatedCodes`). It correctly records a structural property of the source CSV that cannot be re-derived after import. It is not derived state in any sense — it is a captured fact about data that no longer exists.

However, the DB copy is currently **write-only**: no production code reads it back from the database. The active read path uses the in-memory `ParsedArmCsv.hasSparseData` during the import flow before the DB row is created.

The stored value exists as forward-looking provenance — available if a future feature (e.g., import quality badge, audit report) needs to surface this property post-import without re-importing the file.

---

---

## Final Recommendations

### Migration Targets

**`plotsTreated` on `trial_application_events` — migrate to junction table**

This is the only genuine redundant-derived-state column. It is an explicitly documented transitional cache for `ApplicationPlotAssignments`. The dual-write is already in place. The migration sequence is:

1. **Pre-condition:** Confirm all devices have been upgraded past schema v55 (where the junction table was created and backfilled from existing TEXT rows). Schema v55 migration is at `app_database.dart:2048–2118`.

2. **Read path migration:** In `application_sheet_content.dart:_initializeFormState()` (around line 235), replace the TEXT-field read:
   ```dart
   // OLD: reads plotsTreated TEXT
   _selectedPlotLabels = e?.plotsTreated?.split(',') ...
   ```
   with a query to `ApplicationPlotAssignmentRepository.getForEvent(e.id)` and map to labels. This is already the write target; making it the read source completes the transition.

3. **Write path cleanup:** Once the read path no longer uses `plotsTreated`, remove it from both branches of `_buildCompanion()` (lines 800 and 844) and remove the passthrough in `ApplicationRepository._withNewFields()` (lines 482–484).

4. **Schema migration:** After a release cycle confirms no regressions, add a Drift migration step to drop the `plots_treated` column. Note: SQLite 3.35+ (iOS 15+, Android API 34+) supports `DROP COLUMN` directly; older targets require the rename-create-copy-drop pattern already used in the codebase (see the `rate_text_old` migration at v55 lines 2102–2117 as precedent).

No data loss risk: the junction table already contains all data written since v55, and the migration at v55 backfilled all pre-existing rows.

---

### Stay with Documentation

**`exportConfidence` on `compatibility_profiles` — keep, add column comment**

Active, load-bearing, and irreplaceable. Written once at import time from a CSV that is subsequently discarded. Read on every export attempt across all four export paths. Not safely recomputable from stored metadata. No migration needed. Recommended addition: a single-line doc comment on the column explaining it captures the CSV quality score at parse time and is not updated after import.

**`hasSparseData` on `import_snapshots` — keep, note write-only status**

Correct import-time provenance fact. Cannot be recomputed without the original CSV cell data. Consistent with three sibling columns that follow the same write-once pattern. Currently write-only from the DB perspective (in-memory path serves the live read during import). No migration needed. Recommended addition: a code comment noting the active read path is `ParsedArmCsv.hasSparseData` and the DB copy is reserved for future post-import reporting.

---

## Cross-Column Summary

| Column | Table | Classification | Action |
|---|---|---|---|
| `exportConfidence` | `compatibility_profiles` | Defensible event snapshot | **Stay** — add doc comment |
| `plotsTreated` | `trial_application_events` | Transitional TEXT cache | **Migrate** — read from junction table, then drop |
| `hasSparseData` | `import_snapshots` | Defensible event snapshot (write-only from DB) | **Stay** — add doc comment noting write-only status |
