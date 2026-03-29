import '../domain/enums/import_confidence.dart';
import '../domain/models/compatibility_profile_payload.dart';
import '../domain/models/import_snapshot_payload.dart';
import '../domain/models/parsed_arm_csv.dart';

/// Builds [CompatibilityProfilePayload] for persistence from parsed CSV + snapshot.
class CompatibilityProfileBuilder {
  CompatibilityProfilePayload build({
    required ParsedArmCsv parsed,
    required ImportSnapshotPayload snapshot,
  }) {
    final columnMap = <String, dynamic>{
      for (var i = 0; i < snapshot.columnOrder.length; i++)
        snapshot.columnOrder[i]: i,
    };

    final plotMap = <String, dynamic>{
      for (var i = 0; i < snapshot.plotTokens.length; i++)
        'plot_$i': snapshot.plotTokens[i],
    };

    final treatmentMap = <String, dynamic>{
      for (var i = 0; i < snapshot.treatmentTokens.length; i++)
        'treatment_$i': snapshot.treatmentTokens[i],
    };

    final knownUnsupported = <dynamic>[
      for (final f in parsed.unknownPatterns) f.type,
    ];

    return CompatibilityProfilePayload(
      exportRoute: snapshot.sourceRoute,
      columnMap: columnMap,
      plotMap: plotMap,
      treatmentMap: treatmentMap,
      dataStartRow: 2,
      headerEndRow: 1,
      identityRowMarkers: const [1],
      columnOrderOnExport: List<String>.from(snapshot.columnOrder),
      identityFieldOrder: List<String>.from(snapshot.identityColumns),
      knownUnsupported: knownUnsupported,
      exportConfidence: parsed.importConfidence,
      exportBlockReason: parsed.importConfidence == ImportConfidence.blocked
          ? 'Export blocked at import confidence'
          : null,
    );
  }
}
