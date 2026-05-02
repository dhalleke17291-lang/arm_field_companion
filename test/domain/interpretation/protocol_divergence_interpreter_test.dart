import 'package:arm_field_companion/domain/interpretation/protocol_divergence_interpreter.dart';
import 'package:arm_field_companion/domain/relationships/protocol_divergence.dart';
import 'package:flutter_test/flutter_test.dart';

ProtocolDivergence _div({
  required DivergenceType type,
  int? deltaDays,
  bool isMissing = false,
  bool isUnexpected = false,
}) {
  return ProtocolDivergence(
    entityId: '1',
    eventKind: EventKind.assessment,
    type: type,
    isMissing: isMissing,
    isUnexpected: isUnexpected,
    deltaDays: deltaDays,
  );
}

void main() {
  group('interpretProtocolDivergence', () {
    test('timing late — singular', () {
      final m = interpretProtocolDivergence(
        _div(type: DivergenceType.timing, deltaDays: 1),
      );
      expect(m.title, 'Rated Late');
      expect(m.description, '1 day later than planned');
    });

    test('timing late — plural', () {
      final m = interpretProtocolDivergence(
        _div(type: DivergenceType.timing, deltaDays: 3),
      );
      expect(m.title, 'Rated Late');
      expect(m.description, '3 days later than planned');
    });

    test('timing early — singular', () {
      final m = interpretProtocolDivergence(
        _div(type: DivergenceType.timing, deltaDays: -1),
      );
      expect(m.title, 'Rated Early');
      expect(m.description, '1 day earlier than planned');
    });

    test('timing early — plural', () {
      final m = interpretProtocolDivergence(
        _div(type: DivergenceType.timing, deltaDays: -2),
      );
      expect(m.title, 'Rated Early');
      expect(m.description, '2 days earlier than planned');
    });

    test('timing — deltaDays null', () {
      final m = interpretProtocolDivergence(
        _div(type: DivergenceType.timing, deltaDays: null),
      );
      expect(m.title, 'Timing Unknown');
      expect(m.description, 'Session dates could not be compared');
    });

    test('missing', () {
      final m = interpretProtocolDivergence(
        _div(type: DivergenceType.missing, isMissing: true),
      );
      expect(m.title, 'No Ratings Recorded');
      expect(m.description, 'Planned session has no recorded ratings');
    });

    test('unexpected', () {
      final m = interpretProtocolDivergence(
        _div(type: DivergenceType.unexpected, isUnexpected: true),
      );
      expect(m.title, 'Unplanned Session');
      expect(m.description, 'Session was not part of the protocol');
    });

    test('timing — deltaDays zero (defensive; provider omits on-plan timing rows)',
        () {
      final m = interpretProtocolDivergence(
        _div(type: DivergenceType.timing, deltaDays: 0),
      );
      expect(m.title, 'On Plan');
      expect(m.description, 'Rated on the planned date');
    });
  });
}
