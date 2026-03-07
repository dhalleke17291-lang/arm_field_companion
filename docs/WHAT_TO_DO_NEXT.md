# What to Do Next

Based on the current app state and the **quality-driven order** in [DEVELOPMENT_CRITERIA.md](DEVELOPMENT_CRITERIA.md), here is the prioritized list. Focus remains **researcher and technician convenience** and **protocol backbone first**.

---

## Current State (Summary)

**Already in place:**
- Trials, Plots, Assessments, Treatments, TreatmentComponents; optional `Plots.treatmentId`.
- **PlotContext** DTO + **ResolvePlotTreatment** use case + `plotContextProvider`; used in Plot detail and Rating screen.
- Treatments tab: list, add treatment, view components in bottom sheet. Bulk and per-plot **assignment** (treatmentId on Plots).
- Execution: Sessions, ratings, notes, photos, seeding, applications (with mark complete/partial), CSV export.
- Constitution, Development Criteria, and user philosophy (researcher/technician convenience) documented.

**Gaps vs constitution / development order:**
- No formal **trial lifecycle** (Draft → Active → etc.) or restrictions when trial is active.
- Assignments not yet **read-only during execution** (protocol truth).
- Session detail and plot queue do **not** show treatment context (could use PlotContext for technician convenience).
- No **login/user attribution** or **AppError/diagnostics** (honest failure).

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
