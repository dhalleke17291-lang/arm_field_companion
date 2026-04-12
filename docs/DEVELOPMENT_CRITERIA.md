# ARM Field Companion — Development Criteria & Quality-First Order

**Primary goal:** Develop the app **correctly, cleanly, safely, and to a high standard** on all major development criteria — not “finish phases” or chase milestone labels.

**User philosophy:** The app is developed with **researcher and technician convenience** in mind. This philosophy enhances acceptability: the app should fit their workflow, reduce friction in the field and lab, and earn their trust. When in doubt, favour choices that make the app more usable and acceptable to them.

---

## How to Judge Every Build Step

Ask: **“Does this make the app stronger across the important engineering dimensions?”**

Not: “What milestone is this?”

### The 10 Development Criteria

Every change should be evaluated against:

| Criterion | Question |
|----------|----------|
| **Architectural correctness** | Does it fit the frozen system cleanly? |
| **Data integrity** | Does it preserve protocol vs execution truth? |
| **Extensibility** | Can future lab/export/calculator features attach cleanly? |
| **Maintainability** | Is the code clear and coherent? |
| **Clarity of logic** | Is business logic in use cases, not widgets? |
| **UI consistency** | Does it match the current app shell and flow? |
| **Performance** | Does it avoid wasteful repeated logic? |
| **Debuggability** | Will failures be easier to understand after this change? |
| **Exportability** | Will this data be usable later in export? |
| **Future safety** | Does it avoid locking us into bad patterns? |

**If a change fails two or three of these, reject it.**

---

## What “Develop It Well” Means for This App

### 1. Strong data model

The schema must match **real research logic**, not temporary UI convenience.

### 2. Clean separation of concerns

Protocol, execution, diagnostics, export, and future lab/calculator logic must **not blur** into each other.

### 3. Stable internal communication

Screens should **consume resolved context**, not invent truth themselves.

### 4. Controlled extensibility

Future features should **plug in naturally** without redesign.

### 5. Safe implementation style

**No broad rewrites, no careless churn.** Smallest safe change that improves the app structurally.

### 6. Honest reliability

The app should **fail clearly**, not mysteriously.

---

## Quality-Driven Development Order

Not milestone language — **highest-value engineering order**:

### First: Strengthen the protocol backbone

Add and stabilize:

- TrialState
- Treatments
- TreatmentComponents
- PlotAssignments
- treatment/plot resolution queries
- canonical use cases
- PlotContext DTO
- Treatment screens
- plot detail treatment context

**Why first:** Highest-leverage improvement across correctness, cohesion, traceability, future expansion, export readiness, diagnostics quality, UI context quality.

### Second: Make execution symmetrical and disciplined

Strengthen:

- Applications engine
- shared execution pattern
- notes/photos/flags/deviations consistency
- session detail and status logic

### Third: Make the app operationally trustworthy

Add:

- login/user attribution
- AppError structure
- diagnostics UI
- export service foundation

### Fourth: Extend into broader research support

Then add:

- importer
- lab sample flow
- calculator support
- matrix view
- dashboards

---

## Standard to Hold Cursor (and Development) To

```text
Do not optimize for speed or scope completion.
Optimize for architectural correctness, data integrity, maintainability,
extensibility, UI consistency, diagnostics quality, and safe incremental change.

Preserve the current working app.
Do not perform broad refactors.
Do not rewrite unrelated files.
Make the smallest safe change that improves the app structurally.
```

---

## Checklist Before Accepting Any AI Change

Use this before accepting a change:

- [ ] **Architecture** — Does it fit the frozen system cleanly?
- [ ] **Data integrity** — Does it preserve protocol vs execution truth?
- [ ] **Cohesion** — Does it belong naturally with current modules?
- [ ] **Logic placement** — Is business logic in use cases, not widgets?
- [ ] **Safety** — Did it avoid unnecessary rewrites?
- [ ] **Extensibility** — Can future features attach cleanly?
- [ ] **Diagnostics** — Will failures be easier to understand?
- [ ] **Exportability** — Will this data be usable in export?
- [ ] **UI consistency** — Does it match the current app shell and flow?
- [ ] **Performance** — Does it avoid wasteful repeated logic?

**If a change fails two or three of these, reject it.**

---

## In One Sentence

You do not need milestones — you need **quality-first, architecture-safe, incremental development**, and the best next step is still to **strengthen the protocol backbone** before anything else.
