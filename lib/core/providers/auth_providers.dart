import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../current_user.dart';
import '../database/app_database.dart';
import '../last_session_store.dart';
import '../trial_operational_watch_merge.dart';
import '../../features/today/domain/activity_event.dart';
import '../../features/users/user_repository.dart';
import 'infrastructure_providers.dart';
import 'session_providers.dart';
import 'trial_providers.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(databaseProvider));
});

final activeUsersProvider = StreamProvider<List<User>>((ref) {
  return ref.watch(userRepositoryProvider).watchActiveUsers();
});

/// Current user id from SharedPreferences. Invalidate after set.
final currentUserIdProvider =
    FutureProvider.autoDispose<int?>((ref) => getCurrentUserId());

/// Full current user. Depends on currentUserIdProvider.
final currentUserProvider = FutureProvider.autoDispose<User?>((ref) async {
  final id = await ref.watch(currentUserIdProvider.future);
  if (id == null) return null;
  return ref.read(userRepositoryProvider).getUserById(id);
});

/// Lookup by local [Users] id (e.g. lastEditedByUserId). Not limited to current user.
final userByIdProvider =
    FutureProvider.autoDispose.family<User?, int>((ref, userId) async {
  return ref.read(userRepositoryProvider).getUserById(userId);
});

/// Activity events for a given day (wall-clock date "yyyy-MM-dd").
/// Recomputes when operational tables used by [TodayActivityRepository] change.
final todayActivityProvider = StreamProvider.autoDispose
    .family<List<ActivityEvent>, String>((ref, dateLocal) {
  final db = ref.watch(databaseProvider);
  return ref.watch(currentUserIdProvider).when(
        data: (userId) =>
            mergeTodayActivityTableWatches(db).asyncMap((_) async {
          final repo = ref.read(todayActivityRepositoryProvider);
          return repo.getActivityForDate(dateLocal, currentUserId: userId);
        }),
        loading: () => Stream.value(<ActivityEvent>[]),
        error: (e, st) => Stream<List<ActivityEvent>>.error(e, st),
      );
});

/// Days with at least one activity (empty days excluded), with event count. For work log history.
final workLogDatesProvider =
    StreamProvider.autoDispose<List<({String dateLocal, int eventCount})>>(
        (ref) {
  final db = ref.watch(databaseProvider);
  return ref.watch(currentUserIdProvider).when(
        data: (userId) =>
            mergeTodayActivityTableWatches(db).asyncMap((_) async {
          final repo = ref.read(todayActivityRepositoryProvider);
          return repo.getDatesWithActivity(currentUserId: userId);
        }),
        loading: () => Stream.value([]),
        error: (e, st) =>
            Stream<List<({String dateLocal, int eventCount})>>.error(
          e,
          st,
        ),
      );
});

/// Sessions for work log: filter by date (sessionDateLocal) and optionally current user (createdByUserId).
final workLogSessionsProvider = FutureProvider.autoDispose
    .family<List<Session>, String>((ref, dateLocal) async {
  final repo = ref.watch(sessionRepositoryProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  return repo.getSessionsForDate(dateLocal, createdByUserId: userId);
});

class LastSessionContext {
  const LastSessionContext({required this.trial, required this.session});
  final Trial trial;
  final Session session;
}

/// Last session (trialId, sessionId) persisted for "Continue Last Session" home card. Valid only if session still exists and is open.
final lastSessionContextProvider =
    FutureProvider.autoDispose<LastSessionContext?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final ids = LastSessionStore(prefs).get();
  if (ids == null) return null;
  final trialRepo = ref.read(trialRepositoryProvider);
  final sessionRepo = ref.read(sessionRepositoryProvider);
  final trial = await trialRepo.getTrialById(ids.$1);
  final session = await sessionRepo.getSessionById(ids.$2);
  if (trial == null ||
      session == null ||
      session.endedAt != null ||
      session.trialId != trial.id) {
    return null;
  }
  return LastSessionContext(trial: trial, session: session);
});
