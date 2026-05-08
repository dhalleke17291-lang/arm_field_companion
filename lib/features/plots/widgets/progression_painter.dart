import 'package:flutter/material.dart';

import '../../../core/design/app_design_tokens.dart';
import '../models/plot_analysis_models.dart';

class ProgressionPainter extends CustomPainter {
  const ProgressionPainter({
    required this.result,
    required this.colors,
  });

  final ProgressionResult result;
  final List<Color> colors;

  static const double _paddingLeft = 44.0;
  static const double _paddingRight = 16.0;
  static const double _paddingTop = 16.0;
  static const double _paddingBottom = 36.0;

  @override
  void paint(Canvas canvas, Size size) {
    final series = result.series;
    if (series.isEmpty) return;

    final chartW = size.width - _paddingLeft - _paddingRight;
    final chartH = size.height - _paddingTop - _paddingBottom;
    if (chartW <= 0 || chartH <= 0) return;

    // Global min/max across all series
    double globalMin = double.infinity;
    double globalMax = double.negativeInfinity;
    for (final s in series) {
      for (final p in s.points) {
        if (p.mean < globalMin) globalMin = p.mean;
        if (p.mean > globalMax) globalMax = p.mean;
      }
    }
    if (globalMin == double.infinity) return;

    final range = (globalMax - globalMin).abs();
    final buffer = range > 0 ? range * 0.12 : 1.0;
    final yMin = globalMin - buffer;
    final yMax = globalMax + buffer;
    final yRange = yMax - yMin;

    // Build ordered session list from labels
    final sessionLabels = result.sessionLabels;
    final nSessions = sessionLabels.length;
    if (nSessions == 0) return;

    // Build sessionId → x-index map from series data
    final allSessionIds = <int>[];
    for (final s in series) {
      for (final p in s.points) {
        if (!allSessionIds.contains(p.sessionId)) allSessionIds.add(p.sessionId);
      }
    }

    double toY(double value) =>
        _paddingTop + (1 - (value - yMin) / yRange) * chartH;

    double toX(int sessionIndex) {
      if (nSessions == 1) return _paddingLeft + chartW / 2;
      return _paddingLeft + (sessionIndex / (nSessions - 1)) * chartW;
    }

    // Y axis grid + labels
    final labelPaint = TextPainter(textDirection: TextDirection.ltr);
    final axisLinePaint = Paint()
      ..color = AppDesignTokens.borderCrisp
      ..strokeWidth = 1;
    final gridPaint = Paint()
      ..color = AppDesignTokens.borderCrisp.withValues(alpha: 0.6)
      ..strokeWidth = 0.5;

    for (var step = 0; step <= 2; step++) {
      final val = yMin + yRange * (step / 2);
      final y = toY(val);
      canvas.drawLine(
        Offset(_paddingLeft, y),
        Offset(size.width - _paddingRight, y),
        step == 0 || step == 2 ? axisLinePaint : gridPaint,
      );
      final label = _formatValue(val);
      labelPaint.text = TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 9,
          color: AppDesignTokens.secondaryText,
        ),
      );
      labelPaint.layout();
      labelPaint.paint(
        canvas,
        Offset(_paddingLeft - labelPaint.width - 4, y - labelPaint.height / 2),
      );
    }

    // X axis session labels
    for (var i = 0; i < nSessions; i++) {
      final x = toX(i);
      final label = sessionLabels[i];
      labelPaint.text = TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 9,
          color: AppDesignTokens.secondaryText,
        ),
      );
      labelPaint.layout(maxWidth: chartW / nSessions + 4);
      labelPaint.paint(
        canvas,
        Offset(x - labelPaint.width / 2, size.height - _paddingBottom + 4),
      );
    }

    // Draw each series
    for (var si = 0; si < series.length; si++) {
      final s = series[si];
      final color = colors[si % colors.length];

      if (s.points.isEmpty) continue;

      // Build x positions from sessionId ordering
      final points = s.points.map((p) {
        final idx = allSessionIds.indexOf(p.sessionId);
        return Offset(toX(idx), toY(p.mean));
      }).toList();

      // Draw line
      if (points.length > 1) {
        if (s.isCheck) {
          // Dashed line for check treatment
          _drawDashedLine(canvas, points, color);
        } else {
          final linePaint = Paint()
            ..color = color.withValues(alpha: 0.85)
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;
          final path = Path()..moveTo(points.first.dx, points.first.dy);
          for (var i = 1; i < points.length; i++) {
            path.lineTo(points[i].dx, points[i].dy);
          }
          canvas.drawPath(path, linePaint);
        }
      }

      // Draw dots
      for (final pt in points) {
        if (s.isCheck) {
          // Open circle for check
          canvas.drawCircle(
            pt,
            5,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
          canvas.drawCircle(
            pt,
            5,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.fill,
          );
        } else {
          canvas.drawCircle(pt, 5, Paint()..color = color);
          canvas.drawCircle(
            pt,
            5,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
      }
    }
  }

  void _drawDashedLine(Canvas canvas, List<Offset> points, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const dashLen = 6.0;
    const gapLen = 4.0;

    for (var i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      final total = (end - start).distance;
      if (total == 0) continue;
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final ux = dx / total;
      final uy = dy / total;
      var drawn = 0.0;
      var drawing = true;
      var cx = start.dx;
      var cy = start.dy;
      while (drawn < total) {
        final segLen = drawing ? dashLen : gapLen;
        final remaining = total - drawn;
        final actual = remaining < segLen ? remaining : segLen;
        final nx = cx + ux * actual;
        final ny = cy + uy * actual;
        if (drawing) {
          canvas.drawLine(Offset(cx, cy), Offset(nx, ny), paint);
        }
        cx = nx;
        cy = ny;
        drawn += actual;
        drawing = !drawing;
      }
    }
  }

  String _formatValue(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    if (v.abs() >= 10) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  @override
  bool shouldRepaint(covariant ProgressionPainter old) =>
      old.result != result || old.colors != colors;
}
