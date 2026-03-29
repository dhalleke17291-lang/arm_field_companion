import 'package:collection/collection.dart';

import '../domain/enums/arm_column_kind.dart';
import '../domain/models/arm_column_classification.dart';
import '../domain/models/assessment_token.dart';

/// ARM CSV header parsing and classification.
class ArmCsvParser {
  static const Map<String, String> _identityHeaderRoles = {
    'Plot No.': 'plotNumber',
    'trt': 'treatmentNumber',
    'reps': 'rep',
  };

  static const Map<String, String> _treatmentHeaderRoles = {
    'Trial ID': 'trialId',
    'Treatment Name': 'treatmentName',
    'Form Conc': 'formConc',
    'Form Unit': 'formUnit',
    'Form Type': 'formType',
    ' Rate': 'rate',
    'Rate Unit': 'rateUnit',
    'Appl Code': 'applCode',
    ' Type': 'type',
  };

  List<ArmColumnClassification> classifyHeaders(List<String> headers) {
    return headers
        .mapIndexed((index, header) => classifyColumn(header, index))
        .toList();
  }

  ArmColumnClassification classifyColumn(String header, int index) {
    final identityRole = _identityHeaderRoles[header];
    if (identityRole != null) {
      return ArmColumnClassification(
        header: header,
        kind: ArmColumnKind.identity,
        index: index,
        identityRole: identityRole,
      );
    }

    final treatmentRole = _treatmentHeaderRoles[header];
    if (treatmentRole != null) {
      return ArmColumnClassification(
        header: header,
        kind: ArmColumnKind.treatment,
        index: index,
        identityRole: treatmentRole,
      );
    }

    final token = tryParseAssessmentToken(header);
    if (token != null) {
      return ArmColumnClassification(
        header: header,
        kind: ArmColumnKind.assessment,
        index: index,
        assessmentToken: token,
      );
    }

    return ArmColumnClassification(
      header: header,
      kind: ArmColumnKind.unknown,
      index: index,
    );
  }

  /// ARM assessment headers are whitespace-separated (no pipe delimiters in source CSV).
  /// [rawHeader] on the token is the original [header] string (untrimmed).
  AssessmentToken? tryParseAssessmentToken(String header) {
    final trimmed = header.trim();
    if (trimmed.isEmpty) return null;

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length < 2) return null;

    final unit = parts.last;
    final armCode = parts[parts.length - 2];

    String timingCode = '';
    DateTime? ratingDate;

    if (parts.length >= 3) {
      final timingToken = parts[parts.length - 3];
      final parsed = _tryParseArmDate(timingToken);
      if (parsed != null) {
        timingCode = timingToken;
        ratingDate = parsed;
      } else {
        timingCode = '';
        ratingDate = null;
      }
    }

    if (!RegExp(r'^[A-Z]{3,10}$').hasMatch(armCode)) return null;

    return AssessmentToken(
      rawHeader: header,
      armCode: armCode,
      timingCode: timingCode,
      unit: unit,
      ratingDate: ratingDate,
    );
  }

  DateTime? _tryParseArmDate(String value) {
    final segments = value.split('-');
    if (segments.length != 3) return null;

    const monthMap = <String, int>{
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };

    final day = int.tryParse(segments[0]);
    final month = monthMap[segments[1]];
    final yearShort = int.tryParse(segments[2]);
    if (day == null || month == null || yearShort == null) return null;

    try {
      return DateTime(2000 + yearShort, month, day);
    } catch (_) {
      return null;
    }
  }
}
