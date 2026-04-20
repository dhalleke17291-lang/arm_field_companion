/// Application event lifecycle states.
///
/// Stored on [TrialApplicationEvents.status] as lowercase strings.
///
/// pending → applied → closed
///          ↘ cancelled
/// pending → cancelled
///
/// Transitions are strict and forward-only. Use [assertValidApplicationTransition]
/// at the repository layer to enforce.
const String kAppStatusPending = 'pending';
const String kAppStatusApplied = 'applied';
const String kAppStatusClosed = 'closed';
const String kAppStatusCancelled = 'cancelled';

/// All valid application status values.
const List<String> kAppStatusValues = [
  kAppStatusPending,
  kAppStatusApplied,
  kAppStatusClosed,
  kAppStatusCancelled,
];

/// Allowed next statuses from [current].
List<String> allowedNextAppStatuses(String? current) {
  switch (current) {
    case kAppStatusPending:
      return [kAppStatusApplied, kAppStatusCancelled];
    case kAppStatusApplied:
      return [kAppStatusClosed, kAppStatusCancelled];
    case kAppStatusClosed:
      return [];
    case kAppStatusCancelled:
      return [];
    default:
      return [];
  }
}

/// Throws [InvalidApplicationTransitionException] if [from] → [to] is not
/// a valid transition.
void assertValidApplicationTransition(String from, String to) {
  final allowed = allowedNextAppStatuses(from);
  if (!allowed.contains(to)) {
    throw InvalidApplicationTransitionException(from: from, to: to);
  }
}

/// Display label for application status.
String labelForAppStatus(String? status) {
  switch (status) {
    case kAppStatusPending:
      return 'Pending';
    case kAppStatusApplied:
      return 'Applied';
    case kAppStatusClosed:
      return 'Closed';
    case kAppStatusCancelled:
      return 'Cancelled';
    default:
      return status ?? 'Pending';
  }
}

/// Typed exception for invalid application status transitions.
class InvalidApplicationTransitionException implements Exception {
  final String from;
  final String to;

  InvalidApplicationTransitionException({required this.from, required this.to});

  @override
  String toString() =>
      'Invalid application status transition: $from → $to';

  String get message => toString();
}
