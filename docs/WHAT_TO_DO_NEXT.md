# What to Do Next

## Recent work (done)

- **Treatment truth cleanup** — Plots list body, plot layout diagnostics, and integrity check now use Assignment-first resolution for treatment/unassigned. PlotRepository assignment write methods deprecated in favour of AssignmentRepository.
- **Trial lifecycle and protocol lock** — Trial status (Draft / Ready / Active / Closed / Archived), status bar, protocol lock chip and message, activation confirmation. Section headers (Plots, Assessments, Seeding) use standard Add/Bulk Assign and show lock notice when locked; disabled actions with tooltips.
- **Assignments as protocol truth (1.3)** — When trial is Active/Closed/Archived or has any session, assignments are locked: Bulk Assign and per-plot assignment disabled with clear message. UpdatePlotAssignmentUseCase enforces lock.
- **Edit / delete treatment (3.1)** — Treatments tab: edit and delete when protocol not locked; use cases with protocol lock check.
- **Login / user attribution (4.2)** — Current user on About screen; "Change User" / "Select User"; session and export attribution.
- **Export foundation** — Session export: ratings CSV + audit CSV; batch ZIP. **ARM XML export**: session (Export menu) and trial batch (Sessions → Export → CSV or ARM XML ZIP). See [EXPORT.md](EXPORT.md).
- **Full Protocol Details** — Drill-down from trial detail header (description icon); read-only trial info, treatments, assessments, plots/assigned count.
- **Diagnostics** — AppError + diagnostics screen (About → Diagnostics): recent errors, copy single, **copy all**, clear; integrity checks.
- **Docs** — [EXPORT.md](EXPORT.md) (CSV + ARM XML), [PROTOCOL_IMPORT.md](PROTOCOL_IMPORT.md), [CHANGELOG.md](CHANGELOG.md). About screen version from `kAppVersion`.
- **Tests** — Widget tests (Continue Session, Quick Rate, Start Rating); ARM XML use case tests; Full Protocol Details screen tests; batch ARM XML tests; integration tests (draft trial, fallback plot label).

---

Based on the current app state and the **quality-driven order** in [DEVELOPMENT_CRITERIA.md](DEVELOPMENT_CRITERIA.md), here is the prioritized list. Focus remains **researcher and technician convenience** and **protocol backbone first**.

---

## Current State (Summary)

**Already in place:**
- Trials, Plots, Assessments, Treatments, TreatmentComponents; optional `Plots.treatmentId`.
- **Assignments** table and **AssignmentRepository**: treatment-for-plot resolution is Assignment-first, then Plot fallback. Plots list, grid, header, layout diagnostics, and integrity check all use this. Writes go through AssignmentRepository only (PlotRepository assignment methods are deprecated).
- **Trial lifecycle and protocol lock**: Trial status (Draft / Ready / Active / Closed / Archived); protocol lock when Active/Closed/Archived; lock chip, notice, and disabled actions across trial detail.
- **PlotContext** DTO + **ResolvePlotTreatment** use case + `plotContextProvider`; used in Plot detail and Rating screen.
- Treatments tab: list, add treatment, view components. Bulk and per-plot **assignment** via Assignments (Bulk Assign / long-press on plot).
- **Session detail and plot queue** show treatment per plot (assignment-based where used).
- **Assessment library**: AssessmentDefinitions + TrialAssessments; trial tab "Assessments for this trial" with "From library" and "Custom". **Create session and ratings use legacy Assessments only** — TrialAssessments (library) do not yet participate in session or rating flow.
- Execution: Sessions, ratings, notes, photos, seeding, applications (with mark complete/partial), CSV export, audit CSV.
- AppError/diagnostics screen; integrity checks (assignment-aware for plots without treatment).
- Constitution, Development Criteria, and user philosophy documented.

**Gaps vs constitution / development order:**
- **TrialAssessments in sessions**: library assessments are trial-level only; create-session and rating flow use legacy Assessments only. To use library assessments in sessions would require create-session and rating flow to support trial_assessment_id.
- **Login/user attribution**: current user is displayed and used for export/session; flows still allow null user (optional).

---

## Next Steps (in order)

### 1. Protocol backbone — TrialState and assignment discipline ✅ (done)

| # | Task | Why |
|---|------|-----|
| 1.1 | **Formalise trial lifecycle** — Use `Trials.status` as TrialState: e.g. `draft` \| `ready` \| `active` \| `closed` \| `archived`. Add UI to view/change state (e.g. Draft → Ready → Active when starting field work). | Constitution §9: once Active, structural protocol edits restricted. |
| 1.2 | **Restrict structural edits when Active** — When `trial.status == 'active'`: disable or warn on add/remove plots, change assessments, import that changes structure. Allow execution (sessions, ratings, applications) as normal. | Protects research integrity; matches “protocol read-only during execution.” |
| 1.3 | **Assignments as protocol truth** — When trial is Active (or has at least one session), treat assignments as read-only: disable “Bulk Assign Treatments” and per-plot assignment changes, or show “Locked — protocol is fixed.” | Constitution §8: assignments are read-only during execution. |

### 2. Protocol backbone — PlotContext and technician convenience ✅ (done)

| # | Task | Why |
|---|------|-----|
| 2.1 | **Session detail: show treatment per plot** — For each plot row, resolve **PlotContext** and show treatment code (e.g. “Plot 101 · T2”). Use existing `plotContextProvider(plot.id)`. | Technician convenience; single source of truth. |
| 2.2 | **Plot queue: show treatment per plot** — In `_PlotQueueTile`, show treatment code (e.g. “101 · T2”) using PlotContext so technicians see context at a glance. | Same as above; consistency with plot detail and rating screen. |

### 3. Protocol backbone — Treatments ✅ (done)

| # | Task | Why |
|---|------|-----|
| 3.1 | **Edit / delete treatment** — Add edit and delete for Treatments (and optionally components) when trial is in Draft (or when no sessions exist). | Protocol can be corrected before execution; avoids dead data. |

### 4. Operationally trustworthy ✅ (done)

| # | Task | Why |
|---|------|-----|
| 4.1 | **AppError + diagnostics** — Introduce a small **AppError** model and use it for failures; add a simple diagnostics view (e.g. error log, copyable report). | Honest reliability; researchers/technicians get clear failures. |
| 4.2 | **Login / user attribution** — Optional login; store current user and use for session rater and audit/export attribution. | Constitution §5; export and audit readiness. |
| 4.3 | **Export foundation** — Keep CSV; add a small export service that can later include audit metadata and user attribution. | Aligns with constitution §18. |

### 5. Later (broader research support)

- Importer (e.g. plots/treatments from file).
- Lab sample flow.
- Calculator support (spray, seed, etc.).
- Assignment matrix view, dashboards.

---

## Recommended immediate focus

Sections 1–4 are **done**. See "Recent work (done)" above.


**Next priorities:** (1) TrialAssessments in sessions — wire library assessments into create-session and rating flow. (2) Field speed second batch — see FIELD_SPEED_IMPROVEMENTS.md. (3) Later: importer, lab, calculator, matrix view, dashboards.

---

## Field speed (researcher/technician convenience)

For rating and plot-queue flows, prioritise **field speed** and **tap reduction**. See **docs/FIELD_SPEED_IMPROVEMENTS.md** for the full list (Tiers 1–4). The first batch is implemented; the second batch (quick note templates, rep completion haptic, wakelock, end-of-session summary) and later items should be kept in mind for upcoming development. Every extra tap costs 3–5 seconds in the field.

---

## How to use this doc

- Revisit after each chunk of work; tick off done items and adjust order if needed.
- Every change should still pass the **10 development criteria** and the **Cursor standard** (smallest safe change, no broad refactors).
- When in doubt, favour **researcher and technician convenience** and **protocol correctness**.
- When touching the rating screen or plot queue, check **FIELD_SPEED_IMPROVEMENTS.md** so new work aligns with the list and does not remove or conflict with existing speed improvements.
