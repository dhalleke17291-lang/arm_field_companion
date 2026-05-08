import 'dart:math' as math;

import 'package:flutter/material.dart';

class DistributionPainter extends CustomPainter {
  final List<double?> values;
  final List<bool> isOutlier;
  final List<String> repLabels;
  final double? mean;
  final Color treatmentColor;
  final double scaleMin;
  final double scaleMax;

  const DistributionPainter({
    required this.values,
    required this.isOutlier,
    required this.repLabels,
    required this.mean,
    required this.treatmentColor,
    this.scaleMin = 0,
    this.scaleMax = 100,
  });

  double _toX(double v, double width) =>
      ((v - scaleMin) / (scaleMax - scaleMin)) * width;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;

    // 1 — Baseline
    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width, cy),
      Paint()
        ..color = Colors.grey.withValues(alpha:0.25)
        ..strokeWidth = 0.5,
    );

    // 2 — Range line between min and max of non-null values
    final nonNull = values.whereType<double>().toList();
    if (nonNull.length > 1) {
      final minX = _toX(nonNull.reduce(math.min), size.width);
      final maxX = _toX(nonNull.reduce(math.max), size.width);
      canvas.drawLine(
        Offset(minX, cy),
        Offset(maxX, cy),
        Paint()
          ..color = treatmentColor.withValues(alpha:0.2)
          ..strokeWidth = 2,
      );
    }

    // 3 — Rep dots — drawn before mean diamond so diamond is always on top
    for (int i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      final cx = _toX(v, size.width);
      final outlier = i < isOutlier.length && isOutlier[i];

      // Fill
      canvas.drawCircle(
        Offset(cx, cy),
        6,
        Paint()
          ..color = outlier
              ? const Color(0xFFEF9F27)
              : treatmentColor.withValues(alpha:0.65)
          ..style = PaintingStyle.fill,
      );

      // Stroke
      canvas.drawCircle(
        Offset(cx, cy),
        6,
        Paint()
          ..color = outlier ? const Color(0xFFBA7517) : Colors.white
          ..strokeWidth = outlier ? 2.0 : 1.5
          ..style = PaintingStyle.stroke,
      );

      // Rep label — only on outlier dots
      if (outlier && i < repLabels.length) {
        final tp = TextPainter(
          text: TextSpan(
            text: repLabels[i],
            style: const TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(cx - tp.width / 2, cy - tp.height / 2),
        );
      }
    }

    // 4 — Mean diamond — drawn last so it sits on top of all dots
    if (mean != null) {
      final mx = _toX(mean!, size.width);
      const ds = 7.0;
      final path = Path()
        ..moveTo(mx, cy - ds)
        ..lineTo(mx + ds * 0.6, cy)
        ..lineTo(mx, cy + ds)
        ..lineTo(mx - ds * 0.6, cy)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = treatmentColor
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(DistributionPainter old) =>
      old.values != values ||
      old.mean != mean ||
      old.treatmentColor != treatmentColor ||
      old.isOutlier != isOutlier;
}
