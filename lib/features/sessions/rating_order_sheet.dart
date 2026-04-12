import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';

/// Bottom sheet content to set the order of assessments for rating (same sequence for every plot).
/// Use from Session detail (Rate tab) or from Rating screen app bar menu.
class RatingOrderSheetContent extends StatefulWidget {
  const RatingOrderSheetContent({
    super.key,
    required this.session,
    required this.assessments,
    required this.ref,
    required this.onSaved,
  });

  final Session session;
  final List<Assessment> assessments;
  final WidgetRef ref;
  final VoidCallback onSaved;

  @override
  State<RatingOrderSheetContent> createState() =>
      _RatingOrderSheetContentState();
}

class _RatingOrderSheetContentState extends State<RatingOrderSheetContent> {
  late List<Assessment> _ordered;

  @override
  void initState() {
    super.initState();
    _ordered = List.from(widget.assessments);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Rating order',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Drag to set the order. This sequence applies to every plot.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _ordered.length * 56.0 + 24,
            child: ReorderableListView(
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _ordered.removeAt(oldIndex);
                  _ordered.insert(newIndex, item);
                });
              },
              proxyDecorator: (child, index, animation) => Material(
                elevation: 4,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                child: child,
              ),
              children: [
                for (var i = 0; i < _ordered.length; i++)
                  ListTile(
                    key: ValueKey<int>(_ordered[i].id),
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle),
                    ),
                    title: Text(_ordered[i].name),
                    subtitle: Text(
                      '${_ordered[i].dataType}${_ordered[i].unit != null ? ' (${_ordered[i].unit})' : ''}',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  final repo = widget.ref.read(sessionRepositoryProvider);
                  await repo.updateSessionAssessmentOrder(
                    widget.session.id,
                    _ordered.map((a) => a.id).toList(),
                  );
                  widget.onSaved();
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
