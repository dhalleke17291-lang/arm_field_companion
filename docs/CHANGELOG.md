# Changelog

Brief record of notable changes. Version aligns with `pubspec.yaml` and `lib/core/app_info.dart`.

---

## 1.0.0 (current)

### Export

- **Session export** — Ratings CSV + optional session-scoped **audit CSV** (SESSION_STARTED, SESSION_CLOSED, RATING_SAVED, etc.). Single-session export shares both files when audit data exists.
- **Trial batch export** — ZIP of all closed sessions now includes each session’s audit CSV when present.
- **Docs** — [docs/EXPORT.md](EXPORT.md) describes file names, columns, and references.

### Protocol lock and UI

- **Trial status bar** — Status and protocol lock (Editable/Locked) with consistent message: “Protocol is locked because this trial is Active.”
- **Section headers** — Plots, Assessments, and Seeding use standard section Add (or Bulk Assign) and lock notice; lock state shows disabled actions and tooltips.
- **Standard widgets** — `StandardSectionAddButton`, `ProtocolLockNotice`, `OperationalSourceBadge`; lock constants in `AppUiConstants`.

### Diagnostics

- **Copy all errors** — Diagnostics screen (About → Diagnostics) can copy all recent errors to clipboard in one report.
- **Integrity checks** — Run from same screen; no data modified.

### Other

- **audit_metadata** — Helpers for operational source and “mark as recorded” when using `audit_events` for seeding/application plans (ready for future use).
- **Protocol import** — [docs/PROTOCOL_IMPORT.md](PROTOCOL_IMPORT.md) documents CSV import (trial, treatments, plots).
- **About** — Version shown from single source (`kAppVersion`).

---

## Next (see WHAT_TO_DO_NEXT.md)

- Manual test: export (single + batch), trial detail lock, diagnostics.
- Then: Login/User context or Applications/plot context slice.
