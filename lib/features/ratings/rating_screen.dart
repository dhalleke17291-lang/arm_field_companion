import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/widgets/gradient_screen_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/plot_display.dart';
import '../../core/providers.dart';
import '../../core/session_lock.dart';
import '../../core/quick_note_templates.dart';
import '../../core/session_resume_store.dart';
import '../photos/photo_filename_helper.dart';
import '../photos/photo_viewer_screen.dart';
import '../photos/usecases/save_photo_usecase.dart';
import 'last_value_memory.dart';
import 'usecases/save_rating_usecase.dart';
import '../sessions/rating_order_sheet.dart';
import '../sessions/session_detail_screen.dart';

/// Status options for the rating result; maps to persisted resultStatus values.
enum RatingStatus {
  recorded,
  notObserved,
  na,
  missing,
  techIssue,
}

String _statusToValue(RatingStatus s) {
  switch (s) {
    case RatingStatus.recorded:
      return 'RECORDED';
    case RatingStatus.notObserved:
      return 'NOT_OBSERVED';
    case RatingStatus.na:
      return 'NOT_APPLICABLE';
    case RatingStatus.missing:
      return 'MISSING_CONDITION';
    case RatingStatus.techIssue:
      return 'TECHNICAL_ISSUE';
  }
}

class RatingScreen extends ConsumerStatefulWidget {
  final Trial trial;
  final Session session;
  final Plot plot;
  final List<Assessment> assessments;
  final List<Plot> allPlots;
  final int currentPlotIndex;

  /// Restored from session resume (field speed). When set, open on this assessment chip.
  final int? initialAssessmentIndex;

  const RatingScreen({
    super.key,
    required this.trial,
    required this.session,
    required this.plot,
    required this.assessments,
    required this.allPlots,
    required this.currentPlotIndex,
    this.initialAssessmentIndex,
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

  static const String _kLastRaterNameKey = 'last_rater_name';
  String? _raterName;
  String _confidence = 'certain';

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
  final Set<String> _selectedMissingReasons = {};

  // Photos
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final raw = widget.initialAssessmentIndex ?? 0;
    _assessmentIndex = raw.clamp(0, widget.assessments.length - 1);
    _currentAssessment = widget.assessments[_assessmentIndex];
    WakelockPlus.enable();
    SharedPreferences.getInstance().then((prefs) {
      final last = prefs.getString(_kLastRaterNameKey);
      if (last != null && last.trim().isNotEmpty && mounted) {
        setState(() => _raterName = last.trim());
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _saveResumePosition();
    _valueController.dispose();
    super.dispose();
  }

  void _saveResumePosition() {
    SharedPreferences.getInstance().then((prefs) {
      SessionResumeStore(prefs).savePosition(
        widget.session.id,
        widget.currentPlotIndex,
        _assessmentIndex,
      );
    });
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
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: GradientScreenHeader(
        title: 'Plot ${getDisplayPlotLabel(widget.plot, widget.allPlots)}',
        subtitle: widget.session.raterName != null
            ? 'Session ${widget.session.id} · ${widget.session.raterName}'
            : 'Session ${widget.session.id}',
        titleFontSize: 17,
        actions: [
          _buildOfflineIndicator(),
          _buildFlagButton(context),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'rating_order') _showRatingOrderSheet(context);
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'rating_order',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_vert, size: 20),
                    SizedBox(width: 12),
                    Text('Set rating order'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 100,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPlotInfoBar(context),
                    _buildProgressBar(context),
                    if (!isSessionEditable(widget.session))
                      _buildClosedSessionBanner(context),
                    _buildPhotoStrip(context),
                    _buildAssessmentSelector(context),
                    existingRatingAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, st) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text('Error: $e')),
                      ),
                      data: (existing) => _buildRatingArea(context, existing),
                    ),
                  ],
                ),
              ),
            ),
            _buildBottomBar(context),
          ],
        ),
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
            Icon(Icons.lock,
                color: Theme.of(context).colorScheme.onErrorContainer,
                size: 20),
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
      final docsDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${docsDir.path}/photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      final existingPhotos = await ref.read(photoRepositoryProvider).getPhotosForPlotInSession(
        trialId: widget.trial.id,
        plotPk: widget.plot.id,
        sessionId: widget.session.id,
      );
      final sequenceNumber = existingPhotos.length + 1;
      final plotLabel = getDisplayPlotLabel(widget.plot, widget.allPlots);
      final capturedAt = DateTime.now();
      final fileName = generatePhotoFileName(
        trialId: widget.trial.id,
        plotLabel: plotLabel,
        sessionId: widget.session.id,
        capturedAt: capturedAt,
        sequenceNumber: sequenceNumber,
      );
      final finalPath = '${photosDir.path}/$fileName';

      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (shot == null) {
        return;
      }

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
        builder: (_) => PhotoViewerScreen(
          photos: photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildValueSectionPhotoButton(BuildContext context) {
    final photosAsync = ref.watch(
      photosForPlotProvider(
        PhotosForPlotParams(
          trialId: widget.trial.id,
          plotPk: widget.plot.id,
          sessionId: widget.session.id,
        ),
      ),
    );
    final hasPhotos = photosAsync.valueOrNull != null &&
        photosAsync.valueOrNull!.isNotEmpty;
    final count = photosAsync.valueOrNull?.length ?? 0;
    final color = hasPhotos
        ? const Color(0xFF2D5A40)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _capturePhoto(context),
        onLongPress: () => _showPhotoViewerBottomSheet(context),
        child: SizedBox(
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 32,
                  color: color,
                ),
              ),
              if (count > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D5A40),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhotoViewerBottomSheet(BuildContext context) {
    final plotLabel = getDisplayPlotLabel(widget.plot, widget.allPlots);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (modalContext) => Consumer(
        builder: (context, ref, _) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => _PhotoViewerSheetContent(
            ref: ref,
            trialId: widget.trial.id,
            plotPk: widget.plot.id,
            sessionId: widget.session.id,
            plotLabel: plotLabel,
            scrollController: scrollController,
          ),
        ),
      ),
    );
  }

  // ===== UI =====

  Widget _buildOfflineIndicator() {
    return const SizedBox.shrink();
  }

  Widget _buildFlagButton(BuildContext context) {
    final flagsAsync = ref.watch(
        plotFlagsForPlotSessionProvider((widget.plot.id, widget.session.id)));
    return flagsAsync.when(
      data: (flags) {
        final isFlagged = flags.isNotEmpty;
        return IconButton(
          icon: Icon(
            isFlagged ? Icons.flag : Icons.flag_outlined,
            color: isFlagged
                ? AppDesignTokens.flagColor
                : AppDesignTokens.secondaryText,
          ),
          onPressed: () => _toggleFlag(context),
          onLongPress: () => _showFlagDialog(context),
          tooltip: isFlagged
              ? 'Remove flag (tap). Add note (long-press)'
              : 'Flag plot (tap). Add note (long-press)',
        );
      },
      loading: () => const IconButton(
        icon: Icon(Icons.flag_outlined, color: Colors.white),
        onPressed: null,
        tooltip: 'Flag plot',
      ),
      error: (_, __) => IconButton(
        icon: const Icon(Icons.flag_outlined, color: Colors.white),
        onPressed: () => _showFlagDialog(context),
        tooltip: 'Flag plot',
      ),
    );
  }

  void _showRatingOrderSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => RatingOrderSheetContent(
        session: widget.session,
        assessments: List.from(widget.assessments),
        ref: ref,
        onSaved: () {
          ref.invalidate(sessionAssessmentsProvider(widget.session.id));
          if (ctx.mounted) Navigator.pop(ctx);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Rating order updated. It will apply when you start or continue a session.',
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _toggleFlag(BuildContext context) async {
    final flags = ref
            .read(plotFlagsForPlotSessionProvider(
                (widget.plot.id, widget.session.id)))
            .value ??
        [];
    final db = ref.read(databaseProvider);
    if (flags.isNotEmpty) {
      await (db.delete(db.plotFlags)
            ..where((f) =>
                f.plotPk.equals(widget.plot.id) &
                f.sessionId.equals(widget.session.id)))
          .go();
      ref.invalidate(flaggedPlotIdsForSessionProvider(widget.session.id));
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
      ref.invalidate(flaggedPlotIdsForSessionProvider(widget.session.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plot flagged')),
        );
      }
    }
  }

  Widget _buildPlotInfoBar(BuildContext context) {
    final plotCtx = ref.watch(plotContextProvider(widget.plot.id));
    final plotLabel = getDisplayPlotLabel(widget.plot, widget.allPlots);
    final subtitleParts = <String>[
      widget.trial.name,
      widget.session.name,
      if (widget.plot.rep != null) 'Rep ${widget.plot.rep}',
    ];
    final subtitle = subtitleParts.join(' · ');
    return Container(
      margin: const EdgeInsets.fromLTRB(AppDesignTokens.spacing16,
          AppDesignTokens.spacing16, AppDesignTokens.spacing16, 0),
      padding: const EdgeInsets.all(AppDesignTokens.spacing16),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: AppDesignTokens.cardShadowRating,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plot $plotLabel',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppDesignTokens.primaryText,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppDesignTokens.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              plotCtx.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (ctx) => ctx.hasTreatment
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppDesignTokens.primary,
                          borderRadius:
                              BorderRadius.circular(AppDesignTokens.radiusCard),
                        ),
                        child: Text(
                          ctx.treatmentCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.currentPlotIndex + 1} of ${widget.allPlots.length}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppDesignTokens.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Take photo',
                icon: const Icon(Icons.photo_camera,
                    size: 22, color: AppDesignTokens.secondaryText),
                onPressed: () => _capturePhoto(context),
              ),
              if (widget.session.raterName != null)
                Text(
                  widget.session.raterName!,
                  style: const TextStyle(
                      color: AppDesignTokens.secondaryText, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final plotProgress = (widget.currentPlotIndex + 1) / widget.allPlots.length;
    return SizedBox(
      height: 6,
      width: double.infinity,
      child: LinearProgressIndicator(
        value: plotProgress,
        minHeight: 6,
        backgroundColor: AppDesignTokens.backgroundSurface,
        valueColor:
            const AlwaysStoppedAnimation<Color>(AppDesignTokens.primary),
      ),
    );
  }

  Widget _buildAssessmentSelector(BuildContext context) {
    if (widget.assessments.length == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
            AppDesignTokens.spacing16,
            AppDesignTokens.spacing16,
            AppDesignTokens.spacing16,
            AppDesignTokens.spacing8),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppDesignTokens.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppDesignTokens.spacing8),
            Text(
              _currentAssessment.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppDesignTokens.primaryText,
              ),
            ),
            if (_currentAssessment.unit != null) ...[
              const SizedBox(width: 6),
              Text(
                '· ${_currentAssessment.unit}',
                style: const TextStyle(
                    fontSize: 13, color: AppDesignTokens.secondaryText),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDesignTokens.spacing16,
          AppDesignTokens.spacing16,
          AppDesignTokens.spacing16,
          AppDesignTokens.spacing8),
      child: SizedBox(
        height: 36,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0;
                  index < widget.assessments.length;
                  index++) ...[
                if (index > 0) const SizedBox(width: AppDesignTokens.spacing8),
                _buildAssessmentChip(context, index),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssessmentChip(BuildContext context, int index) {
    final assessment = widget.assessments[index];
    final isSelected = assessment.id == _currentAssessment.id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _assessmentIndex = index;
          _currentAssessment = assessment;
          _valueController.clear();
          _selectedStatus = 'RECORDED';
          _selectedMissingReasons.clear();
        });
        _prefillFromLastValue();
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppDesignTokens.primary
              : AppDesignTokens.cardSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppDesignTokens.borderCrisp),
        ),
        alignment: Alignment.center,
        child: Text(
          assessment.name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppDesignTokens.secondaryText,
          ),
        ),
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
    final effectiveStatus = hasCorrection
        ? correctionAsync.value!.newResultStatus
        : existing.resultStatus;
    final effectiveNumeric = hasCorrection
        ? correctionAsync.value!.newNumericValue
        : existing.numericValue;
    final effectiveText = hasCorrection
        ? correctionAsync.value!.newTextValue
        : existing.textValue;
    final displayValue = effectiveStatus == 'RECORDED'
        ? (effectiveNumeric?.toString() ?? '-')
        : (effectiveText?.isNotEmpty == true
            ? effectiveText!
            : effectiveStatus);

    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: hasCorrection ? Colors.amber.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color:
                hasCorrection ? Colors.amber.shade200 : Colors.green.shade200),
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
                  child:
                      const Text('Undo', style: TextStyle(color: Colors.red)),
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
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  Wrap(
                    spacing: 6,
                    children: [
                      'RECORDED',
                      'NOT_OBSERVED',
                      'NOT_APPLICABLE',
                      'MISSING_CONDITION',
                      'TECHNICAL_ISSUE'
                    ]
                        .map((s) => ChoiceChip(
                              label:
                                  Text(s, style: const TextStyle(fontSize: 11)),
                              selected: newStatus == s,
                              onSelected: (_) => setState(() => newStatus = s),
                            ))
                        .toList(),
                  ),
                  if (newStatus == 'RECORDED') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: newValueController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
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
                      const SnackBar(content: Text('Reason is required')),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing16,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (existing != null) _buildCurrentOrCorrectedRow(context, existing),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDesignTokens.spacing16, vertical: 12),
            decoration: BoxDecoration(
              color: AppDesignTokens.cardSurface,
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
              border: Border.all(color: AppDesignTokens.borderCrisp),
              boxShadow: AppDesignTokens.cardShadowRating,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('STATUS'),
                const SizedBox(height: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _statusCard(
                                context, 'Recorded', RatingStatus.recorded)),
                        const SizedBox(width: 6),
                        Expanded(
                            child: _statusCard(context, 'Not observed',
                                RatingStatus.notObserved)),
                        const SizedBox(width: 6),
                        Expanded(
                            child: _statusCard(
                                context, 'N/A', RatingStatus.na)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                            child: _statusCard(
                                context, 'Missing', RatingStatus.missing)),
                        const SizedBox(width: 6),
                        Expanded(
                            child: _statusCard(context, 'Tech issue',
                                RatingStatus.techIssue)),
                      ],
                    ),
                  ],
                ),
                if (_selectedStatus == 'MISSING_CONDITION' ||
                    _selectedStatus == 'TECHNICAL_ISSUE') ...[
                  const SizedBox(height: 12),
                  Text('Reason',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showReasonSheet(context),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFE0DDD6), width: 1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedMissingReasons.isEmpty
                                  ? 'Select reason...'
                                  : '${_selectedStatus == 'MISSING_CONDITION' ? 'Missing' : 'Tech issue'} · ${_selectedMissingReasons.join(', ')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: _selectedMissingReasons.isEmpty
                                    ? Colors.grey.shade400
                                    : _missingActiveColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            _selectedMissingReasons.isEmpty
                                ? Icons.chevron_right
                                : Icons.edit_outlined,
                            size: 16,
                            color: _selectedMissingReasons.isEmpty
                                ? Colors.grey
                                : _missingActiveColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if ((_selectedStatus == 'MISSING_CONDITION' ||
                        _selectedStatus == 'TECHNICAL_ISSUE') &&
                    _selectedMissingReasons.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    color: const Color(0xFFFEF9EE),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: Color(0xFFB45309),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${_selectedStatus == 'MISSING_CONDITION' ? 'Missing' : 'Tech issue'} · ${_selectedMissingReasons.join(', ')}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB45309),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showReasonSheet(context),
                          child: const Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2D5A40),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_selectedStatus == 'RECORDED') ...[
                  const SizedBox(height: 14),
                  Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
                  _sectionLabel('RATER'),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _showRaterSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Theme.of(context)
                                .colorScheme.outline
                                .withValues(alpha: 0.6)),
                        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline,
                              size: 18,
                              color: Theme.of(context)
                                  .colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text(
                            _raterName != null &&
                                    _raterName!.trim().isNotEmpty
                                ? '$_raterName ▾'
                                : 'Set rater',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _sectionLabel('VALUE'),
                  _buildValueSectionPhotoButton(context),
                  if (_isTextAssessment) ...[
                    const SizedBox(height: AppDesignTokens.spacing8),
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
                        fillColor: AppDesignTokens.cardSurface,
                      ),
                      autofocus: true,
                    ),
                  ] else if (_hasScaleDefined) ...[
                    const SizedBox(height: AppDesignTokens.spacing8),
                    Text(
                      _valueController.text.trim().isEmpty
                          ? '${_currentAssessment.minValue}'
                          : _valueController.text,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: AppDesignTokens.primaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_currentAssessment.unit != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _currentAssessment.unit!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppDesignTokens.spacing16),
                    Slider(
                      value: _sliderValue,
                      min: _currentAssessment.minValue!,
                      max: _currentAssessment.maxValue!,
                      divisions: _sliderDivisions,
                      onChanged: (v) {
                        setState(() {
                          _valueController.text = _sliderDivisions != null
                              ? v.round().toString()
                              : v.toStringAsFixed(1);
                        });
                      },
                    ),
                    if (_showValidRangeWarning) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Value outside recommended range',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ] else ...[
                    if (_currentAssessment.minValue != null ||
                        _currentAssessment.maxValue != null ||
                        _currentAssessment.unit != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Scale: ${_currentAssessment.minValue ?? "?"}–${_currentAssessment.maxValue ?? "?"}${_currentAssessment.unit != null ? " ${_currentAssessment.unit}" : ""}',
                        style: const TextStyle(
                          color: AppDesignTokens.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppDesignTokens.spacing8),
                    TextField(
                      controller: _valueController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppDesignTokens.primaryText,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: '0',
                        suffixText: _currentAssessment.unit,
                        filled: true,
                        fillColor: AppDesignTokens.cardSurface,
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: AppDesignTokens.spacing12),
                    _buildQuickButtons(),
                  ],
                ],
                if (_selectedStatus == 'RECORDED') ...[
                  _sectionLabel('CONFIDENCE'),
                  const SizedBox(height: 4),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'certain', label: _confidenceLabel('Certain')),
                      ButtonSegment(value: 'uncertain', label: _confidenceLabel('Uncertain')),
                      ButtonSegment(value: 'estimated', label: _confidenceLabel('Estimated')),
                    ],
                    selected: {_confidence},
                    onSelectionChanged: (Set<String> s) {
                      setState(() => _confidence = s.first);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _confidenceLabel(String text) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13),
    );
  }

  Future<void> _showRaterSheet(BuildContext context) async {
    final controller = TextEditingController(text: _raterName ?? '');
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Rater name',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Enter rater name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  setState(() => _raterName = name.isEmpty ? null : name);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(
                      _kLastRaterNameKey, name.isEmpty ? '' : name);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isTextAssessment =>
      _currentAssessment.dataType.toLowerCase() == 'text';

  bool get _hasScaleDefined =>
      _currentAssessment.minValue != null &&
      _currentAssessment.maxValue != null;

  double get _sliderValue {
    final min = _currentAssessment.minValue!;
    final max = _currentAssessment.maxValue!;
    final v = double.tryParse(_valueController.text);
    if (v == null) return min;
    return v.clamp(min, max);
  }

  int? get _sliderDivisions {
    final min = _currentAssessment.minValue!;
    final max = _currentAssessment.maxValue!;
    final range = (max - min).abs();
    if (range <= 0) return null;
    if (range <= 100 && min == min.roundToDouble() && max == max.roundToDouble()) {
      return range.round();
    }
    return null;
  }

  bool get _showValidRangeWarning {
    return false;
  }

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
              color: isSelected
                  ? AppDesignTokens.primary
                  : AppDesignTokens.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppDesignTokens.primary
                    : AppDesignTokens.borderCrisp,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? AppDesignTokens.primaryTintStrong
                      : AppDesignTokens.shadowVeryLight,
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
                  color:
                      isSelected ? Colors.white : AppDesignTokens.primaryText,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showReasonSheet(BuildContext context) async {
    Set<String> selected = Set.from(_selectedMissingReasons);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            top: false,
            bottom: true,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Select reason',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _missingReasons.map((reason) {
                          final isSelected = selected.contains(reason);
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  selected.remove(reason);
                                } else {
                                  selected.add(reason);
                                }
                              });
                            },
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFEF9EE)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  width: 1,
                                  color: isSelected
                                      ? const Color(0xFFF59E0B)
                                      : Colors.grey,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                reason,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFFB45309)
                                      : Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _selectedMissingReasons.clear();
                            _selectedMissingReasons.addAll(selected);
                          });
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Done'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Persistent next-action dock: same location, same order, every time.
  /// Plot + Assessment + Treatment at top; Save (secondary) + Save & Next (primary); Prev, Jump, Flag below.
  Widget _buildBottomBar(BuildContext context) {
    final isLastPlot = widget.currentPlotIndex >= widget.allPlots.length - 1;
    final isLastAssessment = _assessmentIndex >= widget.assessments.length - 1;
    final isVeryLast = isLastPlot && isLastAssessment;
    final canGoBack = widget.currentPlotIndex > 0;
    final plotLabel = getDisplayPlotLabel(widget.plot, widget.allPlots);
    final assessmentLabel = _currentAssessment.name;

    // Dynamic primary button label
    String primaryLabel;
    if (isVeryLast) {
      primaryLabel = 'Save & Finish';
    } else if (isLastAssessment) {
      primaryLabel = 'Save & Next Plot';
    } else {
      primaryLabel = 'Save & Next';
    }

    final plotCtx = ref.watch(plotContextProvider(widget.plot.id));
    final ctx = plotCtx.valueOrNull;
    final treatmentCode =
        ctx != null && ctx.hasTreatment ? ctx.treatmentCode : null;

    final editable = isSessionEditable(widget.session);

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        decoration: const BoxDecoration(
          color: AppDesignTokens.cardSurface,
          border: Border(top: BorderSide(color: AppDesignTokens.borderCrisp)),
          boxShadow: [
            BoxShadow(
              color: AppDesignTokens.shadowMedium,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dock header: Plot · Assessment, treatment muted
          Row(
            children: [
              Text(
                'Plot $plotLabel',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              Text(
                ' · $assessmentLabel',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppDesignTokens.primaryText,
                ),
              ),
            ],
          ),
          if (treatmentCode != null) ...[
            const SizedBox(height: 2),
            Text(
              'Treatment $treatmentCode',
              style: const TextStyle(
                fontSize: 12,
                color: AppDesignTokens.secondaryText,
              ),
            ),
          ],
          const SizedBox(height: 6),
          // Main actions: Save (outlined) + Save & Next (primary, dominant)
          Row(
            children: [
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _isSaving || !editable
                        ? null
                        : () => _saveRating(context, navigateAfterSave: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppDesignTokens.primary,
                      side:
                          const BorderSide(color: AppDesignTokens.borderCrisp),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDesignTokens.spacing8),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving || !editable
                        ? null
                        : () => _saveRating(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignTokens.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppDesignTokens.divider,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  primaryLabel,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  softWrap: false,
                                  textAlign: TextAlign.center,
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
            ],
          ),
          const SizedBox(height: 6),
          // Secondary: Prev, Jump, Flag (small)
          Row(
            children: [
              TextButton.icon(
                onPressed:
                    canGoBack ? () => _navigatePlot(context, -1) : null,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Prev', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  foregroundColor: AppDesignTokens.secondaryText,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showJumpToPlotDialog(context),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Jump', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  foregroundColor: AppDesignTokens.secondaryText,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showFlagDialog(context),
                icon: const Icon(Icons.flag_outlined, size: 20),
                tooltip: 'Flag plot',
                style: IconButton.styleFrom(
                  foregroundColor: AppDesignTokens.secondaryText,
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }

  Future<void> _showJumpToPlotDialog(BuildContext context) async {
    if (widget.allPlots.isEmpty) return;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jump to Plot'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Plot number',
            hintText: 'e.g. 101',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          keyboardType: TextInputType.number,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    if (!context.mounted) return;
    final index = widget.allPlots.indexWhere(
      (p) => getDisplayPlotLabel(p, widget.allPlots) == result,
    );
    if (index < 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plot "$result" not found')),
        );
      }
      return;
    }
    if (index == widget.currentPlotIndex) return;
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RatingScreen(
          trial: widget.trial,
          session: widget.session,
          plot: widget.allPlots[index],
          assessments: widget.assessments,
          allPlots: widget.allPlots,
          currentPlotIndex: index,
          initialAssessmentIndex: null,
        ),
      ),
    );
  }

  // ===== Actions =====

  /// Saves the current rating. When [navigateAfterSave] is true (default), advances to next
  /// assessment or next plot or shows session complete; when false, stays on current plot/assessment.
  Future<void> _saveRating(BuildContext context,
      {bool navigateAfterSave = true}) async {
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
      textValue = _selectedMissingReasons.isEmpty
          ? null
          : _selectedMissingReasons.join(', ');
    }

    setState(() => _isSaving = true);

    final userId = await ref.read(currentUserIdProvider.future);
    final now = DateTime.now();
    final ratingTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
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
        raterName: _raterName?.trim().isNotEmpty == true
            ? _raterName
            : widget.session.raterName,
        performedByUserId: userId,
        isSessionClosed: widget.session.endedAt != null,
        minValue: _currentAssessment.minValue,
        maxValue: _currentAssessment.maxValue,
        ratingTime: ratingTime,
        confidence: _confidence,
      ),
    );

    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);

    if (result.isSuccess) {
      if (_raterName != null && _raterName!.trim().isNotEmpty) {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString(_kLastRaterNameKey, _raterName!.trim());
        });
      }
      ref.invalidate(sessionRatingsProvider(widget.session.id));
      ref.invalidate(ratedPlotPksProvider(widget.session.id));
      if (numericValue != null) {
        ref.read(lastValueMemoryProvider.notifier).set(
              widget.session.id,
              _currentAssessment.id,
              numericValue,
            );
      }
      if (!navigateAfterSave) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved')),
          );
        }
        return;
      }
      if (_assessmentIndex < widget.assessments.length - 1) {
        setState(() {
          _assessmentIndex++;
          _currentAssessment = widget.assessments[_assessmentIndex];
          _valueController.clear();
          _selectedStatus = 'RECORDED';
          _selectedMissingReasons.clear();
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
        ref
            .read(diagnosticsStoreProvider)
            .recordError(msg, code: 'closed_session_write_blocked');
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
    final flaggedIds = await ref
        .read(flaggedPlotIdsForSessionProvider(widget.session.id).future);
    final flaggedCount = flaggedIds.length;
    final photoCount = await ref
        .read(photoRepositoryProvider)
        .getPhotoCountForSession(widget.session.id);
    final plotCount = widget.allPlots.length;
    final summary =
        '$plotCount plots rated · $flaggedCount flagged · $photoCount photos';

    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDesignTokens.backgroundSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge)),
        contentPadding: EdgeInsets.zero,
        titlePadding: EdgeInsets.zero,
        content: Padding(
          padding: const EdgeInsets.all(AppDesignTokens.spacing24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppDesignTokens.successBg,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(Icons.check_circle,
                    color: AppDesignTokens.primary, size: 36),
              ),
              const SizedBox(height: AppDesignTokens.spacing16),
              const Text(
                'All Plots Rated',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              const SizedBox(height: AppDesignTokens.spacing8),
              Text(
                "You've completed all $plotCount plots in this session.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppDesignTokens.secondaryText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppDesignTokens.spacing8),
              Text(
                summary,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppDesignTokens.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDesignTokens.spacing24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SessionDetailScreen(
                          trial: widget.trial,
                          session: widget.session,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppDesignTokens.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDesignTokens.radiusCard)),
                  ),
                  child: const Text('Back to Session',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: AppDesignTokens.spacing8 + 2),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Keep reviewing plots',
                  style: TextStyle(
                      color: AppDesignTokens.secondaryText, fontSize: 13),
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
        for (int i = widget.currentPlotIndex + 1;
            i < widget.allPlots.length;
            i++) {
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

    // Sequence resets for each new plot: always start at first assessment (A1).
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
          initialAssessmentIndex: null,
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
    if (result.success) {
      ref.invalidate(sessionRatingsProvider(widget.session.id));
      ref.invalidate(ratedPlotPksProvider(widget.session.id));
    } else {
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
        title: Text(
            'Flag Plot ${getDisplayPlotLabel(widget.plot, widget.allPlots)}'),
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
                    descController.text =
                        before.isEmpty ? label : '$before, $label';
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

  static const Color _missingActiveColor = Color(0xFFB45309);

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 14),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _statusCard(
    BuildContext context,
    String label,
    RatingStatus status,
  ) {
    final String value = _statusToValue(status);
    final bool isSelected = _selectedStatus == value;
    Color bgColor = Colors.white;
    Color borderColor = const Color(0xFFE0DDD6);
    Color textColor = Colors.grey.shade500;
    if (isSelected) {
      switch (status) {
        case RatingStatus.recorded:
          bgColor = const Color(0xFFE8F5EE);
          borderColor = const Color(0xFF2D5A40);
          textColor = const Color(0xFF2D5A40);
          break;
        case RatingStatus.missing:
        case RatingStatus.techIssue:
          bgColor = const Color(0xFFFEF9EE);
          borderColor = const Color(0xFFF59E0B);
          textColor = const Color(0xFFB45309);
          break;
        case RatingStatus.notObserved:
        case RatingStatus.na:
          bgColor = const Color(0xFFF1EFE8);
          borderColor = const Color(0xFF888780);
          textColor = const Color(0xFF444441);
          break;
      }
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = value;
          if (value != 'RECORDED') {
            _valueController.clear();
          }
          if (value != 'MISSING_CONDITION' && value != 'TECHNICAL_ISSUE') {
            _selectedMissingReasons.clear();
          }
        });
      },
      child: Container(
        width: double.infinity,
        height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(width: 1, color: borderColor),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

}

class _PhotoViewerSheetContent extends StatelessWidget {
  final WidgetRef ref;
  final int trialId;
  final int plotPk;
  final int sessionId;
  final String plotLabel;
  final ScrollController scrollController;

  const _PhotoViewerSheetContent({
    required this.ref,
    required this.trialId,
    required this.plotPk,
    required this.sessionId,
    required this.plotLabel,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final photosAsync = ref.watch(
      photosForPlotProvider(
        PhotosForPlotParams(
          trialId: trialId,
          plotPk: plotPk,
          sessionId: sessionId,
        ),
      ),
    );
    return photosAsync.when(
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      )),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Could not load photos: $e'),
      ),
      data: (photos) {
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            const SliverToBoxAdapter(
              child: SizedBox(height: 12),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Plot $plotLabel · ${photos.length} photo${photos.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final p = photos[index];
                    final file = File(p.filePath);
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => PhotoViewerScreen(
                              photos: photos,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      onLongPress: () => _confirmDeletePhoto(
                            context,
                            ref,
                            p,
                            trialId: trialId,
                            plotPk: plotPk,
                            sessionId: sessionId,
                          ),
                      borderRadius: BorderRadius.circular(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: file.existsSync()
                            ? Image.file(file, fit: BoxFit.cover)
                            : Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Icon(Icons.broken_image, color: Colors.grey),
                                ),
                              ),
                      ),
                    );
                  },
                  childCount: photos.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Text(
                  'Photos for this plot and session. Tap to view full screen, long-press to delete.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _confirmDeletePhoto(
    BuildContext context,
    WidgetRef ref,
    Photo photo, {
    required int trialId,
    required int plotPk,
    required int sessionId,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text(
          'This photo will be removed. The file may remain on device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(photoRepositoryProvider).deletePhoto(photo.id);
      ref.invalidate(
        photosForPlotProvider(
          PhotosForPlotParams(
            trialId: trialId,
            plotPk: plotPk,
            sessionId: sessionId,
          ),
        ),
      );
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
