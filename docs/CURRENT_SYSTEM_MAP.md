# Agnexis — Current State

**As of May 6, 2026. Schema v82. 2150 tests passing. Analyzer clean.**

> This document supersedes `PRODUCT_ROADMAP_AND_SYSTEM_MAP.md` and `WHAT_TO_DO_NEXT.md`.
> Both are archived with SUPERSEDED headers. Do not use them for build decisions.

---

## What Agnexis Is

**Product thesis:** A trial is a claim under evidence.

**Positioning:** Agnexis connects the protocol's claim to ARM's structure and the field's evidence, then shows whether they still align.

**Current label:** Trial Integrity & Field Execution System.
**Future label (earned post-pilot):** Field Trial Intelligence System.

**Target customers:**
- Tier 1 — GLP/regulated CRO (full provenance, premium)
- Tier 2 — Professional non-GLP CRO/multi-site
- Tier 3 — University/extension/breeding
- Tier 4 — On-farm/simple trials (freemium)

---

## Architecture — Frozen Dependency Spine

Do not invert this chain. All future work extends it.

```text
User
  → Trial (workspace type: ARM-linked | standalone — permanent after creation)
    → Treatments + TreatmentComponents
    → Plots + Assignments (locked when Active)
    → Assessments
    → trial_purposes (intent: Mode A/B/C)
  → Sessions
    → Seeding records
    → Application events (confirmed with GPS + weather)
    → Rating records (ALCOA+ locked after confirmation)
    → Notes, Photos, Evidence anchors
  → Signals (open | deferred | investigating | resolved | expired | suppressed)
    → SignalDecisionEvents (immutable log)
    → ActionEffects (data change log)
  → Trial Cognition (live projections — never stored derived state)
    → trialPurposeProvider
    → trialEvidenceArcProvider (StreamProvider — table-reactive)
    → trialCriticalToQualityProvider (StreamProvider — table-reactive)
    → trialCoherenceProvider (StreamProvider — table-reactive)
    → trialInterpretationRiskProvider (StreamProvider — table-reactive)
    → trialNarrative (V2 — post-pilot)
  → Export (ARM Rating Shell, XML, PDF, CSV)
```

**Foundational rule:** Store only facts immutably. Derive all conclusions as live computations. Never store derived state as fact.

---

## Domain Status — Accurate as of May 2026

### 1. Identity and Access

- User attribution on sessions, exports, audit events ✅
- Local user context ✅
- Role permissions — not implemented (post-pilot)

### 2. Protocol / Reference

- Trials, treatments, treatment components ✅
- Plot structure, randomization, assignments ✅
- Assessments (library + custom) ✅
- Protocol lock when Active/Closed/Archived ✅
- ARM import — full trial structure import ✅
- ARM identity frozen for linked trials ✅
- Workspace type permanent after creation ✅

### 3. Field Execution

- Sessions with GPS + weather capture ✅
- Seeding records ✅
- Application events with BBCH, GPS, weather ✅
- Rating records with ALCOA+ field locking ✅
- Notes, photos, evidence anchors ✅
- Execution field locking on confirmed events ✅
- Amendment reason collection (GLP required, standalone optional) ✅
- Session close diagnostic with signal writers ✅

### 4. Intent Capture

- Mode C — 5-question revelation flow at natural touchpoints ✅
- Mode A (structured GLP study plan, LLM-extractable) — schema ready, UI not wired
- Mode B (prose protocol, manual passage linking) — schema ready, UI not wired
- `regulatory_context`, `known_interpretation_factors`, `readiness_criteria_summary` columns ✅
- Commercial context question at trial creation ✅
- Confounder checklist at first session ✅

### 5. Signal Architecture

- Three signal writers live: scale violation, AOV error variance, replication warning ✅
- Timing window writer ✅
- Signal lifecycle: open → deferred/investigating → resolved/expired/suppressed ✅
- Decision ledger: Signal + SignalDecisionEvent + ActionEffect ✅
- Signal decision UI (confirm/investigate/defer/suppress with reasoning) ✅
- Signal family registry (untreatedCheckVariance, raterDivergence, timingWindowReview, replicationPattern, singleton) ✅
- SignalReviewGroupProjection with familyScientificRole, familyInterpretationImpact, reviewQuestion ✅
- Section 9 grouped cards with expandable interpretation context ✅

### 6. Trial Cognition — V1 Complete

All five providers are **StreamProvider** (table-reactive, never stale):

| Provider | Tables watched | Status |
|----------|---------------|--------|
| `trialEvidenceArcProvider` | sessions, ratingRecords, photos, evidenceAnchors, plots | ✅ Stream |
| `trialCriticalToQualityProvider` | treatments, photos, ratingRecords, plots, signals, trialApplicationEvents, assignments, treatmentComponents, trials | ✅ Stream |
| `trialCoherenceProvider` | trialPurposes, assessments, trialApplicationEvents, treatments, treatmentComponents, trials, assignments, signals, researcherDecisionEvents | ✅ Stream |
| `trialInterpretationRiskProvider` | ratingRecords, treatments, assessments, trialPurposes, plots, assignments, signals | ✅ Stream |
| `openSignalsForTrialProvider` | signals | ✅ Stream |

**Constitution for Trial Cognition (binding):**

- No silent intent
- No silent CTQ
- No silent readiness
- No LLM extraction without source passage
- No trial conclusion claims
- No treatment superiority claims
- No statistical significance claims

### 7. Trial Review — 10 Sections

1. Trial Identity and Purpose
2. Design Summary
3. Execution Arc
4. Critical-to-Quality Status (CTQ)
5. Primary Endpoint Evidence
6. Comparison Readiness
7. Deviations Affecting Interpretation
8. Environmental Evidence
9. Open Decisions and Unresolved Signals
10. Trial Readiness Statement

All sections stream-reactive. Export gate enforced by readiness statement.

### 8. Environmental Evidence Layer

- `trial_environmental_records` schema ✅
- Daily min/max temp + precipitation per trial site ✅
- Event-linked windows (72h pre-application, 48h post-application) ✅
- Section 8 rendering with application windows ✅
- GPS gap: Section 8 reads trial site coordinates, not session GPS — known issue, post-pilot

### 9. ARM Integration

- ARM Rating Shell import (copy-and-inject, header rows preserved) ✅
- ARM Rating Shell export (value injection only, ARM Action Codes round-tripped verbatim) ✅
- ARM XML export ✅
- ARM photo export (clean-named files + manifest CSV) ✅
- ARM identity frozen for linked trials ✅
- ARM does not auto-link photos — manual attachment confirmed ✅

### 10. Export

- ARM Rating Shell (Excel) ✅
- ARM XML ✅
- PDF ✅
- CSV (ratings + audit) ✅
- Export gate wired to readiness statement ✅
- `is_current` export gate on all rating paths ✅

---

## Test Coverage

| Suite | Count |
|-------|-------|
| Full suite | 2150 |
| Domain trial cognition + features/trials | 482 |
| Schema | v82 |

---

## Reliability Tiers for Signals

| Tier | Signals | Default |
|------|---------|---------|
| HIGH | Scale violation (~100%), AOV error variance (~95%), replication warning (~85%) | On, not toggleable |
| MEDIUM | Between-rater divergence, spatial anomaly peak efficacy, AOV skewness/Levene's | Toggleable, moderate language |
| LOW | Spatial anomaly early season, rater drift, threshold learning | Toggleable, observational language |

Language must match tier. No statistical vocabulary in user-facing signal text.

---

## Known Gaps — Honest

| Gap | Severity | Plan |
|-----|----------|------|
| Environmental GPS wiring — Section 8 reads trial site coordinates, session GPS not linked | Medium | Post-pilot investigation |
| Mode A/B intent capture — schema ready, no UI | Low | V2 |
| `trial_purposes` not seeded by ARM import | Low | Edge case fix, low priority |
| Session created with no `trial_purposes` row — interpretation factors silently dropped | Low | Tracked, create minimal partial row before writing |
| Rating Reference Assist ("Guide" button) — schema exists, no UI | Low | Post-pilot |
| Canadian biological profile seeding — deferred pending BBCH/GDD schema | Low | V2 |
| `trialNarrative` provider (V2) | Low | Post-pilot, needs real data |

---

## What Not to Build Before Pilot

- Multi-user sync
- Lab sample flow
- Calculators
- Assignment matrix view / dashboards
- Mode A/B protocol document linking
- V2 trial narrative
- Rating Reference Assist UI
- Canadian biological profiles

---

## Post-Pilot Priorities (in order)

1. **Table-stream conversion verification** — confirm no rebuild loops or race conditions under real field load
2. **Environmental GPS wiring** — link session GPS to Section 8 environmental fetch
3. **Documentation sprint** — update all stale docs, clean duplicate files, update Sentry DSN handling
4. **Large file refactor** — `app_database.dart` (3600+ lines), providers file, large UI files — extract gradually, no broad rewrite
5. **V2 narrative provider** — `trialNarrative` once real pilot data exists to reason against
6. **Mode A/B intent capture** — protocol document linking with audit trail
7. **Rating Reference Assist** — Guide button on rating screen with assessment-specific visual anchors

---

## Sprint History (condensed)

| Sprint | What | Status |
|--------|------|--------|
| A0 | Decision ledger UI — signal confirm/investigate/suppress/defer with reasoning | ✅ |
| A1–A3 | Rating Reference Assist schema, surface audit, design token pass | ✅ |
| A4 | CTQ acknowledgment wiring | ✅ |
| B1 | Structured intent answer foundation — codecs, regulatory context, readiness criteria | ✅ |
| B2a | Commercial context question at trial creation | ✅ |
| B2b | Confounder checklist at first session | ✅ |
| Pre-Pilot Surface Audit | 12 surface fixes — Acknowledge gates, BBCH on session tiles, coherence summary, GPS message, sections 5/6 null cases | ✅ |
| Unit 3A.1 | Signal family registry — SignalFamilyKey, groupingBasis, deterministic grouping | ✅ |
| Unit 3A.2 | Family interpretation depth — familyScientificRole, familyInterpretationImpact, reviewQuestion | ✅ |
| Unit 4A | Family depth fields in SignalReviewGroupProjection | ✅ |
| Unit 4B | Section 9 grouped cards with expandable interpretation context | ✅ |
| Stream conversion | All 5 Trial Review providers converted from FutureProvider to StreamProvider | ✅ |
| CTQ staleness fix | 7 invalidation callsites + centralised utility (now superseded by stream conversion) | ✅ |
| B3 | `_factorSiteConditions` — `known_interpretation_factors` wired into interpretation risk + readiness cautions | ✅ |
| **Next** | **Atlantic AgriTech PEI pilot** | **→** |
