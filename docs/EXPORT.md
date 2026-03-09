# Export (CSV)

Session ratings and session-scoped audit events can be exported to CSV from the app. Export is available from **Session detail** (one closed session) and **Trial detail** (all closed sessions for a trial as a ZIP).

## Single-session export

- **Where:** Session detail screen → Export to CSV (session must be closed).
- **Files produced:**
  - **Ratings CSV** — `AFC_export_<trial>_<session>_session_<id>.csv`
  - **Audit CSV** (when the session has audit events) — `AFC_export_<trial>_<session>_session_<id>_audit.csv`
- **Share:** Both files are shared when the audit file exists.

## Batch export (trial)

- **Where:** Trial detail → Sessions → Export all closed sessions.
- **Output:** One ZIP containing, per closed session, the ratings CSV and (when present) the audit CSV. Filenames as above.

## Ratings CSV columns

- **Trial/session:** `trial_id`, `session_id`, `trial_name`, `session_name`, `session_date_local`, `session_rater_name`, `export_timestamp_utc`, `app_version`, `exported_by` (if set).
- **Plot:** `plot_id`, `rep`, `row`, `column`, `plot_sort_index`, `treatment_id`, `treatment_code`, `treatment_name`, `assignment_source`, `assignment_updated_at_utc`.
- **Assessment:** `assessment_name`, `unit`, `min`, `max`.
- **Rating:** `result_status`, `numeric_value`, `text_value`, `rater_name`, `created_at`; provenance fields (`record_created_at_utc`, `record_app_version`, etc.); IDs (`rating_record_id`, `plot_pk`, `assessment_id`, etc.).
- **Effective value (after correction):** `effective_result_status`, `effective_numeric_value`, `effective_text_value`.
- **Correction (when applicable):** `original_*`, `correction_reason`, `corrected_by_user_id`, `corrected_at_utc`.

## Audit CSV columns

- `trial_id`, `session_id`, `audit_id`, `event_type`, `description`, `performed_by`, `performed_by_user_id`, `created_at_utc`, `metadata`.

Event types include `SESSION_STARTED`, `SESSION_CLOSED`, `RATING_SAVED`, `RATING_UNDONE`, and others as recorded by the app.

## References

- Export repository: `lib/features/export/data/export_repository.dart`
- Session CSV use case: `lib/features/export/domain/export_session_csv_usecase.dart`
- Batch use case: `lib/features/export/domain/export_trial_closed_sessions_usecase.dart`
