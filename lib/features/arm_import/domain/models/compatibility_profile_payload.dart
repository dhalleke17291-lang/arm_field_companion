import '../enums/import_confidence.dart';

/// Row payload for [CompatibilityProfiles] inserts (export mapping metadata).
class CompatibilityProfilePayload {
  const CompatibilityProfilePayload({
    required this.exportRoute,
    required this.columnMap,
    required this.plotMap,
    required this.treatmentMap,
    required this.dataStartRow,
    required this.headerEndRow,
    required this.identityRowMarkers,
    required this.columnOrderOnExport,
    required this.identityFieldOrder,
    required this.knownUnsupported,
    required this.exportConfidence,
    this.exportBlockReason,
  });

  final String exportRoute;
  final Map<String, dynamic> columnMap;
  final Map<String, dynamic> plotMap;
  final Map<String, dynamic> treatmentMap;
  final int dataStartRow;
  final int headerEndRow;
  final List<dynamic> identityRowMarkers;
  final List<String> columnOrderOnExport;
  final List<String> identityFieldOrder;
  final List<dynamic> knownUnsupported;
  final ImportConfidence exportConfidence;
  final String? exportBlockReason;
}
