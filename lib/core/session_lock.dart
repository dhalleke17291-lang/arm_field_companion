import 'database/app_database.dart';

/// Reusable rule: session is editable only when not closed.
/// Use for UI (disable actions) and backend (guard writes).
bool isSessionEditable(Session session) {
  return session.endedAt == null;
}

/// Message shown when user attempts edit on closed session.
const String kClosedSessionBlockedMessage =
    'This session is closed. Data is read-only. Use correction workflow if changes are required.';
