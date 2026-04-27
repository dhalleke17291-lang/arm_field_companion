import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/field_operation_date_rules.dart';

String _yyyymmdd(DateTime d) {
  final l = d.toLocal();
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

/// A `yyyy-MM-dd` on or after the trial's creation day and not after today,
/// matching [validateSessionDateLocal] / [SessionRepository.createSession].
Future<String> sessionDateLocalValidForTrial(AppDatabase db, int trialId) async {
  final trial = await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
      .getSingle();
  final minDay = dateOnlyLocal(trial.createdAt);
  final today = dateOnlyLocal(DateTime.now());
  final d = today.isBefore(minDay) ? minDay : today;
  return _yyyymmdd(d);
}
