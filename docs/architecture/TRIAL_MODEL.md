# Agnexis Trial Model — Architectural Principle Document

## Purpose
This document defines the non-negotiable architectural principles governing all data storage, computation, and presentation in Agnexis. Every pull request, every new feature, and every Cursor prompt must be checked against this document before implementation begins.

## The Foundational Principle
A field trial is a causal system in reality. Agnexis represents that reality honestly.

When the data model mirrors causal reality, the trial reveals itself. Intelligence is not engineered — it emerges from honest representation. The trial is alive when its state is always a live computation, never a stored artifact.

## The Four Layers

### Layer 1 — Fact Layer (database)
Contains only real-world captured facts: events that happened, attributes recorded at the moment they occurred.

**Allowed in this layer — three stored categories:**

**RAW FACT** — real-world event or attribute captured directly at the time it occurred:
- Events: seeding, emergence, applications, ratings, session open/close, photo capture, audit entries
- Attributes recorded at capture time: GPS coordinates, timestamps, weather conditions, rater identity, lot/batch codes
- Protocol definitions imported from ARM shell: treatment structure, plot layout, SE column definitions

**FACT SNAPSHOT** — time-bound evaluation recorded as part of a specific event, never recomputed after, even if derivable in principle:
- A quality or provenance score evaluated against source data that is discarded after the event (e.g., `exportConfidence`: CSV quality score at parse time, against a CSV that is then discarded)
- A diagnostic record of what a specific past system event produced, always labeled as time-bound (e.g., `findingsJson`: findings from one specific export attempt)
- A structural property of source data that cannot be reconstructed once the source is discarded (e.g., `hasSparseData`: whether any assessment cell in the imported CSV was null)

**ROUND-TRIP STORAGE** — verbatim external data preserved for compatibility, never used as internal truth:
- Values held verbatim for ARM export compatibility (marked explicitly)
- Import tokens and column signatures needed to reproduce export column order

**Never allowed in this layer:**
- Status fields computed from other facts
- Completeness flags or scores
- Counts or aggregates derived from child records
- Quality scores or confidence labels computed at query time
- Any field that becomes wrong when underlying facts change without being updated

**The test:** Would this column still be correct if we never updated it after insert? If yes, it is a fact. If no, it is derived state.

### Layer 2 — Primitive Layer (Riverpod providers)
Pure computational building blocks. No domain meaning. No persistence. Fully deterministic and independently testable.

**Primitives to build:**
- eventOrderingProvider — orders events by timestamp within a scope
- windowProvider — filters events within a time or DAT window
- groupingProvider — groups records by treatment, rep, session, or plot
- comparisonProvider — computes delta, ratio, deviation from mean
- statsProvider — computes mean, standard deviation, CV, count

**Rules:**
- Primitives never access the database directly — they receive data as input
- Primitives have no domain vocabulary (no "treatment", no "session" in their logic)
- Primitives are never consumed directly by UI — UI only consumes relationship layer
- Every primitive must be testable without any domain context

### Layer 3 — Relationship Layer (Riverpod providers)
Named domain concepts composed from primitives. This is what screens, reports, and exports consume.

**Relationships to build:**
- protocolDivergenceProvider — planned vs actual across timing, rate, columns, dates
- causalContextProvider — application events and conditions within biological window for any rating
- behavioralSignatureProvider — rater pace, confidence trajectory, edit patterns per session
- spatialStructureProvider — rep effects, neighbor patterns, check plot baseline drift
- evidenceAnchorsProvider — photos, weather, GPS linked to specific claims
- chronologyProvider — event sequence with intervals and gaps

**Rules:**
- Relationships are composed from primitives, never from raw database queries directly
- Relationships consume SETypeProfile where biological windows are needed
- Relationships are named by domain concept, not by computation
- UI never bypasses relationships to call primitives directly
- New screens get new relationships, not new primitives wired directly to UI

### Layer 4 — Interpretation Layer (pure functions)
Thin deterministic mapping from numerical relationship outputs to human-readable consequence statements.

**Rules:**
- No database access
- No primitive calls
- No new computation or reasoning
- No combining of multiple relationships into a verdict
- Input: a single numerical value or severity enum from the relationship layer
- Output: a string message and severity label
- Every mapping is a simple lookup or threshold check, nothing more

**Example of correct interpretation:**
```
interpretCV(double cv) → (message: "High variability — results less reliable", severity: warning)
```

**Example of incorrect interpretation (belongs in relationship layer):**
```
// WRONG — this is reasoning, not translation
if (cv > 60 && drift > 20) return "Unreliable trial"
```

## SETypeProfile — First-Class Entity
SETypeProfile is load-bearing infrastructure, not configuration. Every biological-window-dependent relationship depends on it. If profiles are wrong, the relationship layer produces confident wrong answers.

**Minimum fields per profile:**
- validObservationWindow: the DAT range within which ratings are biologically meaningful
- expectedResponseDirection: whether efficacy increases or decreases with treatment
- varianceExpectation: expected CV range for this SE type under normal conditions
- sensitivityToTiming: how much timing deviation affects rating validity

**Sources:**
- EPPO PP1 standards (free general standards PP1/152, PP1/181, PP1/135)
- ARM shell metadata where available
- Expert elicitation post-pilot

**Rule:** No biological-window computation surfaces in UI until the relevant SETypeProfile exists and is sourced from a defensible reference.

## The Non-Negotiable Rule
**Derived state is never stored. Everything above the Fact Layer is computed.**

A stored value is allowed in Layer 1 only if it records what happened, what was observed/imported, or what was evaluated at a specific event. A value that changes meaning when underlying facts change without being updated is derived state and must move above the fact layer.

If you find yourself adding a column that summarizes, counts, classifies, flags, or caches — stop. That belongs in a provider.

If you find yourself reading a stored field to avoid a query — stop. Write the provider instead.

If Cursor generates a status column or completeness flag — reject it. Redirect to the relationship layer.

## Known FACT SNAPSHOT Instances
These columns are correct applications of the FACT SNAPSHOT category. They are not exceptions — they satisfy the Layer 1 rule. Listed here because they were previously treated as anomalies before the FACT SNAPSHOT doctrine was formalised.

| Column | Table | What Event They Record | Why Not Recomputable |
|--------|-------|------------------------|----------------------|
| exportConfidence | compatibility_profiles | CSV quality score evaluated at parse time against data discarded after import | ArmColumnClassification list is not stored; raw CSV is discarded; re-running the scorer on partial metadata produces wrong results for old snapshots |
| findingsJson | trial_export_diagnostics | Findings produced by one specific past export attempt | Not current state — records what a past export event found; UI must always label as "from last export attempt" |
| hasSparseData | import_snapshots | Whether any assessment cell in the imported CSV was null | Cell-level data is not stored after import; no reconstruction path without the original CSV |

## Known Exceptions (documented, not precedents)
These columns do not fit the three stored categories. They are accepted with explicit constraints. Neither is a precedent for future columns.

| Column | Table | Classification | Why Accepted | Constraint |
|--------|-------|----------------|--------------|------------|
| isCurrent | rating_records | Maintained index | Written atomically by a single write path; functions as a database-level index over the version chain. Not a precedent for other maintained flags. | Must only be written by rating_repository.dart |
| plotsTreated | trial_application_events | DERIVED STATE — transitional cache | PENDING MIGRATION — dual-write in place alongside ApplicationPlotAssignments junction table, which is the canonical source | Do not add new reads. Switch reads to ApplicationPlotAssignments, remove writes, drop column after stability. |

## PR Checklist
Before merging any pull request, verify:

- [ ] No new columns added that summarize, count, classify, or cache computed values
- [ ] No new status fields added to any table
- [ ] New UI features consume relationship providers, not raw database queries
- [ ] New relationship providers are composed from primitives, not raw queries
- [ ] New primitives have tests that pass without domain context
- [ ] SETypeProfile exists for any biological-window computation before it surfaces in UI
- [ ] Interpretation layer functions contain no computation logic — mapping only
- [ ] isCurrent is only written in rating_repository.dart
- [ ] plotsTreated has no new read locations added

## Build Sequence
1. This document (complete)
2. Schema audit — docs/architecture/SCHEMA_AUDIT.md (complete)
3. Derived state investigation — docs/architecture/DERIVED_STATE_INVESTIGATION.md (complete)
4. SETypeProfile as first-class entity — MVP profiles for weed control, phytotoxicity, vigor
5. Primitive layer providers — eventOrdering, window, grouping, comparison, stats
6. Compose protocolDivergence as first relationship — expose on rating screen, session screen, results screen
7. Interpretation layer for protocolDivergence
8. plotsTreated migration — switch reads to ApplicationPlotAssignments, remove writes, drop column
9. Fact base capture — session lock, trusted time, GPS per record, lot/batch codes
10. Pilot — success criterion: auditor picks any value, system shows constituting facts and relationships
