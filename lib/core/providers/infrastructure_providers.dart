import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connectivity/connectivity_service.dart';
import '../connectivity/weather_backfill_service.dart';
import '../database/app_database.dart';
import '../diagnostics/diagnostics_store.dart';
import '../diagnostics/trial_export_diagnostics.dart';
import '../export_guard.dart';
import '../../data/repositories/trial_environmental_repository.dart';
import '../../data/repositories/weather_snapshot_repository.dart';
import '../../data/services/open_meteo_weather_fetch_service.dart';
import '../../data/services/weather_daily_fetch_service.dart';
import '../../domain/se_type_profiles/se_type_profile_repository.dart';
import '../../features/backup/auto_backup_service.dart';
import '../../features/backup/backup_passphrase_store.dart';
import '../../features/backup/backup_service.dart';
import '../../features/backup/restore_service.dart';
import '../../features/diagnostics/integrity_check_repository.dart';
import '../../features/photos/photo_repository.dart';
import '../../features/today/today_activity_repository.dart';

final exportGuardProvider = Provider<ExportGuard>((ref) => ExportGuard());

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final trialExportDiagnosticsMapProvider = StateNotifierProvider<
    TrialExportDiagnosticsMapNotifier,
    Map<int, TrialExportDiagnosticsSnapshot>>((ref) {
  return TrialExportDiagnosticsMapNotifier(ref.watch(databaseProvider));
});

final diagnosticsStoreProvider = Provider<DiagnosticsStore>((ref) {
  return DiagnosticsStore(maxErrors: 50);
});

final integrityCheckRepositoryProvider =
    Provider<IntegrityCheckRepository>((ref) {
  return IntegrityCheckRepository(ref.watch(databaseProvider));
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
});

final weatherDailyFetchServiceProvider =
    Provider<WeatherDailyFetchService>((ref) {
  return OpenMeteoWeatherFetchService();
});

/// When false, skips the post-frame trial environmental fetch on [TrialDataScreen].
/// Default true for production; set to false in widget tests to avoid HTTP/DB side
/// effects from [TrialEnvironmentalRepository.ensureTodayRecordExists].
final environmentalEnsureTodayBackgroundEnabledProvider =
    Provider<bool>((ref) => true);

final trialEnvironmentalRepositoryProvider =
    Provider<TrialEnvironmentalRepository>((ref) {
  return TrialEnvironmentalRepository(
    ref.watch(databaseProvider),
    ref.watch(weatherDailyFetchServiceProvider),
  );
});

final weatherSnapshotRepositoryProvider =
    Provider<WeatherSnapshotRepository>((ref) {
  return WeatherSnapshotRepository(ref.watch(databaseProvider));
});

/// Latest weather snapshot for a rating session (one row per session).
final weatherSnapshotForSessionProvider =
    StreamProvider.autoDispose.family<WeatherSnapshot?, int>((ref, sessionId) {
  return ref
      .watch(weatherSnapshotRepositoryProvider)
      .watchWeatherSnapshotForParent(
        kWeatherParentTypeRatingSession,
        sessionId,
      );
});

final weatherBackfillServiceProvider = Provider<WeatherBackfillService>((ref) {
  return WeatherBackfillService(
    connectivityService: ref.watch(connectivityServiceProvider),
    weatherRepo: ref.watch(weatherSnapshotRepositoryProvider),
    diagnosticsStore: ref.watch(diagnosticsStoreProvider),
  );
});

final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  return PhotoRepository(ref.watch(databaseProvider));
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});

final restoreServiceProvider = Provider<RestoreService>((ref) {
  return RestoreService(ref.watch(databaseProvider));
});

final autoBackupServiceProvider = Provider<AutoBackupService>((ref) {
  return AutoBackupService(
    ref.watch(backupServiceProvider),
    BackupPassphraseStore(),
  );
});

final autoBackupStatusProvider =
    FutureProvider.autoDispose<AutoBackupStatus>((ref) {
  return ref.watch(autoBackupServiceProvider).getStatus();
});

final seTypeProfileRepositoryProvider =
    Provider<SeTypeProfileRepository>((ref) {
  return SeTypeProfileRepository(ref.watch(databaseProvider));
});

/// All seeded SE type profiles, ordered by prefix ascending.
final seTypeProfilesProvider = FutureProvider<List<SeTypeProfile>>((ref) {
  return ref.watch(seTypeProfileRepositoryProvider).getAll();
});

/// SE type profile for a single [ratingTypePrefix], or null if not seeded.
final seTypeProfileByPrefixProvider =
    FutureProvider.autoDispose.family<SeTypeProfile?, String>(
  (ref, ratingTypePrefix) {
    return ref
        .watch(seTypeProfileRepositoryProvider)
        .getByPrefix(ratingTypePrefix);
  },
);

final todayActivityRepositoryProvider =
    Provider<TodayActivityRepository>((ref) {
  return TodayActivityRepository(ref.watch(databaseProvider));
});
