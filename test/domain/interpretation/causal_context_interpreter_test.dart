import 'package:arm_field_companion/domain/interpretation/causal_context_interpreter.dart';
import 'package:arm_field_companion/domain/relationships/causal_context_provider.dart';
import 'package:flutter_test/flutter_test.dart';

CausalEvent _application(int? daysBefore) => CausalEvent(
      type: CausalEventType.application,
      eventDate: null,
      daysBefore: daysBefore,
      label: 'Application',
    );

CausalEvent _weather() => const CausalEvent(
      type: CausalEventType.weather,
      eventDate: null,
      daysBefore: null,
      label: 'Weather',
    );

void main() {
  group('interpretCausalEvent — application', () {
    test('same day (0) → correct description', () {
      final m = interpretCausalEvent(_application(0));
      expect(m.title, 'Prior Application');
      expect(m.description,
          'Application occurred on the same day as this rating');
    });

    test('1 day before → singular description', () {
      final m = interpretCausalEvent(_application(1));
      expect(m.title, 'Prior Application');
      expect(m.description, 'Application occurred 1 day before this rating');
    });

    test('multiple days before → plural description with count', () {
      final m = interpretCausalEvent(_application(5));
      expect(m.title, 'Prior Application');
      expect(m.description, 'Application occurred 5 days before this rating');
    });

    test('null daysBefore → timing not comparable', () {
      final m = interpretCausalEvent(_application(null));
      expect(m.title, 'Prior Application');
      expect(m.description, 'Application timing could not be compared');
    });

    test('negative daysBefore → date is after rating', () {
      final m = interpretCausalEvent(_application(-3));
      expect(m.title, 'Prior Application');
      expect(m.description, 'Application date is after this rating date');
    });
  });

  group('interpretCausalEvent — weather', () {
    test('weather event → Session Weather with standard description', () {
      final m = interpretCausalEvent(_weather());
      expect(m.title, 'Session Weather');
      expect(m.description,
          'Weather conditions were recorded for this rating session');
    });
  });
}
