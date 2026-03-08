# ARM Field Companion — Product Roadmap & Frozen System Map

**Goal:** Freeze the full system map → decide build phases → avoid future spinal redesign.

**Use:** This document is the anchor for product architecture. All build decisions should extend this map, not reshape it.

---

## 1. Final Core System Map (Big Picture Frozen)

The system has eight core domains:

| # | Domain | Contents |
|---|--------|----------|
| **1️⃣ Identity & Access** | Login, Users, Roles (light), Current user context |
| **2️⃣ Protocol / Reference** | Trials, Treatments, TreatmentComponents, Plot structure, Randomization/Assignments, Assessments, ProtocolSeedingFields, ProtocolApplicationFields |
| **3️⃣ Field Execution** | Sessions, SeedingRecords, ApplicationRecords, RatingRecords, Notes, Photos, PlotFlags, DeviationFlags, AuditEvents |
| **4️⃣ Lab / Analytical** | LabSamples, LabMeasurements, Measurement types |
| **5️⃣ Calculation / Decision Support** | Spray mix, dilution, seed rate calculators; unit conversion |
| **6️⃣ Derived Logic** | Treatment resolution, plot context, trial progress, deviation detection, status calculations |
| **7️⃣ Diagnostics** | Runtime errors, import diagnostics, developer diagnostics, future integrity checks |
| **8️⃣ Output / Export** | Export services, export packages, metadata assembly, user/session attribution |

---

## 2. Important Missing Pieces (Acknowledged)

These are acknowledged so the system does not assume them away and force a later redesign.

| Concern | Why it matters | Build now? |
|---------|----------------|------------|
| **Units & measurement system** | Spray rates, lab results, calculators, exports need unit normalization (e.g. g/ha, ml/ha, kg/plot, ppm, %). No full conversion engine yet, but the system must not assume fixed units everywhere. | No — acknowledge field existence |
| **Sample identity (lab)** | Lab measurements need sampleId, source plot, sample type, collection session, timestamp. Without this, lab data is unusable later. | Phase 2 (Lab module) |
| **Device / environment metadata** | Execution records may later include device id, app version, timestamp precision for diagnostics and exports. | Acknowledge only for now |
| **Data integrity checks** | Future automated checks: plots without treatment, execution without session, lab samples without trial link. Part of Diagnostics/Integrity layer. | Phase 3 / later |

---

## 3. Frozen Dependency Spine

**Do not invert or repeatedly change this chain.** Everything should extend it.

```
User
  → Trial
    → Treatments
      → TreatmentComponents
    → Plots
      → Randomization / Assignments
    → Assessments / Protocol fields (Seeding, Application)
  → Sessions
    → Execution records (Seeding, Applications, Ratings, Notes, Photos, Flags, Deviations, Audit)
  → Lab samples / measurements (Phase 2)
  → Derived logic (context, progress, status)
  → Diagnostics
  → Export
```

---

## 4. Build Phases

### Phase 1 — Build Now (Core research workflow)

| Area | What | Status in codebase |
|------|------|--------------------|
| **Protocol completion** | Treatments, TreatmentComponents, assignment structure, Plot structure, Assessments, ProtocolSeedingFields, ProtocolApplicationFields | Treatments + components + assignments (Plots.treatmentId) ✅. ProtocolSeedingFields ✅. ProtocolApplicationFields: ApplicationSlots exist; no separate “protocol application fields” table yet. |
| **Execution completion** | Sessions, Seeding, Applications, Ratings, Notes, Photos, Flags, Deviations | Sessions, SeedingRecords, ApplicationEvents/PlotRecords/Slots, RatingRecords, Notes, Photos, PlotFlags, DeviationFlags, AuditEvents ✅ |
| **Plot context resolution** | plot → treatment → components → protocol context; used by context panel, record screens, export, deviation logic | ResolvePlotTreatment, PlotContext, plotContextProvider ✅; used in plot detail, rating screen, session detail, plot queue ✅ |
| **Basic login** | One user, stored locally; role metadata light; audit + export attribution | ❌ Not implemented |
| **Basic export** | Trial, plots, treatments, assignments, sessions, execution records, user attribution (CSV or JSON) | Session CSV export ✅; full trial/attribution export not yet |
| **Diagnostics (MVP)** | AppError, diagnostics store, diagnostics screen, copyable reports | ❌ Not implemented |

### Phase 2 — Next (extend without changing core)

| Area | What |
|------|------|
| **Lab data module** | LabSamples, LabMeasurements, measurement types; link to trial, plot, sample id |
| **Calculators** | Toolbox: spray, tank mix, seed quantity, unit conversions; optional execution integration |
| **Matrix / field layout** | Visual grid by rep; overlays: treatment, rating status, flags |
| **Progress & status panels** | Trial completion %, rated/seeded/flagged plots from execution |
| **Import system** | Full importer: trial → treatments → components → plots → assignments → assessments → protocol fields; import diagnostics |

### Phase 3 — Future expansion

| Area | What |
|------|------|
| Trial command hub | Dashboard: progress, quick actions, diagnostics, exports |
| SubUnits | Plant-level observations (e.g. Plot 12 → Plant 1, 2) |
| Templates | Reusable setups for protocols, seeding, application |
| Advanced diagnostics | Automated checks: orphans, invalid protocol, integrity warnings |
| Role permissions | Restrict imports, diagnostics, admin |
| Cloud sync / multi-user | If system grows beyond single device |

---

## 5. Build Order (Steps 1–7) vs Current State

| Step | Task | Status |
|------|------|--------|
| **1** | Finish Treatments + TreatmentComponents | ✅ Done (list, add, components; edit/delete when Draft can follow) |
| **2** | Implement Randomization / Assignment model | ✅ Done: Plots.treatmentId + bulk/per-plot assign; no formal “read-only when active” yet |
| **3** | Connect Plot context resolution | ✅ Done (PlotContext everywhere: plot detail, rating, session detail, plot queue) |
| **4** | Finish Applications execution engine | ✅ Done (events, slots, plot records, mark complete/partial) |
| **5** | Implement Login + User context | ❌ Not done |
| **6** | Implement Export foundation | ⚠️ Partial: session CSV ✅; full trial/attribution export not yet |
| **7** | Implement Diagnostics system | ❌ Not done |

**Next logical work (aligned with this roadmap):**

- ~~**Trial lifecycle + assignment discipline** (Step 2 completion)~~ **Done.**
- **Step 5:** Basic login + user context (local user, attribution).
- **Step 6:** Extend export (trial-level, treatments, assignments, user attribution).
- **Step 7:** AppError + diagnostics store + diagnostics screen + copyable reports.

---

## 6. Honest Assessment

- The **big picture** (eight domains + dependency spine + acknowledged gaps) is **stable enough** to avoid repeated spinal changes.
- **No obvious system domains are missing**; units, sample identity, device metadata, and integrity checks are acknowledged.
- **Future work** should mostly **add modules** (Phase 2/3) and **complete Phase 1** (login, export, diagnostics), not reshape the architecture.

---

## 7. Related docs

- **CONSTITUTION.md** — Architecture and guardrails.
- **DEVELOPMENT_CRITERIA.md** — Quality-first order and 10 criteria.
- **WHAT_TO_DO_NEXT.md** — Prioritized task list (trial lifecycle, PlotContext, etc.).
- **SEQUENCE_CATCHUP.md** — Current status vs quality-driven order.

---

*If a single-page system map diagram is added, it can be linked here for visual reference.*
