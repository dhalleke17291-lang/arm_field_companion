import '../../../core/database/app_database.dart';
import '../../../domain/ratings/result_status.dart';

/// Converts a current [RatingRecord] into the string written into an ARM Rating
/// Shell **Plot Data** cell during [ExportArmRatingShellUseCase].
///
/// ## Product semantics (ARM round-trip handoff)
///
/// ARM expects **measured values** in rating columns. Status codes are **not**
/// written into cells; non-[RECORDED] outcomes are surfaced separately via
/// [ComputeArmRoundTripDiagnosticsUseCase] (`nonRecordedRatingsInShellSession`,
/// non-blocking).
///
/// | `result_status` | Cell content |
/// |-----------------|--------------|
/// | **RECORDED** | [RatingRecord.numericValue] as string if non-null; else
///   non-empty trimmed [RatingRecord.textValue] (e.g. text assessments); else
///   empty string. |
/// | **VOID** | Always empty. A voided observation exports as a blank cell even
///   if legacy rows carry [textValue]. |
/// | **NOT_OBSERVED** | Always empty. |
/// | **NOT_APPLICABLE** | Always empty. |
/// | **MISSING_CONDITION** | Trimmed [RatingRecord.textValue] if non-empty
///   (reason / note); else empty. |
/// | **TECHNICAL_ISSUE** | Same as missing condition — trimmed text if any, else
///   empty. |
/// | **Unknown / legacy** status | Trimmed [textValue] only (never numeric), else
///   empty — avoids exporting a stray numeric on an unrecognized status. |
///
/// **Null** [rating] (no current row for plot/assessment/session) → empty string.
String armRatingShellCellValueFromRating(RatingRecord? rating) {
  if (rating == null) return '';

  switch (rating.resultStatus) {
    case ResultStatusDb.recorded:
      if (rating.numericValue != null) {
        return rating.numericValue!.toString();
      }
      final recordedText = rating.textValue?.trim();
      if (recordedText != null && recordedText.isNotEmpty) {
        return recordedText;
      }
      return '';

    case ResultStatusDb.voided:
    case ResultStatusDb.notObserved:
    case ResultStatusDb.notApplicable:
      return '';

    case ResultStatusDb.missingCondition:
    case ResultStatusDb.technicalIssue:
      final note = rating.textValue?.trim();
      if (note != null && note.isNotEmpty) return note;
      return '';

    default:
      final legacyText = rating.textValue?.trim();
      if (legacyText != null && legacyText.isNotEmpty) return legacyText;
      return '';
  }
}
