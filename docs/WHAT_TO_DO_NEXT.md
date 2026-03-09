# What to Do Next

## Recent work (done)

- **Treatment truth cleanup** — Plots list body, plot layout diagnostics, and integrity check now use Assignment-first resolution for treatment/unassigned. PlotRepository assignment write methods deprecated in favour of AssignmentRepository.
- **Trial lifecycle and protocol lock** — Trial status (Draft / Ready / Active / Closed / Archived), status bar, protocol lock chip and message, activation confirmation. Section headers (Plots, Assessments, Seeding) use standard Add/Bulk Assign and show lock notice when locked; disabled actions with tooltips.
- **Export foundation** — Session export includes ratings CSV + session-scoped **audit CSV** when present; batch export ZIP contains both per session. See [EXPORT.md](EXPORT.md).
- **Diagnostics** — AppError + diagnostics screen (About → Diagnostics): recent errors, copy single, **copy all**, clear; integrity checks. Errors recorded from export, ratings, etc.
- **Docs** — [EXPORT.md](EXPORT.md), [PROTOCOL_IMPORT.md](PROTOCOL_IMPORT.md), [CHANGELOG.md](CHANGELOG.md). About screen version from `kAppVersion`.

**Next:** Manual test (export single + batch, trial detail lock, diagnostics). Then: **Login / user attribution** (4.2) or **Edit/delete treatment** (3.1). (Plot queue now shows treatment per plot [2.2]; session detail already showed treatment [2.1].)

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
- Assignments not yet **read-only during execution** (protocol truth) — lock prevents edits when trial is Active/Closed/Archived, but no separate "assignments locked" state.
- **Login/user attribution** optional; many flows still allow null.
- **TrialAssessments in sessions**: library assessments are trial-level only; to use them in sessions would require create-session and rating flow to support trial_assessment_id.

---

## Next Steps (in order)

### 1. Protocol backbone — TrialState and assignment discipline

| # | Task | Why |
|---|------|-----|
| 1.1 | **Formalise trial lifecycle** — Use `Trials.status` as TrialState: e.g. `draft` \| `ready` \| `active` \| `closed` \| `archived`. Add UI to view/change state (e.g. Draft → Ready → Active when starting field work). | Constitution §9: once Active, structural protocol edits restricted. |
| 1.2 | **Restrict structural edits when Active** — When `trial.status == 'active'`: disable or warn on add/remove plots, change assessments, import that changes structure. Allow execution (sessions, ratings, applications) as normal. | Protects research integrity; matches “protocol read-only during execution.” |
| 1.3 | **Assignments as protocol truth** — When trial is Active (or has at least one session), treat assignments as read-only: disable “Bulk Assign Treatments” and per-plot assignment changes, or show “Locked — protocol is fixed.” | Constitution §8: assignments are read-only during execution. |

### 2. Protocol backbone — PlotContext and technician convenience

| # | Task | Why |
|---|------|-----|
| 2.1 | **Session detail: show treatment per plot** — For each plot row, resolve **PlotContext** and show treatment code (e.g. “Plot 101 · T2”). Use existing `plotContextProvider(plot.id)`. | Technician convenience; single source of truth. |
| 2.2 | **Plot queue: show treatment per plot** — In `_PlotQueueTile`, show treatment code (e.g. “101 · T2”) using PlotContext so technicians see context at a glance. | Same as above; consistency with plot detail and rating screen. |

### 3. Protocol backbone — Treatments (small gaps)

| # | Task | Why |
|---|------|-----|
| 3.1 | **Edit / delete treatment** — Add edit and delete for Treatments (and optionally components) when trial is in Draft (or when no sessions exist). | Protocol can be corrected before execution; avoids dead data. |

### 4. Operationally trustworthy (after backbone is solid)

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

**Start with 1.1 and 1.2 (trial lifecycle + restrict edits when Active).**  
That gives you:

- Clear trial state for researchers.
- Protocol protected once field work starts.
- Foundation for 1.3 (assignments read-only) and for future “Ready → Active” workflow.

Then add **2.1 and 2.2** (PlotContext in session detail and plot queue) for quick **technician convenience** wins with minimal risk.

---

## Field speed (researcher/technician convenience)

For rating and plot-queue flows, prioritise **field speed** and **tap reduction**. See **docs/FIELD_SPEED_IMPROVEMENTS.md** for the full list (Tiers 1–4). The first batch is implemented; the second batch (quick note templates, rep completion haptic, wakelock, end-of-session summary) and later items should be kept in mind for upcoming development. Every extra tap costs 3–5 seconds in the field.

---

## How to use this doc

- Revisit after each chunk of work; tick off done items and adjust order if needed.
- Every change should still pass the **10 development criteria** and the **Cursor standard** (smallest safe change, no broad refactors).
- When in doubt, favour **researcher and technician convenience** and **protocol correctness**.
- When touching the rating screen or plot queue, check **FIELD_SPEED_IMPROVEMENTS.md** so new work aligns with the list and does not remove or conflict with existing speed improvements.
