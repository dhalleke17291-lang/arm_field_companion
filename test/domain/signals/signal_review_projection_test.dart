import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/domain/signals/signal_models.dart';
import 'package:arm_field_companion/domain/signals/signal_review_projection.dart';
import 'package:arm_field_companion/domain/signals/signal_review_projection_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

Signal _signal({
  int id = 1,
  int trialId = 10,
  int? sessionId = 20,
  int? plotId = 30,
  String type = 'causal_context_flag',
  String status = 'open',
  String severity = 'review',
  String referenceContext = '{}',
  String consequenceText = 'Raw generated consequence text.',
}) {
  return Signal(
    id: id,
    trialId: trialId,
    sessionId: sessionId,
    plotId: plotId,
    signalType: type,
    moment: 2,
    severity: severity,
    raisedAt: 1000,
    raisedBy: null,
    referenceContext: referenceContext,
    magnitudeContext: null,
    consequenceText: consequenceText,
    status: status,
    createdAt: 1000,
  );
}

void main() {
  group('SignalReviewProjection', () {
    test('maps statuses to plain-language labels', () {
      expect(projectSignalForReview(_signal(status: 'open')).statusLabel,
          'Needs review');
      expect(
          projectSignalForReview(_signal(status: 'investigating')).statusLabel,
          'Under review');
      expect(projectSignalForReview(_signal(status: 'deferred')).statusLabel,
          'Review later');
      expect(projectSignalForReview(_signal(status: 'resolved')).statusLabel,
          'Reviewed');
      expect(projectSignalForReview(_signal(status: 'suppressed')).statusLabel,
          'Hidden from active review');
      expect(projectSignalForReview(_signal(status: 'expired')).statusLabel,
          'No longer active');
    });

    test('maps statuses to operational states', () {
      expect(projectSignalForReview(_signal(status: 'open')).operationalState,
          SignalOperationalState.needsAction);
      expect(
          projectSignalForReview(_signal(status: 'investigating'))
              .operationalState,
          SignalOperationalState.underReview);
      expect(
          projectSignalForReview(_signal(status: 'deferred')).operationalState,
          SignalOperationalState.reviewLater);
    });

    test('maps terminal statuses to historical state', () {
      for (final status in ['resolved', 'suppressed', 'expired']) {
        final projection = projectSignalForReview(_signal(status: status));
        expect(projection.operationalState, SignalOperationalState.historical);
        expect(projection.isHistorical, isTrue);
        expect(projection.isActive, isFalse);
      }
    });

    test('translates severity without overusing critical language', () {
      expect(
          projectSignalForReview(_signal(severity: 'critical')).severityLabel,
          'Needs review before export');
      expect(projectSignalForReview(_signal(severity: 'review')).severityLabel,
          'Needs review');
      expect(projectSignalForReview(_signal(severity: 'info')).severityLabel,
          'For awareness');
    });

    test('preserves raw consequence text only in detailText', () {
      const raw = 'Rating timing is outside the configured biological window.';
      final projection = projectSignalForReview(
        _signal(
          type: 'causal_context_flag',
          consequenceText: raw,
        ),
      );

      expect(projection.detailText, raw);
      expect(projection.displayTitle, isNot(raw));
      expect(projection.shortSummary, isNot(raw));
    });

    test('projection booleans reflect status state', () {
      final open = projectSignalForReview(_signal(status: 'open'));
      expect(open.isActive, isTrue);
      expect(open.isNeedsAction, isTrue);
      expect(open.isUnderReview, isFalse);
      expect(open.isHistorical, isFalse);

      final investigating =
          projectSignalForReview(_signal(status: 'investigating'));
      expect(investigating.isActive, isTrue);
      expect(investigating.isNeedsAction, isFalse);
      expect(investigating.isUnderReview, isTrue);
      expect(investigating.isHistorical, isFalse);

      final deferred = projectSignalForReview(_signal(status: 'deferred'));
      expect(deferred.isActive, isTrue);
      expect(deferred.isNeedsAction, isFalse);
      expect(deferred.isUnderReview, isFalse);
      expect(deferred.isHistorical, isFalse);
    });

    test('open signals require readiness action with readable reason', () {
      final projection = projectSignalForReview(_signal(status: 'open'));

      expect(projection.requiresReadinessAction, isTrue);
      expect(projection.readinessActionReason, isNotNull);
      expect(projection.readinessActionReason, contains('still open'));
      expect(projection.readinessActionReason, contains('reviewed'));
    });

    test('investigating signals do not require readiness action yet', () {
      final projection =
          projectSignalForReview(_signal(status: 'investigating'));

      expect(projection.requiresReadinessAction, isFalse);
      expect(projection.readinessActionReason, isNull);
      expect(projection.isActive, isTrue);
      expect(projection.isUnderReview, isTrue);
    });

    test('deferred signals do not require readiness action yet', () {
      final projection = projectSignalForReview(_signal(status: 'deferred'));

      expect(projection.requiresReadinessAction, isFalse);
      expect(projection.readinessActionReason, isNull);
      expect(projection.isActive, isTrue);
      expect(projection.operationalState, SignalOperationalState.reviewLater);
    });

    test('historical states do not require readiness action', () {
      for (final status in ['resolved', 'suppressed', 'expired']) {
        final projection = projectSignalForReview(_signal(status: status));

        expect(projection.requiresReadinessAction, isFalse);
        expect(projection.readinessActionReason, isNull);
        expect(projection.isHistorical, isTrue);
      }
    });

    test('only open critical signals directly block export', () {
      final openCritical = projectSignalForReview(
        _signal(status: 'open', severity: 'critical'),
      );
      expect(openCritical.blocksExport, isTrue);
      expect(
        openCritical.blocksExportReason,
        contains('critical signal is reviewed'),
      );

      for (final status in [
        'investigating',
        'deferred',
        'resolved',
        'suppressed',
        'expired',
      ]) {
        final projection = projectSignalForReview(
          _signal(status: status, severity: 'critical'),
        );

        expect(projection.blocksExport, isFalse);
        expect(projection.blocksExportReason, isNull);
      }

      final openReview = projectSignalForReview(
        _signal(status: 'open', severity: 'review'),
      );
      expect(openReview.blocksExport, isFalse);
      expect(openReview.blocksExportReason, isNull);
    });

    test('type-aware wording stays calm and short', () {
      expect(
        projectSignalForReview(_signal(type: 'causal_context_flag'))
            .displayTitle,
        'Treatment timing may need review',
      );
      expect(
        projectSignalForReview(_signal(type: 'rater_drift')).displayTitle,
        'Rating consistency may need review',
      );
      expect(
        projectSignalForReview(_signal(type: 'replication_warning'))
            .displayTitle,
        'Replication pattern may affect results',
      );
      expect(
        projectSignalForReview(_signal(type: 'scale_violation')).displayTitle,
        'Recorded values may need review',
      );
    });
  });

  group('SignalReviewGroupProjection', () {
    test('multiple related replication signals collapse into one group', () {
      final groups = projectSignalGroupsForReview([
        _signal(
          id: 2,
          sessionId: 7,
          plotId: 102,
          type: 'replication_warning',
        ),
        _signal(
          id: 1,
          sessionId: 7,
          plotId: 101,
          type: 'replication_warning',
        ),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.groupType, 'replication_warning');
      expect(groups.single.familyKey, SignalFamilyKey.replicationPattern);
      expect(
        groups.single.familyDefinition,
        'Multiple review items point to the same replication-pattern concern.',
      );
      expect(groups.single.groupingBasis, contains('session 7'));
      expect(
          groups.single.displayTitle, 'Replication pattern may affect results');
      expect(groups.single.signalCount, 2);
      expect(groups.single.affectedSessionIds, [7]);
      expect(groups.single.affectedPlotIds, [101, 102]);
      expect(groups.single.memberSignals.map((s) => s.signalId), [1, 2]);
    });

    test('every family key has deterministic interpretation semantics', () {
      for (final key in SignalFamilyKey.values) {
        expect(signalFamilyScientificRole(key), isNotEmpty);
        expect(signalFamilyInterpretationImpact(key), isNotEmpty);
        expect(signalFamilyReviewQuestion(key), isNotEmpty);
      }

      expect(
        signalFamilyScientificRole(SignalFamilyKey.untreatedCheckVariance),
        'Untreated checks establish the baseline used for treatment comparison.',
      );
      expect(
        signalFamilyInterpretationImpact(SignalFamilyKey.replicationPattern),
        'Irregular replication patterns may weaken treatment comparison reliability.',
      );
      expect(
        signalFamilyReviewQuestion(SignalFamilyKey.raterDivergence),
        'Do these assessments require review or re-rating?',
      );
    });

    test('unrelated signals remain separate', () {
      final groups = projectSignalGroupsForReview([
        _signal(
          id: 1,
          sessionId: 7,
          type: 'replication_warning',
        ),
        _signal(
          id: 2,
          sessionId: 8,
          type: 'replication_warning',
        ),
        _signal(
          id: 3,
          sessionId: 7,
          type: 'scale_violation',
        ),
      ]);

      expect(groups, hasLength(3));
      expect(groups.map((g) => g.signalCount), everyElement(1));
      expect(
        groups.expand((g) => g.memberSignals).map((s) => s.signalId).toSet(),
        {1, 2, 3},
      );
    });

    test('rater variability signals group by session and assessment family',
        () {
      final context =
          const SignalReferenceContext(seType: 'PHYGEN').encodeJson();
      final otherContext =
          const SignalReferenceContext(seType: 'VIGOR').encodeJson();
      final groups = projectSignalGroupsForReview([
        _signal(
          id: 1,
          sessionId: 7,
          type: 'rater_drift',
          referenceContext: context,
        ),
        _signal(
          id: 2,
          sessionId: 7,
          type: 'rater_drift',
          referenceContext: context,
        ),
        _signal(
          id: 3,
          sessionId: 7,
          type: 'rater_drift',
          referenceContext: otherContext,
        ),
      ]);

      expect(groups, hasLength(2));
      expect(groups.map((g) => g.signalCount).toList()..sort(), [1, 2]);
      expect(
        groups.firstWhere((g) => g.signalCount == 2).familyKey,
        SignalFamilyKey.raterDivergence,
      );
      expect(
        groups.firstWhere((g) => g.signalCount == 2).familyDefinition,
        'Multiple review items point to the same rating-consistency concern.',
      );
      expect(
        groups.firstWhere((g) => g.signalCount == 2).groupingBasis,
        contains('assessment family PHYGEN'),
      );
    });

    test('timing-window signals group by session and assessment family', () {
      final context =
          const SignalReferenceContext(seType: 'PHYGEN').encodeJson();
      final groups = projectSignalGroupsForReview([
        _signal(
          id: 1,
          sessionId: 7,
          plotId: 101,
          type: 'causal_context_flag',
          referenceContext: context,
        ),
        _signal(
          id: 2,
          sessionId: 7,
          plotId: 102,
          type: 'causal_context_flag',
          referenceContext: context,
        ),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.signalCount, 2);
      expect(groups.single.familyKey, SignalFamilyKey.timingWindowReview);
      expect(
        groups.single.familyDefinition,
        'Multiple review items point to the same treatment-timing review concern.',
      );
      expect(groups.single.groupingBasis, contains('treatment-timing'));
      expect(groups.single.affectedPlotIds, [101, 102]);
      expect(groups.single.memberSignals.map((s) => s.signalId), [1, 2]);
    });

    test('untreated check variance exposes explicit family metadata', () {
      final context =
          const SignalReferenceContext(seType: 'UNTREATED').encodeJson();
      final groups = projectSignalGroupsForReview([
        _signal(
          id: 1,
          sessionId: 7,
          type: 'aov_prediction',
          referenceContext: context,
        ),
        _signal(
          id: 2,
          sessionId: 7,
          type: 'aov_prediction',
          referenceContext: context,
        ),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.familyKey, SignalFamilyKey.untreatedCheckVariance);
      expect(
        groups.single.familyScientificRole,
        'Untreated checks establish the baseline used for treatment comparison.',
      );
      expect(
        groups.single.familyInterpretationImpact,
        'Low untreated-check variation across related assessments may reduce confidence in treatment separation.',
      );
      expect(
        groups.single.reviewQuestion,
        'Are these assessments reliable enough for final comparison?',
      );
      expect(
        groups.single.familyDefinition,
        'Multiple review items point to the same untreated-check reliability concern.',
      );
      expect(groups.single.groupingBasis, contains('untreated-check'));
      expect(
          groups.single.groupingBasis, contains('assessment family UNTREATED'));
    });

    test('singleton uses singleton family metadata', () {
      final groups = projectSignalGroupsForReview([
        _signal(
          id: 1,
          type: 'scale_violation',
          consequenceText: 'Raw scale signal text.',
        ),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.familyKey, SignalFamilyKey.singleton);
      expect(groups.single.familyDefinition,
          'This review item is handled on its own.');
      expect(groups.single.familyScientificRole,
          'This review item should be considered on its own.');
      expect(groups.single.familyInterpretationImpact,
          'Its effect depends on the specific review context.');
      expect(groups.single.reviewQuestion,
          'Does this item need action before review or export?');
      expect(groups.single.groupingBasis, contains('Handled on its own'));
    });

    test('grouping does not depend on consequence text', () {
      final groups = projectSignalGroupsForReview([
        _signal(
          id: 1,
          sessionId: 7,
          plotId: 101,
          type: 'replication_warning',
          consequenceText: 'First generated consequence text.',
        ),
        _signal(
          id: 2,
          sessionId: 7,
          plotId: 102,
          type: 'replication_warning',
          consequenceText: 'Completely different generated text.',
        ),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.familyKey, SignalFamilyKey.replicationPattern);
      expect(groups.single.memberSignals.map((s) => s.signalId), [1, 2]);
    });

    test('interpretation fields do not depend on consequence text', () {
      final first = projectSignalGroupsForReview([
        _signal(
          id: 1,
          sessionId: 7,
          type: 'replication_warning',
          consequenceText: 'First generated consequence text.',
        ),
        _signal(
          id: 2,
          sessionId: 7,
          type: 'replication_warning',
          consequenceText: 'Second generated consequence text.',
        ),
      ]).single;

      final second = projectSignalGroupsForReview([
        _signal(
          id: 1,
          sessionId: 7,
          type: 'replication_warning',
          consequenceText: 'Changed wording A.',
        ),
        _signal(
          id: 2,
          sessionId: 7,
          type: 'replication_warning',
          consequenceText: 'Changed wording B.',
        ),
      ]).single;

      expect(second.familyScientificRole, first.familyScientificRole);
      expect(
          second.familyInterpretationImpact, first.familyInterpretationImpact);
      expect(second.reviewQuestion, first.reviewQuestion);
    });
  });
}
