import '../../core/database/app_database.dart';
import '../../data/repositories/treatment_repository.dart';
import '../../domain/models/arm_treatment_sheet_row.dart';
import 'arm_treatment_metadata_repository.dart';

/// Builds Treatments-sheet data rows from core [Treatments], [TreatmentComponents],
/// and [ArmTreatmentMetadata] (same shape as the shell parser output).
Future<List<ArmTreatmentSheetRow>> armTreatmentSheetRowsForExport({
  required int trialId,
  required List<Treatment> treatments,
  required ArmTreatmentMetadataRepository armTreatmentMetadataRepository,
  required TreatmentRepository treatmentRepository,
}) async {
  final aamMap = await armTreatmentMetadataRepository.getMapForTrial(trialId);
  String? ne(String? s) {
    final x = s?.trim();
    if (x == null || x.isEmpty) return null;
    return x;
  }

  final out = <ArmTreatmentSheetRow>[];
  for (final t in treatments) {
    final aam = aamMap[t.id];
    final order = aam?.armRowSortOrder;
    if (aam == null || order == null) continue;
    final trtNum = int.tryParse(t.code.trim());
    if (trtNum == null) continue;

    final comps = await treatmentRepository.getComponentsForTreatment(t.id);
    final comp = comps.isNotEmpty ? comps.first : null;
    final product = ne(comp?.productName);
    final hasProduct = product != null;

    final ac = ne(aam.armTypeCode);
    final tt = ne(t.treatmentType);
    final typeCode = ac ?? tt;

    out.add(
      ArmTreatmentSheetRow(
        trtNumber: trtNum,
        rowIndex: order,
        typeCode: typeCode,
        treatmentName: hasProduct ? product : null,
        formConc: aam.formConc,
        formConcUnit: ne(aam.formConcUnit),
        formType: ne(aam.formType),
        rate: hasProduct ? comp!.rate : null,
        rateUnit: hasProduct ? ne(comp?.rateUnit) : null,
      ),
    );
  }
  out.sort((a, b) => a.rowIndex.compareTo(b.rowIndex));
  return out;
}
