import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/plot_display.dart';
import '../../core/plot_sort.dart';
import '../../core/session_walk_order_store.dart';
import '../../core/providers.dart';

/// Screen to arrange plot order for custom walk order. Drag to reorder, then Save.
class ArrangePlotsScreen extends ConsumerStatefulWidget {
  const ArrangePlotsScreen({
    super.key,
    required this.trial,
    required this.session,
  });

  final Trial trial;
  final Session session;

  @override
  ConsumerState<ArrangePlotsScreen> createState() => _ArrangePlotsScreenState();
}

class _ArrangePlotsScreenState extends ConsumerState<ArrangePlotsScreen> {
  List<Plot> _orderedPlots = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlotsAndOrder());
  }

  Future<void> _loadPlotsAndOrder() async {
    final plots = await ref.read(plotsForTrialProvider(widget.trial.id).future);
    if (!mounted) return;
    if (plots.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No plots in this trial.';
      });
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final store = SessionWalkOrderStore(prefs);
    final customIds = store.getCustomOrder(widget.session.id);
    final ordered = customIds != null && customIds.isNotEmpty
        ? sortPlotsByCustomOrder(plots, customIds)
        : sortPlotsSerpentine(plots);
    if (!mounted) return;
    setState(() {
      _orderedPlots = ordered;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_orderedPlots.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final store = SessionWalkOrderStore(prefs);
    await store.setCustomOrder(widget.session.id, _orderedPlots.map((p) => p.id).toList());
    await store.setMode(widget.session.id, WalkOrderMode.custom);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Arrange plot order')),
        body: const SafeArea(top: false, child: Center(child: CircularProgressIndicator())),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Arrange plot order')),
        body: SafeArea(top: false, child: Center(child: Text(_error!))),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arrange plot order'),
        actions: [
          TextButton(
            onPressed: _orderedPlots.isEmpty ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(top: false, child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Drag to reorder. This order will be used for Save & Next Plot when Custom walk order is selected.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _orderedPlots.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _orderedPlots.removeAt(oldIndex);
                  _orderedPlots.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final plot = _orderedPlots[index];
                final label = getDisplayPlotLabel(plot, _orderedPlots);
                return ListTile(
                  key: ValueKey(plot.id),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle, color: AppDesignTokens.secondaryText),
                  ),
                  title: Text('Plot $label'),
                  subtitle: plot.rep != null ? Text('Rep ${plot.rep}') : null,
                );
              },
            ),
          ),
        ],
      )),
    );
  }
}
