import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'diagnostic_finding.dart';

/// Shown in trial readiness sheet — identifies [ExportTrialUseCase] snapshots.
const String kTrialExportAttemptLabel = 'Trial Export';

/// Shown in trial readiness sheet — identifies [ExportArmRatingShellUseCase] snapshots.
const String kArmRatingShellExportAttemptLabel = 'ARM Rating Shell';

/// JSON envelope inside [TrialExportDiagnostic.findingsJson].
const int kExportDiagnosticsPayloadVersion = 1;

/// Snapshot from the latest trial-scoped export publish (also persisted in Drift).
class TrialExportDiagnosticsSnapshot {
  const TrialExportDiagnosticsSnapshot({
    required this.findings,
    required this.publishedAt,
    required this.attemptLabel,
  });

  final List<DiagnosticFinding> findings;
  final DateTime publishedAt;

  /// Which export path produced this snapshot (e.g. flat CSV/ZIP vs ARM Rating Shell).
  final String attemptLabel;
}

/// Stable JSON for [DiagnosticFinding] lists (UI + [trialDiagnosticsProvider] merge).
class ExportDiagnosticsPayloadCodec {
  ExportDiagnosticsPayloadCodec._();

  static String encodeFindings(List<DiagnosticFinding> findings) {
    final list = findings
        .map((f) => <String, dynamic>{
              'code': f.code,
              'severity': f.severity.name,
              'message': f.message,
              'detail': f.detail,
              'trialId': f.trialId,
              'sessionId': f.sessionId,
              'plotPk': f.plotPk,
              'source': f.source.name,
              'blocksExport': f.blocksExport,
              'blocksAction': f.blocksAction,
            })
        .toList();
    return jsonEncode(<String, dynamic>{
      'payloadVersion': kExportDiagnosticsPayloadVersion,
      'findings': list,
    });
  }

  static List<DiagnosticFinding> decodeFindings(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) return const [];
      final pv = decoded['payloadVersion'];
      if (pv is! int || pv != kExportDiagnosticsPayloadVersion) {
        return const [];
      }
      final findingsList = decoded['findings'];
      if (findingsList is! List<dynamic>) return const [];
      final out = <DiagnosticFinding>[];
      for (final e in findingsList) {
        if (e is Map<String, dynamic>) {
          out.add(_findingFromJson(e));
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static DiagnosticFinding _findingFromJson(Map<String, dynamic> json) {
    return DiagnosticFinding(
      code: json['code'] as String,
      severity: DiagnosticSeverity.values.byName(json['severity'] as String),
      message: json['message'] as String,
      detail: json['detail'] as String?,
      trialId: json['trialId'] as int?,
      sessionId: json['sessionId'] as int?,
      plotPk: json['plotPk'] as int?,
      source: DiagnosticSource.values.byName(json['source'] as String),
      blocksExport: json['blocksExport'] as bool,
      blocksAction: (json['blocksAction'] as bool?) ?? false,
    );
  }
}

TrialExportDiagnosticsSnapshot trialExportSnapshotFromRow(
  TrialExportDiagnostic row,
) {
  final findings = ExportDiagnosticsPayloadCodec.decodeFindings(row.findingsJson);
  return TrialExportDiagnosticsSnapshot(
    findings: findings,
    publishedAt: row.publishedAt,
    attemptLabel: row.attemptLabel,
  );
}

/// Drift-backed cache: last export attempt snapshot per trial (replaces on publish).
class TrialExportDiagnosticsMapNotifier
    extends StateNotifier<Map<int, TrialExportDiagnosticsSnapshot>> {
  TrialExportDiagnosticsMapNotifier(this._db) : super(const {}) {
    unawaited(_hydrate());
  }

  final AppDatabase _db;

  Future<void> _hydrate() async {
    final rows = await _db.select(_db.trialExportDiagnostics).get();
    final map = <int, TrialExportDiagnosticsSnapshot>{};
    for (final r in rows) {
      final snapshot = trialExportSnapshotFromRow(r);
      map[r.trialId] = snapshot;
    }
    state = map;
  }

  /// Replaces the snapshot for [trialId]. [publishedAt] is set to now on every call.
  void setTrialSnapshot(
    int trialId,
    List<DiagnosticFinding> findings,
    String attemptLabel,
  ) {
    final publishedAt = DateTime.now();
    final snapshot = TrialExportDiagnosticsSnapshot(
      findings: List<DiagnosticFinding>.unmodifiable(findings),
      publishedAt: publishedAt,
      attemptLabel: attemptLabel,
    );
    state = {
      ...state,
      trialId: snapshot,
    };
    unawaited(_persist(
      trialId: trialId,
      publishedAt: publishedAt,
      attemptLabel: attemptLabel,
      findings: findings,
    ));
  }

  Future<void> _persist({
    required int trialId,
    required DateTime publishedAt,
    required String attemptLabel,
    required List<DiagnosticFinding> findings,
  }) async {
    try {
      await _db.into(_db.trialExportDiagnostics).insertOnConflictUpdate(
            TrialExportDiagnosticsCompanion.insert(
              trialId: Value(trialId),
              publishedAt: publishedAt,
              attemptLabel: attemptLabel,
              findingsJson: ExportDiagnosticsPayloadCodec.encodeFindings(findings),
              payloadVersion: const Value(kExportDiagnosticsPayloadVersion),
            ),
          );
    } catch (_) {
      // In-memory state remains authoritative for this session.
    }
  }
}
