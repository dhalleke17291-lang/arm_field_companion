import 'package:flutter/material.dart';

import '../../../core/design/app_design_tokens.dart';

class RatingGpsPill extends StatelessWidget {
  const RatingGpsPill({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.captureOnEachSave,
    required this.onToggleMode,
  });

  final double latitude;
  final double longitude;
  final bool captureOnEachSave;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    final precision = captureOnEachSave ? 5 : 3;
    final latStr = latitude.toStringAsFixed(precision);
    final lngStr = longitude.toStringAsFixed(precision);

    return Tooltip(
      message: captureOnEachSave
          ? 'GPS captured on every save — tap to switch to session-only'
          : 'GPS captured once at session start — tap to switch to per-save',
      child: Material(
        color: AppDesignTokens.successFg.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: AppDesignTokens.successFg.withValues(alpha: 0.45),
            width: 0.75,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onToggleMode,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  captureOnEachSave
                      ? Icons.my_location
                      : Icons.location_searching,
                  size: 13,
                  color: AppDesignTokens.successFg,
                ),
                const SizedBox(width: 5),
                Text(
                  '$latStr, $lngStr',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppDesignTokens.successFg,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
