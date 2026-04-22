import 'database/app_database.dart';

/// Session row (`sessions` table): [Session.status] is TEXT, DB default `'open'`.
/// [SessionRepository.closeSession] sets `status` to [kSessionStatusClosed] and
/// sets [Session.endedAt].
///
/// **Open session (field work in progress)** is defined the same way as
/// [SessionRepository.getOpenSession] / [SessionRepository.watchOpenSession]:
/// [Session.endedAt] is null, [Session.status] is not `closed` or `planned`.
///
/// **Planned session** ([kSessionStatusPlanned]): a pre-scheduled rating slot
/// that has not been started yet. Created programmatically (e.g. by the ARM
/// importer when a protocol lists future rating dates) and lives on the core
/// session lifecycle because the concept is protocol-agnostic — any trial
/// could in principle schedule sessions ahead of time. Planned sessions do
/// not count as "open" for field-work queries and do not block new open
/// sessions. A user transitions a planned session to `open` by starting it.
const String kSessionStatusOpen = 'open';
const String kSessionStatusClosed = 'closed';
const String kSessionStatusPlanned = 'planned';

/// True when this session counts as an open/active field session for trial lifecycle
/// (not ended, not closed, not merely planned-but-not-started). Matches repository
/// queries that filter on `ended_at IS NULL AND status NOT IN ('closed','planned')`.
bool isSessionOpenForFieldWork(Session s) {
  if (s.endedAt != null) return false;
  if (s.status == kSessionStatusClosed) return false;
  if (s.status == kSessionStatusPlanned) return false;
  return true;
}
