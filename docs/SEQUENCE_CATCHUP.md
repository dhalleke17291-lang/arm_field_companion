# Sequence plan — catch-up

**Purpose:** Align with the **quality-driven development order** (Constitution + DEVELOPMENT_CRITERIA.md + WHAT_TO_DO_NEXT.md). No milestones — we judge by whether each step makes the app stronger on the 10 criteria.

---

## 1. Quality-driven order (recap)

| Order | Focus | Goal |
|-------|--------|------|
| **First** | Protocol backbone | TrialState, Treatments, TreatmentComponents, assignments, resolution, PlotContext, treatment screens, plot context in UI |
| **Second** | Execution discipline | Applications engine, shared execution pattern, session/status, notes/photos/flags consistency |
| **Third** | Operationally trustworthy | Login/user attribution, AppError, diagnostics UI, export foundation |
| **Fourth** | Broader research support | Importer, lab sample flow, calculators, matrix view, dashboards |

---

## 2. Current status

### First: Protocol backbone

| Item | Status | Notes |
|------|--------|------|
| TrialState (lifecycle) | ✅ Done | draft→ready→active→closed→archived; status bar + transition buttons in trial detail |
| Treatments | ✅ Done | Table, repo, Treatments tab: list, add, view components (bottom sheet) |
| TreatmentComponents | ✅ Done | Table, repo, loaded by ResolvePlotTreatment |
| Assignments | ✅ Done | Read-only when active/closed/archived; Bulk Assign hidden, per-plot long-press disabled |
| treatment/plot resolution | ✅ Done | TreatmentRepository, getTreatmentForPlot, getComponentsForTreatment |
| ResolvePlotTreatment use case | ✅ Done | Single source of truth for plot + treatment |
| PlotContext DTO | ✅ Done | Used in plot detail and rating screen |
| Treatment screens | ✅ Done | _TreatmentsTab with list, add treatment, components |
| Plot detail treatment context | ✅ Done | plotContextProvider(plot.id) in plot_detail_screen |
| **Restrict edits when Active** | ✅ Done | Import plots + Add test plots + Add assessment disabled when protocol locked; guard in ImportPlotsScreen |
| **Assignments read-only when Active** | ✅ Done | Bulk Assign hidden, per-plot assign on long-press disabled when locked |

### Second: Execution discipline

| Item | Status | Notes |
|------|--------|------|
| Applications engine | ✅ Done | ApplicationEvents, ApplicationPlotRecords, ApplicationSlots; Applications tab; mark complete/partial |
| Session detail + status | ✅ Done | Session detail screen, session list, open/closed |
| CSV export | ✅ Done | ExportSessionCsvUsecase, export from session detail |
| Shared execution pattern | ⚠️ Partial | Ratings, applications, seeding, notes, photos exist; consistency can be tightened |
| **Session detail: treatment per plot** | ✅ Done | Plot rows show “Plot {plotId} · {treatmentCode}” via plotContextProvider |
| **Plot queue: treatment per plot** | ✅ Done | Queue tiles show “Plot {displayLabel}” (e.g. “Plot 101 · T2”) via plotContextProvider |

### Third: Operationally trustworthy

| Item | Status | Notes |
|------|--------|------|
| Export foundation | ✅ Done | Export repo + session CSV use case |
| AppError + diagnostics | ❌ Not done | No structured AppError model or diagnostics UI |
| Login / user attribution | ❌ Not done | raterName/operatorName nullable; no login |

### Fourth: Broader research support

| Item | Status | Notes |
|------|--------|------|
| Importer | ⚠️ Partial | Import plots exists |
| Lab sample flow | ❌ Not done | — |
| Calculators | ❌ Not done | — |
| Matrix view / dashboards | ❌ Not done | — |

---

## 3. Recommended next steps (from WHAT_TO_DO_NEXT.md)

**1. Protocol backbone — TrialState and assignment discipline**

1. **1.1** Formalise trial lifecycle: use `Trials.status` as TrialState (`draft` \| `ready` \| `active` \| `closed` \| `archived`), add UI to view/change state (e.g. Draft → Ready → Active when starting field work).
2. **1.2** Restrict structural edits when Active: when `trial.status == 'active'`, disable or warn on add/remove plots, change assessments, structure-changing import. Allow execution (sessions, ratings, applications) as normal.
3. **1.3** Assignments as protocol truth: when trial is Active (or has sessions), treat assignments as read-only (disable bulk assign and per-plot assignment changes, or show “Locked — protocol is fixed”).

**2. Protocol backbone — PlotContext and technician convenience**

4. **2.1** Session detail: show treatment per plot (resolve PlotContext per plot row, show e.g. “Plot 101 · T2”).
5. **2.2** Plot queue: show treatment per plot in queue tiles (e.g. “101 · T2”) using PlotContext.

**Then (after backbone is solid)**

6. **3.x** Treatments: edit/delete treatment (and optionally components) when trial is Draft / no sessions.
7. **4.1** AppError + diagnostics (structured failures, diagnostics view).
8. **4.2** Login / user attribution (optional login, current user for session/audit/export).

---

## 4. Field speed (researcher/technician convenience)

See **docs/FIELD_SPEED_IMPROVEMENTS.md**. First batch of improvements is in place; keep the list in mind for rating and plot-queue work so new changes don’t remove or conflict with them.

---

## 5. How to use this doc

- Revisit after each chunk of work; tick off done items and adjust order if needed.
- Every change should still pass the **10 development criteria** and the Cursor standard (smallest safe change, no broad refactors).
- When in doubt, favour **researcher and technician convenience** and **protocol correctness**.
