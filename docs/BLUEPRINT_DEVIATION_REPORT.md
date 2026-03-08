# Blueprint & Constitution Deviation Report

This document compares the current ARM Field Companion implementation against the **Master Charter** (docs/MASTER_CHARTER.md) and **Constitution** (docs/CONSTITUTION.md). Each deviation is classified as **positive** (acceptable or beneficial), **negative** (violation or gap to fix), or **neutral** (simplification / not yet implemented by design).

---

## Summary

| Category | Count |
|----------|--------|
| Aligned | Most of spine, execution, session lock, export metadata, diagnostics, corrections, export lineage, context resolution, import transparency |
| Negative deviations (resolved) | 0 (three previously identified items have been fixed) |
| Neutral / gaps | 4 (protocol amendments, assignment model, lab, calculators) |
| Positive deviations | 0 (no intentional overrides) |

---

## 1. Frozen dependency spine (Charter PART 3)

**Charter:** User → Trial → Treatments → TreatmentComponents → Plots → Assignments → AssessmentDefinitions → Sessions → ExecutionRecords → LabSamples → DerivedLogic → Diagnostics → Export.

**Current state:**

- **User, Trial, Treatments, TreatmentComponents, Plots, Sessions, ExecutionRecords (RatingRecords, etc.), Diagnostics, Export** — present and used in lineage.
- **Assignments** — No separate `PlotAssignments` table. Assignment is represented by `Plots.treatmentId` (plot-to-treatment). Lineage is preserved; structure is simpler.
- **AssessmentDefinitions** — Implemented as `Assessments` table (protocol); execution as `RatingRecords` + `SessionAssessments`. Aligned.
- **LabSamples** — Not implemented (Charter Phase 6). Roadmap item, not a deviation.
- **DerivedLogic** — Partial (e.g. plot context resolution, trial/session status). No formal “DerivedLogic” layer; logic lives in use cases and providers. Acceptable.

**Assignment model (explicit note):** Assignments are implemented as **`Plots.treatmentId`** (plot-bound). There is no separate Assignments table. Per architecture audit, this is an acceptable MVP: protocol lock applies, and a first-class Assignments table is the target when randomization/versioning/audit require it. See Constitution §8 and the audit migration strategy. **Neutral** (documented simplification; formalization deferred).

---

## 2. Protocol vs execution separation (Charter PART 2, 5, 6)

**Charter:** Protocol and execution must remain separate; protocol read-only when trial is Active; assessment definitions in protocol, records in execution.

**Current state:**

- Protocol (trials, treatments, components, plots, assessments) is distinct from execution (sessions, rating records, applications, etc.).
- When trial is **Active/Closed/Archived**, protocol edits (plots, assessments, assignments) are blocked via `isProtocolLocked()`; execution (recording ratings, etc.) remains allowed.
- Assessments table = definitions; RatingRecords = execution. No field observations stored in protocol.

**Verdict:** **Aligned.**

---

## 3. Protocol amendments (Charter PART 5)

**Charter:** “Changes must occur through Protocol Amendments, preserving version lineage.”

**Current state:** No Amendment entity or versioned protocol change flow. Protocol is simply locked when active; the codebase comments that an “amendment/versioned path” should be used later.

**Verdict:** **Neutral gap.** Intent is acknowledged; not yet built. Becomes **negative** if protocol changes are ever allowed without an amendment path.

---

## 4. Session execution model (Charter PART 7)

**Charter:** All execution records must belong to sessions; session UX lightweight and task-first.

**Current state:** Ratings, applications, seeding, notes, photos, audit events are session-scoped. Session UX is task-first (session list, start/close, plot queue).

**Verdict:** **Aligned.**

---

## 5. Execution record integrity & corrections (Charter PART 8)

**Charter:** Records preserve historical truth; corrections create audit history rather than overwrite.

**Current state:** Rating corrections go to `RatingCorrections`; original rating unchanged; effective value derived; audit events for corrections; export includes correction metadata.

**Verdict:** **Aligned.**

---

## 6. Export lineage (Charter PART 10)

**Charter:** Each record must include trial, plot, **treatment**, session, operator, timestamp. Flattened exports that remove context are prohibited.

**Current state:** Export includes trial_id, session_id, plot_id, **treatment_id**, **treatment_code**, **treatment_name** (via join from plot → treatment), assessment, timestamps, operator/rater, provenance, correction metadata.

**Verdict:** **Resolved.** Treatment was added to session export rows (ExportRepository: leftOuterJoin on treatments, export of treatment_id/code/name). Full lineage per Charter PART 10 is satisfied.

---

## 7. Context resolution model (Charter PART 12, Constitution §15)

**Charter:** Screen → Provider → UseCase → DTO → UI. UI must not contain domain logic.

**Current state:** Assignment updates are routed through **UpdatePlotAssignmentUseCase** and **PlotRepository** (updatePlotTreatment / updatePlotsTreatmentsBulk). Trial detail screen “Assign Treatment” and “Save All” call the use case; UI only triggers actions and shows errors. Protocol lock is enforced in the use case.

**Verdict:** **Resolved.** Assignment updates no longer bypass the use case layer.

---

## 8. Protocol input gateway & import transparency (Charter PART 15, 16)

**Charter:** Protocol may enter via manual creation, structured spreadsheet import, or external adapter. All inputs normalize to the internal protocol model. **Import transparency:** source detection → structural scan → mapping attempt → validation → import review → user approval → integration. Four categories: Matched Successfully, Auto-Handled, Needs User Review, Must Fix Before Import. User must be able to resolve issues in the import interface; no silent guessing that could alter scientific structure.

**Current state:**

- **Manual creation:** Trials, treatments, plots, assessments, assignments (via plot UI) are created in-app. Aligned.
- **Structured import (plots):** CSV import now follows the transparency flow. **ImportPlotsUseCase.analyzeForImport()** performs structural scan and mapping (including column aliases e.g. Plot → plot_id), classifies results into the four categories (**ImportReviewResult**), and returns normalized rows only when there are no Must Fix errors. **ImportPlotsScreen** shows an **Import Review** card (Matched successfully, Auto-handled, Needs user review, Must fix before import) and an **“Approve and Import”** button; import runs only after user approval using normalized rows. Protocol lock still blocks import when trial is active.
- **Remaining gap:** Full “protocol” import (trial + treatments + plots + assignments + assessments) from one structured source is not yet implemented; current scope is plot-only CSV with full transparency for that scope.

**Verdict:** **Resolved** for the current plot-import scope. Charter PART 16 (transparency, four categories, user approval before integration) is satisfied for plot import. Full protocol import remains a future extension.

---

## 9. Offline execution (Charter PART 11)

**Current state:** Core workflows (sessions, ratings, applications, photos, export to file) work offline. No network dependency for field execution.

**Verdict:** **Aligned.**

---

## 10. Diagnostics & error presentation (Charter PART 4, Constitution §16–17)

**Current state:** AppError model, DiagnosticsStore, Diagnostics screen, copyable reports, integrity checks, runtime error capture. Two-level presentation (user message + diagnostic detail) is partially present (e.g. export failure message + diagnostics log).

**Verdict:** **Aligned.**

---

## 11. Plot identity rule (Constitution §7)

**Charter:** Plots.id is relational identity; plotId is display only. Relationships must not depend on display plot numbers.

**Current state:** FKs use `plot_pk` / `Plots.id`; `plotId` is display. Export and UI use internal id for joins.

**Verdict:** **Aligned.**

---

## 12. Lab / analytical layer (Charter PART 4, 22)

**Charter:** LabSamples, LabMeasurements; sample lineage intact.

**Current state:** Not implemented (Phase 6). Marked as future in roadmap.

**Verdict:** **Neutral.** Not a deviation; planned later.

---

## 13. Calculation / decision support (Charter PART 4)

**Charter:** Operational helpers (e.g. spray calculator, tank mix, seed rate, unit conversion).

**Current state:** No calculators in codebase.

**Verdict:** **Neutral.** Roadmap / expansion item.

---

## 14. Development control (Charter PART 14)

**Charter:** Phases → Milestones → Verification Gates; progress only when verification passes.

**Current state:** Verification is done via `flutter analyze` and tests; no formal “gate” checklist in repo. Constitution emphasizes quality-first development.

**Verdict:** **Neutral.** Practice is present; formal gates not documented in automation.

---

## Recommended fixes (in order of impact)

- **Export lineage:** ✅ Done. Treatment added to session export (join plot → treatment; treatment_id, treatment_code, treatment_name).
- **Context resolution:** ✅ Done. Assignment updates go through UpdatePlotAssignmentUseCase and PlotRepository.
- **Import transparency:** ✅ Done (for plot import). Four categories, Import Review card, Approve and Import flow.
- **Future:** Full protocol import (trial + treatments + plots + assignments from one source) when needed. Formal Assignments table when randomization/versioning/audit require it (see Constitution §8 and audit migration strategy).

---

## Conclusion

- **Aligned / resolved:** Spine (with assignment as documented MVP on Plots), protocol/execution separation, session model, execution integrity (corrections), offline operation, diagnostics, plot identity, assessment definition vs record, **export lineage**, **context resolution (assignment use case)**, **import transparency (plot import)**.
- **Neutral (ok for now):** No protocol Amendment entity yet; no Lab layer; no calculators; assignments implemented as Plots.treatmentId (documented in Constitution §8); verification gates not formalized.

The three previously identified negative deviations have been fixed. The app is aligned with the blueprint and constitution for the current scope; assignment formalization and full protocol import remain planned extensions.
