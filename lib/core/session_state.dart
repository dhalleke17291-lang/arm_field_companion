import 'database/app_database.dart';

/// Session row (`sessions` table): [Session.status] is TEXT, DB default `'open'`.
/// [SessionRepository.closeSession] sets `status` to [kSessionStatusClosed] and
/// sets [Session.endedAt].
///
/// **Open session (field work in progress)** is defined the same way as
/// [SessionRepository.getOpenSession] / [SessionRepository.watchOpenSession]:
/// [Session.endedAt] is null. The `status` column mirrors that (`open` vs `closed`).
const String kSessionStatusOpen = 'open';
const String kSessionStatusClosed = 'closed';

/// True when this session counts as an open/active field session for trial lifecycle
/// (not ended). Matches repository queries on `ended_at IS NULL`, with a guard for
/// `status == closed` if data were ever inconsistent.
bool isSessionOpenForFieldWork(Session s) {
  if (s.endedAt != null) return false;
  if (s.status == kSessionStatusClosed) return false;
  return true;
}
