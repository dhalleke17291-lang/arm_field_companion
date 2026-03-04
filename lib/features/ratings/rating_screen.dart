import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import 'package:drift/drift.dart' as drift;
import 'usecases/save_rating_usecase.dart';

class RatingScreen extends ConsumerStatefulWidget {
  final Trial trial;
  final Session session;
  final Plot plot;
  final List<Assessment> assessments;
  final List<Plot> allPlots;
  final int currentPlotIndex;

  const RatingScreen({
    super.key,
    required this.trial,
    required this.session,
    required this.plot,
    required this.assessments,
    required this.allPlots,
    required this.currentPlotIndex,
  });

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  late Assessment _currentAssessment;
  late int _assessmentIndex;
  final TextEditingController _valueController = TextEditingController();
  String _selectedStatus = 'RECORDED';
  bool _isSaving = false;


  // Missing condition reasons per spec
  final List<String> _missingReasons = [
    'Hail', 'Flood', 'Animal Damage',
    'Spray Miss', 'Lodging', 'Harvested', 'Other'
  ];
  String? _selectedMissingReason;

  @override
  void initState() {
    super.initState();
    _assessmentIndex = 0;
    _currentAssessment = widget.assessments[0];
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existingRatingAsync = ref.watch(currentRatingProvider(
      CurrentRatingParams(
        trialId: widget.trial.id,
        plotPk: widget.plot.id,
        assessmentId: _currentAssessment.id,
        sessionId: widget.session.id,
      ),
    ));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plot ${widget.plot.plotId}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
                '${widget.currentPlotIndex + 1} of ${widget.allPlots.length} plots',
                style:
                    const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => _showFlagDialog(context),
            tooltip: 'Flag plot',
          ),
        ],
      ),
      body: Column(
        children: [
          // Plot info bar
          _buildPlotInfoBar(context),

          // Assessment selector
          _buildAssessmentSelector(context),

          // Main rating area
          Expanded(
            child: existingRatingAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (existing) => _buildRatingArea(context, existing),
            ),
          ),

          // Bottom action bar
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildPlotInfoBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Icon(Icons.grid_on,
              size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text('Plot ${widget.plot.plotId}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary)),
          if (widget.plot.rep != null) ...[
            const SizedBox(width: 12),
            Text('Rep ${widget.plot.rep}',
                style: const TextStyle(color: Colors.grey)),
          ],
          const Spacer(),
          if (widget.session.raterName != null)
            Text(widget.session.raterName!,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAssessmentSelector(BuildContext context) {
    if (widget.assessments.length == 1) {
      return Container(
        padding: const EdgeInsets.all(12),
        child: Text(
          _currentAssessment.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: widget.assessments.length,
        itemBuilder: (context, index) {
          final assessment = widget.assessments[index];
          final isSelected = assessment.id == _currentAssessment.id;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(assessment.name),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _assessmentIndex = index;
                  _currentAssessment = assessment;
                  _valueController.clear();
                  _selectedStatus = 'RECORDED';
                  _selectedMissingReason = null;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildRatingArea(BuildContext context, RatingRecord? existing) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show existing rating if any
          if (existing != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Current: ${existing.resultStatus == 'RECORDED' ? existing.numericValue?.toString() ?? '-' : existing.resultStatus}',
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _undoRating(context, existing),
                    child: const Text('Undo',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),

          // Status selector
          const Text('Status',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              'RECORDED',
              'NOT_OBSERVED',
              'NOT_APPLICABLE',
              'MISSING_CONDITION',
              'TECHNICAL_ISSUE',
            ].map((status) {
              final isSelected = _selectedStatus == status;
              return ChoiceChip(
                label: Text(_statusLabel(status),
                    style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : null)),
                selected: isSelected,
                selectedColor: _statusColor(status),
                onSelected: (_) {
                  setState(() {
                    _selectedStatus = status;
                    if (status != 'RECORDED') {
                      _valueController.clear();
                    }
                    if (status != 'MISSING_CONDITION') {
                      _selectedMissingReason = null;
                    }
                  });
                },
              );
            }).toList(),
          ),

          // Missing condition reasons
          if (_selectedStatus == 'MISSING_CONDITION') ...[
            const SizedBox(height: 12),
            const Text('Reason',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _missingReasons.map((reason) {
                return FilterChip(
                  label: Text(reason, style: const TextStyle(fontSize: 12)),
                  selected: _selectedMissingReason == reason,
                  onSelected: (_) {
                    setState(() => _selectedMissingReason = reason);
                  },
                );
              }).toList(),
            ),
          ],

          // Numeric entry — only for RECORDED
          if (_selectedStatus == 'RECORDED') ...[
            const SizedBox(height: 20),
            const Text('Value',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            if (_currentAssessment.minValue != null)
              Text(
                'Range: ${_currentAssessment.minValue} – ${_currentAssessment.maxValue}${_currentAssessment.unit != null ? " ${_currentAssessment.unit}" : ""}',
                style:
                    const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _valueController,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: '0',
                suffixText: _currentAssessment.unit,
                filled: true,
                fillColor: Colors.white,
              ),
              autofocus: true,
            ),

            // Quick value buttons
            const SizedBox(height: 12),
            _buildQuickButtons(),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickButtons() {
    final min = _currentAssessment.minValue?.toInt() ?? 0;
    final max = _currentAssessment.maxValue?.toInt() ?? 100;
    final range = max - min;

    List<int> quickValues;
    if (range <= 10) {
      quickValues =
          List.generate(range + 1, (i) => min + i);
    } else {
      quickValues = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
          .where((v) => v >= min && v <= max)
          .toList();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: quickValues.map((val) {
        return SizedBox(
          width: 56,
          height: 48,
          child: OutlinedButton(
            onPressed: () {
              _valueController.text = val.toString();
            },
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
            ),
            child: Text(val.toString(),
                style: const TextStyle(fontSize: 16)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 4,
                offset: const Offset(0, -2))
          ],
        ),
        child: Row(
          children: [
            // Previous plot
            if (widget.currentPlotIndex > 0)
              IconButton(
                onPressed: () => _navigatePlot(context, -1),
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous plot',
              ),

            const Spacer(),

            // Save button
            FilledButton.icon(
              onPressed: _isSaving ? null : () => _saveRating(context),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save & Next'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(160, 48),
              ),
            ),

            const Spacer(),

            // Next plot
            if (widget.currentPlotIndex < widget.allPlots.length - 1)
              IconButton(
                onPressed: () => _navigatePlot(context, 1),
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next plot',
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveRating(BuildContext context) async {
    double? numericValue;
    if (_selectedStatus == 'RECORDED') {
      numericValue = double.tryParse(_valueController.text);
      if (numericValue == null && _valueController.text.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please enter a valid number'),
              backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    final useCase = ref.read(saveRatingUseCaseProvider);
    final result = await useCase.execute(SaveRatingInput(
      trialId: widget.trial.id,
      plotPk: widget.plot.id,
      assessmentId: _currentAssessment.id,
      sessionId: widget.session.id,
      resultStatus: _selectedStatus,
      numericValue: numericValue,
      textValue: _selectedMissingReason,
      raterName: widget.session.raterName,
      minValue: _currentAssessment.minValue,
      maxValue: _currentAssessment.maxValue,
    ));

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result.isSuccess) {


      // Auto-advance to next assessment or next plot
      if (_assessmentIndex < widget.assessments.length - 1) {
        setState(() {
          _assessmentIndex++;
          _currentAssessment = widget.assessments[_assessmentIndex];
          _valueController.clear();
          _selectedStatus = 'RECORDED';
          _selectedMissingReason = null;
        });
      } else {
        _navigatePlot(context, 1);
      }
    } else if (result.isDebounced) {
      // Silent — debounce protection working
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result.errorMessage ?? 'Save failed'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _navigatePlot(BuildContext context, int direction) {
    final nextIndex = widget.currentPlotIndex + direction;
    if (nextIndex < 0 || nextIndex >= widget.allPlots.length) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RatingScreen(
          trial: widget.trial,
          session: widget.session,
          plot: widget.allPlots[nextIndex],
          assessments: widget.assessments,
          allPlots: widget.allPlots,
          currentPlotIndex: nextIndex,
        ),
      ),
    );
  }

  Future<void> _undoRating(
      BuildContext context, RatingRecord existing) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Undo Rating'),
        content: Text(
            'Undo rating for Plot ${widget.plot.plotId} – ${_currentAssessment.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Undo')),
        ],
      ),
    );

    if (confirm != true) return;

    final repo = ref.read(ratingRepositoryProvider);
    await repo.undoRating(
      currentRatingId: existing.id,
      raterName: widget.session.raterName,
    );
  }

  Future<void> _showFlagDialog(BuildContext context) async {
    final descController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Flag Plot ${widget.plot.plotId}'),
        content: TextField(
          controller: descController,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
            hintText: 'e.g. Weed patch, border effect',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (descController.text.trim().isEmpty) return;
              final db = ref.read(databaseProvider);
              await db.into(db.plotFlags).insert(
                    PlotFlagsCompanion.insert(
                      trialId: widget.trial.id,
                      plotPk: widget.plot.id,
                      sessionId: widget.session.id,
                      flagType: 'FIELD_OBSERVATION',
                      description:
                          drift.Value(descController.text.trim()),
                      raterName:
                          drift.Value(widget.session.raterName),
                    ),
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save Flag'),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'RECORDED': return 'Recorded';
      case 'NOT_OBSERVED': return 'Not Observed';
      case 'NOT_APPLICABLE': return 'N/A';
      case 'MISSING_CONDITION': return 'Missing';
      case 'TECHNICAL_ISSUE': return 'Tech Issue';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'RECORDED': return Colors.green;
      case 'NOT_OBSERVED': return Colors.orange;
      case 'NOT_APPLICABLE': return Colors.blue;
      case 'MISSING_CONDITION': return Colors.red;
      case 'TECHNICAL_ISSUE': return Colors.purple;
      default: return Colors.grey;
    }
  }
}
