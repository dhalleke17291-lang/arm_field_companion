import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/widgets/gradient_screen_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/database/app_database.dart';
import '../../core/plot_display.dart';
import '../../core/providers.dart';
import '../../core/session_lock.dart';
import '../../core/quick_note_templates.dart';
import '../photos/usecases/save_photo_usecase.dart';
import 'last_value_memory.dart';
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
    'Hail',
    'Flood',
    'Animal Damage',
    'Spray Miss',
    'Lodging',
    'Harvested',
    'Other'
  ];
  String? _selectedMissingReason;

  // Photos
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _assessmentIndex = 0;
    _currentAssessment = widget.assessments[0];
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existingRatingAsync = ref.watch(
      currentRatingProvider(
        CurrentRatingParams(
          trialId: widget.trial.id,
          plotPk: widget.plot.id,
          assessmentId: _currentAssessment.id,
          sessionId: widget.session.id,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EB),
      appBar: GradientScreenHeader(
        title: 'Plot ${getDisplayPlotLabel(widget.plot, widget.allPlots)}',
        subtitle: widget.session.raterName != null
            ? 'Session ${widget.session.id} · ${widget.session.raterName}'
            : 'Session ${widget.session.id}',
        titleFontSize: 17,
        actions: [
          _buildOfflineIndicator(),
          _buildFlagButton(context),
        ],
      ),
      body: Column(
        children: [
          _buildPlotInfoBar(context),
          _buildProgressBar(context),

          if (!isSessionEditable(widget.session)) _buildClosedSessionBanner(context),

          // Photos strip (shows only if photos exist)
          _buildPhotoStrip(context),

          _buildAssessmentSelector(context),

          Expanded(
            child: existingRatingAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (existing) => _buildRatingArea(context, existing),
            ),
          ),

          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildClosedSessionBanner(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.lock, color: Theme.of(context).colorScheme.onErrorContainer, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                kClosedSessionBlockedMessage,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Photos (Capture + Save) =====

  Future<void> _capturePhoto(BuildContext context) async {
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (shot == null) {
        return;
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${docsDir.path}/afc_photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final finalPath =
          '${photosDir.path}/trial_${widget.trial.id}_session_${widget.session.id}_plot_${widget.plot.id}_$now.jpg';

      final userId = await ref.read(currentUserIdProvider.future);
      final usecase = ref.read(savePhotoUseCaseProvider);
      final res = await usecase.execute(
        SavePhotoInput(
          trialId: widget.trial.id,
          plotPk: widget.plot.id,
          sessionId: widget.session.id,
          tempPath: shot.path,
          finalPath: finalPath,
          caption: null,
          raterName: widget.session.raterName,
          performedByUserId: userId,
        ),
      );

      if (!mounted || !context.mounted) return;

      if (!res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.errorMessage ?? 'Failed to save photo')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo saved')),
      );
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo error: $e')),
      );
    }
  }

  Widget _buildPhotoStrip(BuildContext context) {
    final photosAsync = ref.watch(
      photosForPlotProvider(
        PhotosForPlotParams(
          trialId: widget.trial.id,
          plotPk: widget.plot.id,
          sessionId: widget.session.id,
        ),
      ),
    );

    return photosAsync.when(
      loading: () => const SizedBox(height: 0),
      error: (e, st) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          'Photo load error: $e',
          style: const TextStyle(color: Colors.red, fontSize: 12),
        ),
      ),
      data: (photos) {
        if (photos.isEmpty) return const SizedBox(height: 0);

        return SizedBox(
          height: 92,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: photos.length,
            itemBuilder: (context, i) {
              final p = photos[i];
              final file = File(p.filePath);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () =>
                      _openPhotoViewer(context, photos, initialIndex: i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 84,
                      height: 84,
                      color: Colors.black12,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          file.existsSync()
                              ? Image.file(file, fit: BoxFit.cover)
                              : const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                ),
                          Positioned(
                            left: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${i + 1}/${photos.length}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11),
                              ),
                            ),
                          ),
                          if (p.caption != null && p.caption!.trim().isNotEmpty)
                            Positioned(
                              left: 6,
                              right: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  p.caption!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openPhotoViewer(
    BuildContext context,
    List<Photo> photos, {
    required int initialIndex,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoViewerScreen(
          photos: photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  // ===== UI =====

  Widget _buildOfflineIndicator() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Saved locally',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget _buildFlagButton(BuildContext context) {
    final flagsAsync =
        ref.watch(plotFlagsForPlotSessionProvider((widget.plot.id, widget.session.id)));
    return flagsAsync.when(
      data: (flags) {
        final isFlagged = flags.isNotEmpty;
        return IconButton(
          icon: Icon(
            isFlagged ? Icons.flag : Icons.flag_outlined,
            color: isFlagged ? Colors.amber : null,
          ),
          onPressed: () => _toggleFlag(context),
          onLongPress: () => _showFlagDialog(context),
          tooltip: isFlagged
              ? 'Remove flag (tap). Add note (long-press)'
              : 'Flag plot (tap). Add note (long-press)',
        );
      },
      loading: () => const IconButton(
        icon: Icon(Icons.flag_outlined),
        onPressed: null,
        tooltip: 'Flag plot',
      ),
      error: (_, __) => IconButton(
        icon: const Icon(Icons.flag_outlined),
        onPressed: () => _showFlagDialog(context),
        tooltip: 'Flag plot',
      ),
    );
  }

  Future<void> _toggleFlag(BuildContext context) async {
    final flags = ref.read(
        plotFlagsForPlotSessionProvider((widget.plot.id, widget.session.id))).value ?? [];
    final db = ref.read(databaseProvider);
    if (flags.isNotEmpty) {
      await (db.delete(db.plotFlags)
            ..where((f) =>
                f.plotPk.equals(widget.plot.id) &
                f.sessionId.equals(widget.session.id)))
          .go();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flag removed')),
        );
      }
    } else {
      await db.into(db.plotFlags).insert(
            PlotFlagsCompanion.insert(
              trialId: widget.trial.id,
              plotPk: widget.plot.id,
              sessionId: widget.session.id,
              flagType: 'FIELD_OBSERVATION',
              description: const drift.Value('Flagged'),
              raterName: drift.Value(widget.session.raterName),
            ),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plot flagged')),
        );
      }
    }
  }

  Widget _buildPlotInfoBar(BuildContext context) {
    final plotCtx = ref.watch(plotContextProvider(widget.plot.id));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Icon(Icons.grid_on,
              size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            'Plot ${getDisplayPlotLabel(widget.plot, widget.allPlots)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (widget.plot.rep != null) ...[
            const SizedBox(width: 8),
            Text('Rep ${widget.plot.rep}',
                style: const TextStyle(color: Colors.grey)),
          ],
          plotCtx.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (ctx) => ctx.hasTreatment
                ? Row(children: [
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ctx.treatmentCode,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(ctx.treatmentName,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  ])
                : const SizedBox.shrink(),
          ),
          IconButton(
            tooltip: 'Take photo',
            icon: const Icon(Icons.photo_camera, size: 20),
            onPressed: () => _capturePhoto(context),
          ),
          const Spacer(),
          if (widget.session.raterName != null)
            Text(
              widget.session.raterName!,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final plotProgress = (widget.currentPlotIndex + 1) / widget.allPlots.length;
    final assessLabel = widget.assessments.length > 1
        ? 'Assessment ${_assessmentIndex + 1} of ${widget.assessments.length}  ·  '
        : '';
    return Container(
      color: const Color(0xFFF8F6F2),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${assessLabel}Plot ${widget.currentPlotIndex + 1} of ${widget.allPlots.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const Spacer(),
              Text(
                '${(plotProgress * 100).toInt()}% complete',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D5A40),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: plotProgress,
              minHeight: 5,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2D5A40)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildAssessmentSelector(BuildContext context) {
    if (widget.assessments.length == 1) {
      return Container(
        color: const Color(0xFFF8F6F2),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF2D5A40),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _currentAssessment.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            if (_currentAssessment.unit != null) ...[
              const SizedBox(width: 6),
              Text(
                '· ${_currentAssessment.unit}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFFF8F6F2),
      padding: const EdgeInsets.fromLTRB(16, 0, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ASSESSMENT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: widget.assessments.length,
              itemBuilder: (context, index) {
                final assessment = widget.assessments[index];
                final isSelected = assessment.id == _currentAssessment.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _assessmentIndex = index;
                        _currentAssessment = assessment;
                        _valueController.clear();
                        _selectedStatus = 'RECORDED';
                        _selectedMissingReason = null;
                      });
                      _prefillFromLastValue();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2D5A40)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2D5A40)
                              : const Color(0xFFE5E7EB),
                        ),
                        boxShadow: isSelected
                            ? [
                                const BoxShadow(
                                  color: Color(0x302D5A40),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        assessment.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _prefillFromLastValue() {
    final last = ref.read(lastValueMemoryProvider.notifier).get(
          widget.session.id,
          _currentAssessment.id,
        );
    if (last != null && _valueController.text.isEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _valueController.text.isEmpty) {
          setState(() => _valueController.text = last.toString());
        }
      });
    }
  }

  Widget _buildCurrentOrCorrectedRow(
      BuildContext context, RatingRecord existing) {
    final correctionAsync =
        ref.watch(latestCorrectionForRatingProvider(existing.id));
    final hasCorrection = correctionAsync.valueOrNull != null;
    final effectiveStatus =
        hasCorrection ? correctionAsync.value!.newResultStatus : existing.resultStatus;
    final effectiveNumeric =
        hasCorrection ? correctionAsync.value!.newNumericValue : existing.numericValue;
    final effectiveText =
        hasCorrection ? correctionAsync.value!.newTextValue : existing.textValue;
    final displayValue = effectiveStatus == 'RECORDED'
        ? (effectiveNumeric?.toString() ?? '-')
        : (effectiveText?.isNotEmpty == true ? effectiveText! : effectiveStatus);

    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: hasCorrection ? Colors.amber.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: hasCorrection ? Colors.amber.shade200 : Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasCorrection ? Icons.edit_note : Icons.check_circle,
                color: hasCorrection ? Colors.amber.shade800 : Colors.green,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '${hasCorrection ? 'Effective' : 'Current'}: $displayValue${hasCorrection ? ' (corrected)' : ''}',
                style: TextStyle(
                    color: hasCorrection ? Colors.amber.shade800 : Colors.green,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (isSessionEditable(widget.session))
                TextButton(
                  onPressed: () => _undoRating(context, existing),
                  child: const Text('Undo',
                      style: TextStyle(color: Colors.red)),
                )
              else
                TextButton(
                  onPressed: () => _showCorrectDialog(context, existing),
                  child: const Text('Correct value'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCorrectDialog(
      BuildContext context, RatingRecord existing) async {
    final newValueController = TextEditingController(
      text: existing.resultStatus == 'RECORDED'
          ? (existing.numericValue?.toString() ?? '')
          : '',
    );
    final reasonController = TextEditingController();
    String newStatus = existing.resultStatus;

    final applied = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Correct value'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Original: ${existing.resultStatus == "RECORDED" ? existing.numericValue?.toString() ?? "-" : existing.resultStatus}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const Text('New status',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12)),
                  Wrap(
                    spacing: 6,
                    children: ['RECORDED', 'NOT_OBSERVED', 'NOT_APPLICABLE', 'MISSING_CONDITION', 'TECHNICAL_ISSUE']
                        .map((s) => ChoiceChip(
                              label: Text(s, style: const TextStyle(fontSize: 11)),
                              selected: newStatus == s,
                              onSelected: (_) => setState(() => newStatus = s),
                            ))
                        .toList(),
                  ),
                  if (newStatus == 'RECORDED') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: newValueController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'New value',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason *',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. Data entry error',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content: Text('Reason is required')),
                    );
                    return;
                  }
                  double? newNumeric;
                  if (newStatus == 'RECORDED') {
                    newNumeric = double.tryParse(newValueController.text);
                  }
                  final userId = await ref.read(currentUserIdProvider.future);
                  final useCase = ref.read(applyCorrectionUseCaseProvider);
                  final result = await useCase.execute(
                    rating: existing,
                    session: widget.session,
                    newResultStatus: newStatus,
                    newNumericValue: newNumeric,
                    newTextValue: newStatus == 'MISSING_CONDITION'
                        ? newValueController.text.trim().isEmpty
                            ? null
                            : newValueController.text.trim()
                        : null,
                    reason: reason,
                    correctedByUserId: userId,
                  );
                  if (!ctx.mounted) return;
                  if (result.success) {
                    ref.invalidate(
                        latestCorrectionForRatingProvider(existing.id));
                    Navigator.pop(ctx, true);
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                          content: Text(result.errorMessage ?? 'Failed'),
                          backgroundColor: Colors.red),
                    );
                  }
                },
                child: const Text('Apply correction'),
              ),
            ],
          );
        },
      ),
    );
    newValueController.dispose();
    reasonController.dispose();
    if (applied == true && mounted) setState(() {});
  }

  Widget _buildRatingArea(BuildContext context, RatingRecord? existing) {
    if (existing == null &&
        _selectedStatus == 'RECORDED' &&
        _valueController.text.isEmpty) {
      _prefillFromLastValue();
    }
    // Full-screen writing area for notes/observation; one tap Save & Next saves and navigates
    if (_isTextAssessment && _selectedStatus == 'RECORDED') {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (existing != null)
              _buildCurrentOrCorrectedRow(context, existing),
            const Text('Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                  label: Text(
                    _statusLabel(status),
                    style: TextStyle(
                        fontSize: 12, color: isSelected ? Colors.white : null),
                  ),
                  selected: isSelected,
                  selectedColor: _statusColor(status),
                  onSelected: (_) {
                    setState(() {
                      _selectedStatus = status;
                      if (status != 'RECORDED') _valueController.clear();
                      if (status != 'MISSING_CONDITION') {
                        _selectedMissingReason = null;
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _valueController,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                maxLines: null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Add notes or observation…',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                autofocus: true,
              ),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (existing != null)
            _buildCurrentOrCorrectedRow(context, existing),
          const Text('Status',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                label: Text(
                  _statusLabel(status),
                  style: TextStyle(
                      fontSize: 12, color: isSelected ? Colors.white : null),
                ),
                selected: isSelected,
                selectedColor: _statusColor(status),
                onSelected: (_) {
                  setState(() {
                    _selectedStatus = status;
                    if (status != 'RECORDED') _valueController.clear();
                    if (status != 'MISSING_CONDITION') {
                      _selectedMissingReason = null;
                    }
                  });
                },
              );
            }).toList(),
          ),
          if (_selectedStatus == 'MISSING_CONDITION') ...[
            const SizedBox(height: 12),
            const Text('Reason',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _missingReasons.map((reason) {
                return FilterChip(
                  label: Text(reason, style: const TextStyle(fontSize: 12)),
                  selected: _selectedMissingReason == reason,
                  onSelected: (_) =>
                      setState(() => _selectedMissingReason = reason),
                );
              }).toList(),
            ),
          ],
          if (_selectedStatus == 'RECORDED') ...[
            const SizedBox(height: 20),
            const Text('Value',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            if (_isTextAssessment) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _valueController,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                maxLines: 6,
                minLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Add notes or observation…',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.white,
                ),
                autofocus: true,
              ),
            ] else ...[
              if (_currentAssessment.minValue != null ||
                  _currentAssessment.maxValue != null ||
                  _currentAssessment.unit != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Scale: ${_currentAssessment.minValue ?? "?"}–${_currentAssessment.maxValue ?? "?"}${_currentAssessment.unit != null ? " ${_currentAssessment.unit}" : ""}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _valueController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
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
              const SizedBox(height: 12),
              _buildQuickButtons(),
            ],
          ],
        ],
      ),
    );
  }

  bool get _isTextAssessment =>
      _currentAssessment.dataType.toLowerCase() == 'text';

  Widget _buildQuickButtons() {
    final min = _currentAssessment.minValue?.toInt() ?? 0;
    final max = _currentAssessment.maxValue?.toInt() ?? 100;
    final range = max - min;

    final List<int> quickValues = (range <= 10)
        ? List.generate(range + 1, (i) => min + i)
        : [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
            .where((v) => v >= min && v <= max)
            .toList();

    final currentVal = double.tryParse(_valueController.text)?.toInt();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: quickValues.map((val) {
        final isSelected = currentVal == val;
        return GestureDetector(
          onTap: () => setState(() => _valueController.text = val.toString()),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2D5A40) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2D5A40)
                    : const Color(0xFFE5E7EB),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0x402D5A40)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: isSelected ? 10 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                val.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final isLast = widget.currentPlotIndex >= widget.allPlots.length - 1;
    final isLastAssessment = _assessmentIndex >= widget.assessments.length - 1;
    final isVeryLast = isLast && isLastAssessment;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFEAECF0))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Previous button
            if (widget.currentPlotIndex > 0)
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: IconButton(
                  onPressed: () => _navigatePlot(context, -1),
                  icon: const Icon(Icons.chevron_left,
                      color: Color(0xFF6B7280), size: 22),
                  tooltip: 'Previous plot',
                ),
              )
            else
              const SizedBox(width: 50),
            const SizedBox(width: 12),
            // Save button
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving || !isSessionEditable(widget.session)
                      ? null
                      : () => _saveRating(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5A40),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isVeryLast ? 'Save & Finish' : 'Save & Next',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              isVeryLast
                                  ? Icons.check_circle_outline
                                  : Icons.arrow_forward,
                              size: 18,
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Next button
            if (widget.currentPlotIndex < widget.allPlots.length - 1)
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: IconButton(
                  onPressed: () => _navigatePlot(context, 1),
                  icon: const Icon(Icons.chevron_right,
                      color: Color(0xFF6B7280), size: 22),
                  tooltip: 'Next plot',
                ),
              )
            else
              const SizedBox(width: 50),
          ],
        ),
      ),
    );
  }

  // ===== Actions =====

  Future<void> _saveRating(BuildContext context) async {
    double? numericValue;
    String? textValue;
    if (_selectedStatus == 'RECORDED') {
      if (_isTextAssessment) {
        textValue = _valueController.text.trim().isNotEmpty
            ? _valueController.text.trim()
            : null;
      } else {
        numericValue = double.tryParse(_valueController.text);
        if (numericValue == null && _valueController.text.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid number'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    } else if (_selectedStatus == 'MISSING_CONDITION') {
      textValue = _selectedMissingReason;
    }

    setState(() => _isSaving = true);

    final userId = await ref.read(currentUserIdProvider.future);
    final useCase = ref.read(saveRatingUseCaseProvider);
    final result = await useCase.execute(
      SaveRatingInput(
        trialId: widget.trial.id,
        plotPk: widget.plot.id,
        assessmentId: _currentAssessment.id,
        sessionId: widget.session.id,
        resultStatus: _selectedStatus,
        numericValue: numericValue,
        textValue: textValue,
        raterName: widget.session.raterName,
        performedByUserId: userId,
        isSessionClosed: widget.session.endedAt != null,
        minValue: _currentAssessment.minValue,
        maxValue: _currentAssessment.maxValue,
      ),
    );

    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);

    if (result.isSuccess) {
      if (numericValue != null) {
        ref.read(lastValueMemoryProvider.notifier).set(
              widget.session.id,
              _currentAssessment.id,
              numericValue,
            );
      }
      if (_assessmentIndex < widget.assessments.length - 1) {
        setState(() {
          _assessmentIndex++;
          _currentAssessment = widget.assessments[_assessmentIndex];
          _valueController.clear();
          _selectedStatus = 'RECORDED';
          _selectedMissingReason = null;
        });
        _prefillFromLastValue();
      } else {
        if (!context.mounted) return;
        // Last assessment on last plot — session complete
        if (widget.currentPlotIndex >= widget.allPlots.length - 1) {
          _showSessionCompleteDialog(context);
        } else {
          _navigatePlot(context, 1);
        }
      }
    } else if (result.isDebounced) {
      // silent
    } else {
      if (!context.mounted) return;
      final msg = result.errorMessage ?? 'Save failed';
      if (msg == kClosedSessionBlockedMessage) {
        ref.read(diagnosticsStoreProvider).recordError(msg, code: 'closed_session_write_blocked');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showSessionCompleteDialog(BuildContext context) async {
    final flaggedIds = await ref.read(flaggedPlotIdsForSessionProvider(widget.session.id).future);
    final flaggedCount = flaggedIds.length;
    final photoCount = await ref.read(photoRepositoryProvider).getPhotoCountForSession(widget.session.id);
    final plotCount = widget.allPlots.length;
    final summary = '$plotCount plots rated · $flaggedCount flagged · $photoCount photos';

    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF8F6F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        titlePadding: EdgeInsets.zero,
        content: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(Icons.check_circle,
                    color: Color(0xFF2D5A40), size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'All Plots Rated',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You've completed all $plotCount plots in this session.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                summary,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    int count = 0;
                    Navigator.of(context).popUntil((_) => count++ >= 2);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5A40),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back to Session',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Keep reviewing plots',
                  style: TextStyle(
                      color: Color(0xFF6B7280), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigatePlot(BuildContext context, int direction) {
    final nextIndex = widget.currentPlotIndex + direction;
    if (nextIndex < 0 || nextIndex >= widget.allPlots.length) {
      return;
    }

    // Rep completion feedback: haptic when leaving the last plot in current rep (field speed).
    if (direction == 1) {
      final currentRep = widget.plot.rep;
      if (currentRep != null) {
        bool isLastInRep = true;
        for (int i = widget.currentPlotIndex + 1; i < widget.allPlots.length; i++) {
          if (widget.allPlots[i].rep == currentRep) {
            isLastInRep = false;
            break;
          }
        }
        if (isLastInRep) {
          HapticFeedback.mediumImpact();
        }
      }
    }

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

  Future<void> _undoRating(BuildContext context, RatingRecord existing) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Undo Rating'),
        content: Text(
            'Undo rating for Plot ${getDisplayPlotLabel(widget.plot, widget.allPlots)} – ${_currentAssessment.name}?'),
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

    if (confirm != true) {
      return;
    }

    final userId = await ref.read(currentUserIdProvider.future);
    final useCase = ref.read(undoRatingUseCaseProvider);
    final result = await useCase.execute(
      currentRatingId: existing.id,
      sessionId: widget.session.id,
      isSessionClosed: widget.session.endedAt != null,
      raterName: widget.session.raterName,
      performedByUserId: userId,
    );
    if (!mounted) return;
    if (!result.success) {
      if (result.errorMessage == kClosedSessionBlockedMessage) {
        ref.read(diagnosticsStoreProvider).recordError(
              result.errorMessage!,
              code: 'closed_session_write_blocked',
            );
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Undo failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showFlagDialog(BuildContext context) async {
    final descController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Flag Plot ${getDisplayPlotLabel(widget.plot, widget.allPlots)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: kQuickNoteTemplates.map((label) {
                return ActionChip(
                  label: Text(label),
                  onPressed: () {
                    final before = descController.text.trim();
                    descController.text = before.isEmpty ? label : '$before, $label';
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                hintText: 'e.g. Weed patch, border effect',
              ),
              autofocus: true,
            ),
          ],
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
                      description: drift.Value(descController.text.trim()),
                      raterName: drift.Value(widget.session.raterName),
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
      case 'RECORDED':
        return 'Recorded';
      case 'NOT_OBSERVED':
        return 'Not Observed';
      case 'NOT_APPLICABLE':
        return 'N/A';
      case 'MISSING_CONDITION':
        return 'Missing';
      case 'TECHNICAL_ISSUE':
        return 'Tech Issue';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'RECORDED':
        return Colors.green;
      case 'NOT_OBSERVED':
        return Colors.orange;
      case 'NOT_APPLICABLE':
        return Colors.blue;
      case 'MISSING_CONDITION':
        return Colors.red;
      case 'TECHNICAL_ISSUE':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class _PhotoViewerScreen extends StatefulWidget {
  final List<Photo> photos;
  final int initialIndex;

  const _PhotoViewerScreen({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1}/${photos.length}'),
      ),
      body: SafeArea(
        child: PageView.builder(
          controller: _controller,
          itemCount: photos.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) {
            final p = photos[i];
            final file = File(p.filePath);
            final exists = file.existsSync();

            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: exists
                          ? InteractiveViewer(
                              child: Image.file(file, fit: BoxFit.contain),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image,
                                    size: 60, color: Colors.white70),
                                const SizedBox(height: 10),
                                const Text('File not found',
                                    style: TextStyle(color: Colors.white70)),
                                const SizedBox(height: 6),
                                Text(
                                  p.filePath,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white54),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    p.filePath,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  if (p.caption != null && p.caption!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Caption: ${p.caption}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
