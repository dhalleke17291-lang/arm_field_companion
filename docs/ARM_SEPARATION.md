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

## Acknowledged leakage (pre-existing)

For honesty: the current codebase has ARM fields on core tables. These are **grandfathered** and will be migrated off in a dedicated schema-migration phase (Phase 0b). Until then, they pass the boundary test by being tracked on the core tables themselves, not as imports from ARM-only folders.

Pre-existing ARM fields on core tables (not to be extended):

- `Trials`: `isArmLinked`, `armLinkedShellPath`, `shellInternalPath`, `armSourceFile`, `armImportedAt`
- `TrialAssessments`: `armColumnIdInteger`, `armImportColumnIndex`, `armShellColumnId`, `armShellRatingDate`, `seName`, `seDescription`, `armRatingType`, `displayNameOverride`, `pestCode`

**New ARM-specific fields must not be added to these tables.** They belong in the `arm_*_metadata` extension tables introduced in Phase 1a.

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

## What standalone users see

Standalone trials (`WorkspaceType.standalone`, `isArmLinked = false`):

- Never show ARM-only UI (ARM Protocol tab, ARM metadata viewers, ARM shell export).
- Never populate any row in any `arm_*` extension table.
- Core screens (Overview, Plots, Ratings, Sessions, Photos, Timeline) must render correctly with every ARM field null or absent.

## What ARM-linked users see

ARM-linked trials (`isArmLinked = true`):

- Show all core screens unchanged (no branching in core UI on ARM flags).
- Additionally see an **ARM Protocol tab** (in `lib/features/arm_protocol/`) that surfaces ARM-specific richness: full assessment-column metadata, formulation details, the 79-field Applications view, Comments, shell round-trip status.

## Runtime guardrails (existing)

Complementing the import-level separation, `lib/core/trial_state.dart` enforces **write-path** guards: `canEditProtocol()` and `ProtocolEditBlockedException` prevent structural mutation of ARM-linked trials from any code path. See `test/core/arm_protocol_structure_guard_test.dart` for the canonical enforcement suite.

Import-level separation (this doc) + write-path guardrails (existing) + schema extension tables (Phase 0b) are the three layers that keep standalone clean and ARM rich.
