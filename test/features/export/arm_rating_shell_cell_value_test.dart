import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/domain/ratings/result_status.dart';
import 'package:arm_field_companion/features/export/domain/arm_rating_shell_cell_value.dart';
import 'package:flutter_test/flutter_test.dart';

RatingRecord _r({
  required String resultStatus,
  double? numericValue,
  String? textValue,
}) {
  final now = DateTime.now().toUtc();
  return RatingRecord(
    id: 1,
    trialId: 1,
    plotPk: 1,
    assessmentId: 1,
    sessionId: 1,
    resultStatus: resultStatus,
    numericValue: numericValue,
    textValue: textValue,
    isCurrent: true,
    createdAt: now,
    amended: false,
    isDeleted: false,
  );
}

void main() {
  group('armRatingShellCellValueFromRating', () {
    test('null rating -> empty', () {
      expect(armRatingShellCellValueFromRating(null), '');
    });

    test('RECORDED numeric', () {
      expect(
        armRatingShellCellValueFromRating(
          _r(resultStatus: ResultStatusDb.recorded, numericValue: 3.25),
        ),
        '3.25',
      );
    });

    test('RECORDED text when no numeric', () {
      expect(
        armRatingShellCellValueFromRating(
          _r(
            resultStatus: ResultStatusDb.recorded,
            textValue: '  mild  ',
          ),
        ),
        'mild',
      );
    });

    test('RECORDED numeric wins over text', () {
      expect(
        armRatingShellCellValueFromRating(
          _r(
            resultStatus: ResultStatusDb.recorded,
            numericValue: 1,
            textValue: 'ignored',
          ),
        ),
        '1.0',
      );
    });

    test('RECORDED empty when no value', () {
      expect(
        armRatingShellCellValueFromRating(
          _r(resultStatus: ResultStatusDb.recorded),
        ),
        '',
      );
    });

    test('NOT_OBSERVED -> empty', () {
      expect(
        armRatingShellCellValueFromRating(
          _r(resultStatus: ResultStatusDb.notObserved),
        ),
        '',
      );
    });

    test('VOID -> empty even with stray text', () {
      expect(
        armRatingShellCellValueFromRating(
          _r(
            resultStatus: ResultStatusDb.voided,
            textValue: 'should not export',
          ),
        ),
        '',
      );
    });

    test('NOT_APPLICABLE -> empty', () {
      expect(
        armRatingShellCellValueFromRating(
          _r(resultStatus: ResultStatusDb.notApplicable),
        ),
        '',
      );
    });

    test('MISSING_CONDITION without text -> empty', () {
      expect(
        armRatingShellCellValueFromRating(
          _r(resultStatus: ResultStatusDb.missingCondition),
        ),
        '',
      );
    });

    test('MISSING_CONDITION with text -> trimmed text', () {
      expect(
        armRatingShellCellValueFromRating(
          _r(
            resultStatus: ResultStatusDb.missingCondition,
            textValue: '  too wet  ',
          ),
        ),
        'too wet',
      );
    });

    test('TECHNICAL_ISSUE without text -> empty', () {
      expect(
        armRatingShellCellValueFromRating(
          _r(resultStatus: ResultStatusDb.technicalIssue),
        ),
        '',
      );
    });

    test('TECHNICAL_ISSUE with text -> trimmed text', () {
      expect(
        armRatingShellCellValueFromRating(
          _r(
            resultStatus: ResultStatusDb.technicalIssue,
            textValue: 'equipment fault',
          ),
        ),
        'equipment fault',
      );
    });

    test('unknown status uses text only not numeric', () {
      expect(
        armRatingShellCellValueFromRating(
          _r(
            resultStatus: 'LEGACY_X',
            numericValue: 99,
            textValue: 'note',
          ),
        ),
        'note',
      );
    });

    test('unknown status empty when no text', () {
      expect(
        armRatingShellCellValueFromRating(
          _r(
            resultStatus: 'LEGACY_X',
            numericValue: 99,
          ),
        ),
        '',
      );
    });
  });
}
