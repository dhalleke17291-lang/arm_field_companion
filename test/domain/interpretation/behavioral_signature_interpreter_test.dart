import 'package:arm_field_companion/domain/interpretation/behavioral_signature_interpreter.dart';
import 'package:arm_field_companion/domain/relationships/behavioral_signature_provider.dart';
import 'package:flutter_test/flutter_test.dart';

BehavioralSignal _signal(BehavioralSignalType type, double value) =>
    BehavioralSignal(sessionId: 1, type: type, value: value);

void main() {
  group('interpretBehavioralSignal — paceChange', () {
    test('negative value → Later Ratings Faster', () {
      final m = interpretBehavioralSignal(
        _signal(BehavioralSignalType.paceChange, -90.0),
      );
      expect(m.title, 'Later Ratings Faster');
      expect(m.description,
          'Later ratings took less time on average than earlier ones');
    });

    test('positive value → Later Ratings Slower', () {
      final m = interpretBehavioralSignal(
        _signal(BehavioralSignalType.paceChange, 90.0),
      );
      expect(m.title, 'Later Ratings Slower');
      expect(m.description,
          'Later ratings took more time on average than earlier ones');
    });

    test('zero value → Pace Unchanged', () {
      final m = interpretBehavioralSignal(
        _signal(BehavioralSignalType.paceChange, 0.0),
      );
      expect(m.title, 'Pace Unchanged');
      expect(m.description,
          'No pace difference was detected between earlier and later ratings');
    });
  });

  group('interpretBehavioralSignal — confidenceTrend', () {
    test('positive value → Confidence Rising', () {
      final m = interpretBehavioralSignal(
        _signal(BehavioralSignalType.confidenceTrend, 1.0),
      );
      expect(m.title, 'Confidence Rising');
      expect(m.description,
          'Confidence was higher in later ratings than in earlier ones');
    });

    test('negative value → Confidence Falling', () {
      final m = interpretBehavioralSignal(
        _signal(BehavioralSignalType.confidenceTrend, -1.0),
      );
      expect(m.title, 'Confidence Falling');
      expect(m.description,
          'Confidence was lower in later ratings than in earlier ones');
    });

    test('zero value → Confidence Stable', () {
      final m = interpretBehavioralSignal(
        _signal(BehavioralSignalType.confidenceTrend, 0.0),
      );
      expect(m.title, 'Confidence Stable');
      expect(m.description,
          'No confidence difference was detected between earlier and later ratings');
    });
  });

  group('interpretBehavioralSignal — editFrequency', () {
    test('0 edits → No Edits', () {
      final m = interpretBehavioralSignal(
        _signal(BehavioralSignalType.editFrequency, 0.0),
      );
      expect(m.title, 'No Edits');
      expect(m.description, 'No ratings were amended or corrected');
    });

    test('1 edit → singular description', () {
      final m = interpretBehavioralSignal(
        _signal(BehavioralSignalType.editFrequency, 1.0),
      );
      expect(m.title, '1 Edit');
      expect(m.description, '1 rating was amended or corrected');
    });

    test('2 edits → plural description', () {
      final m = interpretBehavioralSignal(
        _signal(BehavioralSignalType.editFrequency, 2.0),
      );
      expect(m.title, '2 Edits');
      expect(m.description, '2 ratings were amended or corrected');
    });

    test('5 edits → plural description with count', () {
      final m = interpretBehavioralSignal(
        _signal(BehavioralSignalType.editFrequency, 5.0),
      );
      expect(m.title, '5 Edits');
      expect(m.description, '5 ratings were amended or corrected');
    });
  });
}
