import 'package:flutter/material.dart';

class TrialScreen extends StatefulWidget {
  const TrialScreen({super.key});

  @override
  State<TrialScreen> createState() => _TrialScreenState();
}

class _TrialScreenState extends State<TrialScreen> {
  final List<String> assessments = [
    "Crop injury %",
    "Disease severity %",
    "Stand count (plants/plot)",
    "Quality grade",
    "Notes / observation",
    "Plant height",
    "Growth stage (BBCH)",
    "Weed cover %",
    "Yield (kg/ha)",
  ];

  final Set<String> selected = {};

  void openAssessmentDialog() {
    final dialogSelected = Set<String>.from(selected);
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Add Assessments",
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Tap chips to select",
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: assessments.map((a) {
                    final isSelected = dialogSelected.contains(a);
                    return FilterChip(
                      label: Text(a),
                      selected: isSelected,
                      onSelected: (_) {
                        setDialogState(() {
                          if (isSelected) {
                            dialogSelected.remove(a);
                          } else {
                            dialogSelected.add(a);
                          }
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() => selected.addAll(dialogSelected));
                        Navigator.pop(context);
                      },
                      child: const Text("Add"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trial 001 – Corn"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Trial 001 – Corn",
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Status: Draft",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: 0.25,
                      backgroundColor: Colors.grey[300],
                      color: Colors.teal,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Empty State
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.analytics_outlined,
                        size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      "No Assessments Yet",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Add from library or create a custom assessment.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            // Add Button
            FilledButton.icon(
              onPressed: openAssessmentDialog,
              icon: const Icon(Icons.add),
              label: const Text("Add Assessment"),
            ),
          ],
        ),
      ),
    );
  }
}
