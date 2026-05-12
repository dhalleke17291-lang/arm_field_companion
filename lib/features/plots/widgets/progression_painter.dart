import 'package:flutter/material.dart';

import '../../../core/design/app_design_tokens.dart';
import '../models/plot_analysis_models.dart';

class ProgressionPainter extends CustomPainter {
  const ProgressionPainter({
    required this.result,
    required this.colors,
    this.axisUnit,
  });

  final ProgressionResult result;
  final List<Color> colors;
  final String? axisUnit;

  static const double _paddingLeft = 74.0;
  static const double _paddingRight = 30.0;
  static const double _paddingTop = 28.0;
  static const double _paddingBottom = 50.0;

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
    final rawYMin = globalMin - buffer;
    final rawYMax = globalMax + buffer;
    final yMin =
        globalMin >= 0 && rawYMin < 0 ? 0.0 : _roundDownToNearestFive(rawYMin);
    var yMax = _roundUpToNearestFive(rawYMax);
    if (yMax <= yMin) yMax = yMin + 5;
    final yRange = yMax - yMin;

    // Build ordered session list from labels
    final assessmentLabels = result.assessmentLabels;
    final nSessions = assessmentLabels.length;
    if (nSessions == 0) return;

    // Build sessionId → x-index map from series data
    final allSessionIds = <int>[];
    for (final s in series) {
      for (final p in s.points) {
        if (!allSessionIds.contains(p.sessionId)) {
          allSessionIds.add(p.sessionId);
        }
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
      ..color = AppDesignTokens.divider.withValues(alpha: 0.35)
      ..strokeWidth = 0.5;
    final axisCaption = _axisCaption();
    if (axisCaption != null) {
      labelPaint.text = TextSpan(
        text: axisCaption,
        style: const TextStyle(
          fontSize: 11,
          color: AppDesignTokens.secondaryText,
          fontWeight: FontWeight.w600,
        ),
      );
      labelPaint.textAlign = TextAlign.right;
      labelPaint.layout();
      labelPaint.paint(
        canvas,
        Offset(
            (_paddingLeft - labelPaint.width - 8).clamp(0.0, _paddingLeft), 0),
      );
    }

    for (final val in [yMin, yMax]) {
      final y = toY(val);
      canvas.drawLine(
        Offset(_paddingLeft, y),
        Offset(size.width - _paddingRight, y),
        axisLinePaint,
      );
      final label = _formatAxisValue(val);
      labelPaint.text = TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 12,
          color: AppDesignTokens.primaryText,
        ),
      );
      labelPaint.layout();
      labelPaint.paint(
        canvas,
        Offset(_paddingLeft - labelPaint.width - 8, y - labelPaint.height / 2),
      );
    }

    // X axis session labels
    for (var i = 0; i < nSessions; i++) {
      final x = toX(i);
      final label = _compactSessionLabel(assessmentLabels[i]);
      final maxLabelWidth = nSessions == 1
          ? chartW
          : (chartW / nSessions + 40).clamp(76.0, 120.0);
      labelPaint.text = TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 12,
          height: 1.0,
          color: AppDesignTokens.secondaryText,
          fontWeight: FontWeight.w600,
        ),
      );
      labelPaint.textAlign = TextAlign.center;
      labelPaint.layout(maxWidth: maxLabelWidth);
      final labelLeft = _xAxisLabelLeft(
        x: x,
        labelWidth: labelPaint.width,
        labelIndex: i,
        labelCount: nSessions,
        chartRight: size.width - _paddingRight,
      );
      labelPaint.paint(
        canvas,
        Offset(labelLeft, size.height - _paddingBottom + 12),
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

      final terminalPoint = points.last;
      final terminalValue = s.points.last.mean;
      _paintTerminalLabel(
        canvas: canvas,
        size: size,
        labelPainter: labelPaint,
        dotCenter: terminalPoint,
        value: terminalValue,
        color: color,
        verticalOffset: s.isCheck ? -4.0 : 0.0,
      );

      // Leading label — first session, left of dot
      if (s.points.length > 1) {
        _paintLeadingLabel(
          canvas: canvas,
          size: size,
          labelPainter: labelPaint,
          dotCenter: points.first,
          value: s.points.first.mean,
          color: color,
          verticalOffset: s.isCheck ? -4.0 : 0.0,
        );
      }
    }
  }

  void _paintTerminalLabel({
    required Canvas canvas,
    required Size size,
    required TextPainter labelPainter,
    required Offset dotCenter,
    required double value,
    required Color color,
    double verticalOffset = 0.0,
  }) {
    labelPainter
      ..textAlign = TextAlign.left
      ..text = TextSpan(
        text: _formatValue(value),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      )
      ..layout();

    const gap = 8.0;
    var left = dotCenter.dx + gap;
    if (left + labelPainter.width > size.width - 2) {
      left = dotCenter.dx - gap - labelPainter.width;
    }
    left = left.clamp(0.0, size.width - labelPainter.width);
    labelPainter.paint(
      canvas,
      Offset(left, dotCenter.dy - labelPainter.height / 2 + verticalOffset),
    );
  }

  void _paintLeadingLabel({
    required Canvas canvas,
    required Size size,
    required TextPainter labelPainter,
    required Offset dotCenter,
    required double value,
    required Color color,
    double verticalOffset = 0.0,
  }) {
    labelPainter
      ..textAlign = TextAlign.left
      ..text = TextSpan(
        text: _formatValue(value),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      )
      ..layout();

    const gap = 8.0;
    var left = dotCenter.dx - gap - labelPainter.width;
    if (left < 0) left = dotCenter.dx + gap;
    left = left.clamp(0.0, size.width - labelPainter.width);
    labelPainter.paint(
      canvas,
      Offset(left, dotCenter.dy - labelPainter.height / 2 + verticalOffset),
    );
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

  String _formatAxisValue(double value) {
    final unit = axisUnit?.trim();
    final formatted = _formatValue(value);
    if (unit == null || unit.isEmpty) return formatted;
    if (unit == '%') return '$formatted%';
    return '$formatted $unit';
  }

  String? _axisCaption() {
    final unit = axisUnit?.trim();
    if (unit == null || unit.isEmpty) return 'Mean value';
    if (unit == '%') return 'Mean (%)';
    return 'Mean ($unit)';
  }

  double _roundDownToNearestFive(double value) {
    return (value / 5).floorToDouble() * 5;
  }

  double _roundUpToNearestFive(double value) {
    return (value / 5).ceilToDouble() * 5;
  }

  String _compactSessionLabel(String label) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})\s+Session\s+(\d+)$')
        .firstMatch(label.trim());
    if (match == null) return label;
    final month = switch (match.group(2)) {
      '01' => 'Jan',
      '02' => 'Feb',
      '03' => 'Mar',
      '04' => 'Apr',
      '05' => 'May',
      '06' => 'Jun',
      '07' => 'Jul',
      '08' => 'Aug',
      '09' => 'Sep',
      '10' => 'Oct',
      '11' => 'Nov',
      '12' => 'Dec',
      _ => match.group(2)!,
    };
    final day = int.tryParse(match.group(3)!) ?? match.group(3)!;
    return '$month $day · S${match.group(4)}';
  }

  double _xAxisLabelLeft({
    required double x,
    required double labelWidth,
    required int labelIndex,
    required int labelCount,
    required double chartRight,
  }) {
    if (labelCount == 1) {
      return (_paddingLeft + (chartRight - _paddingLeft - labelWidth) / 2)
          .clamp(_paddingLeft, chartRight - labelWidth);
    }
    if (labelIndex == 0) return _paddingLeft;
    if (labelIndex == labelCount - 1) return chartRight - labelWidth;
    return (x - labelWidth / 2).clamp(_paddingLeft, chartRight - labelWidth);
  }

  @override
  bool shouldRepaint(covariant ProgressionPainter old) =>
      old.result != result || old.colors != colors;
}
