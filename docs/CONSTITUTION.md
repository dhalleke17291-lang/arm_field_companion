# ARM Field Companion — Master Architecture & Development Constitution

**Authoritative blueprint:** The full **Master Architecture, Development, and Expansion Charter** (including Protocol Input Gateway and Protocol Import Transparency & Intervention System) is in **docs/MASTER_CHARTER.md**. That document is the governing blueprint; this constitution is an in-repo summary aligned with it.

**Governing principle:** Freeze the architecture spine, preserve lineage and traceability, and extend capability without redesign.

**Primary development goal:** Develop the app **correctly, cleanly, safely, and to a high standard** on all major development criteria. Judge every build step by whether it improves the app on architectural correctness, data integrity, extensibility, maintainability, clarity of logic, UI consistency, performance, debuggability, exportability, and future safety. See **docs/DEVELOPMENT_CRITERIA.md** for the full quality-first framework and the standard to hold development to.

---

## 1. Product Identity

ARM Field Companion is a **protocol-aware, session-driven, offline** agricultural research execution platform.

It connects: **Trial protocol → Field execution → Analytical results → Diagnostics → Export.**

The system supports **structured agricultural research workflows**, not simple note-taking.

**User focus:** Development is guided by **researcher and technician convenience**. Every design and implementation choice should enhance the acceptability of the app for them — the people in the field and in the lab who will use it daily.

---

## 2. Core Philosophy

- **Protocol** (the plan) and **Execution** (real field actions) remain separate.
- The system records reality against the plan while preserving traceability.
- **Researcher and technician convenience** drive acceptability; the app should fit their workflow, reduce friction, and earn their trust.

---

## 3. Architectural Layers

1. Identity & Access  
2. Protocol / Reference  
3. Field Execution  
4. Lab / Analytical  
5. Calculation / Decision Support  
6. Derived Logic  
7. Diagnostics  
8. Export / Output  

---

## 4. Dependency Spine (Frozen)

User → Trial → Treatments → TreatmentComponents → Plots → Randomization/Assignments → Assessments/Protocol Fields → Sessions → Execution Records → Lab Samples → Derived Logic → Diagnostics → Export  

**This order is fixed.** Dependencies must not be inverted.

---

## 5. Identity & Access Layer

- Handles authentication and attribution.
- Includes login, users, roles, and current user context.
- Used for session ownership, audit trail, and export attribution.

---

## 6. Protocol / Reference Layer

- Defines experimental design: trials, treatments, treatment components, plots, randomization assignments, assessments, protocol field definitions.
- **Protocol data is read-only during field execution.**

---

## 7. Plot Identity Rule

- **Plots.id is relational identity.** `plotId` is display only.
- Relationships must **never** depend on display plot numbers.

---

## 8. Randomization / Assignment Model

- Assignments define which treatment is applied to which plot.
- Assignments are **protocol truth** and **read-only during execution.**

**Current implementation (MVP):** Assignments are implemented as **`Plots.treatmentId`** (a denormalized FK on the plot row). There is no separate Assignments table. This is an acceptable MVP stand-in: protocol lock applies to this field, and context resolution/export read assignment truth from it. When randomization metadata, assignment history, or versioned amendments are required, the target is a **first-class Assignments table** with a documented migration path from `Plots.treatmentId`. See architecture audit and docs/BLUEPRINT_DEVIATION_REPORT.md.

---

## 9. Trial Lifecycle State

Draft → Ready → Active → Closed → Archived  

Once **Active**, structural protocol edits are restricted to protect research integrity.

**Definitions vs execution.** Locking applies to **protocol definitions** (assessment definitions, plots, assignments). **Recording execution values** (e.g. ratings, notes, application records) in sessions must remain allowed in active trials. Do not confuse “Add Assessment” (definition) with “record a rating” (execution).

**Strict transitions.** Status changes must follow the defined path only. Do not introduce casual “reopen” or status jumping unless explicitly designed.

**Future amendments.** If protocol changes are ever required after activation, they should go through an **amendment / versioned** path (auditable, traceable), not ad-hoc unlock. Design for this when the need arises.

---

## 10. Field Execution Layer

- Execution records capture real activities: **Sessions, Seeding, Applications, Ratings, Notes, Photos, Flags, Deviations, and Audit Events.**
- **All records must belong to a Session.**

---

## 11. Sessions

- Sessions group field activities and provide time context, operator attribution, and audit traceability.

---

## 12. Lab / Analytical Layer

- LabSamples and LabMeasurements capture analytical results.
- Samples maintain lineage from trial/plot context to lab measurements.

---

## 13. Calculation / Decision Support

- Operational helpers: spray calculators, tank mix calculators, seed quantity calculators, unit conversions.
- **Calculator outputs assist workflows but do not replace recorded execution values.**

---

## 14. Derived Logic Layer

- **Business logic lives in UseCases**, not in UI components.
- Examples: ResolvePlotTreatment, GetPlotContext, TrialProgress, SessionProgress.

---

## 15. Context Resolution

**Screen → Provider → UseCase → DTO → UI.**  

Relationships are resolved centrally and reused across screens.

---

## 16. Diagnostics Layer

- Structured error inspection: AppError models, diagnostics screen, error codes, copyable reports for debugging.

---

## 17. Error Presentation

- **Two levels:** user-friendly error message and full diagnostic detail for developers.
- Both come from the same structured **AppError**.

---

## 18. Export Layer

- Exports assemble: trial, treatments, plots, assignments, sessions, execution records, user attribution, lab data, audit metadata.
- Initial formats: JSON and CSV.

---

## 19. Module Ownership

| Layer        | Owns                                              |
|-------------|----------------------------------------------------|
| Identity    | users, login                                      |
| Protocol    | trial design                                      |
| Execution   | sessions, field data                              |
| Lab         | samples, measurements                             |
| Diagnostics | error inspection                                  |
| Export      | data output assembly                              |

---

## 20. UI Structure

- **Primary modules:** Plots, Sessions, Seeding, Applications, Assessments, Treatments. **Future:** Lab.
- **Support views:** assignment matrix, protocol summaries.

---

## 21. Complexity Control Rule

- **Only frequently used functions become top-level modules.**
- Other concepts stay as subviews, support views, or internal tools.

---

## 22. Implementation Guardrails *(strict)*

- **Screens must not contain business logic.** Delegate to UseCases.
- **Canonical context models must be reused.** No ad-hoc duplication.
- **All records must remain exportable and attributable.**
- **Diagnostics must capture structured failures.**
- **Quality bar:** No errors, no bugs, no broken internal strings; everything must run smoothly. Strive for excellence.

---

## 23. Shared Execution Engine Pattern

- Seeding and Applications share a structure: session ownership, list/add/detail flow, dynamic fields, attachments, flags, audit history.

---

## 24. Development Milestone Plan *(informational only)*

Milestones are for roadmap context only. **All work must follow the strict app development parameters below** regardless of phase.

| Milestone | Focus |
|-----------|--------|
| 1 | Protocol-aware read model |
| 2 | Field execution MVP |
| 3 | Attributable, diagnosable, exportable MVP |
| 4 | Import-ready platform |
| 5 | Lab integration |
| 6 | Operational intelligence tools |
| 7 | Advanced expansion |

---

## 25. Immediate Development Focus *(informational only)*

Treatments → TreatmentComponents → Assignments → Context UseCases → Treatment Screens → Plot Context Integration → Applications Module → Login → Diagnostics → Export Foundation.

---

## 26. Key Risks Controlled

- Context resolution fragmentation  
- Diverging execution engines  
- Over-linked schema complexity  

---

## 27. Governing Principle

**Freeze the architecture spine, build in testable milestones, preserve lineage and traceability, and extend capability without redesign.**
