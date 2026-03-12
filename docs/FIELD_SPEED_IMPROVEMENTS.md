# Field Speed Improvements — What We Can Add (Constitution-Aligned)

Based on the current codebase and the constitution/development criteria, here is what we **already have**, what we **can add** (with rough effort), and what to **do first**. Every addition stays aligned: business logic in UseCases where needed, smallest safe change, researcher/technician convenience.

**Rule:** Every extra tap costs 3–5 seconds. Multiply by 24 plots × 3 assessments × 10 sessions — every tap we eliminate matters.

---

## Implemented (first batch)

The following are **already in the app** — keep them in mind when changing the rating or plot-queue flow:

- **Last value memory** — Pre-fills the rating field with the last entered value for that assessment in the session (`last_value_memory.dart` + `lastValueMemoryProvider`). Pre-fill runs when opening a plot and when switching assessment chips.
- **One-tap flag** — Tap flag icon to set/clear a quick flag for the plot in this session; long-press opens the “Add note” dialog. Uses `plotFlagsForPlotSessionProvider`.
- **Plot number quick entry** — In plot queue app bar, “Jump to plot” (search icon) opens a dialog; type plot id and go to that plot’s rating screen.
- **Assessment scale shown** — Rating area shows “Scale: min–max unit” prominently when the assessment has min/max/unit.
- **Offline indicator** — Rating screen app bar shows a “Saved locally” badge so technicians know data is stored offline.
- **Hold-to-save** — Save & Next button responds to both tap and long-press so technicians can use a deliberate long-press to avoid accidental saves.

---

## Tier 1 — Biggest time savers

| # | Item | Status | Can add? | Effort | Notes |
|---|------|--------|----------|--------|-------|
| **1** | **Auto-advance to next plot after save** | ✅ **Already have** | — | — | After last assessment on a plot we call `_navigatePlot(context, 1)`. One tap (Save) advances to next plot. |
| **2** | **Last value memory** | ❌ Not yet | ✅ Yes | Small | Store last entered value per (sessionId, assessmentId) in a provider or in-memory store. On opening next plot for that assessment, pre-fill the field. UseCase or provider only; no schema change if in-memory for session. |
| **3** | **Hold-to-save** | ❌ Not yet | ✅ Yes | Small | Add `onLongPress` on Save button to trigger save; optionally keep tap for “focus only” or make long-press the primary save gesture. UI-only, no business logic change. |
| **4** | **Plot number quick entry** | ❌ Not yet | ✅ Yes | Small | In PlotQueueScreen (or RatingScreen app bar): “Jump to plot” action → dialog with TextField → find plot by `plotId`, push RatingScreen at that index. Fits current navigation. |
| **5** | **One-tap flag** | ⚠️ Partial | ✅ Yes | Small | Today: flag opens dialog (description). Add: **one tap** = set flag (e.g. type `FIELD_OBSERVATION`, description “Flagged” or null); **tap again** = remove flag for this plot/session. Need: provider for “is this plot flagged this session?” + insert/delete. Keep “long-press flag” or menu for “Add note” (current dialog). |

---

## Tier 2 — Significant time savers

| # | Item | Status | Can add? | Effort | Notes |
|---|------|--------|----------|--------|-------|
| **6** | **Assessment carousel — swipe** | ⚠️ Chips only | ✅ Yes | Small–Medium | We have horizontal assessment chips. Add swipe (e.g. `PageView` or `Dismissible`/gesture) on rating area to switch assessment; sync with `_assessmentIndex`. Keeps chips as secondary. |
| **7** | **Bulk same-value entry** | ❌ Not yet | ✅ Yes | Medium | “Apply this value to all remaining plots in this rep” → new UseCase: for current rep + assessment, write same rating to all plots in rep that don’t have a rating yet. Button in rating screen or plot queue. |
| **8** | **Quick note templates** | ✅ **Done** | — | — | Chips in plot notes dialog and flag description dialog; one tap inserts template. |
| **9** | **Session resume** | ❌ Not yet | ✅ Yes | Medium | Persist “last plot index + last assessment index” per session (e.g. small table or SharedPreferences). On opening session → plot queue or rating, restore that position. |
| **10** | **Plot completion indicator** | ✅ **Already have** | — | — | Plot queue uses `ratedPks` and shows rated vs unrated (e.g. check vs circle). Can polish (e.g. stronger green/empty visual) if needed. |

---

## Tier 3 — Workflow polish

| # | Item | Status | Can add? | Effort | Notes |
|---|------|--------|----------|--------|-------|
| **11** | **Rep completion feedback** | ✅ **Done** | — | — | Haptic when leaving last plot in rep (`_navigatePlot` in RatingScreen). |
| **12** | **Offline indicator** | ❌ Not yet | ✅ Yes | Small | Small persistent badge/chip (e.g. “Saved locally” or “Offline”) in app bar or bottom bar so technician never wonders “will this save?”. |
| **13** | **Large tap targets** | ⚠️ Partial | ✅ Yes | Small | Audit main actions (Save, Next, flag, chips); ensure min 48–56dp. Theme or local `minimumSize` / `minTouchTargetSize`. |
| **14** | **Screen stays on during session** | ✅ **Done** | — | — | `wakelock_plus`; enable in PlotQueueScreen and RatingScreen initState, disable in dispose. |
| **15** | **Previous plot quick review** | ❌ Not yet | ✅ Yes | Small–Medium | “Previous plot” button or app bar action → bottom sheet or overlay with last plot’s saved rating(s) for current assessment. Use existing rating read APIs. |

---

## Tier 4 — Protocol intelligence

| # | Item | Status | Can add? | Effort | Notes |
|---|------|--------|----------|--------|-------|
| **16** | **Assessment scale shown** | ❌ Not yet | ✅ Yes | Small | We have `minValue`, `maxValue`, `unit` on Assessment. Show inline near the input, e.g. “Scale: 0–5” or “Unit: %”. |
| **17** | **Out-of-range warning** | ⚠️ Hard block | ✅ Yes | Small | UseCase already enforces min/max. Add **soft** warning in UI when value is outside range (e.g. orange text “Outside typical range”) without blocking save. |
| **18** | **Treatment visible during rating** | ✅ **Already have** | — | — | `_buildPlotInfoBar` uses `plotContextProvider` and shows treatment code + name. |
| **19** | **Photo auto-tag** | ✅ **Already have** | — | — | Photos are saved with plotPk + sessionId; already linked to current plot/session. Optional: add assessmentId to Photos later if needed. |
| **20** | **End-of-session summary** | ❌ Not yet | ✅ Yes | Small | When technician completes last plot (or taps “Finish session”), show a short summary: “X plots rated · Y flagged · Z photos” for 3–5 seconds then close or return to session. Use existing counts. |

---

## What to add first (aligned with constitution)

**Recommended first batch (high impact, small/safe change):**

1. **Last value memory** — Provider or in-session state; pre-fill next plot’s first assessment. Logic in provider or small helper; no schema change.
2. **One-tap flag** — Toggle flag on/off with one tap; keep optional “add note” via long-press or menu. Use existing PlotFlags; add “flags for plot/session” provider + delete for toggle.
3. **Plot number quick entry** — “Jump to plot” in plot queue (or rating) app bar; dialog + navigate to that plot’s rating screen.
4. **Assessment scale shown** — Show min/max/unit next to numeric input. Data already on Assessment.
5. **Offline indicator** — Small “Saved locally” or “Offline” badge. Reassurance, no logic change.
6. **Hold-to-save** — Long-press Save to save; reduces accidental saves while walking. UI-only.

**Second batch (all done):**

7. **Quick note templates** — ✅ Chips in plot notes and flag dialogs (`kQuickNoteTemplates`).  
8. **Rep completion feedback** — ✅ Haptic when leaving last plot in rep.  
9. **Screen stays on** — ✅ Wakelock in PlotQueueScreen and RatingScreen.  
10. **End-of-session summary** — ✅ "X plots rated · Y flagged · Z photos" in session complete dialog.

**Later (medium effort):**

- Session resume (persist position).  
- Bulk same-value entry (new UseCase).  
- Assessment swipe carousel (gesture + state sync).  
- Previous plot quick review (sheet with last rating).  
- Large tap targets audit (theme/layout).

---

## Alignment with constitution and rules

- **Business logic in UseCases:** Last value memory can live in a provider (session-scoped state); bulk same-value and flag toggle can use or extend existing repos/UseCases.  
- **No broad refactors:** Each item is a local change (rating screen, plot queue, providers).  
- **Researcher/technician convenience:** All items reduce taps or uncertainty and support field workflow.  
- **Data integrity:** No change to protocol vs execution; execution data (ratings, flags, notes) remain session-scoped and attributable.

Use this list when deciding what to implement next; prefer the **first batch** for maximum impact with minimum risk.
