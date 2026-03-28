import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/design/form_styles.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/standard_form_bottom_sheet.dart';

const List<String> _kTreatmentTypes = [
  'Chemical',
  'Biological',
  'Cultural',
  'Untreated control',
  'Fertiliser',
  'Other',
];

const List<String> _kTimingCodes = [
  'PRE',
  'POST',
  'EPOST',
  'AT',
  'FPOST',
  'LPOST',
  'MPOST',
  'PREPLANT',
  'Other',
];

/// Modal bottom sheet: add treatment — layout matches [StandardFormBottomSheetLayout].
Future<void> showAddTreatmentSheet(
  BuildContext context,
  WidgetRef ref, {
  required Trial trial,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppDesignTokens.cardSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    showDragHandle: false,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _AddTreatmentSheetBody(
          trial: trial,
          scrollController: scrollController,
          onDone: () {
            if (ctx.mounted) Navigator.pop(ctx);
          },
        ),
      ),
    ),
  );
}

class _AddTreatmentSheetBody extends ConsumerStatefulWidget {
  const _AddTreatmentSheetBody({
    required this.trial,
    required this.scrollController,
    required this.onDone,
  });

  final Trial trial;
  final ScrollController scrollController;
  final VoidCallback onDone;

  @override
  ConsumerState<_AddTreatmentSheetBody> createState() =>
      _AddTreatmentSheetBodyState();
}

class _AddTreatmentSheetBodyState extends ConsumerState<_AddTreatmentSheetBody> {
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _eppoController;
  String? _treatmentType;
  String? _timingCode;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _eppoController = TextEditingController();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _eppoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_codeController.text.trim().isEmpty ||
        _nameController.text.trim().isEmpty) {
      return;
    }
    final repo = ref.read(treatmentRepositoryProvider);
    await repo.insertTreatment(
      trialId: widget.trial.id,
      code: _codeController.text.trim(),
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      treatmentType: _treatmentType,
      timingCode: _timingCode,
      eppoCode: _eppoController.text.trim().isEmpty
          ? null
          : _eppoController.text.trim(),
    );
    ref.invalidate(treatmentsForTrialProvider(widget.trial.id));
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return StandardFormBottomSheetLayout(
      title: 'Add Treatment',
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      body: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(
          FormStyles.formSheetHorizontalPadding,
          0,
          FormStyles.formSheetHorizontalPadding,
          FormStyles.formSheetSectionSpacing,
        ),
        children: [
          TextField(
            controller: _codeController,
            decoration: FormStyles.inputDecoration(
              labelText: 'Code (e.g. T1, T2)',
            ),
          ),
          const SizedBox(height: FormStyles.formSheetFieldSpacing),
          TextField(
            controller: _nameController,
            decoration: FormStyles.inputDecoration(
              labelText: 'Name',
            ),
          ),
          const SizedBox(height: FormStyles.formSheetFieldSpacing),
          TextField(
            controller: _descController,
            maxLines: 2,
            decoration: FormStyles.inputDecoration(
              labelText: 'Description (optional)',
            ),
          ),
          const SizedBox(height: FormStyles.formSheetFieldSpacing),
          DropdownButtonFormField<String?>(
            key: ValueKey('add_type_$_treatmentType'),
            initialValue: _treatmentType,
            decoration: FormStyles.inputDecoration(
              labelText: 'Treatment type',
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('—')),
              ..._kTreatmentTypes.map(
                (s) => DropdownMenuItem<String?>(value: s, child: Text(s)),
              ),
            ],
            onChanged: (v) => setState(() => _treatmentType = v),
          ),
          const SizedBox(height: FormStyles.formSheetFieldSpacing),
          DropdownButtonFormField<String?>(
            key: ValueKey('add_timing_$_timingCode'),
            initialValue: _timingCode,
            decoration: FormStyles.inputDecoration(
              labelText: 'Timing code',
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('—')),
              ..._kTimingCodes.map(
                (s) => DropdownMenuItem<String?>(value: s, child: Text(s)),
              ),
            ],
            onChanged: (v) => setState(() => _timingCode = v),
          ),
          const SizedBox(height: FormStyles.formSheetSectionSpacing),
          ExpansionTile(
            title: const Text(
              'Regulatory details',
              style: FormStyles.expansionTitleStyle,
            ),
            initiallyExpanded: false,
            children: [
              TextField(
                controller: _eppoController,
                decoration: FormStyles.inputDecoration(
                  labelText: 'EPPO code',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
