# ARM Field Companion — Master Architecture, Development, and Expansion Charter

**Final Frozen Edition**

This document is the **authoritative blueprint** for the project. Nothing in the frozen spine or constitutional rules is changed. The import system is integrated as a controlled protocol input gateway that obeys the constitution.

This charter governs: **architecture**, **execution workflows**, **protocol ingestion**, **validation**, **development phases**, **expansion**, and **user-visible transparency**.

---

## PART 1 — System Purpose

ARM Field Companion is a **protocol-aware, session-driven, offline** agricultural research execution platform.

The system connects the research workflow:

**Protocol Design → Field Execution → Lab Measurement → Diagnostics → Export → Derived Interpretation**

The system exists to ensure:

- scientific traceability  
- operational usability  
- data integrity  
- transparent research records  

---

## PART 2 — Core Philosophy

**Two realities must remain separate.**

- **Protocol** — The experimental design and scientific intent.  
- **Execution** — The observed field actions and measurements.

Execution records must remain traceable to protocol context **without mutating protocol truth**.

**Protocol defines structure. Execution records reality.**

---

## PART 3 — Frozen Dependency Spine

The architecture backbone is **permanently frozen**.

```
User
→ Trial
→ Treatments
→ TreatmentComponents
→ Plots
→ Assignments
→ AssessmentDefinitions
→ Sessions
→ ExecutionRecords
→ LabSamples
→ DerivedLogic
→ Diagnostics
→ Export
```

**All system behavior must maintain lineage through this spine. No feature may bypass or reorder it.**

---

## PART 4 — Architectural Layers

1. Identity & Access  
2. Protocol / Reference  
3. Field Execution  
4. Lab / Analytical  
5. Calculation / Decision Support  
6. Derived Logic  
7. Diagnostics  
8. Export  

Each layer owns a specific responsibility.

---

## PART 5 — Protocol Integrity Rules

Protocol structures include: **Trials**, **Treatments**, **TreatmentComponents**, **Plots**, **Assignments**, **AssessmentDefinitions**.

- **Once a trial becomes Active, protocol structures become read-only.**  
- Changes must occur through **Protocol Amendments**, preserving version lineage.  
- **Execution workflows must never mutate protocol truth.**

---

## PART 6 — Assessment Definition vs Assessment Record Rule (Frozen)

- **AssessmentDefinitions** belong to the **Protocol** layer. They define: measurement name, data type, allowed values, units, observation timing.  
- **AssessmentRecords** belong to **Execution**. They must: belong to Sessions, include operator attribution, timestamps, plot context.  
- **Protocol definitions must never store field observations.**

---

## PART 7 — Session Execution Model

Sessions represent field work events. Sessions provide: operator attribution, time context, grouping of execution records, audit traceability.

**All execution records must belong to sessions.** Session UX must remain lightweight and task-first.

---

## PART 8 — Execution Record Integrity

Execution records include: ratings, applications, seeding, notes, photos, flags, deviations.

**Records must preserve historical truth.** Corrections create audit history rather than overwrite values.

---

## PART 9 — Photo Evidence Rule

Photos are treated as evidence records. Photos must: remain immutable, preserve metadata (timestamp, operator, session). Annotations are allowed.

---

## PART 10 — Export Integrity Rule

Exports must preserve **full lineage**. Each record must include: trial, plot, treatment, session, operator, timestamp. **Flattened exports that remove context are prohibited.**

---

## PART 11 — Offline Execution Rule

Core field workflows must function **offline**. Users must be able to: start sessions, record observations, capture photos, log applications, close sessions — **without network connectivity.**

---

## PART 12 — Context Resolution Model

All domain context must follow:

**Screen → Provider → UseCase → DTO → UI**

**UI must not contain domain logic.**

---

## PART 13 — Implementation Doctrine (Frozen)

Implementation must preserve the architecture. Rules include:

- UI presents data but does not resolve domain truth  
- execution workflows cannot mutate protocol structures  
- relational joins must use internal IDs  
- session workflows must remain lightweight  
- execution modules must reuse shared patterns  
- exports must preserve lineage  
- development must follow milestone order  

---

## PART 14 — Development Control System

Development proceeds through: **Phases → Milestones → Verification Gates**

**Progress only continues when verification passes.**

---

## PART 15 — Protocol Input Gateway (Frozen)

Protocol data may enter the system through **controlled input paths**.

**Allowed sources:**

- Manual protocol creation  
- Structured spreadsheet import  
- External protocol adapter (such as ARM exports)  

**Regardless of source, all inputs must normalize into the internal protocol model.** Protocol import may never bypass validation or alter protocol integrity rules.

---

## PART 16 — Protocol Import Transparency & Intervention System (Frozen)

**Protocol imports must operate with full transparency to the user.**

The system must clearly communicate:

- what source type was detected  
- what structures were successfully matched  
- what fields were automatically mapped  
- what data was ignored  
- what **requires user review**  
- what **blocks import**  

### Import process sequence

**Source Detection → Structural Scan → Mapping Attempt → Validation → Import Review → User Approval → Protocol Model Integration**

### Import Status Categories

Import results must classify findings into four categories:

| Category | Meaning |
|----------|--------|
| **Matched Successfully** | Structures mapped without ambiguity. |
| **Auto-Handled** | Minor differences resolved automatically (e.g. column name normalization). |
| **Needs User Review** | Ambiguous mappings requiring confirmation. |
| **Must Fix Before Import** | Structural problems that would damage protocol integrity. |

### Manual Intervention Capability

The system must allow users to **resolve issues within the import interface**. Examples: selecting column mappings, resolving ambiguous identifiers, confirming treatment relationships, selecting correct assessment fields.

**The system must never silently guess when doing so could alter scientific structure.**

### Import Validation Rules

Before protocol import completes, the system must verify:

- trial identity exists  
- plots have unique relational keys  
- assignments reference valid plots and treatments  
- assessment definitions contain no field values  
- required protocol structures exist  

**If validation fails, import must pause and provide a clear error report.**

---

## PART 17 — Phase 1 – Structural Foundation

**Goal:** Establish stable architecture.

**Milestones:** M1 — Core Schema Stabilization | M2 — Protocol Read Model | M3 — Context UseCases

Verification ensures schema respects the dependency spine.

---

## PART 18 — Phase 2 – Session Execution Engine

**Milestones:** M4 — Session Engine | M5 — Shared Execution Pattern

Verification ensures execution modules behave consistently.

---

## PART 19 — Phase 3 – Vertical Workflow

**Milestone:** M6 — Applications Workflow

Assignments → Plot Context → Session → Execution Record → Export.

---

## PART 20 — Phase 4 – Diagnostics & Export

**Milestones:** M7 — Diagnostics Layer | M8 — Export Engine

Verification ensures exports maintain lineage.

---

## PART 21 — Phase 5 – Execution Expansion

**Milestones:** M9 — Ratings | M10 — Notes / Photos / Flags | M11 — Seeding

All modules reuse shared execution patterns.

---

## PART 22 — Phase 6 – Analytical Integration

**Milestones:** M12 — Lab Sample Tracking | M13 — Lab Measurements

Sample lineage must remain intact.

---

## PART 23 — Phase 7 – Derived Intelligence

**Milestone:** M14 — Derived Logic

Examples: trial progress, session progress, completeness checks. **Derived logic must never overwrite raw evidence.**

---

## PART 24 — Danger-Checkpoint Controls (Frozen)

Five predictable failure points are controlled:

1. Schema Drift Control  
2. Single Source Behavior Rule  
3. MVP Ruthlessness Rule  
4. Trust Visibility Rule  
5. Pattern Consolidation Rule  

These rules protect architectural integrity during development.

---

## PART 25 — Final Architecture Verification

Before system stabilization verify:

- dependency spine preserved  
- protocol vs execution separation intact  
- session engine stable  
- context resolution centralized  
- export lineage preserved  
- offline operation reliable  

---

## PART 26 — Long-Term Expansion Roadmap

Future extensions may include: Research Intelligence, Operational Tools, Weather and GPS integration, ARM/EDE advanced adapters, Team collaboration features, Advanced analytics dashboards.

**All expansion must respect the frozen architecture.**

---

## Final Governing Principle

- The **architecture spine** remains frozen.  
- **Protocol truth** remains separate from execution evidence.  
- **Sessions** anchor field work context.  
- **Derived logic** interprets evidence without altering it.  
- **Development** proceeds through verified milestones.  
- **Expansion** occurs only after structural stability is proven.

---

*This document functions as the complete governance system for the project and is intended to be followed as the authoritative blueprint for building the app.*
