import '../../core/database/app_database.dart';
import 'biological_window_profiles.dart';

/// Result of the BBCH application-timing window check.
/// Null from [evaluateBbchTiming] means no pesticide category is set —
/// the window check cannot be applied and is treated as satisfied.
class BbchTimingResult {
  const BbchTimingResult({
    required this.applicationCount,
    required this.pesticideCategory,
    required this.hasBbch,
    this.worstBbch,
    required this.worstSeverity,
    this.profile,
  });

  final int applicationCount;
  final String pesticideCategory;

  /// Whether any application event has a BBCH value recorded.
  final bool hasBbch;

  /// The BBCH value that produced [worstSeverity]. Null when [hasBbch] is false.
  final int? worstBbch;

  /// 0 = within optimal window, 1 = outside optimal but within acceptable,
  /// 2 = outside acceptable window. Valid only when [hasBbch] is true and
  /// [profile] is non-null.
  final int worstSeverity;

  /// Null when no biological window profile is configured for the crop+category.
  final BiologicalWindowProfile? profile;
}

/// Evaluates BBCH application timing against the biological window profile.
///
/// Returns null when no treatment component has a [pesticideCategory] set,
/// meaning the window check is not applicable.
BbchTimingResult? evaluateBbchTiming(
  List<TrialApplicationEvent> applications,
  List<TreatmentComponent> treatmentComponents,
  String? trialCrop,
) {
  final hasCategorySet =
      treatmentComponents.any((c) => c.pesticideCategory != null);
  if (!hasCategorySet) return null;

  final pesticideCategory = treatmentComponents
      .firstWhere((c) => c.pesticideCategory != null)
      .pesticideCategory!;

  final n = applications.length;
  final bbchEvents = applications
      .where((a) => a.growthStageBbchAtApplication != null)
      .toList()
    ..sort((a, b) => b.applicationDate.compareTo(a.applicationDate));

  if (bbchEvents.isEmpty) {
    return BbchTimingResult(
      applicationCount: n,
      pesticideCategory: pesticideCategory,
      hasBbch: false,
      worstSeverity: 0,
    );
  }

  final profile = matchProfile(trialCrop, pesticideCategory);
  if (profile == null) {
    return BbchTimingResult(
      applicationCount: n,
      pesticideCategory: pesticideCategory,
      hasBbch: true,
      worstBbch: bbchEvents.first.growthStageBbchAtApplication,
      worstSeverity: 0,
      profile: null,
    );
  }

  var reportBbch = bbchEvents.first.growthStageBbchAtApplication!;
  var reportSeverity = bbchSeverity(reportBbch, profile);
  for (final e in bbchEvents.skip(1)) {
    final bbch = e.growthStageBbchAtApplication!;
    final sev = bbchSeverity(bbch, profile);
    if (sev > reportSeverity) {
      reportBbch = bbch;
      reportSeverity = sev;
    }
  }

  return BbchTimingResult(
    applicationCount: n,
    pesticideCategory: pesticideCategory,
    hasBbch: true,
    worstBbch: reportBbch,
    worstSeverity: reportSeverity,
    profile: profile,
  );
}

/// Returns 0 if [bbch] is within the optimal window, 1 if outside optimal
/// but within acceptable, 2 if outside acceptable entirely.
int bbchSeverity(int bbch, BiologicalWindowProfile profile) {
  if (bbch < profile.acceptableBbchMin || bbch > profile.acceptableBbchMax) {
    return 2;
  }
  if (bbch < profile.optimalBbchMin || bbch > profile.optimalBbchMax) {
    return 1;
  }
  return 0;
}
