import 'package:flutter/material.dart';

import '../design/app_design_tokens.dart';

/// Opens a modal bottom sheet with a [DraggableScrollableSheet] using shared
/// Agnexis styling: rounded top, keyboard-safe inset padding, and optional
/// snap heights so users can pull content to a comfortable size or nearly
/// full screen without changing sheet internals.
///
/// Use with scrollable bodies that accept the provided [ScrollController]
/// (e.g. [ListView], [CustomScrollView]). Form layouts that already include a
/// drag handle (e.g. [StandardFormBottomSheetLayout]) should keep
/// [showDragHandle] false on the modal — this helper does not add a second
/// system handle.
///
/// For in-screen (non-modal) split layouts, use [DraggableScrollableSheet]
/// directly with the same size defaults if needed.
Future<T?> showAppDraggableModalSheet<T>({
  required BuildContext context,
  required Widget Function(
    BuildContext sheetContext,
    ScrollController scrollController,
  ) sheetBuilder,
  bool useRootNavigator = false,
  double initialChildSize = 0.75,
  double minChildSize = 0.45,
  double maxChildSize = 0.95,
  bool snap = true,
  List<double>? snapSizes,
}) {
  assert(
    minChildSize <= initialChildSize && initialChildSize <= maxChildSize,
    'Child sizes must satisfy min ≤ initial ≤ max.',
  );
  assert(maxChildSize <= 1.0 && minChildSize > 0, 'Sizes must be in (0, 1].');

  final List<double> resolvedSnapSizes;
  if (snap) {
    final raw = snapSizes ??
        <double>[minChildSize, initialChildSize, maxChildSize];
    resolvedSnapSizes = raw.toSet().toList()..sort();
    for (final s in resolvedSnapSizes) {
      assert(
        s >= minChildSize && s <= maxChildSize,
        'Each snap size must be between minChildSize and maxChildSize.',
      );
    }
  } else {
    resolvedSnapSizes = <double>[];
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: useRootNavigator,
    backgroundColor: AppDesignTokens.cardSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    showDragHandle: false,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        expand: false,
        snap: snap,
        snapSizes: snap ? resolvedSnapSizes : null,
        snapAnimationDuration: const Duration(milliseconds: 200),
        builder: (_, scrollController) =>
            sheetBuilder(sheetContext, scrollController),
      ),
    ),
  );
}
