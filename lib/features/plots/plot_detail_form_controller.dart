import '../../core/database/app_database.dart';

/// Allowed plot direction dropdown values (shared with plot detail UI).
const List<String> kPlotDirectionOptions = [
  'North',
  'South',
  'East',
  'West',
  'NE',
  'NW',
  'SE',
  'SW',
  'Other',
];

/// In-memory snapshot for the plot details form (dimensions, direction, soil
/// series, notes, guard row).
class PlotFormDraft {
  const PlotFormDraft({
    required this.plotLength,
    required this.plotWidth,
    required this.plotArea,
    required this.harvestLength,
    required this.harvestWidth,
    required this.harvestArea,
    required this.plotAreaOverride,
    required this.harvestAreaOverride,
    required this.direction,
    required this.isDirectionOther,
    required this.directionOtherText,
    required this.soilSeries,
    required this.plotNotes,
    required this.isGuardRow,
  });

  final double? plotLength;
  final double? plotWidth;
  final double? plotArea;
  final double? harvestLength;
  final double? harvestWidth;
  final double? harvestArea;
  final bool plotAreaOverride;
  final bool harvestAreaOverride;

  /// Dropdown value: null, a known direction string, or `'Other'`.
  final String? direction;

  /// True when [direction] is `'Other'`.
  final bool isDirectionOther;

  final String directionOtherText;

  /// Soil series field (raw text).
  final String soilSeries;

  final String plotNotes;

  final bool isGuardRow;

  /// Builds initial draft from a [Plot] row (direction normalization, area
  /// override detection).
  factory PlotFormDraft.fromPlot(Plot plot, List<String> knownDirections) {
    final dir = plot.plotDirection?.trim() ?? '';
    String? directionDropdown;
    var directionOtherText = '';
    if (dir.isEmpty) {
      directionDropdown = null;
    } else if (knownDirections.contains(dir)) {
      directionDropdown = dir;
    } else {
      directionDropdown = 'Other';
      directionOtherText = dir;
    }

    final plotAreaOverride = plot.plotAreaM2 != null &&
        plot.plotLengthM != null &&
        plot.plotWidthM != null &&
        (plot.plotAreaM2! - (plot.plotLengthM! * plot.plotWidthM!)).abs() >
            0.001;

    final harvestAreaOverride = plot.harvestAreaM2 != null &&
        plot.harvestLengthM != null &&
        plot.harvestWidthM != null &&
        (plot.harvestAreaM2! - (plot.harvestLengthM! * plot.harvestWidthM!))
                .abs() >
            0.001;

    return PlotFormDraft(
      plotLength: plot.plotLengthM,
      plotWidth: plot.plotWidthM,
      plotArea: plot.plotAreaM2,
      harvestLength: plot.harvestLengthM,
      harvestWidth: plot.harvestWidthM,
      harvestArea: plot.harvestAreaM2,
      plotAreaOverride: plotAreaOverride,
      harvestAreaOverride: harvestAreaOverride,
      direction: directionDropdown,
      isDirectionOther: directionDropdown == 'Other',
      directionOtherText: directionOtherText,
      soilSeries: plot.soilSeries ?? '',
      plotNotes: plot.plotNotes ?? '',
      isGuardRow: plot.isGuardRow,
    );
  }
}

/// Parameters for [PlotRepository.updatePlotDetails] produced from a
/// [PlotFormDraft] (parsed numeric fields + override flags).
class UpdatePlotDetailsPayload {
  const UpdatePlotDetailsPayload({
    required this.plotLengthM,
    required this.plotWidthM,
    required this.plotAreaM2,
    required this.harvestLengthM,
    required this.harvestWidthM,
    required this.harvestAreaM2,
    required this.plotDirection,
    required this.soilSeries,
    required this.plotNotes,
  });

  final double? plotLengthM;
  final double? plotWidthM;
  final double? plotAreaM2;
  final double? harvestLengthM;
  final double? harvestWidthM;
  final double? harvestAreaM2;
  final String? plotDirection;
  final String? soilSeries;
  final String? plotNotes;
}

/// Domain helpers for plot detail form: draft-from-plot, save payload, parsing.
class PlotDetailFormController {
  PlotDetailFormController({List<String>? knownDirections})
      : _knownDirections = knownDirections ?? kPlotDirectionOptions;

  final List<String> _knownDirections;

  PlotFormDraft fromPlot(Plot plot) =>
      PlotFormDraft.fromPlot(plot, _knownDirections);

  /// Resolves plot/harvest areas (override vs L×W) and direction for
  /// [updatePlotDetails]. Does not perform I/O.
  UpdatePlotDetailsPayload buildUpdatePayload(PlotFormDraft current) {
    final plotLen = current.plotLength;
    final plotWid = current.plotWidth;
    final harvestLen = current.harvestLength;
    final harvestWid = current.harvestWidth;

    final plotArea = current.plotAreaOverride
        ? current.plotArea
        : (plotLen != null && plotWid != null ? plotLen * plotWid : null);

    final harvestArea = current.harvestAreaOverride
        ? current.harvestArea
        : (harvestLen != null && harvestWid != null
            ? harvestLen * harvestWid
            : null);

    String? direction;
    if (current.direction == 'Other') {
      direction = current.directionOtherText.trim().isEmpty
          ? null
          : current.directionOtherText.trim();
    } else if (current.direction != null && current.direction!.isNotEmpty) {
      direction = current.direction;
    }

    final soilTrim = current.soilSeries.trim();
    final notesTrim = current.plotNotes.trim();

    return UpdatePlotDetailsPayload(
      plotLengthM: plotLen,
      plotWidthM: plotWid,
      plotAreaM2: plotArea,
      harvestLengthM: harvestLen,
      harvestWidthM: harvestWid,
      harvestAreaM2: harvestArea,
      plotDirection: direction,
      soilSeries: soilTrim.isEmpty ? null : soilTrim,
      plotNotes: notesTrim.isEmpty ? null : notesTrim,
    );
  }

  static double? parseDouble(String? text) {
    final s = text?.trim() ?? '';
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  static String doubleToFieldText(double? v) => v?.toString() ?? '';
}
