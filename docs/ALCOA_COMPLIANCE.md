# ALCOA+ Compliance Document

**Application:** Agnexis Field Companion  
**Audience:** CRO / Study Directors, Regulatory Affairs, Developers  
**Date:** 2026-04-26  
**Status:** Living document — update when schema or audit logic changes

---

## 1. What is ALCOA+?

ALCOA+ is the data-integrity framework required by GLP, GEP, and ICH E6(R2). Every field data record must be:

| Principle | Meaning |
|-----------|---------|
| **A**ttributable | Who collected or changed the data, and when |
| **L**egible | Readable now and in the future |
| **C**ontemporaneous | Recorded at the time of the activity |
| **O**riginal | First capture; no undocumented copies |
| **A**ccurate | Free from errors and bias |
| **C**omplete | All required data present; no gaps |
| **C**onsistent | Internal timestamps and sequences do not contradict each other |
| **E**nduring | Records preserved for the required retention period |
| **A**vailable | Accessible to inspectors on request |

---

## 2. Implementation by Principle

### 2.1 Attributable

**Implementation:**
- Every rating row stores `performedBy` (display name) and `performedByUserId` (FK to `users` table).
- `saveRating` requires a user identity; anonymous saves are rejected at the repository layer.
- `updateRating` writes `lastEditedBy` and `lastEditedByUserId` when metadata is changed.
- `applyCorrection` writes `correctedBy` and `correctedByUserId` on the correction record.
- All `audit_events` rows carry `performedBy` and `performedByUserId`.
- GPS coordinates (`capturedLatitude`, `capturedLongitude`) are stored on `rating_records` when location is available.

**Limitations:**
- Device-level authentication is not enforced; the app relies on the user-selection screen. A shared device could allow one user to record under another's identity if the session is not handed over.

**Status:** ✅ Implemented with noted device-sharing caveat.

---

### 2.2 Legible

**Implementation:**
- All data is stored in a SQLite database (Drift ORM) with typed columns — no free-text blobs for structured data.
- Encrypted `.agnexis` backup files contain a complete SQLite snapshot readable after decryption.
- `audit_events.description` is plain English prose, not a code or token.
- Export renders data as human-readable CSV/PDF.

**Status:** ✅ Implemented.

---

### 2.3 Contemporaneous

**Implementation:**
- `rating_records.createdAt` is set to `DateTime.now().toUtc()` at insert time in `saveRating` — no caller-supplied timestamp is accepted for the creation time.
- `audit_events.createdAt` is server-assigned at insert (Drift default: `DateTime.now()`).
- Session `startedAt` and `closedAt` are device-clock timestamps recorded at the moment the action occurs.
- Weather snapshots are captured at session-close time, tagged with the session's `startedAt` as the activity timestamp.

**Limitations:**
- Device clock manipulation is not detected. A user who sets the device clock backward before rating will produce a misleading `createdAt`. No NTP sync check is performed.
- Application events (`TrialApplicationEvents`) and seeding events (`SeedingEvents`) record `appliedAt` / `completedAt` via caller-supplied values; no independent server timestamp validates these.

**Status:** ⚠️ Contemporaneous for ratings; partially contemporaneous for execution events (caller-supplied timestamps, no clock-integrity check).

---

### 2.4 Original

**Implementation:**
- `saveRating` always INSERTs a new row; it never UPDATEs `numericValue`, `textValue`, or `resultStatus` in place. The version chain is maintained via `isCurrent` flag.
- When a researcher changes an existing current rating, the rating screen collects `amendmentReason` (required for GLP workspace trials, optional otherwise) and persists it on the new INSERT row together with `amended = true` and `previousId` — satisfying **Accurate** / traceable “why” for value or status changes.
- `updateRating` is restricted to metadata-only fields (`amendmentReason`, `amendedBy`, `confidence`, `lastEditedByUserId`). Any attempt to change value fields via `updateRating` is rejected by compile-time field absence.
- Hard deletes are prohibited; soft-delete (`isDeleted = true`) preserves the original record.
- `applyCorrection` inserts a new `rating_corrections` row and marks the original rating as `amended = true`; the original numeric value is never overwritten.

**Status:** ✅ Implemented. Version chain enforced at repository layer.

---

### 2.5 Accurate

**Implementation:**
- `_assertCoreNumericColumnIntegrity` enforces that non-recorded statuses cannot store a numeric value; unknown statuses are rejected.
- `RatingIntegrityException` is thrown — not silently swallowed — when invariants are violated.
- Photo evidence is linked to ratings and trials via FK, providing visual corroboration.
- Weather data is captured at session close to provide environmental context for recorded observations.

**Limitations:**
- Numeric value range validation (e.g., scale 1–9) is not enforced at the database layer; it is delegated to the UI. A direct DB write bypassing the UI could insert out-of-range values.

**Status:** ⚠️ Accurate at app layer; no DB-level numeric range constraints.

---

### 2.6 Complete

**Implementation:**
- The Trial Intelligence Grid surfaces all plots that have no rating for any assessment, making gaps visible to the researcher before session close.
- Session summary screen shows completion percentage before the researcher closes a session.
- `audit_events` captures every rating save, correction, and metadata update — no silent mutations.

**Limitations:**
- Application events and seeding events have no mandatory-field enforcement beyond the UI. A record can be saved with `appliedAt = null`.
- Weather is only captured for rating sessions, not for application or seeding events (see Gap Register, §4).

**Status:** ⚠️ Complete for ratings; execution events have optional temporal fields.

---

### 2.7 Consistent

**Implementation:**
- All timestamps are stored as UTC and converted to local time only at display.
- `rating_records.lastEditedAt` is always ≥ `createdAt` (enforced by write order).
- The `isCurrent` flag is managed transactionally in `saveRating` to prevent two rows sharing `isCurrent = true` for the same logical key.
- `audit_events` rows are inserted within the same logical operation as the data mutation they describe.

**Limitations:**
- There is no cross-table consistency check that validates `session.closedAt` > all `rating_records.createdAt` within that session. Inconsistencies from clock jumps would not be detected.

**Status:** ⚠️ Consistent within normal operation; no clock-consistency guard.

---

### 2.8 Enduring

**Implementation:**
- Primary storage is SQLite on the device filesystem (not in-memory).
- Encrypted `.agnexis` backup format is a standard ZIP + AES-256 layer over a SQLite file — restorable without proprietary tooling after decryption.
- Auto-backup silently saves up to 3 rolling backups to the device's application documents directory.
- Manual backup exports to Google Drive, OneDrive, or local share.
- Soft-delete preserves all records indefinitely on device.

**Limitations:**
- Retention schedule (e.g., GLP minimum 15 years) is the responsibility of the CRO, not the app. The app does not enforce a retention period or alert when backups are stale beyond configurable thresholds.
- The `audit_events` table has no archival-to-read-only-store mechanism. All records remain live in the working database.

**Status:** ✅ Records endure on device and in backup. Retention schedule is CRO responsibility.

---

### 2.9 Available

**Implementation:**
- Backup files are sharable via the OS share sheet to any destination the CRO designates.
- Google Drive and OneDrive integrations provide cloud availability.
- Export (CSV, PDF) produces inspector-ready artefacts without requiring app access.
- The backup file contains the complete SQLite database — all tables, all audit rows — at the time of backup.

**Limitations:**
- There is no built-in read-only viewer for `.agnexis` files; inspectors need either the app (restore flow) or manual decryption + SQLite tooling.

**Status:** ✅ Available via backup/export. No dedicated inspector portal.

---

## 3. Developer Rules

The following rules are mandatory for any code that touches field data. Violations must be flagged in code review.

1. **Never hard-delete field data.** Use `isDeleted = true`. The only permitted `DELETE` statement in production code is the now-removed audit-clear path (which has been eliminated — see §4, Gap 7).

2. **`saveRating` is the only path that may change `numericValue`, `textValue`, or `resultStatus`.** Route all value edits through `SaveRatingUseCase`. `updateRating` is metadata-only; enforce this at review time.

3. **Every data mutation must produce an `audit_events` row.** The audit insert must reference the same `trialId`, `sessionId`, and `plotPk` as the mutated record. If the audit insert fails, log the error but do not fail the primary write — audit failure must never silently abort field data saves.

4. **All timestamps must be captured as `DateTime.now().toUtc()` at the moment of the action.** Do not accept caller-supplied creation timestamps. Caller-supplied timestamps are permitted only for activity timestamps on execution events (e.g., `appliedAt`) where the activity pre-dates the data entry.

5. **`performedBy` and `performedByUserId` must be populated on every audit row where a user identity is available.** Absent identity is permissible only for system-generated events (e.g., auto-backup markers).

6. **Do not add any path that bulk-deletes or bulk-updates `audit_events`.** The table is append-only in production. The archived audit-clear code path has been removed (commit history preserved in git).

7. **Soft-delete must propagate to child records.** When a parent is soft-deleted, all children must also be soft-deleted in the same transaction. Orphaned active children of deleted parents are a data-integrity violation.

8. **GPS coordinates must be captured non-blocking.** Use `GpsService.getCurrentPosition()` with a short timeout (≤ 10 s). A null result is valid and must not prevent the primary data write.

9. **Schema changes to tables that hold field data require a migration in `app_database.dart` and a corresponding entry in `CHANGELOG.md`.** Never rely on Drift's destructive migration in a production build.

---

## 4. Gap Register

The following gaps have been identified against full ALCOA+ compliance. Each is assigned a priority and an owner.

| # | Principle | Gap | Impact | Priority | Status |
|---|-----------|-----|--------|----------|--------|
| 1 | Contemporaneous | Device clock is not verified against NTP; a manipulated clock produces misleading `createdAt` | Ratings could appear to precede the actual observation | Medium | Open |
| 2 | Attributable | Device-sharing risk: user-selection screen is not authenticated; a user can rate under a different identity without re-login | Attribution may be incorrect on shared tablets | Medium | Open |
| 3 | Complete / Contemporaneous | ~~`TrialApplicationEvents` had inline weather fields (manual entry only); no GPS columns; no automatic weather capture at application time~~ | ~~Environmental context for spray applications was incomplete~~ | — | **Closed** — GPS columns added to `trial_application_events` v69→v70; weather+GPS captured non-blocking at `markApplicationApplied`; archive-API backfill via `ApplicationWeatherBackfillService`; null-check lock prevents overwrite 2026-04-26 |
| 4 | Complete / Contemporaneous | ~~`SeedingEvents` had no GPS, no weather columns, no automatic capture~~ | ~~Seeding environmental context was absent~~ | — | **Closed** — 13 weather+GPS columns added to `seeding_events` 2026-04-26; repository lock prevents post-completion mutation of execution fields |
| 5 | Accurate | Numeric rating range (e.g., 1–9 scale) is validated in the UI only; no DB-level constraint | A direct-DB write could insert an out-of-range value | Low | Open |
| 6 | Complete | Application event `appliedAt` and seeding event `completedAt` are optional; records can be saved with no activity timestamp | Temporal completeness of execution events is unenforceable | Low | Open |
| 7 | Enduring / Attributable | ~~Audit-clear code path allowed bulk deletion of `audit_events` after backup~~ | ~~Prior audit history could be removed from the device~~ | — | **Closed** — code path removed 2026-04-26 |
| 8 | Available | No built-in read-only inspector view for `.agnexis` files; requires app restore or manual SQLite tooling | Inspector access requires technical setup | Low | Open |
| 9 | Consistent | No cross-table clock-consistency validation (e.g., `session.closedAt` < `rating.createdAt` edge cases from clock jumps go undetected) | Subtle timestamp inconsistencies would not be flagged | Low | Open |
| 10 | Original | ~~`updateApplication` allowed in-place mutation of execution fields (applicationDate, rate, productName, plotsTreated, equipment) on confirmed applications after `appliedAt` was set~~ | ~~Original execution truth could be overwritten without trace~~ | — | **Closed** — repository lock + UI read-only + product row lock implemented 2026-04-26 |
| 11 | Accurate / Original | ~~Value/status amendments created new version rows but did not capture `amendmentReason` from the field workflow (`SaveRatingInput` / rating screen)~~ | ~~Inspectors could not see why a rating was changed~~ | — | **Closed** — reason prompt on amendment + persistence on new row; Trial Data §3 lists reason or “not recorded” |

---

## 5. Audit Event Catalogue

The following `eventType` values are written to `audit_events` by the application:

| Event Type | Trigger | Key Fields |
|------------|---------|------------|
| `RATING_SAVED` | `saveRating` — new rating or new version in chain | `trialId`, `sessionId`, `plotPk`, `performedBy` |
| `RATING_CORRECTED` | `applyCorrection` — post-close amendment | `trialId`, `sessionId`, `plotPk`, `correctedBy` |
| `RATING_METADATA_UPDATED` | `updateRating` — metadata-only edit (reason, confidence, editor) | `trialId`, `sessionId`, `plotPk`, metadata JSON of updated fields |
| `TRIAL_APPLICATION_EVENT_CREATED` | `createApplication` — new application record | `trialId`, `performedBy`, metadata with event id and date |
| `TRIAL_APPLICATION_EVENT_UPDATED` | `updateApplication` — edit on unconfirmed application | `trialId`, `performedBy`, metadata with status and date |
| `APPLICATION_EVENT_UPDATED` | `updateApplication` on confirmed application — editable fields only | `trialId`, `performedBy`, metadata JSON of changed fields and new values |
| `TRIAL_APPLICATION_EVENT_APPLIED` | `markApplicationApplied` — confirmation timestamp set | `trialId`, `performedBy`, `appliedAt` |
| `TRIAL_APPLICATION_COMPLETED` | `completeApplication` | `trialId`, `performedBy` |
| `TRIAL_APPLICATION_CLOSED` | `closeApplication` | `trialId`, `performedBy` |
| `TRIAL_APPLICATION_CANCELLED` | `cancelApplication` | `trialId`, `performedBy`, previous status |
| `SEEDING_EVENT_UPSERTED` | `upsertSeedingEvent` — insert or update on pending event | `trialId`, `performedBy`, `seeding_event_id`, `status`, `seeding_date` |
| `SEEDING_EVENT_UPDATED` | `upsertSeedingEvent` on completed event — editable fields only | `trialId`, `performedBy`, `seeding_event_id`, `changedFields` map |
| `SEEDING_EVENT_COMPLETED` | `markSeedingCompleted` — completion timestamp set | `trialId`, `performedBy`, `completed_at` |
| `APPLICATION_GPS_CAPTURED` | `updateApplicationGps` — GPS written once at confirmation | `trialId`, `trial_application_event_id`, `latitude`, `longitude` |
| `APPLICATION_WEATHER_CAPTURED` | `updateApplicationWeather` — archive weather written once | `trialId`, `trial_application_event_id` |
| `SEEDING_GPS_CAPTURED` | `updateSeedingGps` — GPS written once at seeding completion | `trialId`, `seeding_event_id`, `latitude`, `longitude` |
| `SEEDING_WEATHER_CAPTURED` | `updateSeedingWeather` — archive weather written once | `trialId`, `seeding_event_id`, `source`, `temperatureC`, `precipitationMm`, `completedAt` |

---

*Maintained by the Agnexis development team. Raise compliance questions against the active CRO protocol before filing a gap as closed.*
