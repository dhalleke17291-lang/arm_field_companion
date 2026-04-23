import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/export/domain/arm_shell_metadata_enrichment.dart';
import 'package:arm_field_companion/features/export/domain/shell_link_preview.dart'
    show ShellLinkPreview, ShellTrialFieldChange;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shouldOffer is false when same shell path already linked', () {
    final trial = Trial(
      id: 1,
      name: 'T',
      status: 'draft',
      workspaceType: 'efficacy',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      isDeleted: false,
    );
    const preview = ShellLinkPreview(
      issues: [],
      trialFieldChanges: [
        ShellTrialFieldChange(
          fieldName: 'name',
          oldValue: 'a',
          newValue: 'b',
          isFillEmpty: false,
        ),
      ],
      assessmentFieldChanges: [],
      unmatchedShellColumns: [],
      unmatchedTrialAssessments: [],
      matchedAssessmentColumnCount: 1,
      shellFilePath: '/tmp/shell.xlsx',
      shellFileName: 'shell.xlsx',
      shellTitle: 'T',
      shellPlotCount: 1,
      trialMatchedPlotCount: 1,
      trialPlotCount: 1,
      shellCommentsSheetText: null,
    );
    expect(
      shouldOfferShellMetadataEnrichmentBeforeExport(
        trial: trial,
        existingLinkedShellPath: '/tmp/shell.xlsx',
        selectedShellPath: '/tmp/shell.xlsx',
        preview: preview,
      ),
      isFalse,
    );
  });

  test('shouldOffer is true when linked path differs from selected shell', () {
    final trial = Trial(
      id: 1,
      name: 'T',
      status: 'draft',
      workspaceType: 'efficacy',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      isDeleted: false,
    );
    const preview = ShellLinkPreview(
      issues: [],
      trialFieldChanges: [
        ShellTrialFieldChange(
          fieldName: 'name',
          oldValue: 'a',
          newValue: 'b',
          isFillEmpty: false,
        ),
      ],
      assessmentFieldChanges: [],
      unmatchedShellColumns: [],
      unmatchedTrialAssessments: [],
      matchedAssessmentColumnCount: 1,
      shellFilePath: '/tmp/new.xlsx',
      shellFileName: 'new.xlsx',
      shellTitle: 'T',
      shellPlotCount: 1,
      trialMatchedPlotCount: 1,
      trialPlotCount: 1,
      shellCommentsSheetText: null,
    );
    expect(
      shouldOfferShellMetadataEnrichmentBeforeExport(
        trial: trial,
        existingLinkedShellPath: '/tmp/old.xlsx',
        selectedShellPath: '/tmp/new.xlsx',
        preview: preview,
      ),
      isTrue,
    );
  });
}
