import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/features/plots/widgets/progression_painter.dart';

void main() {
  group('resolveProgressionLabelCollisions', () {
    const labelH = 14.0; // representative text height
    const canvasTop = 28.0;
    const canvasBottom = 350.0;

    ProgressionLabelLayout makeLabel(double top) => ProgressionLabelLayout(
          text: '19.0',
          color: Colors.black,
          left: 100,
          top: top,
        );

    // PP-1: two labels at identical Y → separated after resolution
    test('PP-1: labels at same Y are separated by at least labelH', () {
      final a = makeLabel(100.0);
      final b = makeLabel(100.0);
      resolveProgressionLabelCollisions(
        [a, b],
        labelH,
        canvasTop: canvasTop,
        canvasBottom: canvasBottom,
      );

      final upper = a.top < b.top ? a : b;
      final lower = a.top < b.top ? b : a;
      expect(lower.top - upper.top, greaterThanOrEqualTo(labelH));
    });

    // PP-2: labels already separated → unchanged
    test('PP-2: labels already separated are not moved', () {
      final a = makeLabel(50.0);
      final b = makeLabel(80.0); // gap = 30 > labelH=14
      resolveProgressionLabelCollisions(
        [a, b],
        labelH,
        canvasTop: canvasTop,
        canvasBottom: canvasBottom,
      );
      expect(a.top, 50.0);
      expect(b.top, 80.0);
    });

    // PP-3: three labels all at same Y → each pair separated
    test('PP-3: three labels at same Y are all mutually separated', () {
      final labels = [makeLabel(100.0), makeLabel(100.0), makeLabel(100.0)];
      resolveProgressionLabelCollisions(
        labels,
        labelH,
        canvasTop: canvasTop,
        canvasBottom: canvasBottom,
      );

      labels.sort((a, b) => a.top.compareTo(b.top));
      for (var i = 0; i < labels.length - 1; i++) {
        expect(
          labels[i + 1].top - labels[i].top,
          greaterThanOrEqualTo(labelH),
          reason: 'labels[$i] and labels[${i + 1}] overlap',
        );
      }
    });

    // PP-4: labels close but not identical → also separated
    test('PP-4: labels 2 px apart with labelH=14 → separated', () {
      final a = makeLabel(100.0);
      final b = makeLabel(102.0); // gap = 2 < labelH=14
      resolveProgressionLabelCollisions(
        [a, b],
        labelH,
        canvasTop: canvasTop,
        canvasBottom: canvasBottom,
      );

      final lower = a.top > b.top ? a : b;
      final upper = a.top > b.top ? b : a;
      expect(lower.top - upper.top, greaterThanOrEqualTo(labelH));
    });

    // PP-5: collision near canvas bottom → upper is pushed up, not outside top
    test('PP-5: collision near bottom stays within canvas', () {
      const nearBottom = canvasBottom - labelH - 2.0;
      final a = makeLabel(nearBottom);
      final b = makeLabel(nearBottom); // same Y, no room below
      resolveProgressionLabelCollisions(
        [a, b],
        labelH,
        canvasTop: canvasTop,
        canvasBottom: canvasBottom,
      );

      for (final lbl in [a, b]) {
        expect(lbl.top, greaterThanOrEqualTo(canvasTop));
        expect(lbl.top + labelH, lessThanOrEqualTo(canvasBottom + 0.001));
      }
    });
  });
}
