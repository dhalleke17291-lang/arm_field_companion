import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';

/// Maintenance/debug only. Permanently deletes all data from the app database.
/// Does not modify schema. Optional: clears SharedPreferences.
Future<void> resetAppData(AppDatabase db, {SharedPreferences? prefs}) async {
  await db.transaction(() async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      for (final table in db.allTables) {
        await db.delete(table).go();
      }
    } finally {
      await db.customStatement('PRAGMA foreign_keys = ON');
    }
  });

  if (prefs != null) {
    await prefs.clear();
  }
  await db.ensureAssessmentDefinitionsSeeded();
}
