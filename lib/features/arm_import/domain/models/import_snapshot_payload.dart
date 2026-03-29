class ImportSnapshotPayload {
  final String sourceFile;
  final String sourceRoute;
  final String? armVersion;
  final List<String> rawHeaders;
  final List<String> columnOrder;
  final List<String> rowTypePatterns;
  final int plotCount;
  final int treatmentCount;
  final int assessmentCount;
  final List<String> identityColumns;
  final List<Map<String, dynamic>> assessmentTokens;
  final List<Map<String, dynamic>> treatmentTokens;
  final List<Map<String, dynamic>> plotTokens;
  final List<Map<String, dynamic>> unknownPatterns;
  final bool hasSubsamples;
  final bool hasMultiApplication;
  final bool hasSparseData;
  final bool hasRepeatedCodes;
  final String rawFileChecksum;

  const ImportSnapshotPayload({
    required this.sourceFile,
    required this.sourceRoute,
    required this.armVersion,
    required this.rawHeaders,
    required this.columnOrder,
    required this.rowTypePatterns,
    required this.plotCount,
    required this.treatmentCount,
    required this.assessmentCount,
    required this.identityColumns,
    required this.assessmentTokens,
    required this.treatmentTokens,
    required this.plotTokens,
    required this.unknownPatterns,
    required this.hasSubsamples,
    required this.hasMultiApplication,
    required this.hasSparseData,
    required this.hasRepeatedCodes,
    required this.rawFileChecksum,
  });
}
