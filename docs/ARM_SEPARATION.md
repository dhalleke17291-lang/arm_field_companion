# ARM / Standalone Separation

**Status:** active, enforced by `test/core/arm_separation_boundary_test.dart`.
**Owner:** core architecture.
**Pairs with:** `docs/CONSTITUTION.md`, `lib/core/workspace/workspace_config.dart`.

## Principle (one sentence)

**Core holds what every trial has. ARM extensions hold what ARM specifically demands. Standalone trials must never read, write, render, or depend on ARM-extension data.**

## Why this exists

This app has two trial modes:

- **Standalone** (`TrialMode.standalone`, `WorkspaceType.standalone`): independent trials. User enters everything manually. No ARM contract.
- **Protocol** (`TrialMode.protocol`, `WorkspaceType.variety|efficacy|glp`): research protocols. May additionally be **ARM-linked** — imported from an ARM Rating Shell and round-tripped back to ARM.

ARM shells carry a *lot* of metadata (7 sheets, ~300 metadata fields, ~79-field Applications descriptor block). If ARM-specific fields creep into core tables, screens, and services, the standalone path stops being simple, standalone tests have to mock ARM, and every future change asks "am I in ARM mode?" That breaks the standalone promise.

## The rule

A field belongs in **core** if: a researcher running a private non-ARM trial would naturally want it.

A field belongs in **ARM extension** if: it encodes an ARM-specific code, unit convention, row position, or schema quirk that only makes sense inside the ARM round-trip.

### Examples

| Concept | Core? | ARM extension? |
|---|---|---|
| Trial name, crop, location | ✅ core | |
| Treatment product name, rate, rate unit | ✅ core | |
| Application date, method | ✅ core | |
| Rater name | ✅ core | |
| Growth stage (as free text / BBCH label) | ✅ core | |
| Scheduled rating date | ✅ core | |
| ARM Column ID (integer) | | ✅ ARM |
| SE Name, SE Description, Rating Type code (`CONTRO`/`LODGIN`/...) | | ✅ ARM |
| Pest Code, Part Rated (`PLANT`/`LEAF3`), Collect Basis | | ✅ ARM |
| Form Conc, Form Conc Unit (`%W/W`), Form Type | | ✅ ARM |
| Trt-Eval Interval string (`-7 DA-A`), Plant-Eval Interval string | | ✅ ARM |
| Application Timing Code (`A1`, `A3`, `AA`) | | ✅ ARM |
| All 79 Applications-sheet descriptor fields | | ✅ ARM |
| ARM Pull Flag, ARM Actions column | | ✅ ARM |
| Shell file path, shell-linked timestamps | | ✅ ARM |

**Rule of thumb:** the *concept* (growth stage, product name) goes in core; the *coding* (BBCH, `%W/W`, `CONTRO`) goes in ARM extension.

## Folder layout

```
lib/
  core/                      universal
  domain/
    models/                  ← core models only, no ARM imports
    arm/                     ← ARM-only models
    intelligence/            ← protocol-agnostic
  data/
    repositories/            ← core repositories
    arm/                     ← ARM-only repositories
    services/
      arm_shell_parser.dart  ← ARM-only (existing; moves under data/arm/ over time)
  features/
    ratings/                 ← core, no ARM imports
    sessions/                ← core, no ARM imports
    trials/                  ← core, no ARM imports
    plots/                   ← core
    arm_import/              ← ARM-only (existing)
    arm_protocol/            ← ARM-only (new; ARM Protocol tab lives here)
```

## Import rules (enforced)

1. **Directories outside `arm*/` must not import from `lib/domain/arm/`, `lib/data/arm/`, `lib/features/arm_import/`, or `lib/features/arm_protocol/`.**
2. Directories inside `arm*/` may import from core — that direction is always allowed.
3. Exceptions for pre-existing ARM leakage on core tables (`trials.isArmLinked`, `trial_assessments.armColumnIdInteger`, etc.) are **grandfathered**. New violations are not allowed.

`test/core/arm_separation_boundary_test.dart` enforces rule 1 with a file scan. PRs that add a new core→ARM import will fail the test.

## Schema cleanup (Phase 0b — complete)

All ARM-specific fields that were grandfathered on core tables have now been migrated into the extension tables. Core tables carry no ARM-coded fields.

| Field | Originally on | Moved to | Schema version |
|---|---|---|---|
| `isArmLinked`, `armImportedAt`, `armSourceFile`, `armVersion`, `armImportSessionId`, `armLinkedShellPath`, `armLinkedShellAt`, `shellInternalPath` | `Trials` | `ArmTrialMetadata` | v58 |
| `armImportColumnIndex`, `armShellColumnId`, `armShellRatingDate`, `armColumnIdInteger` | `TrialAssessments` | `ArmAssessmentMetadata` | v60 |
| `pestCode`, `seName`, `seDescription`, `armRatingType` | `TrialAssessments` | `ArmAssessmentMetadata` | v61 |

Each migration used the same three-step pattern — additive v(N) (new columns + backfill), flip writers then readers to the new location with a fallback, and a contract-phase v(N+1) that drops the legacy columns. Legacy `ALTER TABLE ADD COLUMN` calls in older upgrade paths were rewritten as idempotent raw SQL so pre-v58 installs still pass through the drops cleanly.

**Rule going forward:** new ARM-specific fields must land in an `arm_*_metadata` extension table (or a new one if needed). Core tables (`Trials`, `TrialAssessments`, `Sessions`, `Plots`, etc.) are for fields every trial has.

### Residual fields with ARM-ish names on core tables

One generic override is kept on the core tables because it is not ARM-specific:

- `TrialAssessments.displayNameOverride` — a per-trial display label that any trial can use (ARM importers populate it from the ARM SE name, but standalone trials can set it manually). Not gated behind ARM.

The constitution's "concept vs coding" rule applies: the concept (display label) is core; the ARM-specific coding (`AVEFA`, `CONTRO`, …) lives on `ArmAssessmentMetadata`.

## ARM extension tables (Phase 1a)

Three additive tables carry ARM-specific metadata and the bridge between ARM's `(measurement × date)` column model and this app's `(assessment × session)` model. They live in `lib/core/database/app_database.dart` for Drift codegen reasons, but all reads and writes against them must originate from `lib/data/arm/` or `lib/features/arm_*`. Standalone trials have zero rows in any of them.

| Table | Row per | Purpose |
|---|---|---|
| `arm_column_mappings` | ARM shell column | Bridge table: ties every ARM Column ID to the app-side (trial_assessment, session) pair it represents. Preserves ARM's per-date column identity without forcing the core schema to replicate it. Orphan columns (blank metadata) hold `trial_assessment_id = null`, `session_id = null` and exist only so export emits them back as empty columns. |
| `arm_assessment_metadata` | deduplicated trial_assessment | Verbatim ARM assessment-column header fields (SE Name, SE Description, Part Rated, Rating Type, Collect Basis, Num Subsamples, Pest Codes, Rating Min/Max, Rating Unit). Deduplication identity is `(SE Name, Part Rated, Rating Type)`. |
| `arm_session_metadata` | app session | ARM per-date context for a session: ARM Rating Date, Timing code (A1/A3/A6/AA), Crop Stage Maj/Min/Scale, Trt-Eval Interval, Plant-Eval Interval, Rater Initials. Lets round-trip export reproduce the shell's date/timing/stage header. |

### Why the bridge pattern, not a richer TrialAssessments

ARM treats `Weed Control on 2026-04-02` and `Weed Control on 2026-04-23` as two columns with distinct Column IDs. The app treats "Weed Control" as one assessment rated twice — once in the 04-02 session, once in the 04-23 session. If the importer created one `trial_assessment` per ARM column, the same measurement would appear several times in the app's assessment list (one per date), breaking the app's native session-based workflow.

`arm_column_mappings` resolves this: the importer dedups assessment columns on `(SE Name, Part Rated, Rating Type)`, creates one session per unique ARM Rating Date, and stores the ARM-Column-ID → `(trial_assessment, session)` mapping. Core UI sees the deduplicated, session-based shape. Export walks the mapping to rebuild the per-column shell ARM expects. Identity is preserved; workflow stays native.

### Not introduced in Phase 1a

- Core table changes: none. The pre-existing ARM fields on `Trials` and `TrialAssessments` remain as-is; Phase 0b will migrate them into the new extension tables.
- Importer/exporter rewrites: deferred to Phase 1b. Phase 1a is schema foundation only.
- New UI surfaces: none. The ARM Protocol tab lands later; Phase 1a adds no user-visible changes.

## Importer + exporter using the bridge (Phase 1b)

Phase 1b turns the Phase 1a tables into active infrastructure: the importer writes them and the exporter reads them.

### Importer (`ImportArmRatingShellUseCase`)

1. **Deduplicates ARM columns** by `(SE Name, Part Rated, Rating Type, Rating Unit)` into one `trial_assessment` per unique measurement. The app's core "list of assessments" is now the deduplicated set — no more three "Weed Control" rows.
2. **Plans one session per unique ARM Rating Date** with `status = 'planned'`. Planned sessions do not surface as open field-work sessions (see "Planned session status" below); a user transitions a planned session to `open` by starting it normally, at which point rating flow is identical to standalone trials.
3. **Writes `arm_column_mappings`** — one row per ARM column in the shell. Each row carries the ARM Column ID, column index, and references the deduplicated trial_assessment and planned session for that column. Orphan columns (blank measurement metadata) keep `trial_assessment_id` and `session_id` null so export can re-emit them as structurally present but empty.
4. **Writes `arm_assessment_metadata`** (one row per deduplicated trial_assessment, verbatim ARM identity fields) and **`arm_session_metadata`** (one row per planned session, with Rating Date, timing code, crop stage, DA-A/DP intervals).

Historically the importer also populated legacy per-column fields on `trial_assessments` (`armImportColumnIndex`, `armColumnIdInteger`, `seName`, `seDescription`, `armRatingType`, `armShellColumnId`, `armShellRatingDate`, `pestCode`) as advisory shadows. Those shadows were retired in v60 (4 anchor fields) and v61 (4 duplicate SE/pest/rating-type fields); see "Schema cleanup (Phase 0b — complete)" above. `arm_column_mappings` + `arm_assessment_metadata` are now the only sources.

### Exporter (`ExportArmRatingShellUseCase`)

The exporter checks `arm_column_mappings` up front and runs one of two paths:

- **Mapping path (Phase 1b)** — taken when the trial has mapping rows. The exporter iterates mappings in column-index order and, for each mapping, fetches the rating at `(plot, mapping.trial_assessment_id → legacyAssessmentId, mapping.session_id)` and writes it to `mapping.armColumnId`. Orphan mappings skip silently; the shell column stays structurally present but empty. No identity matcher, no positional fallback, no "resolved shell session" — identity is deterministic by construction.
- **Legacy path** — taken when no mappings exist (trials that predate Phase 1b, or tests that construct trials manually). The original matcher + positional-fallback + strict-block logic runs unchanged.

The branch is a pure append; every existing export test exercises the legacy path, new Phase 1b tests exercise the mapping path.

### Planned session status

`kSessionStatusPlanned` is a new value of the core `sessions.status` enum. The concept is protocol-agnostic — any trial can in principle schedule a session ahead of time — so the enum value lives on the core session lifecycle. `SessionRepository.getOpenSession` / `watchOpenSession` and `isSessionOpenForFieldWork` explicitly exclude planned sessions, so they do not show up as "active field work" and do not block a user from starting a new session. Standalone trials continue to run without ever creating a planned session; only the ARM importer writes them today.

### Not introduced in Phase 1b

- Core-table cleanup (dropping the grandfathered ARM columns from `Trials` / `TrialAssessments`): deferred at the time; **now complete** in v58 / v60 / v61. See "Schema cleanup (Phase 0b — complete)" above.
- ARM Protocol tab: not part of 1b. Read-only **Treatments** and **Applications** sub-sections were added later (rating-shell slices **2c** and **3d**); see [Rating Shell sheet pipeline (incremental slices)](#rating-shell-sheet-pipeline-incremental-slices).

## Planned-session surface (Phase 1c)

Phase 1b makes the importer create `kSessionStatusPlanned` rows, but they were invisible to users: no open-session query returned them and no UI branched on the status. Phase 1c is the minimum surface needed so the researcher sees what ARM expects and can start rating from the Sessions tab.

### Nullable ARM metadata provider

`armSessionMetadataProvider(sessionId)` (in `lib/core/providers.dart`) is a `FutureProvider.family` that returns `ArmSessionMetadataData?`. It resolves through `ArmColumnMappingRepository.getSessionMetadata` (also new in 1c) and is null for any session that was not created by the ARM importer. Core UI code consumes this nullable type directly, so the same tile renders cleanly for an ARM planned session (metadata present), a future non-ARM planned session (metadata absent), or a standalone session that is never planned (code path does not branch on status).

The provider lives in `core/providers.dart` — the composition root is already allow-listed in `arm_separation_boundary_test.dart` to read from `lib/data/arm/`. No ARM feature folder is imported by the session tile; it consumes a core-typed provider that returns a core-typed drift row.

### Planned-session tile

The tile in `lib/features/trials/trial_detail_screen.dart` branches on `session.status == kSessionStatusPlanned` and delegates to `_buildPlannedSessionTile`. That builder:

- shows the planned rating date (`session.sessionDateLocal`) as the tile title (the regular tile's "Started HH:mm" subtitle is meaningless for a row whose `startedAt` was stamped at import time);
- composes a compact metadata line from `armSessionMetadataProvider` when non-null: `Timing · Stage · DA-A · DA-P`, with each segment elided when its field is blank;
- renders a `Planned` pill + a `Start` tonal button. The tile itself is also the tap target — both lead to a confirmation dialog → `SessionRepository.startPlannedSession` → route into `PlotQueueScreen` with the now-open session;
- disables starting (greyed button + warning line) when another session on the same trial is already open, so the user is never left wondering why the rating screen refuses to load.

The legacy tile builder is unchanged — every pre-1c session (open, closed, needs-attention) takes the original path.

### `SessionRepository.startPlannedSession`

One method in the core repository does all state transitions:

1. asserts the session exists and is not soft-deleted (`SessionNotFoundException` otherwise);
2. asserts `status == kSessionStatusPlanned` (`PlannedSessionStartException` otherwise);
3. asserts no other session on the trial is `open` (`OpenSessionExistsException` otherwise, same class `createSession` throws, so UI callers have one "trial already has an open session" snackbar to wire);
4. writes `status = open`, `startedAt = now()`;
5. emits a `SESSION_STARTED` audit event with description `Planned session "<name>" started`.

Because the method lives on `SessionRepository` and does not know about ARM, it is equally usable by any future non-ARM planned-session flow.

### Not introduced in Phase 1c

- Pre-filling `CreateSessionScreen` with ARM-expected crop stage / rater / BBCH: deferred. The user enters real field values through the normal open-session flow after starting.
- Editable ARM metadata: still deferred. Phase 1c is read-only consumption of session metadata on the planned-session tile. The **ARM Protocol** tab adds other read-only surfaces (assessments, Treatments sheet, Applications sheet); editing there is out of scope until explicitly specified.
- Overview / timeline / calendar surfaces for planned sessions: deliberately out of scope — one view at a time keeps the visual and navigation contract small.
- Reordering `sessionsForTrialProvider` to put planned sessions ahead of historical closed ones: the existing `startedAt desc` ordering groups imported-same-batch planned rows together, which is fine for now.

## Rating Shell sheet pipeline (incremental slices)

This numbering is **workspace shorthand** for the ARM **Rating Shell (.xlsx)** work: parsers, importers, Protocol tab sub-sections, and trust tests. It sits **alongside** the Phase 0b–1c headings above (schema bridge vs sessions UX), not as a replacement for them.

### Plot Data + bridge (Phase 1b)

- **Parser:** `lib/data/services/arm_shell_parser.dart` — Plot Data grid → `ArmShellImport.assessmentColumns` + `plotRows`.
- **Import:** `ImportArmRatingShellUseCase` — deduplicated assessments, planned sessions, `arm_column_mappings`, `arm_assessment_metadata`, `arm_session_metadata`.
- **Export:** `ExportArmRatingShellUseCase` + `ArmValueInjector` — rating values are injected into the **Plot Data** worksheet XML; other worksheets are copied from the selected shell unless a future phase adds injectors for them.

### Treatments sheet — slices 2a–2d

| Slice | Deliverable | Where |
|------|-------------|--------|
| **2a** | Parser (`ArmTreatmentSheetRow`) | `_parseTreatmentsSheet` in `arm_shell_parser.dart`; `test/data/arm_shell_parser_treatments_sheet_test.dart` |
| **2b** | Importer write-through (core + `arm_treatment_metadata` + components) | `ImportArmRatingShellUseCase`; `test/features/arm_import/import_arm_rating_shell_treatments_sheet_test.dart` |
| **2c** | ARM Protocol tab — read-only Treatments | `ArmTreatmentsSection` in `lib/features/arm_protocol/arm_protocol_tab.dart`; `test/features/arm_protocol/arm_protocol_tab_treatments_test.dart` |
| **2d** | Round-trip trust (dual-write, deterministic re-import, table survey) | `test/features/arm_import/import_arm_rating_shell_round_trip_test.dart` — group *Treatments sheet round-trip trust anchor* |

### Applications sheet — slices 3a–3e

| Slice | Deliverable | Where |
|------|-------------|--------|
| **3a** | `arm_applications` table (v66), repository, indexes | `app_database.dart`, `lib/data/arm/arm_applications_repository.dart`; `test/core/arm_extension_tables_migration_test.dart` |
| **3b** | Parser (`ArmApplicationSheetColumn`, 79 rows × column) | `_parseApplicationsSheet` in `arm_shell_parser.dart`; `test/data/arm_shell_parser_test.dart` |
| **3c** | Importer — `trial_application_events` dual-write + `arm_applications` verbatim rows | `ImportArmRatingShellUseCase`; `test/features/arm_import/import_arm_rating_shell_applications_sheet_test.dart` |
| **3d** | ARM Protocol tab — read-only Applications | `ArmApplicationsSection` in `arm_protocol_tab.dart`; `test/features/arm_protocol/arm_protocol_tab_applications_test.dart` |
| **3e** | Round-trip trust | `import_arm_rating_shell_round_trip_test.dart` — group *Applications sheet round-trip trust anchor* |

### Fixture contract

Sheet layout, row maps, and which sheets are parsed today: **`test/fixtures/arm_shells/README.md`**.

### Gaps (explicit)

- **Export:** `ArmValueInjector` does **not** yet rewrite the **Treatments** or **Applications** worksheets; full workbook round-trip for those sheets is future work.
- **Comments**, **Subsample Plot Data**: not parsed (see README).

## What standalone users see

Standalone trials (`WorkspaceType.standalone`, `isArmLinked = false`):

- Never show ARM-only UI (ARM Protocol tab, ARM metadata viewers, ARM shell export).
- Never populate any row in any `arm_*` extension table.
- Core screens (Overview, Plots, Ratings, Sessions, Photos, Timeline) must render correctly with every ARM field null or absent.

## What ARM-linked users see

ARM-linked trials (`isArmLinked = true`):

- Show all core screens unchanged (no branching in core UI on ARM flags).
- Additionally see an **ARM Protocol tab** (in `lib/features/arm_protocol/`) that surfaces ARM-specific richness: import/shell summary, read-only **Treatments** (sheet 7) and **Applications** (79-row descriptors per imported event) sub-sections, ARM **assessments** metadata, pinned import session, and shell link. **Comments** sheet content is not surfaced there yet.

## Runtime guardrails (existing)

Complementing the import-level separation, `lib/core/trial_state.dart` enforces **write-path** guards: `canEditProtocol()` and `ProtocolEditBlockedException` prevent structural mutation of ARM-linked trials from any code path. See `test/core/arm_protocol_structure_guard_test.dart` for the canonical enforcement suite.

Import-level separation (this doc) + write-path guardrails (existing) + schema extension tables (Phase 0b — complete at v61) are the three layers that keep standalone clean and ARM rich.
