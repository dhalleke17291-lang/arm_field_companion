import 'package:flutter/material.dart';
import '../../core/widgets/gradient_screen_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/widgets/loading_error_widgets.dart';
import '../sessions/usecases/create_session_usecase.dart';

class CreateSessionScreen extends ConsumerStatefulWidget {
  final Trial trial;

  const CreateSessionScreen({super.key, required this.trial});

  @override
  ConsumerState<CreateSessionScreen> createState() =>
      _CreateSessionScreenState();
}

class _CreateSessionScreenState extends ConsumerState<CreateSessionScreen> {
  final _nameController = TextEditingController();
  final _raterController = TextEditingController();
  final Set<int> _selectedLegacyAssessmentIds = {};
  final Set<int> _selectedTrialAssessmentIds = {};
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _setDefaultSessionName();
  }

  Future<void> _setDefaultSessionName() async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Count existing sessions today for this trial
    final db = ref.read(databaseProvider);
    final allSessions = await (db.select(db.sessions)
          ..where((s) => s.trialId.equals(widget.trial.id)))
        .get();
    final todaySessions =
        allSessions.where((s) => s.sessionDateLocal == dateStr).toList();

    final count = todaySessions.length + 1;
    if (mounted) {
      _nameController.text = '$dateStr Session $count';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _raterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final legacyAsync = ref.watch(assessmentsForTrialProvider(widget.trial.id));
    final trialAsync = ref.watch(
        trialAssessmentsWithDefinitionsForTrialProvider(widget.trial.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EB),
      appBar: const GradientScreenHeader(title: 'New Session'),
      body: legacyAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (legacy) => trialAsync.when(
          loading: () => _buildForm(context, legacy, []),
          error: (e, st) => _buildForm(context, legacy, []),
          data: (trialPairs) => _buildForm(context, legacy, trialPairs),
        ),
      ),
      bottomNavigationBar: _buildStartButton(context),
    );
  }

  Widget _buildForm(BuildContext context, List<Assessment> legacy,
      List<(TrialAssessment, AssessmentDefinition)> trialPairs) {
    final assessments = legacy;
    final hasTrial = trialPairs.isNotEmpty;
    final combinedEmpty = assessments.isEmpty && !hasTrial;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trial info banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.energy_savings_leaf,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(widget.trial.name,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Session name
          const Text('Session Name',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'e.g. Morning Rating 2026-03-04',
            ),
          ),
          const SizedBox(height: 20),

          // Rater name
          const Text('Rater Name',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          TextField(
            controller: _raterController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Your name',
            ),
          ),
          const SizedBox(height: 20),

          // Assessment selection — immutable once session starts
          Row(
            children: [
              const Text('Assessments to Rate',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              if (_selectedLegacyAssessmentIds.isNotEmpty ||
                  _selectedTrialAssessmentIds.isNotEmpty)
                Text(
                    '${_selectedLegacyAssessmentIds.length + _selectedTrialAssessmentIds.length} selected',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Assessment set is locked once session starts',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 2),
          const Text(
            "Only custom assessments from the trial's Assessments tab can be added to sessions.",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),

          combinedEmpty
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'No assessments defined.\nGo to Assessments tab to add some.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : Column(
                  children: [
                    ...assessments.map((assessment) {
                      final isSelected =
                          _selectedLegacyAssessmentIds.contains(assessment.id);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedLegacyAssessmentIds.add(assessment.id);
                            } else {
                              _selectedLegacyAssessmentIds
                                  .remove(assessment.id);
                            }
                          });
                        },
                        title: Text(assessment.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: assessment.unit != null
                            ? Text(
                                '${assessment.unit}${assessment.minValue != null ? " • ${assessment.minValue}–${assessment.maxValue}" : ""}')
                            : null,
                        secondary: CircleAvatar(
                          backgroundColor: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade200,
                          child: Icon(Icons.analytics,
                              color: isSelected ? Colors.white : Colors.grey,
                              size: 20),
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      );
                    }),
                    ...trialPairs.map((pair) {
                      final ta = pair.$1;
                      final def = pair.$2;
                      final displayName = ta.displayNameOverride ?? def.name;
                      final isSelected =
                          _selectedTrialAssessmentIds.contains(ta.id);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedTrialAssessmentIds.add(ta.id);
                            } else {
                              _selectedTrialAssessmentIds.remove(ta.id);
                            }
                          });
                        },
                        title: Text(displayName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: def.unit != null
                            ? Text(
                                '${def.unit}${def.scaleMin != null && def.scaleMax != null ? " • ${def.scaleMin}–${def.scaleMax}" : ""}')
                            : null,
                        secondary: CircleAvatar(
                          backgroundColor: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade200,
                          child: Icon(Icons.analytics,
                              color: isSelected ? Colors.white : Colors.grey,
                              size: 20),
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      );
                    }),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _isCreating ? null : () => _startSession(context),
          icon: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.play_arrow),
          label: Text(_isCreating ? 'Starting...' : 'Start Session'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
      ),
    );
  }

  Future<void> _startSession(BuildContext context) async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a session name'),
            backgroundColor: Colors.red),
      );
      return;
    }
    // Warn if no plots
    final db = ref.read(databaseProvider);
    final plotCount = await (db.select(db.plots)
          ..where((p) => p.trialId.equals(widget.trial.id)))
        .get();
    if (!mounted || !context.mounted) return;

    if (plotCount.isEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('No Plots Found'),
          content: const Text(
            'This trial has no plots yet. You can still create a session but you won\'t be able to rate anything until plots are imported.\n\nContinue anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (!mounted || !context.mounted) return;
      if (proceed != true) return;
    }

    if (_selectedLegacyAssessmentIds.isEmpty &&
        _selectedTrialAssessmentIds.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one assessment'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isCreating = true);

    final now = DateTime.now();
    final sessionDateLocal =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final userId = await ref.read(currentUserIdProvider.future);
    final currentUser = await ref.read(currentUserProvider.future);
    final raterName = _raterController.text.trim().isEmpty
        ? (currentUser?.displayName)
        : _raterController.text.trim();

    final trialRepo = ref.read(trialAssessmentRepositoryProvider);
    final resolvedTrialIds =
        await trialRepo.getOrCreateLegacyAssessmentIdsForTrialAssessments(
      widget.trial.id,
      _selectedTrialAssessmentIds.toList(),
    );
    final assessmentIds = [
      ..._selectedLegacyAssessmentIds,
      ...resolvedTrialIds
    ];

    final useCase = ref.read(createSessionUseCaseProvider);
    final result = await useCase.execute(CreateSessionInput(
      trialId: widget.trial.id,
      name: _nameController.text.trim(),
      sessionDateLocal: sessionDateLocal,
      assessmentIds: assessmentIds,
      raterName: raterName,
      createdByUserId: userId,
    ));

    if (!mounted || !context.mounted) return;
    setState(() => _isCreating = false);

    if (result.success) {
      Navigator.pop(context, result.session);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result.errorMessage ?? 'Failed to start session'),
            backgroundColor: Colors.red),
      );
    }
  }
}
