# Audit design: Application events

When the audit layer is built, **no completion or edit is silent**. Every state change on an application event will produce an audit record.

## Reversing a completion

- A **"Mark as Planned"** action will be available on completed events.
- Instead of only flipping status to `planned`, the flow will:
  1. Write an `AuditEvent` record, then
  2. Update the application event back to `planned`.

**Audit record shape:**

| Field / concept | Value |
|-----------------|--------|
| `action` / `eventType` | `completion_reversed` |
| `entity` | `application_event` |
| `entity_id` | application event id |
| `reason` | operator-entered reason |
| `reversed_by` | operator name |
| `reversed_at` | timestamp |

The existing `AuditEvents` table (`eventType`, `description`, `performedBy`, `createdAt`, `metadata`) will be used; entity and payload can be stored in `metadata` (e.g. JSON) and/or `description`.

## Edits

- Every **Edit** save on an application event will write an audit record.

**Audit record shape:**

| Field / concept | Value |
|-----------------|--------|
| `action` / `eventType` | `event_edited` |
| `before` | JSON snapshot of old values |
| `after` | JSON snapshot of new values |
| `edited_by` / `edited_at` | operator and timestamp |

Again, map these into `AuditEvents` columns (`eventType`, `metadata` for JSON, `performedBy`, `createdAt`).

## Frozen rule

> **No completion or edit is silent. Every state change on an application event will produce an audit record when the audit layer is built.**

The application module will be one of the first areas to get full audit coverage.
