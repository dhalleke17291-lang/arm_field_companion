import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import 'domain/activity_event.dart';

/// Wall-clock date string "yyyy-MM-dd" to [start, end) in local time.
void _dateRange(String dateLocal, List<DateTime> out) {
  final start = DateTime.parse('$dateLocal 00:00:00');
  final end = start.add(const Duration(days: 1));
  out.add(start);
  out.add(end);
}

/// All activity for a given day. Queries existing tables; no schema changes.
/// Filter by [currentUserId] where tables have user attribution.
class TodayActivityRepository {
  TodayActivityRepository(this._db);

  final AppDatabase _db;

  /// [dateLocal] = "yyyy-MM-dd". Returns events newest first.
  Future<List<ActivityEvent>> getActivityForDate(
    String dateLocal, {
    int? currentUserId,
  }) async {
    final range = <DateTime>[];
    _dateRange(dateLocal, range);
    final start = range[0];
    final end = range[1];

    final events = <ActivityEvent>[];

    // Session started: sessions.startedAt in range, optional createdByUserId
    final startedSessions = await (_db.select(_db.sessions)
          ..where((s) {
            final inRange = s.startedAt.isBiggerOrEqualValue(start) &
                s.startedAt.isSmallerThanValue(end);
            if (currentUserId != null) {
              return inRange & s.createdByUserId.equals(currentUserId);
            }
            return inRange;
          }))
        .get();
    for (final s in startedSessions) {
      final t = await _db.getTrialById(s.trialId);
      events.add(SessionStartedEvent(
        at: s.startedAt,
        sessionName: s.name,
        trialName: t?.name ?? 'Trial ${s.trialId}',
      ));
    }

    // Session closed: audit_events SESSION_CLOSED in range, optional performedByUserId
    final closedAudit = await (_db.select(_db.auditEvents)
          ..where((e) {
            final match = e.eventType.equals('SESSION_CLOSED') &
                e.createdAt.isBiggerOrEqualValue(start) &
                e.createdAt.isSmallerThanValue(end);
            if (currentUserId != null) {
              return match & e.performedByUserId.equals(currentUserId);
            }
            return match;
          }))
        .get();
    for (final e in closedAudit) {
      if (e.sessionId == null) continue;
      final s = await _db.getSessionById(e.sessionId!);
      if (s == null) continue;
      final t = await _db.getTrialById(s.trialId);
      events.add(SessionClosedEvent(
        at: e.createdAt,
        sessionName: s.name,
        trialName: t?.name ?? 'Trial ${s.trialId}',
      ));
    }

    // Ratings: rating_records.createdAt in range, group by session
    final ratings = await (_db.select(_db.ratingRecords)
          ..where((r) =>
              r.createdAt.isBiggerOrEqualValue(start) &
              r.createdAt.isSmallerThanValue(end)))
        .get();
    final bySession = <int, List<RatingRecord>>{};
    for (final r in ratings) {
      bySession.putIfAbsent(r.sessionId, () => []).add(r);
    }
    for (final entry in bySession.entries) {
      final session = await _db.getSessionById(entry.key);
      final trial = session != null ? await _db.getTrialById(session.trialId) : null;
      final plotPks = entry.value.map((r) => r.plotPk).toSet().length;
      events.add(RatingsBatchEvent(
        at: entry.value.first.createdAt,
        count: plotPks,
        sessionName: session?.name ?? 'Session ${entry.key}',
        trialName: trial?.name ?? (session != null ? 'Trial ${session.trialId}' : ''),
      ));
    }

    // Flags: plot_flags.createdAt in range, group by session
    final flags = await (_db.select(_db.plotFlags)
          ..where((f) =>
              f.createdAt.isBiggerOrEqualValue(start) &
              f.createdAt.isSmallerThanValue(end)))
        .get();
    final flagsBySession = <int, List<PlotFlag>>{};
    for (final f in flags) {
      flagsBySession.putIfAbsent(f.sessionId, () => []).add(f);
    }
    for (final entry in flagsBySession.entries) {
      final session = await _db.getSessionById(entry.key);
      final trial = session != null ? await _db.getTrialById(session.trialId) : null;
      events.add(FlagsBatchEvent(
        at: entry.value.first.createdAt,
        count: entry.value.length,
        sessionName: session?.name ?? 'Session ${entry.key}',
        trialName: trial?.name ?? (session != null ? 'Trial ${session.trialId}' : ''),
      ));
    }

    // Photos: photos.createdAt in range, group by session
    final photos = await (_db.select(_db.photos)
          ..where((p) =>
              p.createdAt.isBiggerOrEqualValue(start) &
              p.createdAt.isSmallerThanValue(end)))
        .get();
    final photosBySession = <int, List<Photo>>{};
    for (final p in photos) {
      photosBySession.putIfAbsent(p.sessionId, () => []).add(p);
    }
    for (final entry in photosBySession.entries) {
      final session = await _db.getSessionById(entry.key);
      final trial = session != null ? await _db.getTrialById(session.trialId) : null;
      events.add(PhotosBatchEvent(
        at: entry.value.first.createdAt,
        count: entry.value.length,
        sessionName: session?.name ?? 'Session ${entry.key}',
        trialName: trial?.name ?? (session != null ? 'Trial ${session.trialId}' : ''),
      ));
    }

    // Plots assigned: assignments.updatedAt in range, optional assignedBy
    final assignments = await (_db.select(_db.assignments)
          ..where((a) {
            final inRange = a.updatedAt.isBiggerOrEqualValue(start) &
                a.updatedAt.isSmallerThanValue(end) &
                a.treatmentId.isNotNull();
            if (currentUserId != null) {
              return inRange & a.assignedBy.equals(currentUserId);
            }
            return inRange;
          }))
        .get();
    final assignByTrial = <int, ({int count, DateTime at})>{};
    for (final a in assignments) {
      final existing = assignByTrial[a.trialId];
      final count = (existing?.count ?? 0) + 1;
      final at = existing == null || a.updatedAt.isAfter(existing.at)
          ? a.updatedAt
          : existing.at;
      assignByTrial[a.trialId] = (count: count, at: at);
    }
    for (final entry in assignByTrial.entries) {
      final t = await _db.getTrialById(entry.key);
      events.add(PlotsAssignedEvent(
        at: entry.value.at,
        count: entry.value.count,
        trialName: t?.name ?? 'Trial ${entry.key}',
      ));
    }

    // Export: audit_events EXPORT_TRIGGERED in range
    final exportAudit = await (_db.select(_db.auditEvents)
          ..where((e) =>
              e.eventType.equals('EXPORT_TRIGGERED') &
              e.createdAt.isBiggerOrEqualValue(start) &
              e.createdAt.isSmallerThanValue(end)))
        .get();
    for (final e in exportAudit) {
      final trialName = e.trialId != null
          ? ((await _db.getTrialById(e.trialId!))?.name ?? 'Trial ${e.trialId}')
          : 'Export';
      final format = e.description.contains('XML') ? 'ARM XML' : 'CSV';
      events.add(ExportDoneEvent(
        at: e.createdAt,
        trialName: trialName,
        format: format,
      ));
    }

    events.sort((a, b) => b.at.compareTo(a.at));
    return events;
  }

  /// Dates that have at least one activity (empty days excluded), with event count per day.
  /// Sorted newest first. [daysBack] default 365.
  Future<List<({String dateLocal, int eventCount})>> getDatesWithActivity({
    int? currentUserId,
    int daysBack = 365,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: daysBack));
    final dateToCount = <String, int>{};

    String toDateLocal(DateTime d) {
      return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    void add(String date) {
      dateToCount[date] = (dateToCount[date] ?? 0) + 1;
    }

    final startedSessions = await (_db.select(_db.sessions)
          ..where((s) {
            final ok = s.startedAt.isBiggerOrEqualValue(cutoff);
            if (currentUserId != null) {
              return ok & s.createdByUserId.equals(currentUserId);
            }
            return ok;
          }))
        .get();
    for (final s in startedSessions) {
      add(toDateLocal(s.startedAt));
    }

    final auditRows = await (_db.select(_db.auditEvents)
          ..where((e) {
            final ok = e.createdAt.isBiggerOrEqualValue(cutoff) &
                (e.eventType.equals('SESSION_CLOSED') |
                    e.eventType.equals('EXPORT_TRIGGERED'));
            if (currentUserId != null) {
              return ok & e.performedByUserId.equals(currentUserId);
            }
            return ok;
          }))
        .get();
    for (final e in auditRows) {
      add(toDateLocal(e.createdAt));
    }

    final ratings = await (_db.select(_db.ratingRecords)
          ..where((r) => r.createdAt.isBiggerOrEqualValue(cutoff)))
        .get();
    for (final r in ratings) {
      add(toDateLocal(r.createdAt));
    }

    final flags = await (_db.select(_db.plotFlags)
          ..where((f) => f.createdAt.isBiggerOrEqualValue(cutoff)))
        .get();
    for (final f in flags) {
      add(toDateLocal(f.createdAt));
    }

    final photos = await (_db.select(_db.photos)
          ..where((p) => p.createdAt.isBiggerOrEqualValue(cutoff)))
        .get();
    for (final p in photos) {
      add(toDateLocal(p.createdAt));
    }

    final assignments = await (_db.select(_db.assignments)
          ..where((a) {
            final ok = a.updatedAt.isBiggerOrEqualValue(cutoff) &
                a.treatmentId.isNotNull();
            if (currentUserId != null) {
              return ok & a.assignedBy.equals(currentUserId);
            }
            return ok;
          }))
        .get();
    for (final a in assignments) {
      add(toDateLocal(a.updatedAt));
    }

    final list = dateToCount.entries
        .map((e) => (dateLocal: e.key, eventCount: e.value))
        .toList()
      ..sort((a, b) => b.dateLocal.compareTo(a.dateLocal));
    return list;
  }
}

extension on AppDatabase {
  Future<Trial?> getTrialById(int id) =>
      (select(trials)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<Session?> getSessionById(int id) =>
      (select(sessions)..where((s) => s.id.equals(id))).getSingleOrNull();
}
