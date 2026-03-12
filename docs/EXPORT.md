# Export (CSV and ARM XML)

Session ratings and session-scoped audit events can be exported from the app. **CSV** export is available from **Session detail** (one closed session) and **Trial detail** (all closed sessions for a trial as a ZIP). **ARM XML** export is available per closed session from Session detail.

## Single-session export

- **Where:** Session detail screen → Export menu (session must be closed). Options: **Export to CSV**, **Export as ARM XML**.
- **Files produced (CSV):**
  - **Ratings CSV** — `AFC_export_<trial>_<session>_session_<id>.csv`
  - **Audit CSV** (when the session has audit events) — `AFC_export_<trial>_<session>_session_<id>_audit.csv`
- **Files produced (ARM XML):**
  - **ARM-style XML** — `AFC_arm_export_<trial>_<session>_session_<id>.xml`
- **Share:** CSV flow shares both files when audit exists; ARM XML flow shares the single XML file.

## Batch export (trial)

- **Where:** Trial detail → Sessions → Export menu (download icon). Options: **Export all to CSV (ZIP)**, **Export all as ARM XML (ZIP)**.
- **Output (CSV):** One ZIP containing, per closed session, the ratings CSV and (when present) the audit CSV. Filenames as in single-session export.
- **Output (ARM XML):** One ZIP containing one ARM-style XML file per closed session. Filename pattern: `AFC_trial_<trial>_arm_xml_<timestamp>.zip`.

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

## ARM XML export (session)

- **Where:** Session detail → Export → Export as ARM XML (session must be closed).
- **Output:** One XML file per closed session. Root element: `arm_export` (attributes: `version`, `source`, `app_version`, `export_timestamp_utc`, `exported_by`). Child sections: `trial`, `session`, `treatments`, `assessments`, `plots`, `ratings`. Rating values use effective values (after correction when applicable).
- **Note:** The element names and structure are schema-agnostic placeholders. When a real ARM XML sample or schema is available, the exporter can be updated to match.

## ARM XML batch export (trial)

- **Where:** Trial detail → Sessions → Export → Export all as ARM XML (ZIP).
- **Output:** One ZIP containing one XML file per closed session (same structure as single-session ARM XML). Share flow is the same as CSV batch.

## References

- Export repository: `lib/features/export/data/export_repository.dart`
- Session CSV use case: `lib/features/export/domain/export_session_csv_usecase.dart`
- Session ARM XML use case: `lib/features/export/domain/export_session_arm_xml_usecase.dart`
- Batch CSV use case: `lib/features/export/domain/export_trial_closed_sessions_usecase.dart`
- Batch ARM XML use case: `lib/features/export/domain/export_trial_closed_sessions_arm_xml_usecase.dart`
